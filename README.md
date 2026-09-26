# git-pkgs Bazel graph

An experimental Bazel/Bzlmod workspace that stitches every active Go module in
the [`git-pkgs`](https://github.com/git-pkgs) org into a single dependency
graph. Gazelle generates the targets from the source; the per-repo build stays
authoritative.

## Prerequisites

`gh` (authenticated), `git`, `jq`, `go` 1.27+, `graphviz`, and `bazelisk` on `$PATH`
(`go install github.com/bazelbuild/bazelisk@latest`, or set `BAZEL=bazel` if
you already manage Bazel versions another way).

## Bootstrap

`make bootstrap` runs, in order:

1. `scripts/sync-repos.sh` lists the org via `gh`, drops forks, archived
   repos, `infra`, and this repo, and clones/updates the rest into `repos/`.
2. `scripts/gen-gowork.sh` writes `go.work` covering every `go.mod` under
   `repos/`, promotes conflicting `replace` directives to workspace level so
   `go work sync` converges, and drops a `# gazelle:prefix` stub in each
   module root so nested modules with foreign import paths resolve locally.
3. `bazel mod tidy` refreshes `use_repo(...)` in `MODULE.bazel` from the
   combined `require` set.
4. `bazel run //:gazelle` scans `repos/` and writes `BUILD.bazel` files.

Generated `BUILD.bazel` files are written only into the local `repos/` clones.
The first run fetches the Go SDK and every transitive external module for the
query index, so expect a few minutes; subsequent runs are seconds.

## Refreshing

```
make sync gazelle    # pull latest main across the org and regenerate
make gazelle         # regenerate from whatever is already in repos/
```

## Querying

```
make graph                             # package-level DOT of all //repos/... edges
make graph-repos                       # collapsed to one node per repo (every edge)
make graph-architecture                # graph-repos with transitive reduction applied
make deps  TARGET=//repos/brief/...    # git-pkgs packages a target pulls in
make rdeps TARGET=//repos/purl:purl    # everything in the org that reaches it
```

Ad-hoc queries work directly (the `.bazelrc` sets `query --noimplicit_deps` so
toolchain edges stay out of results):

```
bazel query 'somepath(//repos/silo/..., //repos/vers:vers)'
bazel query --output=graph 'allpaths(//repos/git-pkgs/..., //repos/purl:purl)'
```

## Notes

Gazelle warnings of the form `finding module path for import
github.com/git-pkgs/<x>/<y>` mean one repo on `main` imports a package another
repo's `main` has since removed: real cross-repo drift the graph is surfacing.

`repos/`, `go.work`, `MODULE.bazel.lock`, and the graph outputs are
git-ignored. `MODULE.bazel` is checked in; `bazel mod tidy` (run by
`make gazelle`) keeps its `use_repo` list matched to the current sync.

## License

[MIT](LICENSE). The cloned repositories under `repos/` keep their own
licences.
