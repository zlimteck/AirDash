import Network
import Foundation

enum PingService {
    static func ping(hosts: [String], port: UInt16 = 443) async -> Int? {
        for host in hosts {
            if let ms = await ping(host: host, port: port) { return ms }
        }
        return nil
    }

    static func ping(host: String, port: UInt16 = 443) async -> Int? {
        await withCheckedContinuation { continuation in
            let state = PingState(continuation: continuation)

            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let connection = NWConnection(to: endpoint, using: .tcp)
            let start = Date()

            connection.stateUpdateHandler = { networkState in
                switch networkState {
                case .ready:
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    connection.cancel()
                    state.finish(ms)
                case .failed:
                    state.finish(nil)
                case .cancelled:
                    state.finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))

            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                connection.cancel()
            }
            state.setTimeoutTask(timeoutTask)
        }
    }
}

private final class PingState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var timeoutTask: Task<Void, Never>?
    private let continuation: CheckedContinuation<Int?, Never>

    init(continuation: CheckedContinuation<Int?, Never>) {
        self.continuation = continuation
    }

    func setTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        defer { lock.unlock() }
        timeoutTask = task
    }

    func finish(_ ms: Int?) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        continuation.resume(returning: ms)
    }
}
