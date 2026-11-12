# Changelog

## Unreleased

### Fixed
- An unreferenced session (`Session.new(model).respond_json(...)`) is no longer collectable while its request waits; every waiting `Session` request now keeps `self` reachable until the native call returns (`respond_json` and `respond_structured` were the ones that did not already). Other fibers run during that wait, so a GC there could finalize the session, cancelling the native request and freeing the tool box its callbacks use.
- A program that called both a waiting `Session` request (`respond`, ...) and `Session.from_transcript(..., tools:)` failed to compile with `BUG: trying to downcast (Fm::Session | String) <- Fm::Session`; `Fm.keep_alive` no longer trips that compiler bug.
- `Generable` on a recursive type (`children : Array(Node)`) overflowed the stack; the recursive reference is now a `$ref` (`#` for the root, otherwise into a root `$defs`), which FoundationModels generates natively.
- Two instantiations of one generic `Generable` type (`Wrap(Int32)` and `Wrap(String)`) shared the title `Wrap(T)`, so FoundationModels merged them and generated both with the first one's shape. Titles now use the instantiated type name.
- `Transcript#==` and `#hash` compared the parse caches too, so a transcript stopped equalling an identical one once either had been read. They now compare the JSON documents, so formatting (pretty vs compact) does not matter either.

## v0.4.0

### Added
- macOS 27 Foundation Models surfaces: `GenerationOptions#tool_calling_mode`, `Fm::ContextOptions` (schema-in-prompt control and `Fm::ReasoningLevel`) accepted as `context_options:` by every `Session` request method, and `Fm::Usage` token counts on `Fm::Response#usage` with `Session#usage` / `Session#last_usage`
- `Fm::Schema` normalizer that emits schemas the native `GenerationSchema` decoder accepts, so structured output and per-tool registration no longer silently fall back to prompt-based JSON and the generic tool bridge
- `Fm::Transcript` as a first-class object (`Session#transcript`, `Session#from_transcript`) and `GenerationErrorCode` replacing magic numbers in error mapping
- `CancelledError`, `UnsupportedSchemaTypeError`, and macOS 27 errors for unsupported capabilities, unsupported transcript content, and transcript mutation during a response
- `SystemLanguageModel#token_count_for`, `#token_count_for_tools`, `#context_size` (the `token_usage_*` names remain as aliases), exact transcript token counting, and `ContextLimit.default_on_device(model)` for the model's runtime-reported context size
- Ameba lint baseline and a CI format check

### Fixed
- `Generable`: nilable unions kept only the first non-nil variant, `@[Flags]` enums were described as strings instead of arrays, and only the last of several stacked `Fm::Guide` annotations was applied
- `Fm::Guide` truncated fractional `minimum` / `maximum` bounds to integers
- `Session#respond(timeout:)` and `SystemLanguageModel#wait_until_available` turned sub-millisecond timeouts into "no timeout" and raised a bare `OverflowError` for negative spans
- An exception in a `Session#stream` block or `tool_callback` unwound into the Swift frame and aborted the process
- A `seed` without a sampling mode was serialized where the Swift decoder never read it, silently dropping reproducibility
- Transcript text nested under `content` / `text` was dropped, under-counting tokens and feeding compaction a transcript with the conversation missing; `Transcript` also gained a `to_json(JSON::Builder)` overload
- Streaming deltas were computed per `Character`, duplicating or dropping grapheme-extending sequences (combining accents, ZWJ emoji)
- macOS 27 error details survive both blocking and streaming FFI paths and keep their typed Crystal exceptions; `UnsupportedTranscriptContentError#unsupported_content` now carries the rejected entries as encoded JSON
- `ext/Makefile` hardcoded an `arm64` target and printed a shell error when `xcrun` was unavailable

### Changed
- Requires Crystal >= 1.21.0
- Automatic context compaction uses FoundationModels' native transcript token count on macOS 26.4+ instead of a character estimate
- Xcode 27 builds use the finalized `SystemLanguageModel.tokenCount(for:)` and `GenerationOptions(samplingMode:)` APIs while keeping a macOS 26 deployment target
- Documentation site redesigned on the shared ecosystem design system

## v0.3.0

### Added
- Per-tool bridge: each Crystal tool is registered as an individual native FoundationModels Tool with its own name, description, and schema (falls back to generic bridge when schema decoding fails)
- `Generable` type support for `Hash`, `Enum`, and non-nil `Union` types in JSON Schema generation
- Prompt-based fallback for structured output when native `GenerationSchema` decoding fails

### Fixed
- `GenerationOptions` now properly maps `top-k`, `top-p`, and `seed` to native `GenerationOptions.SamplingMode` (previously ignored)
- Streaming errors now use full `GenerationError` differentiation instead of generic `generationFailed`

### Improved
- Structured output (`respond_json`, `stream_json`) uses native `GenerationSchema` API for guaranteed schema compliance
- Unified streaming error handling via `mapStreamingError`

### Deprecated
- `Adapter` class (`AdapterAsset` was removed in macOS 26.2 SDK)

## v0.2.0

### Added
- `GenerationGuide` for guided generation with use cases and guardrails
- Granular error types for better error handling
- Chatbot example (`examples/chatbot.cr`)
- Context, JSON schema, timeout, token usage examples
- CI workflow with GitHub Actions
- Swift FFI extension (`ext/ffi.swift`)
- Tests and specs

### Improved
- Code quality improvements across core modules
- Session and model handling

## v0.1.0

- Initial release
