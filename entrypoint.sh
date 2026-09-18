#!/bin/sh
# Entrypoint. Starts as root, aligns the "dev" user to PUID/PGID (default
# 1000/1000), fixes ownership of image-owned files only, then re-executes
# itself as that user and serves one shared tmux session over ttyd.
#
# Mounted volumes are never chown'd recursively: their ownership is the
# host's responsibility and walking a large work directory on every start
# would be slow and surprising.
set -e

HOME_DIR=/home/dev
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if [ "$(id -u)" = "0" ]; then
  case "$PUID$PGID" in *[!0-9]*) echo "PUID/PGID must be numeric" >&2; exit 1 ;; esac

  # Rewrite uid/gid directly. usermod -u would recursively chown the home
  # directory, which walks every mounted volume.
  sed -i "s/^dev:x:[0-9]*:[0-9]*:/dev:x:${PUID}:${PGID}:/" /etc/passwd
  sed -i "s/^dev:x:[0-9]*:/dev:x:${PGID}:/" /etc/group

  # Image-owned files and directories.
  for p in "$HOME_DIR" "$HOME_DIR/.bashrc" "$HOME_DIR/.bashrc.extra" \
           "$HOME_DIR/.profile" "$HOME_DIR/.bash_logout" "$HOME_DIR/.tmux.conf"; do
    [ -e "$p" ] && chown "${PUID}:${PGID}" "$p"
  done
  chown -R "${PUID}:${PGID}" "$HOME_DIR/.config"

  # Mount points: create if missing, chown only the top level.
  for d in work .claude .kube .talos .local .local/state; do
    mkdir -p "$HOME_DIR/$d"
    chown "${PUID}:${PGID}" "$HOME_DIR/$d" 2>/dev/null || true
  done

  for d in work .claude .kube .talos .local/state; do
    if ! setpriv --reuid="$PUID" --regid="$PGID" --clear-groups test -w "$HOME_DIR/$d"; then
      echo "devbox: WARNING $HOME_DIR/$d is not writable by uid ${PUID}; fix ownership on the host" >&2
    fi
  done

  echo "devbox: starting as uid=${PUID} gid=${PGID}"
  exec setpriv --reuid="$PUID" --regid="$PGID" --clear-groups \
       env HOME="$HOME_DIR" USER=dev LOGNAME=dev "$0" "$@"
fi

# ---- unprivileged from here -------------------------------------------------
cd "$HOME_DIR/work" 2>/dev/null || cd "$HOME_DIR"

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
