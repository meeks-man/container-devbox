# Status and next steps

_Last updated 2026-09-18 (late evening). Pick up from "Next" below._

## Where things are

**Images** (repo `meeks-man/container-devbox`, GHCR public, nightly rebuild 05:17 UTC, amd64 + arm64)

| Image | State |
|---|---|
| `container-devbox` | Working in production on the NAS. Latest commit adds HTTPS on 7681 (self-signed, persisted in the state dir). Build was in progress when we stopped. |
| `container-vscode` | New. Official VS Code on linuxserver webtop, same CLI toolset. First build was in progress when we stopped; **not yet tested**. |

**Toolset in both:** neovim 0.12, k9s, kubectl 1.37, talosctl 1.14, helm 4.3, kustomize 5.8, git 2.47, tmux 3.7c, Claude Code, yazi, yaml-language-server, prettier, yamlfmt, yamllint, Node 24. Shared installer: `images/common/install-tools.sh`.

**Layout:** `images/<name>/Dockerfile`, `compose/` samples (placeholders only), `docs/truenas.md` setup guide, matrix workflow.

**Deployed (personal, not in repo):** TrueNAS, dataset `FastClass/devboxs/meeks`, user `meeks` uid/gid 3000, app `devbox-meeks` on 7681, kubeconfig and talosconfig in place, k9s/yazi/nvim verified, Claude login was pending on email.

## Next

1. **Confirm the build** at github.com/meeks-man/container-devbox/actions went green for both images. Read the version manifests in the job summaries.
2. **devbox after Watchtower pulls the HTTPS build:** URL becomes `https://<nas>:7681`, accept the cert once. Check `docker logs devbox-meeks` for `serving https`.
3. **Install the VS Code box:** `mkdir /mnt/FastClass/devboxs/meeks/vscode && chown 3000:3000 …`, then Install via YAML with `compose/vscode.truenas.yaml` (POOL=FastClass, USER=meeks, PUID/PGID=3000). Open `https://<nas>:7691`. Verify: VS Code autostarts on /config/work, integrated terminal has k9s/claude, Copilot sign-in persists across a restart.
4. **Change the placeholder passwords** in both TrueNAS apps.
5. **Caddy + Authentik in front:** forward_auth to Authentik, inject the ttyd Basic header, set `TTYD_SSL=0`, drop KasmVNC CUSTOM_USER/PASSWORD, stop publishing ports to the LAN. Per-user routing on `X-Authentik-Username` (snippet in chat history; worth adding to docs when done).
6. **Kasm Brave box:** done. `VNCOPTIONS=-MaxDisconnectionTime 300` + `KASM_SVC_*=0`; resets itself 5 min after disconnect.

## Open questions

- Do we want `openvscode-server` (native web UI, no Copilot) as an alternative image, or is the streamed desktop enough?
- Idle shutdown for the devbox containers (Sablier or custom) once Caddy is in place.
- Longer term: control plane for per-user provisioning (the "own Coder" idea): Authentik OIDC → create container + dataset + Caddy route.
