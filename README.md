# container-devbox

[![build](https://github.com/meeks-man/container-devbox/actions/workflows/build.yml/badge.svg)](https://github.com/meeks-man/container-devbox/actions/workflows/build.yml)

Browser terminal (ttyd) into a shared tmux session with Neovim, k9s, kubectl,
Claude Code, talosctl, helm, kustomize, git, yazi, and YAML tooling. Published to
`ghcr.io/meeks-man/container-devbox`, rebuilt nightly from every tool's latest upstream
release, for linux/amd64 and linux/arm64.

## Run

```bash
mkdir -p data/{claude,work,kube,talos,local} && touch data/gitconfig && chown -R 1000:1000 data
cp ~/.kube/config data/kube/config      # or your talos-generated kubeconfig
# edit TTYD_CREDENTIAL in compose.yaml
docker compose up -d
```

Open http://<host>:7681. Put it behind Caddy with TLS before exposing it
beyond the LAN. Watchtower in the same compose file pulls each nightly image
and recreates the container; your data lives in ./data so nothing is lost.

## First run

- `claude` then `/login` once. The token lives in ./data/claude.
- `k9s` reads ./data/kube/config. For Talos: put talosconfig in ./data/talos/config, then `talosctl kubeconfig ~/.kube/config`.
- Create ./data/gitconfig on the host with your git name and email before first start.
- `y` opens yazi and cd's to wherever you quit. `v` is nvim, `k` is kubectl.

## How updates work

| Trigger | What happens |
|---|---|
| Push to main | Image rebuilt and pushed as `latest`, `YYYYMMDD`, and `sha-xxxxxxx` |
| Nightly 05:17 UTC | Same, with no layer cache, so new upstream releases land |
| Watchtower on the host | Checks hourly, pulls new `latest`, recreates the container |

Each workflow run prints the installed versions in its job summary.
Pin a date tag instead of `latest` if you want to freeze a known-good build.

## YAML tooling

| Tool | Role |
|---|---|
| yaml-language-server | LSP in Neovim: schemas, completion, diagnostics, format |
| prettier | Formatter used by the LSP, also on CLI: `prettier -w file.yaml` |
| yamlfmt | Google's formatter, CLI: `yamlfmt file.yaml` |
| yamllint | Linter, CLI: `yamllint .` (see .yamllint.yaml) |

Kubernetes schema is applied to k8s/, kubernetes/, manifests/, clusters/, apps/,
infrastructure/, talos/ paths and *.k8s.yaml. Edit the globs in
config/nvim/init.lua. Everything else resolves through SchemaStore.

## Build locally

```bash
docker build -t devbox .
```

## Layout

```
.github/workflows/build.yml   nightly + on-push multi-arch build to GHCR
Dockerfile                    two-stage: tmux from source, then runtime
compose.yaml                  run config + watchtower (generic Docker host)
compose.truenas.yaml          same, with TrueNAS dataset paths; see docs/truenas.md
entrypoint.sh                 ttyd -> tmux new-session -A -s main
config/tmux.conf              mouse, vi keys, Alt+hjkl panes, kube context in status
config/nvim/                  init.lua, no plugins, built-in LSP + completion
config/yazi/                  yazi.toml
config/bashrc.extra           PATH, history, zoxide, fzf, y/k/v aliases
```
