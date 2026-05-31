// SharedUI
//
// Engine-neutral UI: theme, window chrome, the engine-switch confirmation dialog,
// and generic controls. Depends on EngineKit only. Must never import a concrete
// engine module; engine modules may import SharedUI.
//
// Populated in Phase 3/4 (see plans/dario-integration-architecture.md, Sections 42, 37-40).

import Foundation
import EngineKit

/// Marker namespace for the SharedUI module.
public enum SharedUI {}
