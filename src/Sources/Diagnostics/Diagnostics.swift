// Diagnostics
//
// Observability primitives shared by engines: LogStore, HealthMonitor, CrashReporter,
// Telemetry, DiagnosticsBundle, SecretScrubber. Depends on EngineKit only.
//
// Populated in Phase 1/6 (see plans/dario-integration-architecture.md, Sections 31, 64-70).

import Foundation
import EngineKit

/// Marker namespace for the Diagnostics module.
public enum Diagnostics {}
