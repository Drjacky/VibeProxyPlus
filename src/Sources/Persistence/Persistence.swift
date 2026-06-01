// Persistence
//
// Namespaced storage primitives shared by engines: NamespacedDefaults, KeychainStore, and
// EngineDirectoryLayout (per-engine dotfolders such as ~/.cli-proxy-api and ~/.dario).
// Depends on EngineKit only.

import Foundation
import EngineKit

/// Marker namespace for the Persistence module.
public enum Persistence {}
