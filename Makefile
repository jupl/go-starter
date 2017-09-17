# Overridable options
PACKAGE?=...
GO?=go

# Go related variables
goget=$(GO) get
gopath=$(shell $(GO) env GOPATH)
gobin=$(gopath)/bin
goacc=$(gobin)/go-acc
gobindata=$(gobin)/go-bindata
godep=$(gobin)/dep

# Search for relevant files
# https://stackoverflow.com/a/18258352
# https://stackoverflow.com/a/12324443
rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))
exclude=$(foreach v,$(2),$(if $(findstring $(1),$(v)),,$(v)))
go_files=$(call exclude,vendor/,$(call rwildcard,,*.go))
src_files=$(call exclude,_test.go,$(go_files))

.PHONY: setup install clean format htmlcov test generate

#
# Tasks
#
setup: generate vendor
install: setup $(src_files)
	$(GO) install ./cmd/$(PACKAGE)

#
# Development
#
clean:
	rm -f coverage.out
format: $(go_files)
	$(GO) fmt ./...
coverage.out: setup $(go_files) $(goacc)
	$(goacc) -o coverage.out ./...
htmlcov: coverage.out
	$(GO) tool cover -html=coverage.out
test: setup $(go_files)
	$(GO) test -cover ./...

#
# Project dependencies
#
generate: $(gobindata)
	$(GO) generate ./...
vendor: Gopkg.toml Gopkg.lock $(go_files) $(godep)
	$(godep) ensure

#
# Go bin dependencies
#
$(goacc):
	$(goget) github.com/ory/go-acc
$(gobindata):
	$(goget) github.com/jteeuwen/go-bindata/...
$(godep):
	$(goget) github.com/golang/dep/cmd/dep
