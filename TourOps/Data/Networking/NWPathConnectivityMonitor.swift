//
//  NWPathConnectivityMonitor.swift
//  TourOps
//

import Foundation
import Network

struct NWPathConnectivityMonitor: ConnectivityMonitorProtocol {

    func connectivityUpdates() -> AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let monitor = NWPathMonitor()

            monitor.pathUpdateHandler = { @Sendable path in
                continuation.yield(path.status == .satisfied)
            }

            continuation.onTermination = { @Sendable _ in
                monitor.cancel()
            }

            monitor.start(
                queue: DispatchQueue(label: "com.tourops.connectivity")
            )
        }
    }
}
