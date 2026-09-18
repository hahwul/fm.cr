import Foundation
import FoundationModels

private struct TokenUsageError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func noOpToolCallback(
    _ userData: UnsafeMutableRawPointer?,
    _ toolName: UnsafePointer<CChar>?,
    _ argumentsJson: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>? {
    _ = userData
    _ = toolName
    _ = argumentsJson
    return nil
}

private func tokenUsageTools(from toolsJson: UnsafePointer<CChar>?) throws -> [any Tool] {
    let toolDefinitions = try parseToolDefinitions(toolsJson)
    if toolDefinitions.isEmpty {
        return []
    }
    let dispatcher = ToolDispatcher(
        toolDefinitions: toolDefinitions,
        userData: nil,
        callback: noOpToolCallback
    )
    return buildToolBridges(dispatcher: dispatcher)
}

/// Returns the token count for a prompt using 26.4+ APIs when available.
/// Returns a sentinel when runtime APIs are unavailable.
@_cdecl("fm_model_token_usage_for")
public func fm_model_token_usage_for(
    _ modelPtr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int64 {
    let model = Unmanaged<AnyObject>.fromOpaque(modelPtr).takeUnretainedValue() as! SystemLanguageModel
    let promptString = String(cString: prompt)

    if #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) {
        do {
            let tokenCount = try AsyncWaiter.wait {
                try await model.tokenCount(for: promptString)
            }
            guard let tokenCount = Int64(exactly: tokenCount) else {
                throw TokenUsageError(message: "Token count value is out of Int64 range")
            }
            return tokenCount
        } catch {
            if let errorOut = errorOut {
                errorOut.pointee = createGenerationErrorFromException(error)
            }
            return -1
        }
    }

    // Runtime is older than 26.4; Crystal surfaces nil so callers can choose a fallback.
    _ = errorOut
    return tokenUsageUnavailableSentinel
}

/// Returns the token count for instructions + tools using 26.4+ APIs when available.
/// Returns a sentinel when runtime APIs are unavailable.
@_cdecl("fm_model_token_usage_for_tools")
public func fm_model_token_usage_for_tools(
    _ modelPtr: UnsafeMutableRawPointer,
    _ instructions: UnsafePointer<CChar>,
    _ toolsJson: UnsafePointer<CChar>?,
    _ errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int64 {
    let model = Unmanaged<AnyObject>.fromOpaque(modelPtr).takeUnretainedValue() as! SystemLanguageModel
    let instructionsString = String(cString: instructions)

    if #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) {
        do {
            let tools = try tokenUsageTools(from: toolsJson)
            let tokenCount = try AsyncWaiter.wait {
                let instructionsCount = try await model.tokenCount(for: Instructions(instructionsString))
                guard !tools.isEmpty else { return instructionsCount }

                let toolsCount = try await model.tokenCount(for: tools)
                let (total, overflow) = instructionsCount.addingReportingOverflow(toolsCount)
                guard !overflow else {
                    throw TokenUsageError(message: "Combined token count value is out of Int range")
                }
                return total
            }
            guard let tokenCount = Int64(exactly: tokenCount) else {
                throw TokenUsageError(message: "Token count value is out of Int64 range")
            }
            return tokenCount
        } catch {
            if let errorOut = errorOut {
                errorOut.pointee = createGenerationErrorFromException(error)
            }
            return -1
        }
    }

    // Runtime is older than 26.4; Crystal surfaces nil so callers can choose a fallback.
    _ = errorOut
    return tokenUsageUnavailableSentinel
}

/// Returns the model's context window size. The symbol was added in the 26.4
/// SDK but is back-deployed by FoundationModels to macOS 26.0.
@_cdecl("fm_model_context_size")
public func fm_model_context_size(_ modelPtr: UnsafeMutableRawPointer) -> Int64 {
    let model = Unmanaged<AnyObject>.fromOpaque(modelPtr).takeUnretainedValue() as! SystemLanguageModel

    if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        return Int64(model.contextSize)
    }

    return tokenUsageUnavailableSentinel
}
