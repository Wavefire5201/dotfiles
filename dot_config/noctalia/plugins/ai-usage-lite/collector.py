#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["browser-cookie3", "curl-cffi"]
# ///
import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


HOME = Path.home()
CACHE = HOME / ".cache" / "ai-usage-lite"
GO_CACHE = CACHE / "opencode-go.json"
GO_TTL = 120
# Keep showing the last reading for a while, then surface the failure instead.
GO_MAX_STALE = 6 * 3600
CONSOLE_API = "https://opencode.ai/console/api"
CONSOLE_SESSION_COOKIES = ("__Host-console_session", "console_session")
OPENCODE_WINDOWS = {"Rolling": 5 * 3600, "Weekly": 7 * 86400, "Monthly": 30 * 86400}


def emit(data):
    print(json.dumps(data, ensure_ascii=False))


def short_reset(text):
    text = text.replace(" days", "d").replace(" day", "d")
    text = text.replace(" hours", "h").replace(" hour", "h")
    text = text.replace(" minutes", "m").replace(" minute", "m")
    text = text.replace(" seconds", "s").replace(" second", "s")
    return re.sub(r"\s+", " ", text).strip()


def secs_from_reset(text):
    d = re.search(r"(\d+)d", text)
    h = re.search(r"(\d+)h", text)
    m = re.search(r"(\d+)m", text)
    return (
        (int(d.group(1)) * 86400 if d else 0)
        + (int(h.group(1)) * 3600 if h else 0)
        + (int(m.group(1)) * 60 if m else 0)
    )


def pace_for(pct, reset, window_s):
    """Return (indicator, label) for a usage window; ("", "") if no data."""
    if pct is None or not reset or window_s <= 0:
        return "", ""
    remaining = secs_from_reset(reset)
    if remaining <= 0:
        return "", ""
    elapsed = (window_s - remaining) * 100 // window_s
    elapsed = max(0, min(100, elapsed))
    delta = pct - elapsed
    if delta > 0:
        return "↑", f"{delta}pts ahead"
    if delta < 0:
        return "↓", f"{-delta}pts under"
    return "→", "on track"


def cls_for_pct(pct):
    if pct >= 90:
        return "critical"
    if pct >= 75:
        return "high"
    if pct >= 50:
        return "mid"
    return "low"


def pct_from_text(text):
    matches = [int(x) for x in re.findall(r"([0-9]{1,3})%", text or "")]
    return max(matches) if matches else -1


def strip_markup(text):
    return re.sub(r"<[^>]+>", "", text or "")


def run_waybar_helper(name, command):
    try:
        proc = subprocess.run(command, text=True, capture_output=True, timeout=25)
        raw = (proc.stdout or "").strip()
        if raw:
            parsed = json.loads(raw)
            text = strip_markup(str(parsed.get("text", "")).strip())
            tooltip = str(parsed.get("tooltip", "")).strip()
            return {
                "id": name,
                "ok": True,
                "text": text,
                "tooltip": tooltip or text,
                "className": parsed.get("class", cls_for_pct(pct_from_text(text))),
                "pct": pct_from_text(text + "\n" + tooltip),
            }
        err = (proc.stderr or "").strip() or f"{command[0]} returned no output"
        return {"id": name, "ok": False, "text": f"{name} ⚠", "tooltip": err, "className": "critical", "pct": -1}
    except Exception as exc:
        return {"id": name, "ok": False, "text": f"{name} ⚠", "tooltip": str(exc), "className": "critical", "pct": -1}


def browser_cookies():
    """Cookies for opencode.ai from the first browser holding a console session.

    The v2 console authenticates with the `__Host-console_session` cookie; the
    v1 `auth` cookie is still present in older profiles but the new API rejects
    it, so a jar without a session cookie is treated as signed out.
    """
    import browser_cookie3

    fallback = None
    for browser in ("brave", "chromium", "firefox", "chrome", "edge"):
        fn = getattr(browser_cookie3, browser, None)
        if not fn:
            continue
        try:
            jar = fn(domain_name="opencode.ai")
            cookies = {c.name: c.value for c in jar}
        except Exception:
            continue
        if any(name in cookies for name in CONSOLE_SESSION_COOKIES):
            return cookies
        if cookies and fallback is None:
            fallback = cookies
    if fallback is not None:
        raise RuntimeError("signed out of the v2 console; sign in at opencode.ai/console")
    return None


def console_get(path, cookies, org_id=None):
    from curl_cffi import requests

    headers = {
        "Accept": "application/json",
        "Origin": "https://opencode.ai",
        "Referer": "https://opencode.ai/console/",
    }
    if org_id:
        # Every org-scoped route 400s with `org_required` without this header.
        headers["x-org-id"] = org_id
    resp = requests.get(
        CONSOLE_API + path,
        cookies=cookies,
        impersonate="chrome",
        timeout=15,
        headers=headers,
    )
    if resp.status_code == 401:
        raise RuntimeError("console session expired; sign in at opencode.ai/console")
    if resp.status_code == 403:
        raise RuntimeError(f"{path} forbidden for this account")
    if resp.status_code != 200:
        raise RuntimeError(f"{path} returned HTTP {resp.status_code}")
    try:
        return resp.json()
    except Exception:
        raise RuntimeError(f"{path} returned non-JSON response")


def pick_org_id(payload):
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


def meter_pct(meter):
    """Percent of the allowance consumed; -1 when the meter has no limit."""
    try:
        limit = int(meter.get("limitMicroCents") or 0)
        used = int(meter.get("usedMicroCents") or 0)
    except (TypeError, ValueError):
        return -1
    if limit <= 0:
        return -1
    return max(0, min(100, round(used * 100 / limit)))


def until_text(value):
    """Render an ISO-8601 instant as the compact `26d 17h` form used elsewhere."""
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


def fetch_opencode_go():
    """Read Go usage from the v2 console JSON API.

    v1 served a `/workspace/<id>/go` HTML page that this widget scraped. v2
    replaced it with a cookie-authenticated SPA, so the numbers now come from
    `/console/api/go/status`, scoped by an `x-org-id` header. (The similar
    `/api/internal/...` routes are the staff admin API and answer 403 here.)
    """
    cookies = browser_cookies()
    if not cookies:
        raise RuntimeError("no opencode.ai cookies; sign in at opencode.ai/console")

    org_id = pick_org_id(console_get("/orgs", cookies))
    status = console_get("/go/status", cookies, org_id=org_id) or {}
    access = status.get("access")
    if not isinstance(access, dict):
        raise RuntimeError("no active OpenCode Go subscription")

    meters = access.get("meters") or {}
    # The month meter carries no resetsAt of its own; it ends with the period.
    spec = (
        ("Rolling", "fiveHour", None),
        ("Weekly", "week", None),
        ("Monthly", "month", access.get("endsAt")),
    )
    windows = []
    for label, key, fallback_reset in spec:
        meter = meters.get(key)
        if not isinstance(meter, dict):
            continue
        pct = meter_pct(meter)
        if pct < 0:
            continue
        windows.append({"label": label, "pct": pct, "reset": until_text(meter.get("resetsAt") or fallback_reset)})

    if not windows:
        raise RuntimeError("OpenCode Go usage meters missing from console response")
    return {"windows": windows, "ts": time.time()}


def opencode_go_provider(fmt):
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = None
    try:
        cached = json.loads(GO_CACHE.read_text())
        if time.time() - cached.get("ts", 0) < GO_TTL:
            return render_opencode_go(cached, fmt, stale=False)
    except Exception:
        cached = None

    try:
        data = fetch_opencode_go()
        GO_CACHE.write_text(json.dumps(data))
        return render_opencode_go(data, fmt, stale=False)
    except Exception as exc:
        # Serve the last good reading briefly, but stop pretending once the
        # cache outlives GO_MAX_STALE -- a silent freeze hid the v1->v2 break.
        if cached and time.time() - cached.get("ts", 0) < GO_MAX_STALE:
            return render_opencode_go(cached, fmt, stale=True, reason=str(exc))
        return {"id": "opencode", "ok": False, "text": "Go ⚠", "tooltip": f"OpenCode Go\n{exc}", "className": "critical", "pct": -1}


def render_opencode_go(data, fmt, stale, reason=""):
    windows = data.get("windows", [])
    max_pct = max((w.get("pct", 0) for w in windows), default=0)
    first = windows[0] if windows else {"pct": 0, "reset": ""}

    pace = {}
    for w in windows:
        ind, label = pace_for(w.get("pct"), w.get("reset", ""), OPENCODE_WINDOWS.get(w.get("label", ""), 0))
        pace[w["label"].lower() + "_pace_indicator"] = ind
        pace[w["label"].lower() + "_pace_pts"] = label
    max_window = next((w for w in windows if w.get("pct", 0) == max_pct), None)
    if max_window:
        ind, label = pace_for(max_window.get("pct"), max_window.get("reset", ""), OPENCODE_WINDOWS.get(max_window.get("label", ""), 0))
        pace["max_pace_indicator"] = ind
        pace["max_pace_pts"] = label
    else:
        pace["max_pace_indicator"] = ""
        pace["max_pace_pts"] = ""

    values = {
        "max_pct": str(max_pct),
        "rolling_pct": str(first.get("pct", 0)),
        "rolling_reset": first.get("reset", ""),
        **pace,
    }
    text = fmt
    for key, val in values.items():
        text = text.replace("{" + key + "}", str(val))
    if stale:
        text += " ⏸"

    lines = ["OpenCode Go" + (" (stale)" if stale else "")]
    if stale and reason:
        lines.append(reason)
    for w in windows:
        tail = pace.get(w["label"].lower() + "_pace_pts", "")
        line = f"{w['label']:<8}{w['pct']:>3}%  ·  {w['reset']}"
        if tail:
            line += f"  ·  {tail}"
        lines.append(line)
    return {"id": "opencode", "ok": True, "text": text, "tooltip": "\n".join(lines), "className": cls_for_pct(max_pct), "pct": max_pct}


def symbolize_pace(text):
    text = re.sub(r"(\d+)pts ahead", r"▲\1", text)
    text = re.sub(r"(\d+)pts under", r"▼\1", text)
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--order", default="claude,codex,antigravity,opencode")
    parser.add_argument("--separator", default="  ")
    parser.add_argument("--only-worst", action="store_true")
    parser.add_argument("--claude-enabled", action="store_true")
    parser.add_argument("--codex-enabled", action="store_true")
    parser.add_argument("--antigravity-enabled", action="store_true")
    parser.add_argument("--opencode-enabled", action="store_true")
    parser.add_argument("--claude-format", default="Cl {session_pct}%")
    parser.add_argument("--codex-format", default="Cx {session_pct}%")
    parser.add_argument("--antigravity-format", default="AG {worst_pct}%")
    parser.add_argument("--opencode-format", default="Go {max_pct}%")
    args = parser.parse_args()
    args.order = (args.order or "claude,codex,antigravity,opencode").strip() or "claude,codex,antigravity,opencode"
    args.separator = args.separator if args.separator is not None and args.separator != "" else "  "
    args.claude_format = (args.claude_format or "Cl {session_pct}%").strip() or "Cl {session_pct}%"
    args.codex_format = (args.codex_format or "Cx {session_pct}%").strip() or "Cx {session_pct}%"
    args.antigravity_format = (args.antigravity_format or "AG {worst_pct}%").strip() or "AG {worst_pct}%"
    args.opencode_format = (args.opencode_format or "Go {max_pct}%").strip() or "Go {max_pct}%"

    providers = {}
    if args.claude_enabled:
        providers["claude"] = run_waybar_helper("claude", [
            str(HOME / ".local/bin/claudebar"),
            "--format", args.claude_format,
            "--tooltip-format", "Claude\nSession  {session_pct}%  ·  {session_reset}  ·  {session_pace_pts}\nWeekly   {weekly_pct}%  ·  {weekly_reset}  ·  {weekly_pace_pts}\n{model_name}  {model_pct}%  ·  {model_reset}"
        ])
    if args.codex_enabled:
        providers["codex"] = run_waybar_helper("codex", [
            str(HOME / ".local/bin/codexbar"),
            "--format", args.codex_format,
            "--tooltip-format", "Codex\nSession  {session_pct}%  ·  {session_reset}  ·  {session_pace_pts}\nWeekly   {weekly_pct}%  ·  {weekly_reset}  ·  {weekly_pace_pts}"
        ])
    if args.opencode_enabled:
        providers["opencode"] = opencode_go_provider(args.opencode_format)
    if args.antigravity_enabled:
        providers["antigravity"] = run_waybar_helper("antigravity", [
            str(HOME / ".config/waybar/scripts/antigravity-usage.py"),
        ])

    ordered = [providers[k] for k in [x.strip() for x in args.order.split(",")] if k in providers]
    ordered += [v for k, v in providers.items() if v not in ordered]
    for p in ordered:
        p["tooltip"] = symbolize_pace(p.get("tooltip", ""))

    visible = ordered
    if args.only_worst and ordered:
        visible = [max(ordered, key=lambda p: p.get("pct", -1))]

    summary = args.separator.join([p.get("text", "") for p in visible if p.get("text")])
    tooltip = "\n\n".join([p.get("tooltip", "") for p in ordered if p.get("tooltip")])
    worst_pct = max((p.get("pct", -1) for p in ordered), default=-1)
    worst_class = cls_for_pct(worst_pct if worst_pct >= 0 else 0)

    emit({"summary": summary or "AI --", "tooltip": tooltip or "AI Usage Lite", "className": worst_class, "providers": ordered})


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        emit({"summary": "AI ⚠", "tooltip": str(exc), "className": "critical", "providers": []})
