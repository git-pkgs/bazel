#!/usr/bin/env bash
set -euo pipefail

# Clone or fast-forward every active (non-fork, non-archived) Go repository
# in the git-pkgs org into ./repos/<name>. Requires gh and git.

cd "$(dirname "$0")/.."
mkdir -p repos

ORG=git-pkgs
EXCLUDE_REGEX='^(infra|bazel)$'

gh repo list "$ORG" --limit 500 \
  --json name,isArchived,isFork,primaryLanguage,sshUrl \
  --jq '.[]
        | select(.isArchived | not)
        | select(.isFork | not)
        | select(.primaryLanguage.name == "Go")
        | [.name, .sshUrl] | @tsv' |
while IFS=$'\t' read -r name url; do
  [[ "$name" =~ $EXCLUDE_REGEX ]] && { echo "skip  $name (excluded)"; continue; }
  dest="repos/$name"
  if [[ -d "$dest/.git" ]]; then
    echo "sync  $name"
    git -C "$dest" fetch --quiet origin
    git -C "$dest" reset --quiet --hard "origin/$(git -C "$dest" rev-parse --abbrev-ref origin/HEAD | sed 's|^origin/||')"
  else
    echo "clone $name"
    git clone --quiet "$url" "$dest"
  fi
done
