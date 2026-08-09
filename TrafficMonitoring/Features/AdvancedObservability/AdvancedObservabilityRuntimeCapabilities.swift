#if os(macOS)
import Foundation
import Security

struct AdvancedObservabilityRuntimeCapabilities {
    static let systemExtensionInstallEntitlement = "com.apple.developer.system-extension.install"

    let canInstallSystemExtension: Bool
    let teamIdentifier: String?

    static var current: AdvancedObservabilityRuntimeCapabilities {
        guard let signing = signingInformation() else {
            return AdvancedObservabilityRuntimeCapabilities(
                canInstallSystemExtension: false,
                teamIdentifier: nil
            )
        }

        let entitlements = signing[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        let canInstall = entitlements?[systemExtensionInstallEntitlement] as? Bool ?? false
        let team = signing[kSecCodeInfoTeamIdentifier as String] as? String

        return AdvancedObservabilityRuntimeCapabilities(
            canInstallSystemExtension: canInstall,
            teamIdentifier: team
        )
    }

    private static func signingInformation() -> [String: Any]? {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess,
              let code else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode else { return nil }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
              let values = information as? [String: Any] else { return nil }

        return values
    }
}
#endif
