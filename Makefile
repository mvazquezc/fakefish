IMAGE_NAME ?= fakefish
ORG        ?= fakefish
REGISTRY   ?= quay.io
IMAGE_URL  ?= $(REGISTRY)/$(ORG)/$(IMAGE_NAME)
AUTHOR     ?= Mario Vazquez <mavazque@redhat.com>
TAG        ?= latest

.PHONY: build-dell build-custom pre-reqs

default: pre-reqs build-custom

build-dell:
	podman build . -f dell_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors="$(AUTHOR)"

build-custom:
	podman build . -f custom_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors"=$(AUTHOR)"

build-kubevirt:
	podman build . -f kubevirt_scripts/Containerfile -t $(IMAGE_URL):$(TAG) --label org.opencontainers.image.authors="$(AUTHOR)"
