import Foundation

@MainActor
final class HRVViewModel: ObservableObject {
    @Published var clientID: String = ""
    @Published var clientSecret: String = ""
    @Published var accessToken: String = ""
    @Published var isLoading = false
    @Published var samples: [HRVSample] = []
    @Published var errorMessage: String?

    private let client = WhoopAPIClient()

    init() {
        loadConfig()
    }

    func loadConfig() {
        do {
            let config = try WhoopConfig.loadFromBundle()
            clientID = config.clientID
            clientSecret = config.clientSecret
            accessToken = config.accessToken
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchLastWeekHRV() async {
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            errorMessage = WhoopAPIError.missingAccessToken.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            samples = try await client.fetchLastWeekHRV(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
