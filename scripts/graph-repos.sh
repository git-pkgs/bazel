#!/usr/bin/env bash
set -euo pipefail

# Collapse the package-level Bazel graph to one node per repo and emit DOT.

cd "$(dirname "$0")/.."
: "${BAZEL:=bazelisk}"

$BAZEL query --keep_going --noimplicit_deps --output=graph \
  'kind("go_library|go_binary", //repos/...)' 2>/dev/null |
grep ' -> ' |
sed -E 's|//repos/([^/:"]+)[^"]*|\1|g; s/^[[:space:]]*//' |
awk -F' -> ' '$1 != $2' |
sort -u |
{
  echo 'digraph gitpkgs {'
  echo '  rankdir=LR; node [shape=box,fontname=monospace];'
  sed 's/^/  /; s/$/;/'
  echo '}'
}
