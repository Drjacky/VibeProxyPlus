// Persistence
//
// Namespaced storage primitives shared by engines: NamespacedDefaults, KeychainStore,
// EngineDirectoryLayout (per-engine dotfolders such as ~/.cli-proxy-api and ~/.dario),
// FileStore. Depends on EngineKit only.
//
// Populated in Phase 1 (see plans/dario-integration-architecture.md, Sections 26-32).

import Foundation
import EngineKit

/// Marker namespace for the Persistence module.
public enum Persistence {}
