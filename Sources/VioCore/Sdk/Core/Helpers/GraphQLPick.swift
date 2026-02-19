import Foundation

public enum GraphQLPick {
    public static func pickPath<T>(_ dict: [String: Any]?, path: [Any]) -> T? {
        guard var cur: Any = dict else { return nil }
        for seg in path {
            if let key = seg as? String, let m = cur as? [String: Any] {
                cur = m[key] as Any
            } else if let idx = seg as? Int, let arr = cur as? [Any], idx >= 0, idx < arr.count {
                cur = arr[idx]
            } else {
                return nil
            }
        }
        if T.self == Any.self { return (cur as Any) as? T }
        if let val = cur as? T { return val }
        if let m = cur as? [String: Any], T.self == [String: Any].self { return (m as! T) }
        if let a = cur as? [Any], T.self == [Any].self { return (a as! T) }
        return nil
    }

    public static func pickPathRequired<T>(
        _ dict: [String: Any]?, path: [Any],
        code: String = "EMPTY_RESPONSE",
        message: String? = nil
    ) throws -> T {
        if let v: T = pickPath(dict, path: path) { return v }
        throw SdkException(
            message ?? "Required value not found at path \(path)", code: code,
            details: ["path": path])
    }

    public static func decodeJSON<T: Decodable>(_ obj: Any, as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        let dec = JSONDecoder()
        return try dec.decode(T.self, from: data)
    }
}
