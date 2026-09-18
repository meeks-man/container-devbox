# syntax=docker/dockerfile:1
# container-devbox: tmux + ttyd + neovim + k9s + kubectl + talosctl + helm + kustomize + git + Claude Code + yazi + YAML tooling
# Every tool is pulled from its upstream "latest" release at build time.
# Rebuild with:  docker compose build --no-cache --pull

############################
# Stage 1: build tmux from the latest release tarball
############################
FROM debian:bookworm-slim AS tmux-build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl build-essential pkg-config \
      libevent-dev libncurses-dev bison \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    TV="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/tmux/tmux/releases/latest | sed 's#.*/tag/##')"; \
    curl -fsSL "https://github.com/tmux/tmux/releases/download/${TV}/tmux-${TV}.tar.gz" | tar -xz -C /tmp; \
    cd "/tmp/tmux-${TV}"; \
    ./configure --prefix=/usr/local; \
    make -j"$(nproc)"; \
    make install; \
    /usr/local/bin/tmux -V

############################
# Stage 2: runtime image
############################
FROM debian:bookworm-slim
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color \
    COLORTERM=truecolor

# Runtime packages. build-essential is only here for pip and npm native deps.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git gnupg openssh-client less procps sudo \
      unzip xz-utils tar jq file \
      python3 python3-pip \
      ripgrep fd-find fzf zoxide bat p7zip-full poppler-utils \
      libevent-core-2.1-7 libncurses6 libncursesw6 libtinfo6 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# tmux from stage 1
COPY --from=tmux-build /usr/local/bin/tmux /usr/local/bin/tmux

# Node LTS (needed for Claude Code, yaml-language-server, prettier)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g --no-fund --no-audit \
         @anthropic-ai/claude-code \
         yaml-language-server \
         prettier \
    && npm cache clean --force

# yamllint
RUN pip3 install --no-cache-dir --break-system-packages yamllint

# Binaries from GitHub "latest" releases + kubectl stable
RUN set -eux; \
    ARCH="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$ARCH" in \
      amd64) NVIM_ARCH=x86_64; K9S_ARCH=amd64; TTYD_ARCH=x86_64; YAZI_ARCH=x86_64-unknown-linux-gnu; YAMLFMT_ARCH=x86_64; KUBE_ARCH=amd64 ;; \
      arm64) NVIM_ARCH=arm64;  K9S_ARCH=arm64; TTYD_ARCH=aarch64; YAZI_ARCH=aarch64-unknown-linux-gnu; YAMLFMT_ARCH=arm64; KUBE_ARCH=arm64 ;; \
      *) echo "unsupported arch: $ARCH" >&2; exit 1 ;; \
    esac; \
    latest() { curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/tag/##'; }; \
    \
    # neovim
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" | tar -xz -C /opt; \
    ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim; \
    \
    # k9s
    curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${K9S_ARCH}.tar.gz" | tar -xz -C /usr/local/bin k9s; \
    \
    # ttyd
    curl -fsSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${TTYD_ARCH}"; \
    chmod +x /usr/local/bin/ttyd; \
    \
    # yazi (+ ya package manager)
    curl -fsSL -o /tmp/yazi.zip "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${YAZI_ARCH}.zip"; \
    unzip -q /tmp/yazi.zip -d /tmp/yazi; \
    install -m755 "/tmp/yazi/yazi-${YAZI_ARCH}/yazi" "/tmp/yazi/yazi-${YAZI_ARCH}/ya" /usr/local/bin/; \
    \
    # yamlfmt (asset name embeds the version, so resolve the tag first)
    YV="$(latest google/yamlfmt)"; \
    curl -fsSL "https://github.com/google/yamlfmt/releases/download/${YV}/yamlfmt_${YV#v}_Linux_${YAMLFMT_ARCH}.tar.gz" | tar -xz -C /usr/local/bin yamlfmt; \
    \
    # kubectl (stable channel)
    KV="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"; \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KV}/bin/linux/${KUBE_ARCH}/kubectl"; \
    chmod +x /usr/local/bin/kubectl; \
    \
    # talosctl (Talos Linux CLI; generates kubeconfig for k9s/kubectl)
    curl -fsSL -o /usr/local/bin/talosctl "https://github.com/siderolabs/talos/releases/latest/download/talosctl-linux-${KUBE_ARCH}"; \
    chmod +x /usr/local/bin/talosctl; \
    \
    # helm (version from the official latest-version endpoint)
    HV="$(curl -fsSL https://get.helm.sh/helm-latest-version)"; \
    curl -fsSL "https://get.helm.sh/helm-${HV}-linux-${KUBE_ARCH}.tar.gz" | tar -xz -C /tmp; \
    install -m755 "/tmp/linux-${KUBE_ARCH}/helm" /usr/local/bin/helm; \
    \
    # kustomize (tags look like kustomize/v5.x.y; asset embeds the bare version)
    KZ="$(latest kubernetes-sigs/kustomize)"; KZV="${KZ#kustomize/}"; \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/${KZ}/kustomize_${KZV}_linux_${KUBE_ARCH}.tar.gz" | tar -xz -C /usr/local/bin kustomize; \
    \
    rm -rf /tmp/*; \
    \
    # print versions so the build log doubles as a manifest (informational, never fails the build)
    echo "=== installed versions ==="; \
    for c in "nvim --version" "k9s version --short" "ttyd --version" "yazi --version" \
             "yamlfmt --version" "kubectl version --client" "talosctl version --client --short" \
             "helm version --short" "kustomize version" \
             "tmux -V" "git --version" "claude --version" "yaml-language-server --version" \
             "prettier --version" "yamllint --version" "node --version"; do \
      printf '%-32s' "$c"; $c 2>&1 | head -1 || true; \
    done

# Unprivileged user
RUN useradd -m -u 1000 -s /bin/bash dev \
    && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

COPY --chown=dev:dev config/tmux.conf   /home/dev/.tmux.conf
COPY --chown=dev:dev config/nvim        /home/dev/.config/nvim
COPY --chown=dev:dev config/yazi        /home/dev/.config/yazi
COPY --chown=dev:dev config/bashrc.extra /home/dev/.bashrc.extra
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && echo '[ -f ~/.bashrc.extra ] && . ~/.bashrc.extra' >> /home/dev/.bashrc \
    && mkdir -p /home/dev/work /home/dev/.claude /home/dev/.kube /home/dev/.talos \
    && chown -R dev:dev /home/dev

USER dev
WORKDIR /home/dev/work
ENV EDITOR=nvim \
    VISUAL=nvim \
    CLAUDE_CONFIG_DIR=/home/dev/.claude \
    DISABLE_AUTOUPDATER=1 \
    TTYD_PORT=7681

EXPOSE 7681
# 401 counts as healthy: ttyd is up and asking for the configured password.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${TTYD_PORT}/" | grep -Eq '^(200|401)$' || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
