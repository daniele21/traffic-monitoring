import Darwin
import Foundation
import OSLog
import Security

@objc protocol AdvancedObservabilityXPCProtocol {
    func fetchSnapshot(withReply reply: @escaping (Data?) -> Void)
}

final class ProviderXPCService: NSObject, NSXPCListenerDelegate, AdvancedObservabilityXPCProtocol {
    static let machServiceName = "group.com.daniele21.trafficmonitoring.advanced-observability"
    static let shared = ProviderXPCService()

    private let logger = Logger(subsystem: "com.daniele21.trafficmonitoring.filter", category: "XPC")
    private let clientValidator = XPCClientCodeSignatureValidator(
        expectedIdentifier: "com.daniele21.trafficmonitoring"
    )
    private var listener: NSXPCListener?

    private override init() { super.init() }

    func start() {
        guard listener == nil else { return }
        let listener = NSXPCListener(machServiceName: Self.machServiceName)
        listener.delegate = self
        listener.resume()
        self.listener = listener
        logger.info("Advanced Observability XPC listener started")
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        switch clientValidator.validate(connection: newConnection) {
        case let .accepted(identity):
            logger.info("Accepted XPC client identifier=\(identity.identifier, privacy: .public) team=\(identity.teamIdentifier, privacy: .private(mask: .hash))")
            newConnection.exportedInterface = NSXPCInterface(with: AdvancedObservabilityXPCProtocol.self)
            newConnection.exportedObject = self
            newConnection.resume()
            return true

        case let .rejected(reason):
            logger.error("Rejected XPC client: \(reason, privacy: .public)")
            newConnection.invalidate()
            return false
        }
    }

    func fetchSnapshot(withReply reply: @escaping (Data?) -> Void) {
        reply(ProviderEvidenceStore.shared.snapshotData())
    }
}

private struct XPCClientIdentity {
    let identifier: String
    let teamIdentifier: String
}

private enum XPCClientValidationResult {
    case accepted(XPCClientIdentity)
    case rejected(String)
}

/// Validates the process connecting to the provider's Mach service before any
/// evidence is returned. The client must be the Traffic Monitoring host app,
/// have a valid code signature, and be signed by the same Apple Developer Team
/// as the provider. Ad-hoc builds intentionally fail closed because they do not
/// carry a stable Team ID.
private struct XPCClientCodeSignatureValidator {
    let expectedIdentifier: String

    func validate(connection: NSXPCConnection) -> XPCClientValidationResult {
        guard let providerIdentity = Self.currentProcessIdentity(),
              !providerIdentity.teamIdentifier.isEmpty else {
            return .rejected("Provider has no stable Apple Developer Team identity")
        }

        guard let clientCode = Self.code(for: connection.auditToken) else {
            return .rejected("Could not resolve connecting process code signature")
        }

        guard SecCodeCheckValidity(clientCode, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else {
            return .rejected("Connecting process code signature is not valid")
        }

        guard let clientIdentity = Self.identity(for: clientCode) else {
            return .rejected("Connecting process signing identity is unavailable")
        }

        guard clientIdentity.identifier == expectedIdentifier else {
            return .rejected("Unexpected client bundle identifier")
        }

        guard clientIdentity.teamIdentifier == providerIdentity.teamIdentifier else {
            return .rejected("Client and provider Team IDs do not match")
        }

        return .accepted(clientIdentity)
    }

    private static func code(for auditToken: audit_token_t) -> SecCode? {
        var token = auditToken
        let tokenData = Data(bytes: &token, count: MemoryLayout.size(ofValue: token))
        let attributes = [kSecGuestAttributeAudit as String: tokenData] as CFDictionary
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code) == errSecSuccess else {
            return nil
        }
        return code
    }

    private static func currentProcessIdentity() -> XPCClientIdentity? {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess,
              let code else { return nil }
        return identity(for: code)
    }

    private static func identity(for code: SecCode) -> XPCClientIdentity? {
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any],
              let identifier = values[kSecCodeInfoIdentifier as String] as? String,
              let teamIdentifier = values[kSecCodeInfoTeamIdentifier as String] as? String,
              !identifier.isEmpty,
              !teamIdentifier.isEmpty else {
            return nil
        }

        return XPCClientIdentity(identifier: identifier, teamIdentifier: teamIdentifier)
    }
}
