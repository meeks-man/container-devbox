# syntax=docker/dockerfile:1
# container-vscode: Microsoft's official VS Code desktop streamed to the browser
# with KasmVNC, on linuxserver's webtop (XFCE, PUID/PGID, /config home).
# Carries the same CLI toolset as container-devbox so the integrated terminal
# matches. Build context is the repo root:  docker build -f images/vscode/Dockerfile .
FROM lscr.io/linuxserver/webtop:debian-xfce
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

# Base packages, then Microsoft's apt repo and the official VS Code build.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git openssh-client tmux less procps jq file \
      unzip xz-utils tar bash python3 python3-pip \
      ripgrep fd-find fzf zoxide bat fonts-jetbrains-mono \
    && install -d -m0755 /usr/share/keyrings \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
         > /etc/apt/sources.list.d/vscode.list \
    && apt-get update && apt-get install -y --no-install-recommends code \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# Shared toolset
COPY images/common/install-tools.sh images/common/versions.sh /tmp/common/
RUN sh /tmp/common/install-tools.sh \
    && install -m755 /tmp/common/versions.sh /usr/local/bin/devbox-versions \
    && rm -rf /tmp/common \
    && echo "=== installed versions ===" && devbox-versions

# Shell niceties for the integrated terminal (same file the devbox uses)
COPY images/devbox/config/bashrc.extra /etc/devbox-bashrc
RUN echo '[ -f /etc/devbox-bashrc ] && . /etc/devbox-bashrc' >> /etc/bash.bashrc

# Autostart VS Code, seed default settings, create mount points
COPY images/vscode/root/ /

ENV TITLE="VS Code" \
    EDITOR=nvim VISUAL=nvim \
    CLAUDE_CONFIG_DIR=/config/.claude \
    DISABLE_AUTOUPDATER=1
