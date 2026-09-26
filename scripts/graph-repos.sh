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
awk '
  { print; src[$1]++; dst[$3]++; all[$1]; all[$3] }
  END {
    for (n in all) if (!(n in dst)) { roots  = roots  " " n; print n " [fillcolor=\"#dbeafe\" color=\"#3b82f6\"]" }
    for (n in all) if (!(n in src)) { leaves = leaves " " n; print n " [fillcolor=\"#dcfce7\" color=\"#22c55e\"]" }
    print "{ rank=source" roots " }"
    print "{ rank=sink"   leaves " }"
  }' |
{
  cat <<'EOF'
digraph gitpkgs {
  rankdir=LR;
  concentrate=true;
  ranksep=0.9; nodesep=0.15;
  node [shape=box style="rounded,filled" fillcolor="#f4f4f4" color="#888888"
        fontname="Helvetica" fontsize=11 height=0 margin="0.15,0.04"];
  edge [color="#777777" arrowsize=0.6 penwidth=1];
EOF
  sed 's/^/  /; s/$/;/'
  echo '}'
}
