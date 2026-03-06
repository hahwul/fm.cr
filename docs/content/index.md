+++
title = "fm.cr"
description = "Crystal bindings for Apple FoundationModels.framework"
+++

Crystal bindings for Apple's FoundationModels framework. Run on-device AI powered by Apple Intelligence directly from Crystal.

> Requires **macOS 26+** (Tahoe) with Apple Intelligence enabled.

## Overview

fm.cr provides a Crystal interface to Apple's on-device language model through a Swift FFI bridge. It supports text generation, streaming, structured output with JSON schemas, tool calling, and context management -- all running locally on Apple Silicon.

## Quick Links

- **[Getting Started](/user-guide/getting-started/)** -- Installation, prerequisites, and your first program
- **[Basic Usage](/user-guide/basic-usage/)** -- Models, sessions, and generating responses
- **[API Reference](/api-reference/system-language-model/)** -- Complete API documentation

## Features

- **Text Generation** -- Synchronous and streaming responses
- **Structured Output** -- Type-safe responses using `Generable` or raw JSON schemas
- **Tool Calling** -- Extend model capabilities with custom tools
- **Adapters** -- Load custom adapters from file paths or bundle assets to customize model behavior
- **Context Management** -- Transcript export, token estimation, and automatic compaction
- **Session Restore** -- Save and restore conversation state via transcripts

## Installation

Add fm.cr to your `shard.yml`:

```yaml
dependencies:
  fm:
    github: hahwul/fm.cr
```

Then run:

```bash
shards install
```

The native Swift FFI library is built automatically via the `postinstall` script.
