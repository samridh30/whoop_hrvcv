import Foundation

enum WhoopAPIError: LocalizedError {
    case invalidResponse
    case missingConfig
    case loginRequired
    case rateLimited
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from backend."
        case .missingConfig:
            return "Missing app config. Add BACKEND_BASE_URL to WhoopConfig.plist."
        case .loginRequired:
            return "Connect your WHOOP account to continue."
        case .rateLimited:
            return "Rate limit reached. Try again soon."
        case let .requestFailed(statusCode, message):
            return "Request failed (\(statusCode)): \(message)"
        }
    }
}

struct WhoopAPIClient {
    private let config: WhoopConfig
    private let session: URLSession

    init(config: WhoopConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func authStartURL() -> URL {
        config.backendBaseURL.appendingPathComponent("auth/start")
    }

    func fetchLastWeekHRV() async throws -> [HRVSample] {
        var components = URLComponents(url: config.backendBaseURL.appendingPathComponent("hrv"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "days", value: "7")]

        guard let url = components?.url else {
            throw WhoopAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(BackendHRVResponse.self, from: data)
            return payload.samples.sorted { $0.date < $1.date }
        case 401:
            throw WhoopAPIError.loginRequired
        case 429:
            throw WhoopAPIError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhoopAPIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
