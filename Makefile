PUSH ?= 
LOAD ?=

LOCAL_ARCH = $(shell uname -m)
ifeq ($(LOAD), 1)
PLATFORMS ?= $(LOCAL_ARCH)
ifneq (1, $(words $(PLATFORMS)))
$(error Cannot load for more than one platform: [$(PLATFORMS)])
endif
else
PLATFORMS ?= amd64 arm64 arm/v7
endif

null  :=
space := $(null) #
comma := ,

DOCKER_PLATFORMS = $(subst $(space),$(comma),$(strip $(addprefix linux/, $(PLATFORMS))))
REGISTRY ?= devcaptest.azurecr.io
UNIQUE_ID ?= $(USER)
PREFIX ?= $(REGISTRY)/$(UNIQUE_ID)
COMMON_DOCKER_BUILD_ARGS = $(if $(LOAD), --load) $(if $(PUSH), --push) --platform=$(DOCKER_PLATFORMS) 

# Evaluate VERSION and TIMESTAMP immediately to avoid
# any lazy evaluation change in the values
VERSION := $(shell cat version.txt)
TIMESTAMP := $(shell date +"%Y%m%d_%H%M%S")

VERSION_LABEL=v$(VERSION)-$(TIMESTAMP)
LABEL_PREFIX ?= $(VERSION_LABEL)

.PHONY: all
all: apps brokers

.PHONY: apps
apps: anomaly-detection-app video-streaming-app

%-app:
	docker buildx build $(COMMON_DOCKER_BUILD_ARGS) \
		--tag "$(PREFIX)/$@:$(LABEL_PREFIX)" \
		--build-arg APPLICATION=$@ \
		--file build/apps/Dockerfile.python-app .

.PHONY: brokers
brokers: udev-video-broker opcua-monitoring-broker

udev-video-broker:
	docker buildx build $(COMMON_DOCKER_BUILD_ARGS) \
		--tag "$(PREFIX)/$@:$(LABEL_PREFIX)" \
		--build-arg EXTRA_CARGO_ARGS="$(if $(BUILD_RELEASE_FLAG), --release)" \
		--file build/brokers/Dockerfile.rust \
		brokers/$@

opcua-monitoring-broker:
	docker buildx build $(COMMON_DOCKER_BUILD_ARGS) \
		--tag "$(PREFIX)/$@:$(LABEL_PREFIX)" \
		--file build/brokers/Dockerfile.opcua-monitoring-broker .
