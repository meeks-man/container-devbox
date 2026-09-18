# syntax=docker/dockerfile:1
# container-devbox: browser terminal (ttyd + tmux) with neovim, k9s, kubectl,
# talosctl, helm, kustomize, git, Claude Code, yazi and YAML tooling.
# Build context is the repo root:  docker build -f images/devbox/Dockerfile .

############################
# Stage 1: tmux from the latest release tarball
############################
FROM debian:trixie-slim AS tmux-build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl build-essential pkg-config \
      libevent-dev libncurses-dev bison \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    TV="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/tmux/tmux/releases/latest | sed 's#.*/tag/##')"; \
    curl -fsSL "https://github.com/tmux/tmux/releases/download/${TV}/tmux-${TV}.tar.gz" | tar -xz -C /tmp; \
    cd "/tmp/tmux-${TV}"; ./configure --prefix=/usr/local; make -j"$(nproc)"; make install; \
    /usr/local/bin/tmux -V

############################
# Stage 2: runtime
############################
FROM debian:trixie-slim
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color COLORTERM=truecolor

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git gnupg openssh-client less procps tzdata util-linux \
      unzip xz-utils tar jq file bash \
      python3 python3-pip \
      ripgrep fd-find fzf zoxide bat p7zip-full poppler-utils \
      libevent-core-2.1-7t64 libncurses6 libncursesw6 libtinfo6 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

COPY --from=tmux-build /usr/local/bin/tmux /usr/local/bin/tmux

# Shared toolset (node, claude, LSPs, nvim, k9s, kubectl, talosctl, helm, kustomize, yazi, yamlfmt, yamllint)
COPY images/common/install-tools.sh images/common/versions.sh /tmp/common/
RUN sh /tmp/common/install-tools.sh \
    && install -m755 /tmp/common/versions.sh /usr/local/bin/devbox-versions \
    && rm -rf /tmp/common

# ttyd (devbox only)
RUN set -eux; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in amd64) T=x86_64 ;; arm64) T=aarch64 ;; esac; \
    curl -fsSL -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${T}"; \
    chmod +x /usr/local/bin/ttyd; \
    echo "=== installed versions ==="; devbox-versions

# Unprivileged user. No sudo: the image is rebuilt nightly, so anything you
# would install by hand belongs in this Dockerfile instead.
RUN useradd -m -u 1000 -s /bin/bash dev

COPY --chown=dev:dev images/devbox/config/tmux.conf    /home/dev/.tmux.conf
COPY --chown=dev:dev images/devbox/config/nvim         /home/dev/.config/nvim
COPY --chown=dev:dev images/devbox/config/yazi         /home/dev/.config/yazi
COPY --chown=dev:dev images/devbox/config/bashrc.extra /home/dev/.bashrc.extra
COPY images/devbox/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && echo '[ -f ~/.bashrc.extra ] && . ~/.bashrc.extra' >> /home/dev/.bashrc \
    && mkdir -p /home/dev/work /home/dev/.claude /home/dev/.kube /home/dev/.talos \
    && chown -R dev:dev /home/dev

# The entrypoint starts as root, aligns "dev" to PUID/PGID, then drops to it.
WORKDIR /home/dev/work
ENV PUID=1000 PGID=1000 \
    EDITOR=nvim VISUAL=nvim \
    CLAUDE_CONFIG_DIR=/home/dev/.claude \
    DISABLE_AUTOUPDATER=1 \
    TTYD_PORT=7681

EXPOSE 7681
# 401 counts as healthy: ttyd is up and asking for the configured password.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${TTYD_PORT}/" | grep -Eq '^(200|401)$' || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
