# container-devbox

[![build](https://github.com/meeks-man/container-devbox/actions/workflows/build.yml/badge.svg)](https://github.com/meeks-man/container-devbox/actions/workflows/build.yml)

Per-user development boxes for a homelab, published to GHCR and rebuilt
nightly from every tool's latest upstream release, for linux/amd64 and
linux/arm64. Both images honour `PUID`/`PGID` and keep all state in mounted
directories, so one dataset per person holds everything.

| Image | What you get | Port |
|---|---|---|
| `ghcr.io/meeks-man/container-devbox` | Browser terminal: ttyd into a shared tmux session | 7681 http |
| `ghcr.io/meeks-man/container-vscode` | Official VS Code desktop streamed via KasmVNC (linuxserver webtop) | 3000 http / 3001 https |

Both carry the same CLI toolset: neovim, k9s, kubectl, talosctl, helm,
kustomize, git, Claude Code, yazi, yaml-language-server, prettier, yamlfmt,
yamllint, tmux, ripgrep, fd, fzf, zoxide, bat.

## Run

Generic Docker host: `compose/devbox.yaml`.
TrueNAS SCALE: `compose/devbox.truenas.yaml` and `compose/vscode.truenas.yaml`,
with the dataset prep in [docs/truenas.md](docs/truenas.md).

Mount the same per-user directories into both containers and they become two
windows onto one profile: same work files, kubeconfig, talosconfig, Claude
session and git identity.

## First run

- `claude` then `/login` once. The token lives in the mounted claude directory.
- `k9s` reads the mounted kubeconfig. `talosctl` reads the mounted talosconfig.
- Terminal: `y` opens yazi and cd's to where you quit, `v` is nvim, `k` is kubectl.
- VS Code: opens on `/config/work`. Extensions and settings persist in the
  mounted `/config`. `--password-store=basic` is set so Copilot and other
  sign-ins survive restarts without a keyring.

## How updates work

| Trigger | What happens |
|---|---|
| Push to main | Both images rebuilt and pushed as `latest`, `YYYYMMDD`, `sha-xxxxxxx` |
| Nightly 05:17 UTC | Same, no layer cache, so new upstream releases land |
| Watchtower on the host | Pulls new `latest`, recreates the container, data untouched |

Each workflow run prints the installed versions in its job summary.
Pin a date tag instead of `latest` to freeze a known-good build.

## Running as a different user (PUID / PGID)

Set `PUID` and `PGID` to the owner of the mounted directories. The devbox
entrypoint starts as root, rewrites the internal user to match, fixes
ownership of image-owned files only, and drops privileges before ttyd starts.
The vscode image inherits the same behaviour from linuxserver's webtop base.
Mounted volumes are never chown'd recursively.

For several people, run one container per person with their own `PUID`,
`PGID`, dataset, port and credential. Files they create are owned by them on
the host.

## Layout

```
images/common/install-tools.sh   shared installer: every CLI tool at upstream latest
images/common/versions.sh        prints installed versions (devbox-versions in the image)
images/devbox/                   Dockerfile, entrypoint.sh, tmux/nvim/yazi/bash config
images/vscode/                   Dockerfile on webtop + autostart, default settings
compose/                         run configs for a generic host and for TrueNAS
docs/truenas.md                  dataset, user and permissions setup on TrueNAS
.github/workflows/build.yml      matrix build of both images to GHCR
```

## Build locally

```bash
docker build -f images/devbox/Dockerfile -t devbox .
docker build -f images/vscode/Dockerfile -t vscode .
```
