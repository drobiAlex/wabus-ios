import Foundation

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
}

actor WebSocketService {
    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var subscribedTiles: Set<String> = []
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectDelay: TimeInterval = 2.0
    private var intentionalDisconnect = false

    private var messageContinuation: AsyncStream<WSInboundMessage>.Continuation?
    private(set) var messageStream: AsyncStream<WSInboundMessage>

    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private(set) var stateStream: AsyncStream<ConnectionState>

    init() {
        var msgCont: AsyncStream<WSInboundMessage>.Continuation?
        messageStream = AsyncStream { msgCont = $0 }
        messageContinuation = msgCont

        var stCont: AsyncStream<ConnectionState>.Continuation?
        stateStream = AsyncStream { stCont = $0 }
        stateContinuation = stCont
    }

    func connect() {
        intentionalDisconnect = false
        reconnectDelay = 2.0
        doConnect()
    }

    func disconnect() {
        intentionalDisconnect = true
        cleanup()
        stateContinuation?.yield(.disconnected)
    }

    func updateSubscriptions(tileIds: Set<String>) {
        let toSubscribe = tileIds.subtracting(subscribedTiles)
        let toUnsubscribe = subscribedTiles.subtracting(tileIds)

        if !toSubscribe.isEmpty {
            let msg = WSSubscribe(tileIds: Array(toSubscribe))
            send(msg)
        }
        if !toUnsubscribe.isEmpty {
            let msg = WSUnsubscribe(tileIds: Array(toUnsubscribe))
            send(msg)
        }
        subscribedTiles = tileIds
    }

    // MARK: - Private

    private func doConnect() {
        cleanup()
        stateContinuation?.yield(.connecting)

        let request = URLRequest(url: AppConfig.wsURL)
        let wsTask = session.webSocketTask(with: request)
        self.task = wsTask
        wsTask.resume()

        stateContinuation?.yield(.connected)
        reconnectDelay = 2.0

        if !subscribedTiles.isEmpty {
            let msg = WSSubscribe(tileIds: Array(subscribedTiles))
            send(msg)
        }

        startReceiveLoop()
        startPingLoop()
    }

    private func startReceiveLoop() {
        receiveTask = Task { [weak task] in
            guard let task else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8),
                           let parsed = try? WSInboundMessage.parse(data: data) {
                            messageContinuation?.yield(parsed)
                        }
                    case .data(let data):
                        if let parsed = try? WSInboundMessage.parse(data: data) {
                            messageContinuation?.yield(parsed)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        await handleDisconnect()
                    }
                    return
                }
            }
        }
    }

    private func startPingLoop() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled else { return }
                send(WSPing())
            }
        }
    }

    private func handleDisconnect() {
        cleanup()
        stateContinuation?.yield(.disconnected)

        guard !intentionalDisconnect else { return }

        reconnectTask = Task {
            let delay = reconnectDelay
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, !intentionalDisconnect else { return }
            reconnectDelay = min(reconnectDelay * 2, 30.0)
            doConnect()
        }
    }

    private func cleanup() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func send<T: Encodable>(_ message: T) {
        guard let data = try? AppConfig.jsonEncoder.encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }
}
