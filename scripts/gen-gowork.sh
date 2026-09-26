#!/usr/bin/env bash
set -euo pipefail

# Regenerate go.work from every go.mod found under ./repos.
# Module-level `replace` directives are promoted to workspace level so that
# conflicting pseudo-versions across repos resolve to a single choice
# (highest version wins). Local-path replaces are dropped because the
# target module is already present via a `use` directive.

cd "$(dirname "$0")/.."

mods=()
while IFS= read -r f; do
  mods+=("./$(dirname "$f")")
done < <(find repos -maxdepth 3 -name go.mod -not -path '*/vendor/*' -not -path '*/testdata/*' | sort)

if [[ ${#mods[@]} -eq 0 ]]; then
  echo "no go.mod found under repos/; run scripts/sync-repos.sh first" >&2
  exit 1
fi

rm -f go.work go.work.sum
go work init "${mods[@]}"

# Each module root needs a BUILD.bazel so go_deps can load go.mod as a label,
# and a gazelle:prefix directive so nested modules whose path differs from
# their parent (e.g. a vendored fork) get the right importpath.
for m in "${mods[@]}"; do
  path=$(go mod edit -json "$m/go.mod" | jq -r .Module.Path)
  grep -q '^# gazelle:prefix ' "$m/BUILD.bazel" 2>/dev/null && continue
  printf '# gazelle:prefix %s\n' "$path" > "$m/BUILD.bazel"
done

while IFS=' ' read -r old new ver; do
  [[ -z "$ver" ]] && continue
  go work edit -replace "${old}=${new}@${ver}"
done < <(
  for m in "${mods[@]}"; do
    go mod edit -json "$m/go.mod" |
      jq -r '.Replace[]? | select(.New.Version != null and .New.Version != "")
             | "\(.Old.Path) \(.New.Path) \(.New.Version)"'
  done | sort -k1,1 -k3,3V | awk '{last[$1]=$0} END{for(k in last) print last[k]}'
)

go work sync
echo "go.work: ${#mods[@]} modules"
