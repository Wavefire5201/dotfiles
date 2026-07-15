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
from pathlib import Path


HOME = Path.home()
CACHE = HOME / ".cache" / "ai-usage-lite"
GO_CACHE = CACHE / "opencode-go.json"
GO_TTL = 120


def emit(data):
    print(json.dumps(data, ensure_ascii=False))


def short_reset(text):
    text = text.replace(" days", "d").replace(" day", "d")
    text = text.replace(" hours", "h").replace(" hour", "h")
    text = text.replace(" minutes", "m").replace(" minute", "m")
    text = text.replace(" seconds", "s").replace(" second", "s")
    return re.sub(r"\s+", " ", text).strip()


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
    import browser_cookie3

    for browser in ("brave", "chromium", "firefox", "chrome", "edge"):
        fn = getattr(browser_cookie3, browser, None)
        if not fn:
            continue
        try:
            jar = fn(domain_name="opencode.ai")
            cookies = {c.name: c.value for c in jar}
            if cookies:
                return cookies
        except Exception:
            continue
    return None


def fetch_opencode_go():
    from curl_cffi import requests

    cookies = browser_cookies()
    if not cookies:
        raise RuntimeError("no opencode.ai cookies; sign in in a supported browser")

    req = {"cookies": cookies, "impersonate": "chrome", "timeout": 12}
    auth = requests.get("https://opencode.ai/auth", allow_redirects=True, **req)
    match = re.search(r"/workspace/(wrk_[A-Za-z0-9]+)", str(auth.url) + " " + auth.text)
    if not match:
        raise RuntimeError("could not resolve OpenCode workspace id")

    workspace = match.group(1)
    html = requests.get(f"https://opencode.ai/workspace/{workspace}/go", **req).text
    text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))

    windows = []
    for label in ("Rolling", "Weekly", "Monthly"):
        m = re.search(
            label + r" Usage\s*([0-9]+)\s*%.*?Resets in ([0-9]+ \w+(?: [0-9]+ \w+)?)",
            text,
        )
        if m:
            windows.append({"label": label, "pct": int(m.group(1)), "reset": short_reset(m.group(2))})

    if not windows:
        raise RuntimeError("OpenCode Go usage block not found")
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
        if cached:
            return render_opencode_go(cached, fmt, stale=True)
        return {"id": "opencode", "ok": False, "text": "Go ⚠", "tooltip": f"OpenCode Go\n{exc}", "className": "critical", "pct": -1}


def render_opencode_go(data, fmt, stale):
    windows = data.get("windows", [])
    max_pct = max((w.get("pct", 0) for w in windows), default=0)
    first = windows[0] if windows else {"pct": 0, "reset": ""}
    values = {
        "max_pct": str(max_pct),
        "rolling_pct": str(first.get("pct", 0)),
        "rolling_reset": first.get("reset", ""),
    }
    text = fmt
    for key, val in values.items():
        text = text.replace("{" + key + "}", str(val))
    if stale:
        text += " ⏸"

    lines = ["OpenCode Go" + (" (stale)" if stale else "")]
    lines += [f"{w['label']:<8}{w['pct']:>3}%  ·  {w['reset']}" for w in windows]
    return {"id": "opencode", "ok": True, "text": text, "tooltip": "\n".join(lines), "className": cls_for_pct(max_pct), "pct": max_pct}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--order", default="claude,codex,opencode")
    parser.add_argument("--separator", default="  ")
    parser.add_argument("--only-worst", action="store_true")
    parser.add_argument("--claude-enabled", action="store_true")
    parser.add_argument("--codex-enabled", action="store_true")
    parser.add_argument("--opencode-enabled", action="store_true")
    parser.add_argument("--claude-format", default="Cl {session_pct}%")
    parser.add_argument("--codex-format", default="Cx {session_pct}%")
    parser.add_argument("--opencode-format", default="Go {max_pct}%")
    args = parser.parse_args()
    args.order = (args.order or "claude,codex,opencode").strip() or "claude,codex,opencode"
    args.separator = args.separator if args.separator is not None and args.separator != "" else "  "
    args.claude_format = (args.claude_format or "Cl {session_pct}%").strip() or "Cl {session_pct}%"
    args.codex_format = (args.codex_format or "Cx {session_pct}%").strip() or "Cx {session_pct}%"
    args.opencode_format = (args.opencode_format or "Go {max_pct}%").strip() or "Go {max_pct}%"

    providers = {}
    if args.claude_enabled:
        providers["claude"] = run_waybar_helper("claude", [
            str(HOME / ".local/bin/claudebar"),
            "--format", args.claude_format,
            "--tooltip-format", "Claude\nSession  {session_pct}%  ·  {session_reset}\nWeekly   {weekly_pct}%  ·  {weekly_reset}\nSonnet   {sonnet_pct}%"
        ])
    if args.codex_enabled:
        providers["codex"] = run_waybar_helper("codex", [
            str(HOME / ".local/bin/codexbar"),
            "--format", args.codex_format,
            "--tooltip-format", "Codex\nSession  {session_pct}%  ·  {session_reset}\nWeekly   {weekly_pct}%  ·  {weekly_reset}"
        ])
    if args.opencode_enabled:
        providers["opencode"] = opencode_go_provider(args.opencode_format)

    ordered = [providers[k] for k in [x.strip() for x in args.order.split(",")] if k in providers]
    ordered += [v for k, v in providers.items() if v not in ordered]

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
