import Foundation

@objc protocol AdvancedObservabilityXPCProtocol {
    func fetchSnapshot(withReply reply: @escaping (Data?) -> Void)
}

final class ProviderXPCService: NSObject, NSXPCListenerDelegate, AdvancedObservabilityXPCProtocol {
    static let machServiceName = "group.com.daniele21.trafficmonitoring.advanced-observability"
    static let shared = ProviderXPCService()

    private var listener: NSXPCListener?

    private override init() { super.init() }

    func start() {
        guard listener == nil else { return }
        let listener = NSXPCListener(machServiceName: Self.machServiceName)
        listener.delegate = self
        listener.resume()
        self.listener = listener
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // B0 capability spike: production must additionally validate the connecting
        // app's code-signing identity before accepting the connection.
        newConnection.exportedInterface = NSXPCInterface(with: AdvancedObservabilityXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func fetchSnapshot(withReply reply: @escaping (Data?) -> Void) {
        reply(ProviderEvidenceStore.shared.snapshotData())
    }
}
