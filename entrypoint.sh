#!/bin/sh
# Serve a single shared tmux session over ttyd.
# Every browser tab that connects attaches to the same tmux session ("main"),
# so closing the tab never kills what is running inside.
set -e

set -- -W \
       -p "${TTYD_PORT:-7681}" \
       -t fontSize="${TTYD_FONT_SIZE:-14}" \
       -t 'fontFamily=JetBrains Mono, Cascadia Code, Fira Code, monospace' \
       -t enableSixel=true \
       -t titleFixed="${TTYD_TITLE:-devbox}"

if [ -n "$TTYD_CREDENTIAL" ]; then
  set -- "$@" -c "$TTYD_CREDENTIAL"
fi

exec ttyd "$@" tmux new-session -A -s main
