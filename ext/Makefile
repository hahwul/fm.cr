SWIFTC ?= swiftc
MODULE_NAME = fm_ffi
LIB_NAME = lib$(MODULE_NAME).a

# Build for the host architecture. Hardcoding arm64 produced an arm64 archive
# on an x86_64 host, which then failed to link into the Crystal binary with an
# architecture-mismatch error rather than anything pointing back here.
# macosx26.0 is the deployment floor (FoundationModels requires macOS 26+).
HOST_ARCH := $(shell uname -m)
SWIFT_ARCH ?= $(if $(HOST_ARCH),$(HOST_ARCH),arm64)
SWIFT_TARGET ?= $(SWIFT_ARCH)-apple-macosx26.0

# Detect SDK path
SDK_PATH := $(shell xcrun --show-sdk-path --sdk macosx 2>/dev/null)
SDK_VERSION := $(shell xcrun --show-sdk-version --sdk macosx 2>/dev/null)

# Determine token usage source file based on SDK version (>= 26.4).
#
# The numeric comparisons are guarded by pattern matches: without xcrun (or
# with an SDK version that does not parse) SDK_MAJOR is empty, and the previous
# `[ "" -gt 26 ]` leaked a bare `[: Illegal number:` to stderr on every build.
# The old `2>/dev/null` only covered the last `[` of the `&&` chain.
SDK_MAJOR := $(word 1,$(subst ., ,$(SDK_VERSION)))
SDK_MINOR := $(word 2,$(subst ., ,$(SDK_VERSION)))

# Reduce each component to digits so the tests below are always numeric. An
# absent component yields an empty major (handled as "no") or a zero minor.
SDK_MAJOR_NUM := $(strip $(shell printf '%s' '$(SDK_MAJOR)' | tr -cd '0-9'))
SDK_MINOR_NUM := $(or $(strip $(shell printf '%s' '$(SDK_MINOR)' | tr -cd '0-9')),0)

USE_TOKEN_API := $(shell \
	major='$(SDK_MAJOR_NUM)'; minor='$(SDK_MINOR_NUM)'; \
	if [ -z "$$major" ]; then echo no; \
	elif [ "$$major" -gt 26 ]; then echo yes; \
	elif [ "$$major" -eq 26 ] && [ "$$minor" -ge 4 ]; then echo yes; \
	else echo no; fi)

ifeq ($(USE_TOKEN_API),yes)
TOKEN_USAGE_SRC = token_usage_api.swift
else
TOKEN_USAGE_SRC = token_usage_fallback.swift
endif

SWIFT_SOURCES = ffi.swift $(TOKEN_USAGE_SRC)

SWIFT_FLAGS = -emit-library -static \
	-module-name $(MODULE_NAME) \
	-target $(SWIFT_TARGET)

ifneq ($(SDK_PATH),)
SWIFT_FLAGS += -sdk $(SDK_PATH)
endif

.PHONY: all clean

all: $(LIB_NAME)

$(LIB_NAME): $(SWIFT_SOURCES)
	$(SWIFTC) $(SWIFT_FLAGS) -o $@ $(SWIFT_SOURCES)

clean:
	rm -f $(LIB_NAME) *.o *.swiftmodule *.swiftdoc *.abi.json
