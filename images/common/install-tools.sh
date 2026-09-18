#!/bin/sh
# Shared installer used by every image in this repo.
# Fetches each CLI tool from its upstream "latest" release.
# Expects a Debian-based image with: curl ca-certificates tar unzip xz-utils gnupg python3 python3-pip bash
set -eu

ARCH="${TARGETARCH:-$(dpkg --print-architecture)}"
case "$ARCH" in
  amd64) NVIM_ARCH=x86_64; K9S_ARCH=amd64; YAZI_ARCH=x86_64;  YAMLFMT_ARCH=x86_64; KUBE_ARCH=amd64 ;;
  arm64) NVIM_ARCH=arm64;  K9S_ARCH=arm64; YAZI_ARCH=aarch64; YAMLFMT_ARCH=arm64;  KUBE_ARCH=arm64 ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac
latest() { curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/tag/##'; }

# --- Node LTS, Claude Code, YAML LSP, prettier --------------------------------
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y --no-install-recommends nodejs
rm -rf /var/lib/apt/lists/*
npm install -g --no-fund --no-audit @anthropic-ai/claude-code yaml-language-server prettier
npm cache clean --force

# --- yamllint -------------------------------------------------------------------
pip3 install --no-cache-dir --break-system-packages yamllint

# --- neovim -------------------------------------------------------------------
curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" | tar -xz -C /opt
ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim

# --- k9s ------------------------------------------------------------------------
curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${K9S_ARCH}.tar.gz" | tar -xz -C /usr/local/bin k9s

# --- yazi: gnu build needs glibc >= 2.39, use the static musl build otherwise ----
GLIBC="$(ldd --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+$')"
if [ "$(printf '%s\n2.39\n' "$GLIBC" | sort -V | head -1)" = "2.39" ]; then LIBC=gnu; else LIBC=musl; fi
curl -fsSL -o /tmp/yazi.zip "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${YAZI_ARCH}-unknown-linux-${LIBC}.zip"
unzip -q /tmp/yazi.zip -d /tmp/yazi
install -m755 /tmp/yazi/yazi-*/yazi /tmp/yazi/yazi-*/ya /usr/local/bin/

# --- yamlfmt (asset name embeds the version) ----------------------------------
YV="$(latest google/yamlfmt)"
curl -fsSL "https://github.com/google/yamlfmt/releases/download/${YV}/yamlfmt_${YV#v}_Linux_${YAMLFMT_ARCH}.tar.gz" | tar -xz -C /usr/local/bin yamlfmt

# --- kubectl (stable channel) ---------------------------------------------------
KV="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KV}/bin/linux/${KUBE_ARCH}/kubectl"
chmod +x /usr/local/bin/kubectl

# --- talosctl -------------------------------------------------------------------
curl -fsSL -o /usr/local/bin/talosctl "https://github.com/siderolabs/talos/releases/latest/download/talosctl-linux-${KUBE_ARCH}"
chmod +x /usr/local/bin/talosctl

# --- helm -----------------------------------------------------------------------
HV="$(curl -fsSL https://get.helm.sh/helm-latest-version)"
curl -fsSL "https://get.helm.sh/helm-${HV}-linux-${KUBE_ARCH}.tar.gz" | tar -xz -C /tmp
install -m755 "/tmp/linux-${KUBE_ARCH}/helm" /usr/local/bin/helm

# --- kustomize (tags look like kustomize/v5.x.y) --------------------------------
KZ="$(latest kubernetes-sigs/kustomize)"; KZV="${KZ#kustomize/}"
curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/${KZ}/kustomize_${KZV}_linux_${KUBE_ARCH}.tar.gz" | tar -xz -C /usr/local/bin kustomize

rm -rf /tmp/yazi /tmp/yazi.zip "/tmp/linux-${KUBE_ARCH}"
