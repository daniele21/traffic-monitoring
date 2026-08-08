import Foundation
import NetworkExtension

func main() -> Never {
    autoreleasepool {
        // Apple recommends starting Network Extension system-extension mode before
        // bringing up a custom XPC listener in the same system extension process.
        NEProvider.startSystemExtensionMode()
        ProviderXPCService.shared.start()
    }
    dispatchMain()
}

main()
