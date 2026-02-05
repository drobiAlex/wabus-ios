import Foundation

// MARK: - Outbound Messages

struct WSSubscribe: Encodable {
    let type = "subscribe"
    let payload: Payload

    struct Payload: Encodable {
        let tileIds: [String]
    }

    init(tileIds: [String]) {
        self.payload = Payload(tileIds: tileIds)
    }
}

struct WSUnsubscribe: Encodable {
    let type = "unsubscribe"
    let payload: Payload

    struct Payload: Encodable {
        let tileIds: [String]
    }

    init(tileIds: [String]) {
        self.payload = Payload(tileIds: tileIds)
    }
}

struct WSPing: Encodable {
    let type = "ping"
}

// MARK: - Inbound Messages

enum WSInboundMessage: Sendable {
    case snapshot([Vehicle])
    case delta(updates: [Vehicle], removes: [String])
    case pong

    static func parse(data: Data, decoder: JSONDecoder = AppConfig.jsonDecoder) throws -> WSInboundMessage {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        switch envelope.type {
        case "snapshot":
            let snap = try decoder.decode(SnapshotEnvelope.self, from: data)
            return .snapshot(snap.payload.vehicles)
        case "delta":
            let delta = try decoder.decode(DeltaEnvelope.self, from: data)
            return .delta(updates: delta.payload.updates ?? [], removes: delta.payload.removes ?? [])
        case "pong":
            return .pong
        default:
            throw ParseError.unknownType(envelope.type)
        }
    }

    private struct Envelope: Decodable {
        let type: String
    }

    private struct SnapshotEnvelope: Decodable {
        let payload: Payload
        struct Payload: Decodable {
            let vehicles: [Vehicle]
        }
    }

    private struct DeltaEnvelope: Decodable {
        let payload: Payload
        struct Payload: Decodable {
            let updates: [Vehicle]?
            let removes: [String]?
        }
    }

    enum ParseError: Error {
        case unknownType(String)
    }
}
