#!/bin/sh
# Waybar wrapper: Claude usage via claudebar (compact bar text + clean tooltip)
exec "$HOME/.local/bin/claudebar" \
  --format 'Cl {session_pct}%' \
  --tooltip-format 'Claude Max
Session  {session_pct}%  ·  {session_reset}
Weekly   {weekly_pct}%  ·  {weekly_reset}
Sonnet   {sonnet_pct}%'
