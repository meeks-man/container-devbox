# Running on TrueNAS SCALE

TrueNAS runs Docker natively (24.10 and later) and accepts a compose file as a
Custom App. The only NAS-specific work is preparing a dataset the container
user can write to.

Throughout, replace `POOL` with your pool name and `USER` with the person's
name. The examples use uid/gid 1000; use whatever uid owns the dataset and set
`PUID`/`PGID` to match.

## 1. Create the datasets

Datasets -> pick your pool -> Add Dataset.

| Setting | Value |
|---|---|
| Parent | `POOL/devboxs` (create it first; one child dataset per person lives under it) |
| Name | `USER` |
| Dataset Preset | Generic |
| Compression | inherit (lz4) |
| atime | off |
| Record size | default |

One dataset per person with subdirectories is simpler than a dataset per
mount. A single snapshot then captures Claude history, kubeconfig, work files
and shell history together, and you restore them as a unit.

Keep it outside `ix-apps`. Data in the apps dataset is tied to the app's
lifecycle; this dataset should survive an uninstall.

## 2. Create the user and own the dataset

Create the group first so its gid matches the uid: Credentials -> Groups ->
Add, then Credentials -> Users -> Add with that primary group, no home
directory, shell nologin, password disabled. This account exists only to own
files. Then from System -> Shell (as root):

```bash
D=/mnt/POOL/devboxs/USER
mkdir -p $D/{claude,work,kube,talos,local}
printf '[user]\n\tname = YOUR-GIT-NAME\n\temail = you@example.com\n' > $D/gitconfig
chown -R 1000:1000 $D
chmod 700 $D $D/claude $D/kube $D/talos
id USER
```

The gitconfig file must exist before the first start. If Docker finds nothing
at that path it creates a directory, and git then fails to read it.

## 3. Copy credentials in

```bash
cp /path/to/kubeconfig  $D/kube/config
cp /path/to/talosconfig $D/talos/config
chown 1000:1000 $D/kube/config $D/talos/config
chmod 600 $D/kube/config $D/talos/config
```

## 4. Snapshot it

Data Protection -> Periodic Snapshot Tasks -> Add.
Dataset `POOL/devboxs`, recursive, daily, keep two weeks. Recursive covers
every person's child dataset automatically. Add it to any replication task
you already run.

## 5. Install the app

Apps -> Discover -> Custom App -> Install via YAML. Paste
`compose/devbox.truenas.yaml` with POOL and USER replaced, PUID/PGID set, and
the ttyd password changed.

Open `http://<truenas-ip>:7681`. Run `claude` and `/login` once; the token
lands in the claude directory and survives image updates.

## Adding the VS Code box to the same profile

`compose/vscode.truenas.yaml` mounts the same per-user directories plus one
extra for VS Code's own state. Create it and install:

```bash
D=/mnt/POOL/devboxs/USER
mkdir -p $D/vscode && chown 1000:1000 $D/vscode
```

Then Apps -> Custom App -> Install via YAML with `compose/vscode.truenas.yaml`.
Open `https://<truenas-ip>:7691` (self-signed) or `http://<truenas-ip>:7690`,
log in with CUSTOM_USER / PASSWORD, and VS Code opens on the work directory.
Sign in to Copilot or GitHub inside VS Code as normal; credentials persist in
`$D/vscode`.

The devbox and VS Code containers can run at the same time. Both see the same
files, and a Claude Code session started in one is visible from the other via
`claude --resume`.

## Several people on one NAS

```
POOL/devboxs/alice   owned by alice (uid 1001)   PUID=1001 PGID=1001   ports 7681 / 7690 / 7691
POOL/devboxs/bob     owned by bob   (uid 1002)   PUID=1002 PGID=1002   ports 7682 / 7692 / 7693
```

Duplicate the services once per person, changing `container_name`, the host
paths, `PUID`, `PGID`, the ports and the credential. One watchtower service
covers all of them. Find a user's uid with `id <name>` in the TrueNAS shell.

Running as the shared `apps` user (568) works too, but it gives every other
568 app on the NAS a path to this one's credentials. Prefer per-person uids.

## Notes

- Watchtower is scoped by label and will not touch other TrueNAS apps.
- TrueNAS shows the apps as "custom" and does not manage their updates itself.
  Watchtower does that from the nightly GHCR build.
- Resource limits in the compose files are a starting point. Raise them if
  Claude Code sessions, builds or VS Code feel slow.
- Once Caddy and Authentik sit in front, drop the ttyd and KasmVNC passwords
  and stop publishing the ports to the LAN.
