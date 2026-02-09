import Foundation
import os.log

@MainActor
final class Telemetry {
    static let shared = Telemetry()
    private let logger = Logger(subsystem: "com.smartreminders", category: "telemetry")
    private init() {}
    
    func log(event: String, properties: [String: Any] = [:]) {
        let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        logger.info("event=\(event) props=\(props)")
    }
}
