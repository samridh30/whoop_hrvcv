import Foundation

struct WhoopConfig {
    let backendBaseURL: URL

    static func loadFromBundle() throws -> WhoopConfig {
        guard
            let url = Bundle.main.url(forResource: "WhoopConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            throw WhoopAPIError.missingConfig
        }

        guard
            let backendURLString = raw["BACKEND_BASE_URL"] as? String,
            let backendBaseURL = URL(string: backendURLString),
            !backendURLString.isEmpty
        else {
            throw WhoopAPIError.missingConfig
        }

        return WhoopConfig(backendBaseURL: backendBaseURL)
    }
}
