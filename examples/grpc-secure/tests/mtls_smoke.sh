#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
	printf 'usage: %s SERVER_BIN CLIENT_BIN OPENSSL_BIN\n' "$0" >&2
	exit 64
fi

server_bin=$1
client_bin=$2
openssl_bin=$3
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ava-grpc-mtls.XXXXXXXX")
server_pid=''
port=''
server_log="${test_root}/server.log"

cleanup() {
	if [[ -n "${server_pid}" ]] && kill -0 "${server_pid}" 2>/dev/null; then
		kill -TERM "${server_pid}" 2>/dev/null || true
		wait "${server_pid}" 2>/dev/null || true
	fi
	if [[ -n "${test_root}" && "${test_root}" == "${TMPDIR:-/tmp}/ava-grpc-mtls."* ]]; then
		rm -rf -- "${test_root}"
	fi
}
trap cleanup EXIT

fail() {
	printf 'mTLS smoke test failed: %s\n' "$1" >&2
	if [[ -f "${server_log}" ]]; then
		sed -n '1,120p' "${server_log}" >&2
	fi
	exit 1
}

"${openssl_bin}" genpkey -algorithm RSA \
	-pkeyopt rsa_keygen_bits:2048 -out "${test_root}/ca.key" >/dev/null 2>&1
"${openssl_bin}" req -x509 -new -sha256 -days 1 \
	-key "${test_root}/ca.key" \
	-subj '/CN=AVA gRPC test CA' \
	-addext 'basicConstraints=critical,CA:TRUE' \
	-addext 'keyUsage=critical,keyCertSign,cRLSign' \
	-out "${test_root}/ca.crt" >/dev/null 2>&1

"${openssl_bin}" genpkey -algorithm RSA \
	-pkeyopt rsa_keygen_bits:2048 -out "${test_root}/server.key" >/dev/null 2>&1
"${openssl_bin}" req -new -sha256 \
	-key "${test_root}/server.key" \
	-subj '/CN=localhost' \
	-addext 'basicConstraints=critical,CA:FALSE' \
	-addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
	-addext 'extendedKeyUsage=serverAuth' \
	-addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
	-out "${test_root}/server.csr" >/dev/null 2>&1
"${openssl_bin}" x509 -req -sha256 -days 1 \
	-in "${test_root}/server.csr" \
	-CA "${test_root}/ca.crt" \
	-CAkey "${test_root}/ca.key" \
	-CAcreateserial -copy_extensions copy \
	-out "${test_root}/server.crt" >/dev/null 2>&1

for identity in authorized.test unauthorized.test; do
	"${openssl_bin}" genpkey -algorithm RSA \
		-pkeyopt rsa_keygen_bits:2048 -out "${test_root}/${identity}.key" >/dev/null 2>&1
	"${openssl_bin}" req -new -sha256 \
		-key "${test_root}/${identity}.key" \
		-subj "/CN=${identity}" \
		-addext 'basicConstraints=critical,CA:FALSE' \
		-addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
		-addext 'extendedKeyUsage=clientAuth' \
		-addext "subjectAltName=DNS:${identity}" \
		-out "${test_root}/${identity}.csr" >/dev/null 2>&1
	"${openssl_bin}" x509 -req -sha256 -days 1 \
		-in "${test_root}/${identity}.csr" \
		-CA "${test_root}/ca.crt" \
		-CAkey "${test_root}/ca.key" \
		-CAserial "${test_root}/ca.srl" -copy_extensions copy \
		-out "${test_root}/${identity}.crt" >/dev/null 2>&1
done
chmod 0600 "${test_root}"/*.key

env \
	AVA_GRPC_BIND_ADDRESS='127.0.0.1:0' \
	AVA_GRPC_SERVER_CERT="${test_root}/server.crt" \
	AVA_GRPC_SERVER_KEY="${test_root}/server.key" \
	AVA_GRPC_CLIENT_CA="${test_root}/ca.crt" \
	AVA_GRPC_ALLOWED_IDENTITIES='authorized.test' \
	"${server_bin}" >"${server_log}" 2>&1 &
server_pid=$!

started=false
for _ in $(seq 1 100); do
	if grep -q '"event":"server_started"' "${server_log}" 2>/dev/null; then
		started=true
		break
	fi
	if ! kill -0 "${server_pid}" 2>/dev/null; then
		fail 'server exited before becoming ready'
	fi
	sleep 0.1
done
[[ "${started}" == true ]] || fail 'server did not become ready'
port=$(sed -n 's/.*"port":\([0-9][0-9]*\).*/\1/p' "${server_log}" | tail -n 1)
[[ "${port}" =~ ^[0-9]+$ ]] || fail 'server did not report its selected port'
((port >= 1 && port <= 65535)) || fail 'server reported an invalid selected port'

authorized_output=$(env \
	AVA_GRPC_TARGET="127.0.0.1:${port}" \
	AVA_GRPC_CLIENT_CERT="${test_root}/authorized.test.crt" \
	AVA_GRPC_CLIENT_KEY="${test_root}/authorized.test.key" \
	AVA_GRPC_SERVER_CA="${test_root}/ca.crt" \
	"${client_bin}" 'AVA') || fail 'authorized client call failed'
[[ "${authorized_output}" == 'Hello AVA' ]] || fail 'authorized response was unexpected'

set +e
unauthorized_output=$(env \
	AVA_GRPC_TARGET="127.0.0.1:${port}" \
	AVA_GRPC_CLIENT_CERT="${test_root}/unauthorized.test.crt" \
	AVA_GRPC_CLIENT_KEY="${test_root}/unauthorized.test.key" \
	AVA_GRPC_SERVER_CA="${test_root}/ca.crt" \
	"${client_bin}" 'AVA' 2>&1)
unauthorized_status=$?
set -e
[[ ${unauthorized_status} -ne 0 ]] || fail 'unauthorized identity was accepted'
[[ "${unauthorized_output}" == *'code 7'* ]] || fail 'unauthorized identity did not receive PERMISSION_DENIED'

kill -TERM "${server_pid}"
wait "${server_pid}" || fail 'server returned failure during graceful shutdown'
server_pid=''
grep -q '"event":"shutdown_complete"' "${server_log}" || \
	fail 'graceful shutdown completion was not logged'

printf 'mTLS smoke test passed\n'
