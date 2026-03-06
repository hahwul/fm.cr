+++
title = "Getting Started"
description = "Prerequisites, installation, and your first fm.cr program"
weight = 1
+++

## Prerequisites

Before using fm.cr, ensure your environment meets these requirements:

| Requirement | Version |
|-------------|---------|
| macOS | 26+ (Tahoe) |
| Xcode | 26+ with FoundationModels.framework |
| Crystal | >= 1.19.1 |
| Hardware | Apple Silicon (M1 or later) |

Apple Intelligence must be enabled in **System Settings > Apple Intelligence & Siri**.

> The active developer directory must point to the full Xcode installation, not Command Line Tools. If you encounter build errors, run: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  fm:
    github: hahwul/fm.cr
```

Then install:

```bash
shards install
```

The native Swift FFI library (`libfm_ffi.a`) is built automatically via the `postinstall` script.

## Your First Program

Create a file called `hello.cr`:

```crystal
require "fm"

# Create the on-device language model
model = Fm::SystemLanguageModel.new

# Ensure the model is available
model.ensure_available!

# Create a session with instructions
session = Fm::Session.new(model, instructions: "You are a helpful assistant.")

# Generate a response
response = session.respond("What is the capital of France?")
puts response.content
```

Run it:

```bash
crystal run hello.cr
```

## Checking Model Availability

Before generating responses, you can check whether the model is available and handle different states:

```crystal
model = Fm::SystemLanguageModel.new

case model.availability
when .available?
  puts "Ready to use"
when .device_not_eligible?
  puts "Device doesn't support Apple Intelligence"
when .apple_intelligence_not_enabled?
  puts "Enable Apple Intelligence in System Settings"
when .model_not_ready?
  puts "Model is still downloading..."
end
```

You can also use `ensure_available!` to raise an appropriate error if the model is not ready.

## Troubleshooting

### Build fails with `FoundationModelsMacros` not found

This happens when the active developer directory is set to Command Line Tools instead of Xcode.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify with:

```bash
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer
```

### Model is not available or device not eligible

Apple Intelligence must be enabled on your Mac, and the device must have Apple Silicon. Check **System Settings > Apple Intelligence & Siri**.

### Token usage returns `nil`

The `token_usage_for` API requires **macOS 26.4+**. On older versions, it returns `nil` by design.
