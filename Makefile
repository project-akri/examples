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

%-app:
	docker buildx build $(COMMON_DOCKER_BUILD_ARGS) --build-arg APPLICATION=$@ --tag "$(PREFIX)/$@:$(LABEL_PREFIX)" --file $(DOCKERFILE_DIR)/Dockerfile.python-app .

.PHONY: all
all: apps

.PHONY: apps
apps: anomaly-detection-app video-streaming-app

%-app:
	docker buildx build $(COMMON_DOCKER_BUILD_ARGS) \
		--build-arg APPLICATION=$@ \
		--tag "$(PREFIX)/$@:$(LABEL_PREFIX)" \
		--file build/apps/Dockerfile.python-app .

