// SharedUI
//
// Engine-neutral UI: theme, window chrome, the engine-switch confirmation dialog,
// and generic controls. Depends on EngineKit only. Must never import a concrete
// engine module; engine modules may import SharedUI.

import Foundation
import EngineKit

/// Marker namespace for the SharedUI module.
public enum SharedUI {}
