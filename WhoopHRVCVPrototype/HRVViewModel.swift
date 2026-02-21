import Foundation

@MainActor
final class HRVViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var samples: [HRVSample] = []
    @Published var errorMessage: String?
    @Published var requiresLogin = false

    private var client: WhoopAPIClient?

    init() {
        do {
            let config = try WhoopConfig.loadFromBundle()
            client = WhoopAPIClient(config: config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var loginURL: URL? {
        client?.authStartURL()
    }

    func refreshHRV() async {
        guard let client else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            samples = try await client.fetchLastWeekHRV()
            requiresLogin = false
        } catch let error as WhoopAPIError {
            if case .loginRequired = error {
                requiresLogin = true
            }
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
