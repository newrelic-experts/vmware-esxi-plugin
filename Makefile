INTEGRATION  := vmware-esxi
BINARY_NAME  := nr-$(INTEGRATION)
GO_PKGS      := $(shell go list ./... | grep -v -e "/vendor/" -e "/example")
GO_FILES     := $(shell find src -type f -name "*.go")
BUILD_DIR    := ./bin/
COVERAGE_DIR := ./coverage/
VALIDATE_DEPS = github.com/golang/lint/golint
DEPS          = github.com/kardianos/govendor
TEST_DEPS     = github.com/axw/gocov/gocov github.com/AlekSi/gocov-xml github.com/stretchr/testify/assert

GO       = govendor
GOLINT   = golint
GOFMT    = gofmt
GOVENDOR = govendor

all: build

build: clean validate test coverage compile

clean:
	@echo "=== $(INTEGRATION) === [ clean            ]: removing binaries and coverage file..."
	@rm -rfv $(BUILD_DIR)/* $(COVERAGE_DIR)/*

validate-deps:
	@echo "=== $(INTEGRATION) === [ validate-deps    ]: installing validation dependencies..."
	@$(GO) get -v $(VALIDATE_DEPS)

fmt:
	@printf "=== $(INTEGRATION) === [ validate-fmt     ]: running gofmt...  "
# `gofmt` expects files instead of packages. `go fmt` works with
# packages, but forces -l -w flags.
	@OUTPUT="$(shell $(GOFMT) -l $(GO_FILES))" ;\
	if [ -z "$$OUTPUT" ]; then \
		echo "passed." ;\
	else \
		echo "failed. Incorrect syntax in the following files:" ;\
		echo "$$OUTPUT" ;\
		exit 1 ;\
	fi

lint:
	@printf "=== $(INTEGRATION) === [ validate-lint    ]: running golint... "
	@OUTPUT="$(shell $(GOLINT) $(GO_PKGS) | tr \" \')" ;\
	if [ -z "$$OUTPUT" ]; then \
		echo "passed." ;\
	else \
		echo "failed. Issues found:" ;\
		echo "$$OUTPUT" ;\
		exit 1 ;\
	fi

vet:
	@printf "=== $(INTEGRATION) === [ validate-vet     ]: running go vet... "
	@OUTPUT="$(shell $(GO) vet $(GO_PKGS))" ;\
	if [ -z "$$OUTPUT" ]; then \
		echo "passed." ;\
	else \
		echo "failed. Issues found:" ;\
		echo "$$OUTPUT" ;\
		exit 1;\
	fi

validate-only: fmt lint vet
validate: validate-deps validate-only

compile-deps:
	@echo "=== $(INTEGRATION) === [ compile-deps     ]: installing build dependencies..."
	@$(GO) get $(DEPS)
	@$(GOVENDOR) sync

compile-only:
	@echo "=== $(INTEGRATION) === [ compile          ]: building $(BINARY_NAME)..."
	@$(GO) build -o $(BUILD_DIR)/$(BINARY_NAME) $(GO_FILES)

compile: compile-deps compile-only

coverage:
	@echo "=== $(INTEGRATION) === [ coverage         ]: generating coverage results..."
	@rm -rf $(COVERAGE_DIR)/*
	@for d in $(GO_PKGS); do \
		pkg=`basename $$d` ;\
		$(GO) test -coverprofile $(COVERAGE_DIR)/$$pkg.tmp $$d ;\
	done
	@echo 'mode: set' > $(COVERAGE_DIR)/coverage.out
	@cat $(COVERAGE_DIR)/*.tmp | grep -v 'mode: set' >> $(COVERAGE_DIR)/coverage.out
	@$(GO) tool cover -html=$(COVERAGE_DIR)/coverage.out -o $(COVERAGE_DIR)/coverage.html

test-deps: compile-deps
	@echo "=== $(INTEGRATION) === [ test-deps        ]: installing testing dependencies..."
	@$(GO) get -v $(TEST_DEPS)

test-unit:
	@echo "=== $(INTEGRATION) === [ unit-test        ]: running unit tests..."
	@$(GO) test -tags unit $(GO_PKGS)

test-integration:
	@echo "=== $(INTEGRATION) === [ integration-test ]: running integrtation tests..."
	@$(GO) test -tags integration $(GO_PKGS)

test-only: test-unit test-integration
test: test-deps test-only

.PHONY: all build clean coverage fmt lint vet validate-deps validate-only validate compile-deps compile-only compile test-deps test-unit test-integration test-only test
