#!/usr/bin/make -f

RELEASE_VERSION ?= latest

.PHONY: test-build test build build-static docker-test docker-build-static build-bats docker-acceptance docker-image release update-deps

test-build: test build

test:
	go test -race ./...

build:
	go build -o bin/ ./...

docker-image:
	docker build -t kubeconform:${RELEASE_VERSION} .

save-image:
	docker save --output kubeconform-image.tar kubeconform:${RELEASE_VERSION}

push-image:
	docker tag kubeconform:latest ghcr.io/yannh/kubeconform:${RELEASE_VERSION}
	docker push ghcr.io/yannh/kubeconform:${RELEASE_VERSION}

build-static:
	CGO_ENABLED=0 GOFLAGS=-mod=vendor GOOS=linux GOARCH=amd64 GO111MODULE=on go build -trimpath -tags=netgo -ldflags "-extldflags=\"-static\""  -a -o bin/ ./...

docker-test:
	docker run -t -v $$PWD:/go/src/github.com/yannh/kubeconform -w /go/src/github.com/yannh/kubeconform golang:1.17 make test

docker-build-static:
	docker run -t -v $$PWD:/go/src/github.com/yannh/kubeconform -w /go/src/github.com/yannh/kubeconform golang:1.17 make build-static

build-bats:
	docker build -t bats -f Dockerfile.bats .

docker-acceptance: build-bats
	docker run -t bats -p acceptance.bats
	docker run --network none -t bats -p acceptance-nonetwork.bats

build-single-target:
	docker run -t -e GOOS=linux -e GOARCH=amd64 -v $$PWD:/go/src/github.com/yannh/kubeconform -w /go/src/github.com/yannh/kubeconform goreleaser/goreleaser:v0.176.0 build --single-target --skip-post-hooks --rm-dist --snapshot
	cp dist/kubeconform_linux_amd64/kubeconform bin/

release:
	docker run -e GITHUB_TOKEN -t -v /var/run/docker.sock:/var/run/docker.sock -v $$PWD:/go/src/github.com/yannh/kubeconform -w /go/src/github.com/yannh/kubeconform goreleaser/goreleaser:v0.176.0 release --rm-dist

update-deps:
	go get -u ./...
	go mod tidy
