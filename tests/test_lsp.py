"""Tests for ava.lsp – BERK Language Server and supporting utilities.

Covers:
  - Stream-alive helpers (_is_stream_readable, _is_stream_writable)
  - LSP base-protocol codec (read_message / write_message)
  - BerkLanguageServer lifecycle and protocol handling
  - RestartManager exponential-backoff logic
  - Module entry-point (``python -m ava.lsp``)

Run directly (no pytest required):
    python tests/test_lsp.py
Or via pytest:
    pytest tests/test_lsp.py -v
"""

import io
import json
import sys
import os

# Make sure the project root is on the path when run directly
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ava.lsp.server import (
    BerkLanguageServer,
    StreamClosedError,
    _is_stream_readable,
    _is_stream_writable,
    read_message,
    write_message,
)
from ava.lsp.restart_manager import RestartManager


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------


def _make_request(method: str, req_id: int, params=None) -> dict:
    msg = {"jsonrpc": "2.0", "id": req_id, "method": method}
    if params is not None:
        msg["params"] = params
    return msg


def _make_notification(method: str, params=None) -> dict:
    msg = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        msg["params"] = params
    return msg


def _encode_message(msg: dict) -> bytes:
    body = json.dumps(msg).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    return header + body


def _write_session(buf: io.BytesIO, messages: list) -> None:
    """Encode *messages* into *buf* and seek to the beginning."""
    for msg in messages:
        buf.write(_encode_message(msg))
    buf.seek(0)


def _read_all_messages(buf: io.BytesIO) -> list:
    """Decode all LSP messages written to *buf*."""
    buf.seek(0)
    messages = []
    while True:
        msg = read_message(buf)
        if msg is None:
            break
        messages.append(msg)
    return messages


def _build_lsp_bytes(messages: list) -> bytes:
    """Encode a list of JSON-RPC messages into LSP wire format."""
    return b"".join(_encode_message(m) for m in messages)


# ---------------------------------------------------------------------------
# Stream-alive check tests
# ---------------------------------------------------------------------------


class TestStreamSafety:
    """Tests for stream-alive checks and error handling."""

    def test_open_stream_is_readable(self):
        buf = io.BytesIO(b"hello")
        assert _is_stream_readable(buf) is True

    def test_open_stream_is_writable(self):
        buf = io.BytesIO()
        assert _is_stream_writable(buf) is True

    def test_closed_stream_not_readable(self):
        buf = io.BytesIO(b"data")
        buf.close()
        assert _is_stream_readable(buf) is False

    def test_closed_stream_not_writable(self):
        buf = io.BytesIO()
        buf.close()
        assert _is_stream_writable(buf) is False

    def test_none_stream_not_readable(self):
        assert _is_stream_readable(None) is False

    def test_none_stream_not_writable(self):
        assert _is_stream_writable(None) is False

    def test_read_from_closed_stream_returns_none(self):
        buf = io.BytesIO(b"Content-Length: 2\r\n\r\nhi")
        buf.close()
        assert read_message(buf) is None

    def test_write_to_closed_stream_raises(self):
        buf = io.BytesIO()
        buf.close()
        try:
            write_message(buf, {"jsonrpc": "2.0", "method": "test"})
            assert False, "Expected StreamClosedError"
        except StreamClosedError:
            pass


# ---------------------------------------------------------------------------
# Message codec tests
# ---------------------------------------------------------------------------


class TestMessageCodec:
    """Tests for LSP message read/write."""

    def test_round_trip(self):
        msg = {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}
        buf = io.BytesIO()
        write_message(buf, msg)
        buf.seek(0)
        result = read_message(buf)
        assert result == msg

    def test_read_empty_stream(self):
        buf = io.BytesIO(b"")
        assert read_message(buf) is None

    def test_read_malformed_header(self):
        buf = io.BytesIO(b"Not-A-Valid-Header\r\n\r\n{}")
        # No Content-Length → returns None
        assert read_message(buf) is None

    def test_read_truncated_body(self):
        # Content-Length says 100 bytes but body is only 2
        buf = io.BytesIO(b"Content-Length: 100\r\n\r\n{}")
        assert read_message(buf) is None

    def test_multiple_messages(self):
        msgs = [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
            {"jsonrpc": "2.0", "method": "initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "shutdown"},
        ]
        buf = io.BytesIO()
        for m in msgs:
            write_message(buf, m)
        buf.seek(0)
        decoded = []
        while True:
            m = read_message(buf)
            if m is None:
                break
            decoded.append(m)
        assert decoded == msgs

    def test_unicode_content(self):
        msg = {"jsonrpc": "2.0", "method": "$/logTrace", "params": {"message": "hällo wörld 🌍"}}
        buf = io.BytesIO()
        write_message(buf, msg)
        buf.seek(0)
        result = read_message(buf)
        assert result == msg


# ---------------------------------------------------------------------------
# Server lifecycle tests
# ---------------------------------------------------------------------------


class TestServerLifecycle:
    """Tests for BerkLanguageServer lifecycle and protocol handling."""

    def test_server_creation(self):
        server = BerkLanguageServer(
            reader=io.BytesIO(b""), writer=io.BytesIO()
        )
        assert server.SERVER_NAME == "BERK Language Server"
        assert not server._running

    def test_server_exits_on_empty_input(self):
        server = BerkLanguageServer(
            reader=io.BytesIO(b""), writer=io.BytesIO()
        )
        server.start()
        assert not server._running

    def test_full_session(self):
        input_buf = io.BytesIO()
        _write_session(
            input_buf,
            [
                _make_request("initialize", 1, {"capabilities": {}}),
                _make_notification("initialized"),
                _make_request("shutdown", 2),
                _make_notification("exit"),
            ],
        )

        output_buf = io.BytesIO()
        server = BerkLanguageServer(reader=input_buf, writer=output_buf)
        server.start()

        responses = _read_all_messages(output_buf)
        assert len(responses) == 2  # initialize + shutdown responses
        assert "capabilities" in responses[0]["result"]
        assert responses[0]["result"]["serverInfo"]["name"] == "BERK Language Server"
        assert server._shutdown_requested

    def test_initialize_returns_capabilities(self):
        server = BerkLanguageServer(
            reader=io.BytesIO(b""), writer=io.BytesIO()
        )
        result = server._handle_initialize({})
        assert "capabilities" in result
        assert "serverInfo" in result
        assert result["capabilities"]["hoverProvider"] is True

    def test_unknown_method_returns_error(self):
        input_buf = io.BytesIO()
        _write_session(
            input_buf,
            [_make_request("nonexistent/method", 1)],
        )
        output_buf = io.BytesIO()
        server = BerkLanguageServer(reader=input_buf, writer=output_buf)
        server.start()

        responses = _read_all_messages(output_buf)
        assert len(responses) == 1
        assert "error" in responses[0]
        assert responses[0]["error"]["code"] == -32601

    def test_stream_destroyed_graceful_shutdown(self):
        """Reproduce the ERR_STREAM_DESTROYED scenario from the issue."""
        input_buf = io.BytesIO()
        _write_session(
            input_buf,
            [_make_request("initialize", 1, {"capabilities": {}})],
        )
        output_buf = io.BytesIO()
        output_buf.close()  # Simulate stream destruction before any writes

        server = BerkLanguageServer(reader=input_buf, writer=output_buf)
        # Must not raise – should stop gracefully
        server.start()
        assert not server._running

    def test_notification_without_handler_is_ignored(self):
        """Notifications for unknown methods must be silently ignored."""
        input_buf = io.BytesIO()
        _write_session(
            input_buf,
            [_make_notification("$/unknownNotification", {"data": 1})],
        )
        output_buf = io.BytesIO()
        server = BerkLanguageServer(reader=input_buf, writer=output_buf)
        server.start()

        # No output expected – unknown notifications are silently dropped
        responses = _read_all_messages(output_buf)
        assert responses == []


# ---------------------------------------------------------------------------
# Restart manager tests
# ---------------------------------------------------------------------------


class TestRestartManager:
    """Tests for the exponential-backoff restart manager."""

    def test_bounded_retries(self):
        mgr = RestartManager(max_retries=3, initial_delay=0.001, max_delay=1.0)
        for _ in range(3):
            mgr.record_failure()
        assert not mgr.should_restart()
        assert mgr.failures == 3

    def test_exponential_backoff(self):
        mgr = RestartManager(max_retries=10, initial_delay=0.1, max_delay=100.0)
        expected = [0.1, 0.2, 0.4, 0.8, 1.6, 3.2]
        for exp in expected:
            mgr.record_failure()
            assert abs(mgr._delay_for() - exp) < 1e-9

    def test_invalid_params(self):
        try:
            RestartManager(max_retries=0)
            assert False, "Expected ValueError"
        except ValueError:
            pass
        try:
            RestartManager(initial_delay=-1.0)
            assert False, "Expected ValueError"
        except ValueError:
            pass
        try:
            RestartManager(initial_delay=10.0, max_delay=1.0)
            assert False, "Expected ValueError"
        except ValueError:
            pass

    def test_max_delay_cap(self):
        mgr = RestartManager(max_retries=20, initial_delay=0.1, max_delay=0.5)
        for _ in range(10):
            mgr.record_failure()
        assert mgr._delay_for() == 0.5

    def test_reset(self):
        mgr = RestartManager(max_retries=3, initial_delay=0.001, max_delay=1.0)
        mgr.record_failure()
        mgr.record_failure()
        assert mgr.failures == 2
        mgr.reset()
        assert mgr.failures == 0
        assert mgr.should_restart()

    def test_success_resets_counter(self):
        mgr = RestartManager(max_retries=3, initial_delay=0.001, max_delay=1.0)
        mgr.record_failure()
        mgr.record_failure()
        assert mgr.failures == 2
        # Simulate a successful run resetting the counter
        mgr.reset()
        assert mgr.failures == 0


# ---------------------------------------------------------------------------
# Module entry-point tests
# ---------------------------------------------------------------------------


class TestModuleEntryPoint:
    """Tests for ``python -m ava.lsp`` and main() with restart integration."""

    def test_module_is_importable(self):
        import ava.lsp.__main__  # noqa: F401

    def test_main_clean_shutdown_exits_zero(self):
        """A proper shutdown sequence should not trigger restarts."""
        import subprocess

        msgs = _build_lsp_bytes([
            _make_request("initialize", 1, {"capabilities": {}}),
            _make_notification("initialized"),
            _make_request("shutdown", 2),
            _make_notification("exit"),
        ])
        result = subprocess.run(
            [sys.executable, "-m", "ava.lsp"],
            input=msgs,
            capture_output=True,
            timeout=10,
            cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        )
        assert result.returncode == 0, (
            f"Expected exit 0, got {result.returncode}\n"
            f"stderr: {result.stderr.decode()}"
        )


# ---------------------------------------------------------------------------
# Run all tests if executed directly (no pytest required)
# ---------------------------------------------------------------------------


def _run_tests():
    """Simple test runner that works without pytest."""
    classes = [
        TestStreamSafety,
        TestMessageCodec,
        TestServerLifecycle,
        TestRestartManager,
        TestModuleEntryPoint,
    ]
    passed = 0
    failed = 0

    for cls in classes:
        instance = cls()
        methods = [m for m in dir(cls) if m.startswith("test_")]
        for name in sorted(methods):
            method = getattr(instance, name)
            try:
                method()
                print(f"  \u2705 {cls.__name__}.{name}")
                passed += 1
            except Exception as exc:
                print(f"  \u274c {cls.__name__}.{name}: {exc}")
                failed += 1

    print()
    print("=" * 50)
    print(f"Results: {passed} passed, {failed} failed")
    return failed == 0


if __name__ == "__main__":
    success = _run_tests()
    sys.exit(0 if success else 1)
