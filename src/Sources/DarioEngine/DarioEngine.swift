// DarioEngine
//
// Fully isolated implementation of the Dario engine (bundled local subprocess HTTP proxy).
// Implemented in Phase 5: DarioHost, config resolver, health probe, logs, routing/DNS/
// profiles/import-export/diagnostics UI. On-disk home is ~/.dario.
//
// ISOLATION INVARIANT: this module must NEVER import CLIProxyEngine.
//
// Depends on EngineKit, Persistence, ProcessRuntime, Diagnostics, SharedUI.

import Foundation
import EngineKit

/// Marker namespace for the DarioEngine module.
public enum DarioEngine {}
