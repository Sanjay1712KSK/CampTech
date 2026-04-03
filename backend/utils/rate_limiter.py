import time


_REQUEST_LOG: dict[str, list[float]] = {}


def enforce_rate_limit(key: str, limit: int, window_seconds: int) -> None:
    now = time.time()
    timestamps = _REQUEST_LOG.setdefault(key, [])
    cutoff = now - window_seconds
    timestamps[:] = [stamp for stamp in timestamps if stamp >= cutoff]
    if len(timestamps) >= limit:
        raise ValueError('Too many requests. Please wait before trying again.')
    timestamps.append(now)
