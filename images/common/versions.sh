#!/bin/sh
# Prints one line per installed tool. Installed as /usr/local/bin/devbox-versions.
for c in "nvim --version" "k9s version --short" "yazi --version" "yamlfmt --version" \
         "kubectl version --client" "talosctl version --client --short" "helm version --short" \
         "kustomize version" "tmux -V" "git --version" "claude --version" \
         "yaml-language-server --version" "prettier --version" "yamllint --version" "node --version" \
         "ttyd --version" "code --version --user-data-dir /tmp/vscode-version --no-sandbox"; do
  command -v "${c%% *}" >/dev/null 2>&1 || continue
  printf '%-34s' "${c%% --user-data-dir*}"; $c 2>&1 | grep -m1 -E '[0-9]+\.[0-9]+' || true
done
