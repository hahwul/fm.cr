import Foundation

/// Returns a sentinel so Crystal can use local token estimation.
@_cdecl("fm_model_token_usage_for")
public func fm_model_token_usage_for(
    _ modelPtr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int64 {
    _ = modelPtr
    _ = prompt
    _ = errorOut
    return tokenUsageUnavailableSentinel
}

/// Returns a sentinel so Crystal can use local token estimation.
@_cdecl("fm_model_token_usage_for_tools")
public func fm_model_token_usage_for_tools(
    _ modelPtr: UnsafeMutableRawPointer,
    _ instructions: UnsafePointer<CChar>,
    _ toolsJson: UnsafePointer<CChar>?,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int64 {
    _ = modelPtr
    _ = instructions
    _ = toolsJson
    _ = errorOut
    return tokenUsageUnavailableSentinel
}
