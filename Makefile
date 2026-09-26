BAZEL ?= bazelisk
UNIVERSE = //repos/...

.PHONY: bootstrap sync gazelle graph graph-repos deps rdeps clean

bootstrap: sync gazelle

sync:
	./scripts/sync-repos.sh

gazelle:
	find repos -name BUILD.bazel -delete 2>/dev/null || true
	./scripts/gen-gowork.sh
	$(BAZEL) mod tidy
	GOPROXY=off $(BAZEL) run //:gazelle

graph:
	$(BAZEL) query --keep_going --noimplicit_deps --output=graph \
	  'kind("go_library|go_binary", $(UNIVERSE))' > graph.dot
	@echo "wrote graph.dot ($$(grep -c ' -> ' graph.dot) edges)"

graph-repos:
	./scripts/graph-repos.sh > graph-repos.dot
	@echo "wrote graph-repos.dot"

deps:
	@test -n "$(TARGET)" || { echo "usage: make deps TARGET=//repos/purl:purl"; exit 1; }
	$(BAZEL) query --keep_going \
	  'filter("^//repos/", kind("go_library|go_binary", deps($(TARGET))))'

rdeps:
	@test -n "$(TARGET)" || { echo "usage: make rdeps TARGET=//repos/purl:purl"; exit 1; }
	$(BAZEL) query --keep_going \
	  'kind("go_library|go_binary", rdeps($(UNIVERSE), $(TARGET)))'

clean:
	find repos -name BUILD.bazel -delete 2>/dev/null || true
	rm -f go.work go.work.sum graph.dot graph-repos.dot
	$(BAZEL) clean
