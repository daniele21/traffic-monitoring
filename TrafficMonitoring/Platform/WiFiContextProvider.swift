#if os(macOS)
import CoreWLAN
import Foundation

struct WiFiContextProvider {
    private let client = CWWiFiClient.shared()

    func currentSSIDByInterface() -> [String: String] {
        let names = client.interfaceNames() ?? []
        return names.reduce(into: [String: String]()) { result, name in
            guard let ssid = client.interface(withName: name)?.ssid(), !ssid.isEmpty else { return }
            result[name] = ssid
        }
    }

    func knownWiFiInterfaceNames() -> Set<String> {
        Set(client.interfaceNames() ?? [])
    }
}
#endif
