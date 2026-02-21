import Foundation

enum WhoopAPIError: LocalizedError {
    case invalidResponse
    case missingConfig
    case missingAccessToken
    case unauthorized
    case rateLimited
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from WHOOP API."
        case .missingConfig:
            return "Missing WHOOP config. Add WhoopConfig.plist with CLIENT_ID, CLIENT_SECRET, REDIRECT_URI, and ACCESS_TOKEN."
        case .missingAccessToken:
            return "Missing ACCESS_TOKEN in WhoopConfig.plist."
        case .unauthorized:
            return "Unauthorized. Check your WHOOP access token and scopes."
        case .rateLimited:
            return "WHOOP API rate limit reached. Try again soon."
        case let .requestFailed(statusCode, message):
            return "WHOOP request failed (\(statusCode)): \(message)"
        }
    }
}

struct WhoopAPIClient {
    private let baseURL = URL(string: "https://api.prod.whoop.com/developer/v2")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLastWeekHRV(accessToken: String, now: Date = Date()) async throws -> [HRVSample] {
        let calendar = Calendar(identifier: .iso8601)
        let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        var collected: [HRVSample] = []
        var nextToken: String? = nil

        repeat {
            let page = try await fetchRecoveries(
                accessToken: accessToken,
                start: start,
                end: now,
                limit: 25,
                nextToken: nextToken
            )

            let pageSamples = page.records.compactMap { record -> HRVSample? in
                guard record.scoreState == "SCORED", let hrv = record.score?.hrvRMSSDMilli else {
                    return nil
                }

                return HRVSample(cycleID: record.cycleID, date: record.createdAt, hrvRMSSDMilli: hrv)
            }

            collected.append(contentsOf: pageSamples)
            nextToken = page.nextToken
        } while nextToken != nil

        return collected.sorted { $0.date < $1.date }
    }

    private func fetchRecoveries(
        accessToken: String,
        start: Date,
        end: Date,
        limit: Int,
        nextToken: String?
    ) async throws -> RecoveryCollectionResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("recovery"), resolvingAgainstBaseURL: false)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var queryItems = [
            URLQueryItem(name: "start", value: formatter.string(from: start)),
            URLQueryItem(name: "end", value: formatter.string(from: end)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let nextToken {
            queryItems.append(URLQueryItem(name: "nextToken", value: nextToken))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw WhoopAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(RecoveryCollectionResponse.self, from: data)
        case 401:
            throw WhoopAPIError.unauthorized
        case 429:
            throw WhoopAPIError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhoopAPIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
