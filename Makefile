MAKEFLAGS+=--no-builtin-rules

# Overridable options
PACKAGE?=./...
GO?=go
ASSETS=assets

# Functions
# https://stackoverflow.com/a/18258352
# https://stackoverflow.com/a/12324443
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $2,$d))
dir_from_file=$(notdir $(patsubst %/,%,$(dir $(abspath $1))))
package_path_from_file=$(patsubst %/,./%,$(sort $(dir $1)))
package_from_bin=\
	$(strip\
	$(foreach p,$(packages),\
	$(if $(findstring $1,$(shell $(GO) list -f '{{.Target}}' $p)),$p,)))
files_from_package=\
	$(foreach p,$1,\
	$(foreach q,$2,\
	$(shell $(GO) list -f '{{range $q}}$p/{{.}} {{end}}' $p)))
assets_from_bindata=$(call rwildcard,$(patsubst %bindata.go,%$(ASSETS)/,$1),%)
find_packages=\
	$(patsubst $(base_path)%,.%,\
	$(filter-out $(base_path)/vendor/%,\
	$(filter $(base_path) || $(base_path)/%,\
	$(sort\
	$(shell $(GO) list -f '{{range .Deps}}{{.}} {{end}}' $1)\
	$(shell $(GO) list $1)))))

# Go related variables
go_get:=$(GO) get
go_path:=$(shell $(GO) env GOPATH)
go_bin:=$(go_path)/bin
base_path:=$(CURDIR:$(go_path)/src/%=%)
bindata:=$(go_bin)/go-bindata
dep:=$(go_bin)/dep
goacc:=$(go_bin)/go-acc

# Determine go files
packages:=$(call find_packages,$(PACKAGE))
source_files:=\
	$(filter-out %/bindata.go %.pb.go,\
	$(call files_from_package,$(packages),.GoFiles))
test_files:=$(call files_from_package,$(packages),.TestGoFiles .XTestGoFiles)
bin_files:=\
	$(filter $(go_bin)/%,\
	$(shell $(GO) list -f '{{.Target}}' $(packages)))
assets_files:=\
	$(patsubst %/$(ASSETS),%/bindata.go,\
	$(filter-out ./vendor/%,\
	$(call rwildcard,./,%/$(ASSETS))))
proto_files:=\
	$(patsubst %.proto,%.pb.go,\
	$(filter-out ./vendor/%,\
	$(call rwildcard,./,%.proto)))

.PHONY: help setup install clean format htmlcov test
.SUFFIXES:

#
# Tasks
#
help: # https://blog.sneawo.com/blog/2017/06/13/makefile-help-target/
	@egrep '^(.+)\:\ .*##\ (.+)' ${MAKEFILE_LIST}\
	| sed 's/:.*##/#/'\
	| column -t -c 2 -s '#'
setup: $(assets_files) $(proto_files) vendor ## Set up project
install: $(bin_files) ## Install application
clean: ## Clean up files
	@printf '==> '
	rm -f coverage.out
format: $(source_files) $(test_files) ## Format all go files
	@printf '==> '
	$(GO) fmt $(call package_path_from_file,$?)
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
	cd $(dir $@); go-bindata -pkg $(call dir_from_file,$@) $(ASSETS)
%.pb.go: %.proto | $(protoc)
	@printf '==> '
	protoc --go_out=plugins=grpc,import_path=$(call dir_from_file,$@):. $?
coverage.out: $(source_files) $(test_files) | $(goacc)
	@printf '==> '
	$(goacc) -o $@ $(call package_path_from_file,$(filter %_test.go,$^))
vendor: $(source_files) $(test_files) $(proto_files) | $(dep)
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
$(protoc):
	@printf '==> '
	$(go_get) github.com/golang/protobuf/protoc-gen-go
