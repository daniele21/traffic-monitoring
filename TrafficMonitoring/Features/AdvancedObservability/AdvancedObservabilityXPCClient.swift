#if os(macOS)
import Foundation

@objc private protocol AdvancedObservabilityRemoteProtocol {
    func fetchSnapshot(withReply reply: @escaping (Data?) -> Void)
}

final class AdvancedObservabilityXPCClient {
    static let machServiceName = "group.com.daniele21.trafficmonitoring.advanced-observability"

    enum ClientError: LocalizedError {
        case unavailable(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case let .unavailable(message): message
            case .invalidResponse: "Advanced Observability returned an invalid snapshot."
            }
        }
    }

    func loadSnapshot(timeout: TimeInterval = 1.5, completion: @escaping (Result<AdvancedObservabilitySnapshot?, Error>) -> Void) {
        let connection = NSXPCConnection(machServiceName: Self.machServiceName, options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: AdvancedObservabilityRemoteProtocol.self)

        let gate = CompletionGate()
        func finish(_ result: Result<AdvancedObservabilitySnapshot?, Error>) {
            guard gate.claim() else { return }
            connection.invalidate()
            completion(result)
        }

        connection.interruptionHandler = {
            finish(.failure(ClientError.unavailable("Advanced Observability provider connection was interrupted.")))
        }
        connection.invalidationHandler = {
            finish(.failure(ClientError.unavailable("Advanced Observability provider is not available.")))
        }
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            finish(.failure(error))
        }) as? AdvancedObservabilityRemoteProtocol else {
            finish(.failure(ClientError.unavailable("Advanced Observability provider could not be contacted.")))
            return
        }

        proxy.fetchSnapshot { data in
            guard let data else {
                finish(.success(nil))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                finish(.success(try decoder.decode(AdvancedObservabilitySnapshot.self, from: data)))
            } catch {
                finish(.failure(ClientError.invalidResponse))
            }
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            finish(.failure(ClientError.unavailable("Advanced Observability provider did not respond in time.")))
        }
    }
}

private final class CompletionGate {
    private let lock = NSLock()
    private var completed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        return true
    }
}
#endif
