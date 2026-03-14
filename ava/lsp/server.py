"""BERK Language Server – LSP server implementation for the AVA project.

Communicates over stdin/stdout using the LSP base protocol (Content-Length
framing + JSON-RPC 2.0 payloads).  All writes are guarded against
``ERR_STREAM_DESTROYED`` errors so the process shuts down gracefully instead
of crashing in an infinite restart loop.
"""

import io
import json
import logging
import sys
import threading
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Stream helpers
# ---------------------------------------------------------------------------


class StreamClosedError(OSError):
    """Raised when a write is attempted on a closed or destroyed stream."""


def _is_stream_readable(stream: Optional[io.BufferedIOBase]) -> bool:
    """Return *True* if *stream* is open and can be read from."""
    if stream is None:
        return False
    if hasattr(stream, "closed") and stream.closed:
        return False
    return True


def _is_stream_writable(stream: Optional[io.BufferedIOBase]) -> bool:
    """Return *True* if *stream* is open and can be written to."""
    if stream is None:
        return False
    if hasattr(stream, "closed") and stream.closed:
        return False
    return True


# ---------------------------------------------------------------------------
# LSP base-protocol codec
# ---------------------------------------------------------------------------


def _read_headers(stream: io.BufferedIOBase) -> Optional[int]:
    """Parse LSP Content-Length headers.  Returns length or None on error."""
    content_length: Optional[int] = None
    while True:
        try:
            raw = stream.readline()
        except (OSError, ValueError):
            return None
        if not raw:
            return None
        line = raw.decode("ascii", errors="replace").rstrip("\r\n")
        if line == "":
            # Blank line ends the header block
            break
        if line.lower().startswith("content-length:"):
            try:
                content_length = int(line.split(":", 1)[1].strip())
            except (ValueError, IndexError):
                return None
    return content_length


def _read_exactly(stream: io.BufferedIOBase, n: int) -> Optional[bytes]:
    """Read exactly *n* bytes.  Returns *None* on short or failed reads."""
    try:
        data = stream.read(n)
    except (OSError, ValueError):
        return None
    if data is None or len(data) < n:
        return None
    return data


def read_message(stream: io.BufferedIOBase) -> Optional[Dict[str, Any]]:
    """Read one LSP message from *stream*.

    Returns the decoded JSON object, or *None* if the stream is closed /
    the input is malformed.
    """
    if not _is_stream_readable(stream):
        return None
    content_length = _read_headers(stream)
    if content_length is None:
        return None
    body = _read_exactly(stream, content_length)
    if body is None:
        return None
    try:
        return json.loads(body.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None


def write_message(stream: io.BufferedIOBase, msg: Dict[str, Any]) -> None:
    """Write one LSP message to *stream*.

    Raises :exc:`StreamClosedError` if the stream is closed or the write
    fails due to a broken pipe / destroyed stream (mirrors the Node.js
    ``ERR_STREAM_DESTROYED`` error that originally motivated this server).
    """
    if not _is_stream_writable(stream):
        raise StreamClosedError("Stream is closed or None")
    body = json.dumps(msg).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    try:
        stream.write(header + body)
        stream.flush()
    except (OSError, ValueError) as exc:
        raise StreamClosedError(str(exc)) from exc


# ---------------------------------------------------------------------------
# BERK Language Server
# ---------------------------------------------------------------------------


class BerkLanguageServer:
    """Minimal LSP server with robust stream lifecycle management.

    The server communicates over stdin/stdout using the LSP base protocol.
    All writes are guarded against ``ERR_STREAM_DESTROYED`` errors so the
    process shuts down gracefully instead of crashing in an infinite
    restart loop.
    """

    SERVER_NAME = "BERK Language Server"
    SERVER_VERSION = "0.1.0"

    def __init__(
        self,
        reader: Optional[io.BufferedIOBase] = None,
        writer: Optional[io.BufferedIOBase] = None,
    ):
        self._reader = reader or sys.stdin.buffer
        self._writer = writer or sys.stdout.buffer
        self._running = False
        self._shutdown_requested = False
        self._initialized = False
        self._lock = threading.Lock()

    # -- public API ---------------------------------------------------------

    def start(self) -> None:
        """Run the server main loop (blocking)."""
        self._running = True
        logger.info("%s %s started", self.SERVER_NAME, self.SERVER_VERSION)

        try:
            while self._running:
                msg = read_message(self._reader)
                if msg is None:
                    # Stream closed – exit cleanly instead of crashing
                    logger.info("LSP: input stream closed, shutting down")
                    break

                self._dispatch(msg)
        except KeyboardInterrupt:
            logger.info("LSP: interrupted by user")
        finally:
            self._running = False
            logger.info("%s stopped", self.SERVER_NAME)

    def stop(self) -> None:
        """Request the server to stop."""
        self._running = False

    # -- message dispatch ---------------------------------------------------

    def _dispatch(self, msg: Dict[str, Any]) -> None:
        """Route an incoming JSON-RPC message to the correct handler."""
        method = msg.get("method", "")
        params = msg.get("params") or {}
        msg_id = msg.get("id")  # None for notifications

        handler_name = "_handle_" + method.replace("/", "_")
        handler = getattr(self, handler_name, None)

        if msg_id is not None:
            # Request – must always produce a response
            if handler is None:
                self._send_error(msg_id, -32601, f"Method not found: {method}")
                return
            try:
                result = handler(params)
                self._send_response(msg_id, result)
            except Exception as exc:  # noqa: BLE001
                self._send_error(msg_id, -32603, str(exc))
        else:
            # Notification – silently ignore unknown methods
            if handler is not None:
                handler(params)

    # -- response helpers ---------------------------------------------------

    def _send_response(self, msg_id: Any, result: Any) -> None:
        self._safe_write(
            {"jsonrpc": "2.0", "id": msg_id, "result": result}
        )

    def _send_error(
        self, msg_id: Any, code: int, message: str, data: Any = None
    ) -> None:
        error: Dict[str, Any] = {"code": code, "message": message}
        if data is not None:
            error["data"] = data
        self._safe_write(
            {"jsonrpc": "2.0", "id": msg_id, "error": error}
        )

    def _send_notification(self, method: str, params: Any = None) -> None:
        msg: Dict[str, Any] = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        self._safe_write(msg)

    def _safe_write(self, msg: Dict[str, Any]) -> None:
        """Write a message, catching destroyed-stream errors."""
        with self._lock:
            try:
                write_message(self._writer, msg)
            except StreamClosedError:
                logger.warning(
                    "LSP: stream destroyed, stopping server gracefully"
                )
                self._running = False

    # -- LSP method handlers ------------------------------------------------

    def _handle_initialize(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Handle the ``initialize`` request."""
        self._initialized = True
        return {
            "capabilities": {
                "textDocumentSync": 1,  # Full sync
                "hoverProvider": True,
                "completionProvider": {
                    "triggerCharacters": ["."],
                    "resolveProvider": False,
                },
                "diagnosticProvider": {
                    "interFileDependencies": False,
                    "workspaceDiagnostics": False,
                },
            },
            "serverInfo": {
                "name": self.SERVER_NAME,
                "version": self.SERVER_VERSION,
            },
        }

    def _handle_initialized(self, params: Dict[str, Any]) -> None:
        """Handle the ``initialized`` notification."""
        logger.info("LSP: client initialized successfully")

    def _handle_shutdown(self, params: Dict[str, Any]) -> None:
        """Handle the ``shutdown`` request."""
        self._shutdown_requested = True
        logger.info("LSP: shutdown requested")
        return None

    def _handle_exit(self, params: Dict[str, Any]) -> None:
        """Handle the ``exit`` notification."""
        self._running = False
        logger.info("LSP: exit notification received")

    # -- textDocument handlers ----------------------------------------------

    def _handle_textDocument_didOpen(self, params: Dict[str, Any]) -> None:
        """Handle ``textDocument/didOpen`` notification."""
        uri = params.get("textDocument", {}).get("uri", "")
        logger.debug("LSP: opened %s", uri)

    def _handle_textDocument_didChange(self, params: Dict[str, Any]) -> None:
        """Handle ``textDocument/didChange`` notification."""
        uri = params.get("textDocument", {}).get("uri", "")
        logger.debug("LSP: changed %s", uri)

    def _handle_textDocument_didClose(self, params: Dict[str, Any]) -> None:
        """Handle ``textDocument/didClose`` notification."""
        uri = params.get("textDocument", {}).get("uri", "")
        logger.debug("LSP: closed %s", uri)


# ---------------------------------------------------------------------------
# Entry-point
# ---------------------------------------------------------------------------


def main() -> None:
    """Launch the BERK Language Server with automatic restart on failure.

    Uses :class:`~ava.lsp.restart_manager.RestartManager` to apply
    exponential backoff when the server exits unexpectedly (e.g. due to
    ``spawn UNKNOWN`` or ``OSError`` from the host IDE).
    """
    from ava.lsp.restart_manager import RestartManager

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        stream=sys.stderr,  # LSP uses stdout for protocol; logs go to stderr
    )

    restart_mgr = RestartManager()
    exit_code = 1

    while True:
        try:
            server = BerkLanguageServer()
            server.start()
            if server._shutdown_requested:
                # Clean shutdown requested by the client – exit immediately.
                exit_code = 0
                break
            # Server stopped without a shutdown request (e.g. broken pipe).
            # Let the restart manager decide if we should retry.
            restart_mgr.record_failure()
        except OSError as exc:
            # Catches spawn / pipe / stream errors that crash the process.
            logger.error("LSP: OS error during server operation – %s", exc)
            restart_mgr.record_failure()
        except KeyboardInterrupt:
            logger.info("LSP: interrupted by user")
            exit_code = 0
            break
        if not restart_mgr.should_restart():
            logger.error(
                "LSP: giving up after %d consecutive failures",
                restart_mgr.failures,
            )
            break
        restart_mgr.wait()

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
