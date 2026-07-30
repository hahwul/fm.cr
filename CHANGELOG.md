# Changelog

## Unreleased

### Fixed
- `Generable` kept only the first non-nil variant of a nilable union, so `String | Int32 | Nil` was described as a bare integer and the schema rejected the string variant
- `Fm::Guide` truncated fractional `minimum` / `maximum` bounds to integers, widening `minimum: 0.5` to `0` and narrowing `maximum: 9.5` to `9`
- `Generable` described a `@[Flags]` enum as a string, but `JSON::Serializable` reads and writes it as an array of member names, so structured generation could never decode it; the synthesized `None` / `All` members were advertised as values too
- Only the last of several stacked `Fm::Guide` annotations on a field was applied, silently discarding the rest
- `Session#respond(timeout:)` and `SystemLanguageModel#wait_until_available` truncated sub-millisecond timeouts to `0`, which means "no timeout" — a tiny timeout became an unbounded wait — and raised a bare `OverflowError` for negative spans
- Transcript text nested under a `content` / `text` key (how FoundationModels represents multi-segment content) was dropped from text extraction, under-counting tokens and feeding compaction a transcript with the conversation missing
- An exception raised in a `Session#stream` block unwound into the Swift frame holding the FFI semaphore, aborting the process instead of surfacing at the call site; `tool_callback` had the same exposure outside its inner rescue
- A `seed` set without a sampling mode was serialized outside the `sampling` object, where the Swift decoder never read it, so requested reproducibility was silently dropped
- `Transcript` could not be embedded in an enclosing JSON document — no `to_json(JSON::Builder)` overload existed — despite exposing `to_json` / `from_json`
- Streaming deltas were computed from a `Character` count, so a snapshot extending the last grapheme (combining accents, ZWJ emoji sequences) emitted duplicated or missing characters
- `ext/Makefile` hardcoded an `arm64` target, producing an unlinkable archive on x86_64 hosts, and printed a shell error when `xcrun` was unavailable

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
