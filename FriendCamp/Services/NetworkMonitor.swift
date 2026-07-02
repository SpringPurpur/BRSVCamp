import Network
import Observation

// Folosit doar ca să alegem sursa implicită de tile-uri la deschiderea hărții (Apple dacă
// ești online, OpenStreetMap dacă nu) — nu declanșează niciun refetch/resincronizare ulterior.
@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    var isConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.isConnected = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
