//
//  BonjourBrowser.swift
//  Poseiosc Sender (iOS)
//
//  Browses for "_osc._udp" services (the Poseiosc Receiver advertises one) and
//  resolves a tapped service to a concrete host + port by opening a throwaway
//  UDP connection and reading the resolved remote endpoint.
//

import Foundation
import Network
import Observation
import os.lock

struct DiscoveredReceiver: Identifiable, Equatable {
    let name: String
    let endpoint: NWEndpoint

    var id: String { name }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.name == rhs.name }
}

@Observable @MainActor
final class BonjourBrowser {
    private(set) var receivers: [DiscoveredReceiver] = []
    private(set) var isBrowsing = false

    private var browser: NWBrowser?

    func start() {
        guard browser == nil else { return }
        let browser = NWBrowser(
            for: .bonjour(type: "_osc._udp", domain: nil),
            using: NWParameters(dtls: nil, udp: .init())
        )
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let found = results.compactMap { result -> DiscoveredReceiver? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredReceiver(name: name, endpoint: result.endpoint)
            }
            .sorted { $0.name < $1.name }
            Task { @MainActor in
                self?.receivers = found
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.isBrowsing = state == .ready
            }
        }
        browser.start(queue: .global(qos: .utility))
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        receivers = []
        isBrowsing = false
    }

    /// Resolve a Bonjour service endpoint to host + port via a throwaway UDP
    /// connection, reading the resolved remote endpoint once it's ready.
    /// IPv4 is forced because the receiver's OSC server binds IPv4-only.
    /// Returns nil on failure or after a 4-second timeout.
    func resolve(_ receiver: DiscoveredReceiver) async -> (host: String, port: UInt16)? {
        let parameters = NWParameters.udp
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let connection = NWConnection(to: receiver.endpoint, using: parameters)

        // The connection reports .cancelled after our own cancel() on success,
        // so completion must be one-shot.
        let resumed = OSAllocatedUnfairLock(initialState: false)
        return await withCheckedContinuation { continuation in
            @Sendable func finish(_ result: (host: String, port: UInt16)?) {
                let isFirst = resumed.withLock { done in
                    if done { return false }
                    done = true
                    return true
                }
                guard isFirst else { return }
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case .hostPort(let host, let port) = connection.currentPath?.remoteEndpoint {
                        finish((Self.hostString(host), port.rawValue))
                    } else {
                        finish(nil)
                    }
                case .failed:
                    finish(nil)
                case .cancelled:
                    finish(nil)  // no-op when we cancelled after success
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))

            Task {
                try? await Task.sleep(for: .seconds(4))
                finish(nil)
            }
        }
    }

    /// Renders an NWEndpoint.Host as a plain address string, dropping any
    /// "%en0"-style interface scope suffix.
    private nonisolated static func hostString(_ host: NWEndpoint.Host) -> String {
        let raw: String
        switch host {
        case .ipv4(let address): raw = "\(address)"
        case .ipv6(let address): raw = "\(address)"
        case .name(let name, _): raw = name
        @unknown default: raw = "\(host)"
        }
        return raw.components(separatedBy: "%").first ?? raw
    }
}
