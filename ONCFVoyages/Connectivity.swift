//
//  Connectivity.swift
//  Live network reachability so the app can warn when offline.
//

import Foundation
import Network

@MainActor
final class Connectivity: ObservableObject {
    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ma.oncf.voyages.connectivity")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let up = path.status == .satisfied
            Task { @MainActor in self?.isOnline = up }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
