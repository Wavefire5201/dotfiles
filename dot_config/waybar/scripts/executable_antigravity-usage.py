#!/usr/bin/env python3
"""Waybar widget: Antigravity usage via agy local gRPC-web API (HTTP/2).

Discovers listening ports of running `agy` processes, queries
RetrieveUserQuotaSummary, and reports 5h + weekly usage per group.
"""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

CACHE = Path.home() / ".cache" / "antigravity-usage"
DATA_CACHE = CACHE / "data.json"
TTL = 120


def emit(text, tooltip, cls):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}))
    sys.exit(0)


def short_reset(s):
    if not s:
        return ""
    from datetime import datetime, timezone
    try:
        # Parse ISO 8601 with possible Z
        ts = s.replace("Z", "+00:00")
        target = datetime.fromisoformat(ts)
        if target.tzinfo is None:
            target = target.replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        delta = target - now
        total_seconds = int(delta.total_seconds())
        if total_seconds <= 0:
            return "now"
        days = total_seconds // 86400
        hours = (total_seconds % 86400) // 3600
        minutes = (total_seconds % 3600) // 60
        if days > 0:
            return f"{days}d {hours}h"
        if hours > 0:
            return f"{hours}h {minutes}m"
        return f"{minutes}m"
    except Exception:
        return re.sub(r"\s+", " ", s).strip()


def cls_for_pct(pct):
    if pct >= 90:
        return "critical"
    if pct >= 75:
        return "high"
    if pct >= 50:
        return "mid"
    return "low"


AG_WINDOW_SECS = {"5h": 5 * 3600, "weekly": 7 * 86400}


def pace_label(pct, reset_iso, window_secs):
    """Return (indicator, label) for a usage window; ("", "") if no data."""
    if pct is None or not reset_iso or window_secs <= 0:
        return "", ""
    try:
        from datetime import datetime, timezone

        ts = reset_iso.replace("Z", "+00:00")
        target = datetime.fromisoformat(ts)
        if target.tzinfo is None:
            target = target.replace(tzinfo=timezone.utc)
        remaining = int(target.timestamp() - time.time())
        elapsed = (window_secs - remaining) * 100 // window_secs
        elapsed = max(0, min(100, elapsed))
    except Exception:
        return "", ""
    delta = pct - elapsed
    if delta > 0:
        return "↑", f"{delta}pts ahead"
    if delta < 0:
        return "↓", f"{-delta}pts under"
    return "→", "on track"


def discover_ports():
    """Find listening 127.0.0.1 ports of running agy processes via ss."""
    try:
        r = subprocess.run(
            ["ss", "-tlnp"],
            capture_output=True, text=True, timeout=3,
        )
        ports = []
        for line in r.stdout.split("\n"):
            if "agy" not in line:
                continue
            match = re.search(r"127\.0\.0\.1:(\d+)", line)
            if match:
                ports.append(int(match.group(1)))
        return sorted(set(ports))
    except Exception:
        return []


def fetch_summary(ports):
    """Query RetrieveUserQuotaSummary on each port via curl (HTTP/2)."""
    for port in ports:
        url = f"https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
        try:
            r = subprocess.run(
                ["curl", "-sk", "--http2-prior-knowledge", "-X", "POST", url,
                 "-H", "Content-Type: application/json", "-d", "{}"],
                capture_output=True, text=True, timeout=4,
            )
            if r.returncode == 0 and r.stdout.strip():
                data = json.loads(r.stdout)
                if data.get("response", {}).get("groups"):
                    return data
        except Exception:
            continue
    return None


def normalize_group(name):
    """Map group displayName to a short label and family key."""
    lower = name.lower()
    if "gemini" in lower:
        return "G", "gemini"
    if "claude" in lower or "gpt" in lower:
        return "C/G", "claude_gpt"
    return name.split()[0][:3], "other"


def parse_summary(data):
    """Extract (session_pct, weekly_pct, session_reset, weekly_reset) per group."""
    result = {}
    for group in data.get("response", {}).get("groups", []):
        label, key = normalize_group(group.get("displayName", ""))
        session = next(
            (b for b in group.get("buckets", [])
             if b.get("window") == "5h" or "five" in b.get("displayName", "").lower()),
            None,
        )
        weekly = next(
            (b for b in group.get("buckets", [])
             if b.get("window") == "weekly"),
            None,
        )
        result[key] = {
            "label": label,
            "session_remaining": (session or {}).get("remainingFraction"),
            "session_reset": (session or {}).get("resetTime", ""),
            "weekly_remaining": (weekly or {}).get("remainingFraction"),
            "weekly_reset": (weekly or {}).get("resetTime", ""),
        }
    return result


def build_output(groups):
    """Build compact waybar text (Gemini only) and full tooltip."""
    parts = []
    tooltip_lines = ["Antigravity"]
    worst_pct = 0

    for key, show_in_bar in (("gemini", True), ("claude_gpt", False)):
        g = groups.get(key)
        if not g:
            continue
        s_pct = None
        if g["session_remaining"] is not None:
            s_pct = round((1 - g["session_remaining"]) * 100)
            worst_pct = max(worst_pct, s_pct)
        w_pct = None
        if g["weekly_remaining"] is not None:
            w_pct = round((1 - g["weekly_remaining"]) * 100)
            worst_pct = max(worst_pct, w_pct)

        s_str = f"{s_pct}%" if s_pct is not None else "--%"
        w_str = f"{w_pct}%" if w_pct is not None else "--%"
        s_ind, s_pts = pace_label(s_pct, g["session_reset"], AG_WINDOW_SECS["5h"])
        w_ind, w_pts = pace_label(w_pct, g["weekly_reset"], AG_WINDOW_SECS["weekly"])
        if show_in_bar:
            parts.append(f"{g['label']} {s_str}{s_ind}/{w_str}{w_ind}")

        full_name = "Gemini" if key == "gemini" else "Claude/GPT"
        s_reset = short_reset(g["session_reset"])
        w_reset = short_reset(g["weekly_reset"])
        s_tail = f" · {s_pts}" if s_pts else ""
        w_tail = f" · {w_pts}" if w_pts else ""
        tooltip_lines.append(
            f"{full_name}  5h {s_str}{s_ind}{s_tail} · wk {w_str}{w_ind}{w_tail} (resets {w_reset})"
        )

    text = "  ".join(parts) if parts else "AG --/--"
    cls = cls_for_pct(worst_pct)
    return text, "\n".join(tooltip_lines), cls, worst_pct


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    try:
        cached = json.loads(DATA_CACHE.read_text())
        if time.time() - cached.get("ts", 0) < TTL:
            emit(cached.get("text", "AG --/--"),
                 cached.get("tooltip", "Antigravity (cached)"),
                 cached.get("class", "low"))
    except Exception:
        pass

    ports = discover_ports()
    if not ports:
        emit("AG ⚠", "Antigravity not running", "critical")

    data = fetch_summary(ports)
    if not data:
        emit("AG ⚠", "Could not connect to Antigravity API", "critical")

    groups = parse_summary(data)
    text, tooltip, cls, worst_pct = build_output(groups)

    cache_data = {"ts": time.time(), "text": text, "tooltip": tooltip, "class": cls}
    DATA_CACHE.write_text(json.dumps(cache_data))

    emit(text, tooltip, cls)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        emit("AG ⚠", str(exc), "critical")
