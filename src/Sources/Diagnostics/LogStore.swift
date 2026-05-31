import Foundation
import EngineKit

/// A fixed-capacity circular buffer that overwrites the oldest element when full.
///
/// When `count` reaches capacity, appending a new element overwrites the element at the
/// logical head and advances both head and tail, so the buffer always holds the most recent
/// `capacity` elements. Generalized from the engine log buffer in the original ServerManager.
struct RingBuffer<Element> {
    private var storage: [Element?]
    private var head = 0
    private var tail = 0
    private(set) var count = 0

    init(capacity: Int) {
        let safeCapacity = max(1, capacity)
        storage = Array(repeating: nil, count: safeCapacity)
    }

    var capacity: Int { storage.count }

    mutating func append(_ element: Element) {
        let capacity = storage.count
        storage[tail] = element

        if count == capacity {
            head = (head + 1) % capacity
        } else {
            count += 1
        }

        tail = (tail + 1) % capacity
    }

    mutating func removeAll() {
        let capacity = storage.count
        storage = Array(repeating: nil, count: capacity)
        head = 0
        tail = 0
        count = 0
    }

    func elements() -> [Element] {
        let capacity = storage.count
        guard count > 0 else { return [] }

        var result: [Element] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            let storageIndex = (head + index) % capacity
            if let value = storage[storageIndex] {
                result.append(value)
            }
        }

        return result
    }
}

/// A thread-safe, bounded, in-memory log buffer scoped to a single engine (or the shell).
///
/// Each engine owns its own `LogStore` so logs never cross engine boundaries. Lines are
/// timestamped on append and capped at `capacity`. An optional `onUpdate` callback is invoked
/// on the main queue after each append so UI log viewers can refresh.
public final class LogStore: @unchecked Sendable {
    private let scope: String
    private var buffer: RingBuffer<String>
    private let lock = NSLock()
    private let timestampFormatter: DateFormatter

    /// Invoked on the main queue with the full current log snapshot after each append.
    public var onUpdate: (([String]) -> Void)?

    /// - Parameters:
    ///   - scope: A short label included in each line (for example the engine id or "shell").
    ///   - capacity: Maximum number of retained lines. Defaults to 1000 (the original cap).
    public init(scope: String, capacity: Int = 1000) {
        self.scope = scope
        self.buffer = RingBuffer(capacity: capacity)
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        self.timestampFormatter = formatter
    }

    /// Appends a timestamped line and notifies `onUpdate` on the main queue.
    public func append(_ message: String) {
        let timestamp = timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"

        lock.lock()
        buffer.append(line)
        let snapshot = buffer.elements()
        lock.unlock()

        if let onUpdate {
            DispatchQueue.main.async {
                onUpdate(snapshot)
            }
        }
    }

    /// Returns the current retained lines, oldest first.
    public func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return buffer.elements()
    }

    /// Clears all retained lines.
    public func clear() {
        lock.lock()
        buffer.removeAll()
        lock.unlock()
    }
}
