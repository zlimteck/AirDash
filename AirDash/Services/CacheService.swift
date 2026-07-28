import Foundation

final class TtlCache<T: Sendable>: @unchecked Sendable {
    private var value: T?
    private var fetchedAt: Date?
    private let ttl: TimeInterval
    private let lock = NSLock()

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get() -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard let value, let fetchedAt, Date().timeIntervalSince(fetchedAt) < ttl else { return nil }
        return value
    }

    func set(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        self.value = value
        self.fetchedAt = Date()
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        value = nil
        fetchedAt = nil
    }
}

final class KeyedTtlCache<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    private var store: [Key: (value: Value, fetchedAt: Date)] = [:]
    private let ttl: TimeInterval
    private let lock = NSLock()

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get(for key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = store[key], Date().timeIntervalSince(entry.fetchedAt) < ttl else { return nil }
        return entry.value
    }

    func set(_ value: Value, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        store[key] = (value, Date())
    }

    func invalidate(for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
}
