import Foundation
import NetworkExtension

func main() -> Never {
    autoreleasepool {
        NEProvider.startSystemExtensionMode()
    }
    dispatchMain()
}

main()
