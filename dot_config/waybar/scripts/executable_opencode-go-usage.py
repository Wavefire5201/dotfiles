#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["browser-cookie3", "curl-cffi"]
# ///
"""Waybar widget: OpenCode Go subscription usage.

Scrapes the server-rendered /workspace/<id>/go console page (auth via browser
cookies) and reports Rolling (5h) / Weekly / Monthly usage. No public API exists;
the parse targets stable UI text, so it survives console redeploys.
"""
import json, re, sys, time
from pathlib import Path

CACHE = Path.home() / ".cache" / "opencode-go-usage"
DATA_CACHE = CACHE / "data.json"
TTL = 120  # seconds
BROWSERS = ["brave", "chromium", "firefox", "chrome", "edge"]
DOMAIN = "opencode.ai"


def emit(text, tooltip, cls):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}))
    sys.exit(0)  # always exit 0 so Waybar never hides the module


def short_reset(s):
    s = s.replace(" days", "d").replace(" day", "d")
    s = s.replace(" hours", "h").replace(" hour", "h")
    s = s.replace(" minutes", "m").replace(" minute", "m")
    s = s.replace(" seconds", "s").replace(" second", "s")
    return re.sub(r"\s+", " ", s).strip()


def load_cookies():
    import browser_cookie3
    for b in BROWSERS:
        fn = getattr(browser_cookie3, b, None)
        if not fn:
            continue
        try:
            jar = fn(domain_name=DOMAIN)
            d = {c.name: c.value for c in jar}
            if d:
                return d
        except Exception:
            continue
    return None


def fetch():
    from curl_cffi import requests as crequests
    cookies = load_cookies()
    if not cookies:
        raise RuntimeError("no opencode.ai cookies — sign in at opencode.ai")
    s = dict(cookies=cookies, impersonate="chrome", timeout=12)
    # /auth redirects to /workspace/<wid>; reuse that to discover the workspace
    r = crequests.get("https://opencode.ai/auth", allow_redirects=True, **s)
    m = re.search(r"/workspace/(wrk_[A-Za-z0-9]+)", str(r.url) + " " + r.text)
    if not m:
        raise RuntimeError("could not resolve workspace id")
    wid = m.group(1)
    html = crequests.get(f"https://opencode.ai/workspace/{wid}/go", **s).text
    text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))
    windows = []
    for label in ("Rolling", "Weekly", "Monthly"):
        mm = re.search(
            label + r" Usage\s*([0-9]+)\s*%.*?Resets in ([0-9]+ \w+(?: [0-9]+ \w+)?)",
            text,
        )
        if mm:
            windows.append({"label": label, "pct": int(mm.group(1)),
                            "reset": short_reset(mm.group(2))})
    if not windows:
        raise RuntimeError("usage block not found (login expired?)")
    return {"windows": windows, "ts": time.time()}


def render(data, stale=False):
    w = data["windows"]
    pct = max(x["pct"] for x in w)
    mark = " ⏸" if stale else ""
    text = f"Go {pct}%{mark}"
    lines = ["OpenCode Go"] + [
        f"{x['label']:<8}{x['pct']:>3}%  ·  {x['reset']}" for x in w
    ]
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
        if cached:  # fall back to stale data on transient failure
            return render(cached, stale=True)
        emit("Go ⚠", f"OpenCode Go\n{e}", "critical")


if __name__ == "__main__":
    main()
