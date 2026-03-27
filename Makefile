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

USE_OPENCV_BASE_VERSION = 0.0.11
AMD64_SUFFIX = amd64
ARM32V7_SUFFIX = arm32v7
ARM64V8_SUFFIX = arm64v8

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
brokers: udev-video-broker onvif-video-broker opcua-monitoring-broker

udev-video-broker:
	docker buildx build $(COMMON_DOCKER_BUILD_ARGS) \
		--tag "$(PREFIX)/$@:$(LABEL_PREFIX)" \
		--build-arg EXTRA_CARGO_ARGS="$(if $(BUILD_RELEASE_FLAG), --release)" \
		--file build/brokers/Dockerfile.rust \
		brokers/$@

# Still use old-ish style for onvif-video-broker as app uses .NET 3.1 that doesn't have multi-arch manifest
onvif-video-broker: onvif-video-broker-multiarch

onvif-video-broker-multiarch: onvif-video-broker-amd64 onvif-video-broker-arm64 onvif-video-broker-arm32
ifeq (1, $(PUSH))
	docker buildx imagetools create --tag "$(PREFIX)/onvif-video-broker:$(LABEL_PREFIX)"
endif

ONVIF_BUILDX_PUSH_OUTPUT = type=image,name=$(PREFIX)/onvif-video-broker,push-by-digest=true,name-canonical=true,push=true
ONVIF_BUILDX_ARGS = $(if $(LOAD), --load --tag $(PREFIX)/onvif-video-broker:$(LABEL_PREFIX)) $(if $(PUSH), --output $(ONVIF_BUILDX_PUSH_OUTPUT)) -f build/brokers/Dockerfile.onvif-video-broker

onvif-video-broker-amd64:
ifneq (,or(findstring(amd64,$(PLATFORMS)), findstring(x86_64,$(PLATFORMS))))
	docker buildx build $(ONVIF_BUILDX_ARGS) $(if $(PUSH), --iidfile onvif-video-broker.sha-amd64) --build-arg OUTPUT_PLATFORM_TAG=$(USE_OPENCV_BASE_VERSION)-$(AMD64_SUFFIX) --build-arg DOTNET_PUBLISH_RUNTIME=linux-x64 .
endif

onvif-video-broker-arm32:
ifneq (,findstring(arm/v7,$(PLATFORMS)))
	docker buildx build $(ONVIF_BUILDX_ARGS) $(if $(PUSH), --iidfile onvif-video-broker.sha-arm32) --build-arg OUTPUT_PLATFORM_TAG=$(USE_OPENCV_BASE_VERSION)-$(ARM32V7_SUFFIX) --build-arg DOTNET_PUBLISH_RUNTIME=linux-arm .
endif

onvif-video-broker-arm64:
ifneq (,or(findstring(aarch64,$(PLATFORMS)),findstring(arm64,$(PLATFORMS))))
	docker buildx build $(ONVIF_BUILDX_ARGS) $(if $(PUSH), --iidfile onvif-video-broker.sha-arm64) --build-arg OUTPUT_PLATFORM_TAG=$(USE_OPENCV_BASE_VERSION)-$(ARM64V8_SUFFIX) --build-arg DOTNET_PUBLISH_RUNTIME=linux-arm64 .
endif

opcua-monitoring-broker:
	docker buildx build $(COMMON_DOCKER_BUILD_ARGS) \
		--tag "$(PREFIX)/$@:$(LABEL_PREFIX)" \
		--file build/brokers/Dockerfile.opcua-monitoring-broker \
		brokers/$@
