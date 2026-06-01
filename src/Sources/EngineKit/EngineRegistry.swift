import Foundation

/// The single list of engines the application knows how to build.
///
/// The shell registers each engine's descriptor and a factory closure at boot. Adding a new
/// engine is a new module plus one `register` call. The registry never imports a concrete engine
/// module; factories are supplied by the shell, which is the only component allowed to depend on
/// both engines.
@MainActor
public final class EngineRegistry {
    /// Builds an engine instance from a context.
    public typealias Factory = (EngineContext) -> Engine

    private struct Registration {
        let descriptor: EngineDescriptor
        let factory: Factory
    }

    private var registrations: [EngineID: Registration] = [:]
    private var order: [EngineID] = []

    public init() {}

    /// Registers an engine. Re-registering the same id replaces the previous entry.
    public func register(_ descriptor: EngineDescriptor, factory: @escaping Factory) {
        if registrations[descriptor.id] == nil {
            order.append(descriptor.id)
        }
        registrations[descriptor.id] = Registration(descriptor: descriptor, factory: factory)
    }

    /// All registered descriptors, in registration order.
    public var descriptors: [EngineDescriptor] {
        order.compactMap { registrations[$0]?.descriptor }
    }

    /// Whether an engine with the given id is registered.
    public func contains(_ id: EngineID) -> Bool {
        registrations[id] != nil
    }

    /// The descriptor for an id, if registered.
    public func descriptor(for id: EngineID) -> EngineDescriptor? {
        registrations[id]?.descriptor
    }

    /// Builds the engine for the given id using the supplied context, or nil if unregistered.
    public func make(_ id: EngineID, context: EngineContext) -> Engine? {
        registrations[id]?.factory(context)
    }
}
