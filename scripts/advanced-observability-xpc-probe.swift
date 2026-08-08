#!/usr/bin/env swift

import Darwin
import Foundation

@objc private protocol AdvancedObservabilityProbeProtocol {
    func fetchSnapshot(withReply reply: @escaping (Data?) -> Void)
}

enum ProbeResult {
    case rejected(String)
    case accepted(Int?)
}

let serviceName = "group.com.daniele21.trafficmonitoring.advanced-observability"
let connection = NSXPCConnection(machServiceName: serviceName, options: [])
connection.remoteObjectInterface = NSXPCInterface(with: AdvancedObservabilityProbeProtocol.self)

let lock = NSLock()
var result: ProbeResult?
let semaphore = DispatchSemaphore(value: 0)

func finish(_ value: ProbeResult) {
    lock.lock()
    defer { lock.unlock() }
    guard result == nil else { return }
    result = value
    semaphore.signal()
}

connection.interruptionHandler = {
    finish(.rejected("connection interrupted"))
}
connection.invalidationHandler = {
    finish(.rejected("connection invalidated"))
}
connection.resume()

guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
    finish(.rejected(error.localizedDescription))
}) as? AdvancedObservabilityProbeProtocol else {
    print("PASS: unauthorized probe could not obtain a provider proxy")
    connection.invalidate()
    exit(EXIT_SUCCESS)
}

proxy.fetchSnapshot { data in
    finish(.accepted(data?.count))
}

if semaphore.wait(timeout: .now() + 3) == .timedOut {
    print("PASS: unauthorized probe received no evidence response within timeout")
    connection.invalidate()
    exit(EXIT_SUCCESS)
}

connection.invalidate()

lock.lock()
let finalResult = result
lock.unlock()

switch finalResult {
case let .rejected(reason):
    print("PASS: unauthorized XPC client was rejected (\(reason))")
    exit(EXIT_SUCCESS)
case let .accepted(size):
    let description = size.map { "\($0) bytes" } ?? "nil snapshot"
    fputs("FAIL: unauthorized XPC client was accepted and received \(description)\n", stderr)
    exit(EXIT_FAILURE)
case .none:
    print("PASS: unauthorized probe received no evidence")
    exit(EXIT_SUCCESS)
}
