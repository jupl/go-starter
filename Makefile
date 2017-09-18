MAKEFLAGS+=--no-builtin-rules

# Overridable options
PACKAGE?=...
GO?=go

# Go related variables
go_get=$(GO) get
go_bin=$(shell $(GO) env GOPATH)/bin
goacc=$(go_bin)/go-acc
bindata=$(go_bin)/go-bindata
dep=$(go_bin)/dep

# Search for relevant files
# https://stackoverflow.com/a/18258352
# https://stackoverflow.com/a/12324443
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $2,$d))
files:=$(filter-out vendor/%,$(call rwildcard,,%.go))
go_files:=$(filter-out %/bindata.go,$(files))
src_files:=$(filter-out %_test.go,$(files))
generate_files:=$(patsubst %/assets,%/bindata.go,$(filter %/assets,$(call rwildcard,,%)))

.PHONY: setup install clean format htmlcov test
.SUFFIXES:

#
# Tasks
#
help: # https://blog.sneawo.com/blog/2017/06/13/makefile-help-target/
	@egrep '^(.+)\:\ .*##\ (.+)' ${MAKEFILE_LIST} | sed 's/:.*##/#/' | column -t -c 2 -s '#'
setup: $(generate_files) vendor ## Set up project
install: $(src_files) | setup ## Install application
	@printf '%s ' '==>'
	$(GO) install ./cmd/$(PACKAGE)

#
# Development
#
clean: ## Clean up files
	@printf '%s ' '==>'
	rm -f coverage.out
format: $(go_files) ## Format all go files
	@printf '%s ' '==>'
	$(GO) fmt ./...
htmlcov: coverage.out ## Generate HTML coverage report
	@printf '%s ' '==>'
	$(GO) tool cover -html=coverage.out
test: coverage.out ## Run all tests with code coverage

#
# Files
#
%/bindata.go: %/assets %/assets/* %/assets/*/* | $(bindata)
	@printf '%s ' '==>'
	$(GO) generate -x ./$(patsubst %/assets,%,$<)
coverage.out: $(files) | setup $(goacc)
	@printf '%s ' '==>'
	$(goacc) -o $@ ./...
vendor: Gopkg.toml Gopkg.lock $(go_files) | $(dep)
	@printf '%s ' '==>'
	$(dep) ensure

#
# Go bin dependencies
#
$(goacc):
	@printf '%s ' '==>'
	$(go_get) github.com/ory/go-acc
$(bindata):
	@printf '%s ' '==>'
	$(go_get) github.com/jteeuwen/go-bindata/...
$(dep):
	@printf '%s ' '==>'
	$(go_get) github.com/golang/dep/cmd/dep
