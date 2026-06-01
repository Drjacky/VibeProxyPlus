// DarioEngine
//
// Isolated implementation of the Dario engine: a bundled local subprocess HTTP proxy with its
// own settings UI, health probe, and logs. On-disk home is ~/.dario.
//
// ISOLATION INVARIANT: this module must NEVER import CLIProxyEngine.
//
// Depends on EngineKit, Persistence, ProcessRuntime, Diagnostics, SharedUI.

import Foundation
import EngineKit

/// Marker namespace for the DarioEngine module.
public enum DarioEngine {}
