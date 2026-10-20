//
//  ConnectivityMonitorProtocol.swift
//  TourOps
//

import Foundation

protocol ConnectivityMonitorProtocol {

    /// Emits `true` while the network path is usable and `false` while it is
    /// not. The current state is emitted first. The underlying monitor lives
    /// only as long as the stream is being consumed.
    func connectivityUpdates() -> AsyncStream<Bool>
}
