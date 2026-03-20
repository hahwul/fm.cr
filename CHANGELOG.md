# Changelog

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
