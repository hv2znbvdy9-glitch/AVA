"""Exponential-backoff restart manager for the BERK Language Server."""

import logging
import time

logger = logging.getLogger(__name__)


class RestartManager:
    """Exponential-backoff restart manager.

    Tracks consecutive failures and provides a :meth:`wait` method that
    sleeps for an exponentially increasing interval (capped at
    *max_delay*) between restart attempts.
    """

    DEFAULT_MAX_RETRIES: int = 10
    DEFAULT_INITIAL_DELAY: float = 1.0
    DEFAULT_MAX_DELAY: float = 60.0

    def __init__(
        self,
        max_retries: int = DEFAULT_MAX_RETRIES,
        initial_delay: float = DEFAULT_INITIAL_DELAY,
        max_delay: float = DEFAULT_MAX_DELAY,
    ) -> None:
        if max_retries < 1:
            raise ValueError("max_retries must be >= 1")
        if initial_delay <= 0:
            raise ValueError("initial_delay must be > 0")
        if max_delay < initial_delay:
            raise ValueError("max_delay must be >= initial_delay")
        self._max_retries = max_retries
        self._initial_delay = initial_delay
        self._max_delay = max_delay
        self._failures = 0

    # -- public API ---------------------------------------------------------

    @property
    def failures(self) -> int:
        """Number of consecutive failures recorded so far."""
        return self._failures

    def record_failure(self) -> None:
        """Increment the failure counter and log a warning."""
        self._failures += 1
        logger.warning(
            "LSP: restart failure %d/%d",
            self._failures,
            self._max_retries,
        )

    def should_restart(self) -> bool:
        """Return *True* if another restart attempt should be made."""
        return self._failures < self._max_retries

    def reset(self) -> None:
        """Reset the failure counter (e.g. after a successful run)."""
        self._failures = 0

    def _delay_for(self) -> float:
        """Compute the current backoff delay without sleeping."""
        return min(
            self._initial_delay * (2 ** (self._failures - 1)),
            self._max_delay,
        )

    def wait(self) -> None:
        """Sleep for the appropriate backoff interval."""
        time.sleep(self._delay_for())
