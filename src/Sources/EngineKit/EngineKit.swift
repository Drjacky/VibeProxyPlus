// EngineKit
//
// Shared engine contracts and lifecycle abstractions (Engine, EngineDescriptor, EngineID,
// EngineContext, EngineRegistry, EngineSelectionStore, CrashSentinel). Depends on Foundation only.
// This module must never import any concrete engine module (CLIProxyEngine, DarioEngine).

import Foundation

/// Marker namespace for the EngineKit module.
public enum EngineKit {
    /// Semantic version of the engine-contract surface. Bumped when contracts change.
    public static let contractVersion = "0.0.0"
}
