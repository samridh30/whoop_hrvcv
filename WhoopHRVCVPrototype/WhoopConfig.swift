import Foundation

struct WhoopConfig {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let accessToken: String

    static func loadFromBundle() throws -> WhoopConfig {
        guard
            let url = Bundle.main.url(forResource: "WhoopConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            throw WhoopAPIError.missingConfig
        }

        guard
            let clientID = raw["CLIENT_ID"] as? String,
            let clientSecret = raw["CLIENT_SECRET"] as? String,
            let redirectURI = raw["REDIRECT_URI"] as? String,
            let accessToken = raw["ACCESS_TOKEN"] as? String,
            !clientID.isEmpty,
            !clientSecret.isEmpty,
            !redirectURI.isEmpty,
            !accessToken.isEmpty
        else {
            throw WhoopAPIError.missingConfig
        }

        return WhoopConfig(
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI,
            accessToken: accessToken
        )
    }
}
