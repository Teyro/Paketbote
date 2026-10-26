import Foundation

/// JSON-Wert, wie er von Home Assistant kommt (Zustände, Attribute, WebSocket-Nachrichten).
public enum JSON: Equatable, Sendable, Codable {
    case null
    case bool(Bool)
    case zahl(Double)
    case text(String)
    case liste([JSON])
    case objekt([String: JSON])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let d = try? c.decode(Double.self) { self = .zahl(d) }
        else if let s = try? c.decode(String.self) { self = .text(s) }
        else if let a = try? c.decode([JSON].self) { self = .liste(a) }
        else { self = .objekt(try c.decode([String: JSON].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .zahl(let d):
            if d.rounded() == d && abs(d) < 1e15 { try c.encode(Int64(d)) } else { try c.encode(d) }
        case .text(let s): try c.encode(s)
        case .liste(let a): try c.encode(a)
        case .objekt(let o): try c.encode(o)
        }
    }

    public subscript(_ schluessel: String) -> JSON? {
        if case .objekt(let o) = self { return o[schluessel] }
        return nil
    }

    public subscript(_ index: Int) -> JSON? {
        if case .liste(let a) = self, a.indices.contains(index) { return a[index] }
        return nil
    }

    public var text: String? { if case .text(let s) = self { return s }; return nil }
    public var zahl: Double? { if case .zahl(let d) = self { return d }; return nil }
    public var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var liste: [JSON]? { if case .liste(let a) = self { return a }; return nil }
    public var objekt: [String: JSON]? { if case .objekt(let o) = self { return o }; return nil }
    public var istNull: Bool { if case .null = self { return true }; return false }

    public static func lesen(_ daten: Data) -> JSON? { try? JSONDecoder().decode(JSON.self, from: daten) }
    public static func lesen(_ text: String) -> JSON? { lesen(Data(text.utf8)) }
    public var daten: Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public var zeichenkette: String { String(decoding: daten, as: UTF8.self) }
}

extension JSON: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
                ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral {
    public init(stringLiteral value: String) { self = .text(value) }
    public init(integerLiteral value: Int) { self = .zahl(Double(value)) }
    public init(floatLiteral value: Double) { self = .zahl(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(arrayLiteral elements: JSON...) { self = .liste(elements) }
    public init(dictionaryLiteral elements: (String, JSON)...) { self = .objekt(Dictionary(elements, uniquingKeysWith: { $1 })) }
    public init(nilLiteral: ()) { self = .null }
}

public extension JSON {
    static func texte(_ liste: [String]) -> JSON { .liste(liste.map { .text($0) }) }
}
