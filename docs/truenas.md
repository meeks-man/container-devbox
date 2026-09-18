# Running on TrueNAS SCALE

TrueNAS runs Docker natively (24.10 and later) and accepts a compose file as a
Custom App. The only NAS-specific work is preparing a dataset the container
user can write to.

## 1. Create the dataset

Datasets -> pick your pool -> Add Dataset.

| Setting | Value |
|---|---|
| Parent | `POOL/apps` (create it first if you do not have one) |
| Name | `devbox` |
| Dataset Preset | Generic |
| Compression | inherit (lz4) |
| atime | off |
| Record size | default |

One dataset with subdirectories is simpler than a dataset per mount. A single
snapshot then captures Claude history, kubeconfig, work files, and shell
history together, and you restore them as a unit.

Keep it outside `ix-apps`. Data in the apps dataset is tied to the app's
lifecycle; this dataset should survive an uninstall.

## 2. Own it as uid 1000

The image runs as user `dev`, uid 1000. From System -> Shell:

```bash
D=/mnt/POOL/apps/devbox
mkdir -p $D/{claude,work,kube,talos,local}
touch $D/gitconfig
printf '[user]\n\tname = meeks-man\n\temail = joshua.meeks@gmail.com\n' > $D/gitconfig
chown -R 1000:1000 $D
chmod 700 $D/claude $D/kube $D/talos
```

The gitconfig file must exist before the first start. If Docker finds nothing
at that path it creates a directory, and git then fails to read it.

If your TrueNAS login is the first user you created, it is probably already
uid 1000 and you can also do this through the Permissions editor. Check with
`id <username>` in the shell.

## 3. Copy credentials in

```bash
cp /path/to/talos-new/kubeconfig  $D/kube/config
cp /path/to/talos-new/talosconfig $D/talos/config
chown 1000:1000 $D/kube/config $D/talos/config
chmod 600 $D/kube/config $D/talos/config
```

## 4. Snapshot it

Data Protection -> Periodic Snapshot Tasks -> Add.
Dataset `POOL/apps/devbox`, daily, keep two weeks. Add it to any replication
task you already run.

## 5. Install the app

Apps -> Discover -> Custom App -> Install via YAML. Paste
`compose.truenas.yaml` with POOL replaced and the ttyd password set.

Open `http://<truenas-ip>:7681`. Run `claude` and `/login` once; the token
lands in the claude directory and survives image updates.

## Notes

- Watchtower is scoped by label and will not touch other TrueNAS apps.
- TrueNAS shows the app as "custom" and does not manage its updates itself.
  Watchtower does that from the nightly GHCR build.
- Resource limits in the compose file are a starting point. Raise them if
  Claude Code sessions or builds feel slow.

## Several people on one NAS

Give each person their own dataset and run the container as their TrueNAS
account:

```
POOL/apps/devbox/josh    owned by josh   (uid 1000)   PUID=1000 PGID=1000  port 7681
POOL/apps/devbox/alice   owned by alice  (uid 1001)   PUID=1001 PGID=1001  port 7682
```

Duplicate the `devbox` service in the compose file once per person, changing
`container_name`, the host paths, `PUID`, `PGID`, the port, and
`TTYD_CREDENTIAL`. One watchtower service covers all of them. Find a user's
uid with `id <name>` in the TrueNAS shell.

Running as the shared `apps` user (568) works too, by setting `PUID=568` and
`PGID=568` and owning the dataset accordingly, but that gives every other
568 app on the NAS a path to this one's credentials. Prefer per-person uids.
