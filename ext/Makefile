SWIFTC ?= swiftc
MODULE_NAME = fm_ffi
LIB_NAME = lib$(MODULE_NAME).a
SWIFT_TARGET ?= arm64-apple-macosx26.0

# Detect SDK path
SDK_PATH := $(shell xcrun --show-sdk-path --sdk macosx 2>/dev/null)
SDK_VERSION := $(shell xcrun --show-sdk-version --sdk macosx 2>/dev/null)

# Determine token usage source file based on SDK version (>= 26.4)
SDK_MAJOR := $(word 1,$(subst ., ,$(SDK_VERSION)))
SDK_MINOR := $(word 2,$(subst ., ,$(SDK_VERSION)))
USE_TOKEN_API := $(shell \
	if [ "$(SDK_MAJOR)" -gt 26 ] 2>/dev/null; then echo yes; \
	elif [ "$(SDK_MAJOR)" -eq 26 ] && [ "$(SDK_MINOR)" -ge 4 ] 2>/dev/null; then echo yes; \
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
