# AVA Issue #220 — Safe Port Audit

Date: 2026-10-17  
Target repository: `hv2znbvdy9-glitch/AVA`  
Related change: [`69-007/AVA#149`](https://github.com/69-007/AVA/pull/149)  
Reviewed source commit: [`76a40bd4a9f5d791e8f0d19e3eb075667c7eead7`](https://github.com/69-007/AVA/commit/76a40bd4a9f5d791e8f0d19e3eb075667c7eead7)

## Decision

**Do not copy the related Python security/package patch into the target repository unchanged.** The source patch resolves the `ava/security.py` versus `ava/security/` name collision and changes setuptools package discovery, but its authentication defaults remain unsafe. The target repository's current `main` has a different project layout and does not contain the source `pyproject.toml` or the matching `ava/security/` package at the expected paths.

This branch records the evidence and acceptance gates. It does not change `main`, merge code, launch a workflow, or claim that local Windows tests ran.

## Evidence

1. The related PR is merged in `69-007/AVA`: [PR #149](https://github.com/69-007/AVA/pull/149).
2. Its merge commit deletes `ava/security.py`, adds package marker files, extends `ava/security/__init__.py`, and changes `pyproject.toml` from a hard-coded package list to setuptools package discovery.
3. In the source repository's current `ava/security/auth.py`, `AVA_ADMIN_API_KEY` still falls back to the literal `devito-master-key-001`. The password hash still falls back to SHA-256 of the placeholder `YourSecurePasswordHere_ChangeMe`. Thus an unset environment variable does not fail closed.
4. The source `ava/security/__init__.py` exports `ADMIN_API_KEYS`, `OWNER_PASSWORD_HASH`, and owner identity fields. This is not needed for a safe public import surface and may expose authentication internals.
5. The target repository's current `ava/__init__.py` exports the policy-guard API from `ava.policy`; its `README.md` describes a JavaScript CLI/library and the repository's existing Python checks target the policy guard. No matching `pyproject.toml`, `ava/security.py`, or `ava/security/auth.py` was found on target `main` by the checks performed for this audit.

## Required changes before a security implementation can be accepted

- Make missing credentials fail closed: no default API key and no placeholder password hash.
- Do not export secrets, credential maps, password hashes, or owner identity details from a package's public `__init__`.
- Do not use raw SHA-256 for password storage; use a dedicated password-hashing scheme with appropriate parameters, or remove password authentication if it is not part of the target design.
- Define the intended Python distribution boundary first. Only then add/adjust `pyproject.toml` and verify that package discovery includes the intended modules without unintentionally packaging unrelated directories.
- Add isolated tests for imports, editable/package installation, missing and valid credentials, rejected fallback credentials, and public exports. Run them in GitHub Actions and inspect the actual logs before considering the change ready.
- If any non-placeholder credential was ever used or exposed, revoke/rotate it; deleting it from the current source alone does not invalidate it or remove it from history.

## Verification status

| Check | Result |
|---|---|
| Related PR and merge diff inspected | Complete |
| Authentication defaults reviewed | Unsafe defaults found |
| Target layout checked for matching Python packaging/security files | Layout mismatch found |
| Target Python import/package/auth tests executed | Not executed; no matching auth package to test |
| Windows laptop execution | Not executed from this session |
| GitHub Actions for this branch | Not dispatched |
| Merge to `main` | Not performed |

## Acceptance gate

This audit-only PR is intentionally a **draft**. It documents why the source patch cannot safely be ported verbatim. A separate implementation PR should follow only after the target repository's intended Python security/package scope is established and the security acceptance tests above are available.
