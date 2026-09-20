#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["browser-cookie3", "curl-cffi"]
# ///
"""Waybar widget: OpenCode Go subscription usage.

Reads the console's JSON API (auth via browser cookies) and reports Rolling
(5h) / Weekly / Monthly usage.

The v1 console server-rendered `/workspace/<id>/go`, which this script used to
scrape. v2 replaced that with an SPA, so the numbers now come from
`/console/api/go/status`, scoped by an `x-org-id` header. Note that the
similarly-named `/console/api/internal/orgs/<id>/go/status` is the staff admin
API and answers 403 for normal accounts.
"""
import json, re, sys, time
from datetime import datetime, timezone
from pathlib import Path

CACHE = Path.home() / ".cache" / "opencode-go-usage"
DATA_CACHE = CACHE / "data.json"
TTL = 120  # seconds
MAX_STALE = 6 * 3600  # past this, report the failure instead of the last value
BROWSERS = ["brave", "chromium", "firefox", "chrome", "edge"]
DOMAIN = "opencode.ai"
CONSOLE_API = "https://opencode.ai/console/api"
# v2 session cookie; the v1 `auth` cookie lingers in old profiles but is rejected.
SESSION_COOKIES = ("__Host-console_session", "console_session")


def emit(text, tooltip, cls):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}))
    sys.exit(0)  # always exit 0 so Waybar never hides the module


def until(value):
    """Render an ISO-8601 instant as the compact `26d 17h` form."""
    if not value:
        return ""
    try:
        when = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return ""
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    secs = int((when - datetime.now(timezone.utc)).total_seconds())
    if secs <= 0:
        return ""
    days, rem = divmod(secs, 86400)
    hours, rem = divmod(rem, 3600)
    minutes = rem // 60
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes and not days:
        parts.append(f"{minutes}m")
    return " ".join(parts) or "<1m"


def load_cookies():
    import browser_cookie3
    fallback = None
    for b in BROWSERS:
        fn = getattr(browser_cookie3, b, None)
        if not fn:
            continue
        try:
            jar = fn(domain_name=DOMAIN)
            d = {c.name: c.value for c in jar}
        except Exception:
            continue
        if any(n in d for n in SESSION_COOKIES):
            return d
        if d and fallback is None:
            fallback = d
    if fallback is not None:
        raise RuntimeError("signed out of the v2 console — sign in at opencode.ai/console")
    return None


def api_get(path, cookies, org=None):
    from curl_cffi import requests as crequests
    headers = {
        "Accept": "application/json",
        "Origin": "https://opencode.ai",
        "Referer": "https://opencode.ai/console/",
    }
    if org:
        headers["x-org-id"] = org  # org-scoped routes 400 `org_required` without it
    r = crequests.get(CONSOLE_API + path, cookies=cookies, impersonate="chrome",
                      timeout=15, headers=headers)
    if r.status_code == 401:
        raise RuntimeError("console session expired — sign in at opencode.ai/console")
    if r.status_code == 403:
        raise RuntimeError(f"{path} forbidden for this account")
    if r.status_code != 200:
        raise RuntimeError(f"{path} returned HTTP {r.status_code}")
    try:
        return r.json()
    except Exception:
        raise RuntimeError(f"{path} returned non-JSON")


def org_id(payload):
    items = payload if isinstance(payload, list) else []
    if isinstance(payload, dict):
        for key in ("orgs", "data", "items"):
            if isinstance(payload.get(key), list):
                items = payload[key]
                break
    for item in items:
        if isinstance(item, dict) and isinstance(item.get("id"), str) and item["id"]:
            return item["id"]
    raise RuntimeError("no organization on this console account")


def pct_of(meter):
    """Percent of the allowance consumed; -1 when the meter carries no limit."""
    try:
        limit = int(meter.get("limitMicroCents") or 0)
        used = int(meter.get("usedMicroCents") or 0)
    except (TypeError, ValueError):
        return -1
    if limit <= 0:
        return -1
    return max(0, min(100, round(used * 100 / limit)))


def fetch():
    cookies = load_cookies()
    if not cookies:
        raise RuntimeError("no opencode.ai cookies — sign in at opencode.ai/console")
    oid = org_id(api_get("/orgs", cookies))
    status = api_get("/go/status", cookies, org=oid) or {}
    access = status.get("access")
    if not isinstance(access, dict):
        raise RuntimeError("no active OpenCode Go subscription")
    meters = access.get("meters") or {}
    # The month meter has no resetsAt of its own; it ends with the period.
    spec = (("Rolling", "fiveHour", None),
            ("Weekly", "week", None),
            ("Monthly", "month", access.get("endsAt")))
    windows = []
    for label, key, fallback_reset in spec:
        m = meters.get(key)
        if not isinstance(m, dict):
            continue
        pct = pct_of(m)
        if pct < 0:
            continue
        windows.append({"label": label, "pct": pct,
                        "reset": until(m.get("resetsAt") or fallback_reset)})
    if not windows:
        raise RuntimeError("usage meters missing from console response")
    return {"windows": windows, "ts": time.time()}


def render(data, stale=False, reason=""):
    w = data["windows"]
    pct = max(x["pct"] for x in w)
    text = f"Go {pct}%{' ⏸' if stale else ''}"
    lines = ["OpenCode Go" + (" (stale)" if stale else "")]
    if stale and reason:
        lines.append(reason)
    lines += [f"{x['label']:<8}{x['pct']:>3}%  ·  {x['reset']}" for x in w]
    cls = "critical" if pct >= 90 else "high" if pct >= 75 else "mid" if pct >= 50 else "low"
    emit(text, "\n".join(lines), cls)


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    # fresh cache?
    try:
        cached = json.loads(DATA_CACHE.read_text())
        if time.time() - cached["ts"] < TTL:
            return render(cached)
    except Exception:
        cached = None
    # fetch live
    try:
        data = fetch()
        DATA_CACHE.write_text(json.dumps(data))
        return render(data)
    except Exception as e:
        # Serve the last good reading briefly, but stop pretending once the
        # cache outlives MAX_STALE -- a silent freeze hid the v1->v2 break.
        if cached and time.time() - cached.get("ts", 0) < MAX_STALE:
            return render(cached, stale=True, reason=str(e))
        emit("Go ⚠", f"OpenCode Go\n{e}", "critical")


if __name__ == "__main__":
    main()
