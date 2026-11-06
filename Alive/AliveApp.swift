import SwiftUI
import AppKit
import Network
import Observation
import ServiceManagement

@main
struct AliveApp: App {
    @State private var model = StatusModel()
    @State private var login = LoginItem()

    var body: some Scene {
        MenuBarExtra {
            Text(model.state.title)
            Divider()
            Button(login.title) { login.toggle() }
            Divider()
            Button("Quitter") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            model.state.icon
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
@Observable
final class StatusModel {
    nonisolated enum State: Equatable {
        case offline, noInternet, online

        var title: String {
            switch self {
            case .online: "Connecté à Internet"
            case .noInternet: "Connecté, pas d'accès Internet"
            case .offline: "Pas de réseau"
            }
        }

        var color: Color {
            switch self {
            case .online: .green
            case .noInternet: .orange
            case .offline: .red
            }
        }

        var icon: Image {
            let color = self.color
            return Image(size: CGSize(width: 18, height: 18)) { context in
                context.fill(
                    Path(ellipseIn: CGRect(x: 4, y: 4, width: 10, height: 10)),
                    with: .color(color)
                )
            }
            .renderingMode(.original)
        }
    }

    nonisolated struct Transition: Equatable {
        var state: State
        var consecutiveFailures = 0
        static let failuresBeforeWarning = 2

        mutating func apply(hasInterface: Bool, reachable: Bool?) {
            guard hasInterface else {
                consecutiveFailures = 0
                state = .offline
                return
            }
            guard let reachable else { return }

            if reachable {
                consecutiveFailures = 0
                state = .online
                return
            }

            consecutiveFailures += 1
            if consecutiveFailures >= Self.failuresBeforeWarning {
                state = .noInternet
            }
        }
    }

    private(set) var state: State = .offline

    private static let probeInterval: Duration = .seconds(10)
    private static let probeTimeout: TimeInterval = 8
    private static let probeURL = URL(string: "https://captive.apple.com/hotspot-detect.html")!

    private let monitor = NWPathMonitor()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var probe: Task<Void, Never>?
    @ObservationIgnored private var hasInterface = false
    @ObservationIgnored private var transition = Transition(state: .offline)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hasInterface = connected
                self.check()
            }
        }
        monitor.start(queue: DispatchQueue(label: "alive.path"))

        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.probeInterval)
                guard !Task.isCancelled else { return }
                self?.check()
            }
        }
    }

    nonisolated static func isCaptiveSuccess(_ data: Data) -> Bool {
        String(decoding: data, as: UTF8.self).contains("Success")
    }

    nonisolated static func isReachable(statusCode: Int, data: Data) -> Bool {
        statusCode == 200 && isCaptiveSuccess(data)
    }

    private func check() {
        probe?.cancel()

        guard hasInterface else {
            apply(hasInterface: false, reachable: nil)
            return
        }

        probe = Task {
            let reachable = await internetReachable()
            guard !Task.isCancelled else { return }
            apply(hasInterface: true, reachable: reachable)
        }
    }

    private func apply(hasInterface: Bool, reachable: Bool?) {
        transition.apply(hasInterface: hasInterface, reachable: reachable)
        state = transition.state
    }

    private func internetReachable() async -> Bool {
        var request = URLRequest(url: Self.probeURL, timeoutInterval: Self.probeTimeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            return Self.isReachable(statusCode: statusCode, data: data)
        } catch {
            return false
        }
    }
}

@MainActor
@Observable
final class LoginItem {
    private let service = SMAppService.mainApp
    private(set) var status: SMAppService.Status

    init() {
        status = service.status
    }

    var title: String {
        switch status {
        case .enabled: "Ne plus ouvrir à la connexion"
        case .requiresApproval: "Autoriser l'ouverture dans Réglages"
        default: "Ouvrir à la connexion"
        }
    }

    func toggle() {
        do {
            switch status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                openSettings()
            default:
                try service.register()
            }
        } catch {
            openSettings()
        }
        status = service.status
    }

    private func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        NSWorkspace.shared.open(url)
    }
}
