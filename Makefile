#!/bin/make

GO_TAG:=$(shell /bin/sh -c 'eval `go tool dist env`; echo "$${GOOS}_$${GOARCH}"')
GIT_TAG:=$(shell git rev-parse --short HEAD)
GOPATH:=$(shell go env GOPATH)
SOURCES:=$(shell find . -name '*.go')

-include contrib/config.mak

# variables that should be set in contrib/config.mak
ifeq ($(DIST_ARCHS),)
DIST_ARCHS=linux_amd64 linux_386 linux_arm linux_arm64 linux_ppc64 linux_ppc64le darwin_amd64 darwin_386 freebsd_386 freebsd_amd64 freebsd_arm windows_386 windows_amd64
endif
ifeq ($(PROJECT_NAME),)
PROJECT_NAME:=$(shell basename `pwd`)
endif

# do we have a defined target arch?
ifneq ($(TARGET_ARCH),)
TARGET_ARCH_SPACE:=$(subst _, ,$(TARGET_ARCH))
TARGET_GOOS=$(word 1,$(TARGET_ARCH_SPACE))
TARGET_GOARCH=$(word 2,$(TARGET_ARCH_SPACE))
endif

.PHONY: all deps update fmt test check doc dist update-make

all: $(PROJECT_NAME)

$(PROJECT_NAME): $(SOURCES)
	$(GOPATH)/bin/goimports -w -l .
	go build -v -gcflags "-N -l"

clean:
	go clean

deps:
	go get -v .

update:
	go get -u .

fmt:
	go fmt ./...
	$(GOPATH)/bin/goimports -w -l .

test:
	go test ./...

check:
	@if [ ! -f $(GOPATH)/bin/gometalinter ]; then go get github.com/alecthomas/gometalinter; fi
	$(GOPATH)/bin/gometalinter ./...

doc:
	@if [ ! -f $(GOPATH)/bin/godoc ]; then go get golang.org/x/tools/cmd/godoc; fi
	$(GOPATH)/bin/godoc -v -http=:6060 -index -play

dist:
	@mkdir -p dist/$(PROJECT_NAME)_$(GIT_TAG)
	@make -s dist/$(PROJECT_NAME)_$(GIT_TAG).tar.lzma

dist/$(PROJECT_NAME)_$(GIT_TAG).tar.lzma: $(patsubst %,dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME).%,$(DIST_ARCHS))
	tar --lzma -cvf $@ -C dist/$(PROJECT_NAME)_$(GIT_TAG) .

dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME).%: $(SOURCES)
	@echo "Building $(PROJECT_NAME) for $*"
	@TARGET_ARCH="$*" make -s dist/$(PROJECT_NAME)_$(GIT_TAG)/build_$(PROJECT_NAME).$*
	@mv 'dist/$(PROJECT_NAME)_$(GIT_TAG)/build_$(PROJECT_NAME).$*' 'dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME).$*'

ifneq ($(TARGET_ARCH),)
dist/$(PROJECT_NAME)_$(GIT_TAG)/build_$(PROJECT_NAME).$(TARGET_ARCH): $(SOURCES)
	@GOOS="$(TARGET_GOOS)" GOARCH="$(TARGET_GOARCH)" go build -a -o "$@" -gcflags "-N -l"
endif

update-make:
	@echo "Updating Makefile ..."
	@curl -s "https://raw.githubusercontent.com/MagicalTux/make-go/master/Makefile" >Makefile.upd
	@mv -f "Makefile.upd" "Makefile"
