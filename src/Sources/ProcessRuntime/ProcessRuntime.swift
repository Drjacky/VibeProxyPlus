// ProcessRuntime
//
// Hardened subprocess lifecycle primitives shared by engines: ManagedProcess,
// PortAllocator, ProcessSupervisor, OrphanReaper. Depends on EngineKit only.
//
// Populated in Phase 1 (see plans/dario-integration-architecture.md, Sections 9-10).

import Foundation
import EngineKit

/// Marker namespace for the ProcessRuntime module.
public enum ProcessRuntime {}
