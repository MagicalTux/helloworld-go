#!/bin/make

GO_TAG:=$(shell /bin/sh -c 'eval `go tool dist env`; echo "$${GOOS}_$${GOARCH}"')
GIT_TAG:=$(shell git rev-parse --short HEAD)
GOPATH:=$(shell go env GOPATH)
SOURCES:=$(shell find . -name '*.go')
DATE_TAG:=$(shell date '+%Y%m%d%H%M%S')
AWS:=$(shell which 2>/dev/null aws)

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
	go build -v -gcflags="-N -l" -ldflags=all="-X github.com/magicaltux/goupd.PROJECT_NAME=$(PROJECT_NAME) -X github.com/magicaltux/goupd.MODE=DEV -X github.com/magicaltux/goupd.GIT_TAG=$(GIT_TAG) -X github.com/magicaltux/goupd.DATE_TAG=$(DATE_TAG)"

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
	@make -s dist/$(PROJECT_NAME)_$(GIT_TAG).tar.xz
	@make -s $(patsubst %,dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME)_$(GIT_TAG)_%.tar.gz,$(DIST_ARCHS))
ifneq ($(AWS),)
	@echo "Uploading ..."
	@aws s3 cp --cache-control 'max-age=31536000' "dist/$(PROJECT_NAME)_$(GIT_TAG).tar.xz" "s3://dist-go/$(PROJECT_NAME)/$(PROJECT_NAME)_$(DATE_TAG)_$(GIT_TAG).tar.xz"
	aws s3 cp --cache-control 'max-age=31536000' $(patsubst %,dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME)_$(GIT_TAG)_%.tar.gz,$(DIST_ARCHS)) "s3://dist-go/$(PROJECT_NAME)/$(PROJECT_NAME)_$(DATE_TAG)_$(GIT_TAG)/"
	@echo "Configuring dist repository"
	@echo "$(DIST_ARCHS)" | aws s3 cp --cache-control 'max-age=31536000' --content-type 'text/plain' - "s3://dist-go/$(PROJECT_NAME)/$(PROJECT_NAME)_$(DATE_TAG)_$(GIT_TAG).arch"
	@echo "$(DATE_TAG) $(GIT_TAG) $(PROJECT_NAME)_$(DATE_TAG)_$(GIT_TAG)" | aws s3 cp --cache-control 'max-age=3600' --content-type 'text/plain' - "s3://dist-go/$(PROJECT_NAME)/LATEST"
	@echo "Sending to production complete!"
endif

dist/$(PROJECT_NAME)_$(GIT_TAG).tar.xz: dist/$(PROJECT_NAME)_$(GIT_TAG) $(patsubst %,dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME).%,$(DIST_ARCHS))
	@echo "Generating $@"
	@tar -cJf $@ --owner=root:0 --group=root:0 -C dist/$(PROJECT_NAME)_$(GIT_TAG) $(patsubst %,$(PROJECT_NAME).%,$(DIST_ARCHS))

dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME)_$(GIT_TAG)_%.tar.gz: dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME).%
	@echo "Generating $@"
	@tar -czf "$@" --owner=root:0 --group=root:0 --transform='flags=r;s|$(PROJECT_NAME).$*|$(PROJECT_NAME)|' -C dist/$(PROJECT_NAME)_$(GIT_TAG) $(PROJECT_NAME).$*

dist/$(PROJECT_NAME)_$(GIT_TAG):
	@mkdir "$@"

dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME).%: $(SOURCES)
	@echo " * Building $(PROJECT_NAME) for $*"
	@TARGET_ARCH="$*" make -s dist/$(PROJECT_NAME)_$(GIT_TAG)/build_$(PROJECT_NAME).$*
	@mv 'dist/$(PROJECT_NAME)_$(GIT_TAG)/build_$(PROJECT_NAME).$*' 'dist/$(PROJECT_NAME)_$(GIT_TAG)/$(PROJECT_NAME).$*'

ifneq ($(TARGET_ARCH),)
dist/$(PROJECT_NAME)_$(GIT_TAG)/build_$(PROJECT_NAME).$(TARGET_ARCH): $(SOURCES)
	@GOOS="$(TARGET_GOOS)" GOARCH="$(TARGET_GOARCH)" go build -a -o "$@" -gcflags="-N -l -trimpath=$(shell pwd)" -ldflags=all="-s -w -X github.com/magicaltux/goupd.PROJECT_NAME=$(PROJECT_NAME) -X github.com/magicaltux/goupd.MODE=PROD -X github.com/magicaltux/goupd.GIT_TAG=$(GIT_TAG) -X github.com/magicaltux/goupd.DATE_TAG=$(DATE_TAG)"
endif

update-make:
	@echo "Updating Makefile ..."
	@curl -s "https://raw.githubusercontent.com/MagicalTux/make-go/master/Makefile" >Makefile.upd
	@mv -f "Makefile.upd" "Makefile"
