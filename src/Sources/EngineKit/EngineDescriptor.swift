import Foundation

/// Static, declarative metadata describing an engine.
///
/// The registry uses this to list known engines and to label UI affordances without
/// instantiating the engine. The `id` is the stable, persisted identifier.
public struct EngineDescriptor: Sendable, Equatable {
    /// Stable, persisted engine identifier.
    public let id: EngineID
    /// Human-readable name shown in menus and dialogs (for example "cliproxyapiplus").
    public let displayName: String

    public init(id: EngineID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
