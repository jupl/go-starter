MAKEFLAGS+=--no-builtin-rules

# Overridable options
PACKAGE?=./...
GO?=go

# Functions
# https://stackoverflow.com/a/18258352
# https://stackoverflow.com/a/12324443
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $2,$d))
package_from_file=$(patsubst %/,./%,$(sort $(dir $1)))
package_from_bin=\
	$(strip \
	$(foreach p,$(packages), \
	$(if $(findstring $1,$(shell $(GO) list -f '{{.Target}}' $p)),$p,)))
files_from_package=\
	$(foreach p,$1, \
	$(foreach q,$2, \
	$(shell $(GO) list -f '{{range $q}}$p/{{.}} {{end}}' $p)))
assets_from_bindata=$(call rwildcard,$(patsubst %bindata.go,%assets/,$1),%)
find_packages=\
	$(patsubst $(base_path)%,.%, \
	$(filter-out $(base_path)/vendor/%, \
	$(filter $(base_path) || $(base_path)/%, \
	$(sort \
	$(shell $(GO) list -f '{{range .Deps}}{{.}} {{end}}' $1) \
	$(shell $(GO) list $1)))))

# Go related variables
go_get:=$(GO) get
go_path:=$(shell $(GO) env GOPATH)
go_bin:=$(go_path)/bin
goacc:=$(go_bin)/go-acc
bindata:=$(go_bin)/go-bindata
dep:=$(go_bin)/dep
base_path:=$(CURDIR:$(go_path)/src/%=%)

# Determine go files
packages:=$(call find_packages,$(PACKAGE))
source_files:=\
	$(filter-out %/bindata.go, \
	$(call files_from_package,$(packages),.GoFiles))
test_files:=$(call files_from_package,$(packages),.TestGoFiles .XTestGoFiles)
bin_files:=\
	$(filter $(go_bin)/%, \
	$(shell $(GO) list -f '{{.Target}}' $(packages)))
assets_files:=\
	$(patsubst %assets.go,%bindata.go, \
	$(foreach a, \
		$(filter-out vendor/%, \
		$(call rwildcard,,assets.go %/assets.go)), \
	$(if $(call rwildcard,$(patsubst %.go,%/,$a),%),$a,)))

.PHONY: help setup install clean format htmlcov test
.SUFFIXES:

#
# Tasks
#
help: # https://blog.sneawo.com/blog/2017/06/13/makefile-help-target/
	@egrep '^(.+)\:\ .*##\ (.+)' ${MAKEFILE_LIST} \
	| sed 's/:.*##/#/' \
	| column -t -c 2 -s '#'
setup: vendor $(assets_files) ## Set up project
install: $(bin_files) ## Install application
clean: ## Clean up files
	@printf '==> '
	rm -f coverage.out
format: $(source_files) $(test_files) ## Format all go files
	@printf '==> '
	$(GO) fmt $(call package_from_file,$?)
htmlcov: setup coverage.out ## Generate HTML coverage report
	@printf '==> '
	$(GO) tool cover -html=coverage.out
test: setup coverage.out ## Run all tests with code coverage

#
# Files
#
.SECONDEXPANSION:
$(go_bin)/%: $$(call files_from_package,$$(call package_from_bin,$$@),.GoFiles)
	@printf '==> '
	$(GO) install $(call package_from_bin,$@)
bindata.go %/bindata.go: $$(call assets_from_bindata,$$@) | $(bindata)
	@printf '==> '
	$(GO) generate -x ./$(patsubst %bindata.go,%assets.go,$@)
coverage.out: $(source_files) $(test_files) | $(goacc)
	@printf '==> '
	$(goacc) -o $@ $(call package_from_file,$(filter %_test.go,$^))
vendor: Gopkg.toml Gopkg.lock $(source_files) $(test_files) | $(dep)
	@printf '==> '
	$(dep) ensure

#
# Go bin dependencies
#
$(goacc):
	@printf '==> '
	$(go_get) github.com/ory/go-acc
$(bindata):
	@printf '==> '
	$(go_get) github.com/jteeuwen/go-bindata/...
$(dep):
	@printf '==> '
	$(go_get) github.com/golang/dep/cmd/dep
