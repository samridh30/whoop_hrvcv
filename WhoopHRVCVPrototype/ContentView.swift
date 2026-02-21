import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HRVViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("WHOOP Client ID")
                    .font(.headline)

                TextField("Configured client ID", text: $viewModel.clientID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(true)

                Text("WHOOP Client Secret")
                    .font(.headline)

                TextField("Configured client secret", text: $viewModel.clientSecret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(true)

                Button {
                    viewModel.loadConfig()
                } label: {
                    Text("Reload Client ID + Client Secret From Config")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Text("WHOOP Access Token")
                    .font(.headline)

                TextField("Configured access token", text: $viewModel.accessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await viewModel.fetchLastWeekHRV() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Fetch Last 7 Days HRV")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                List(viewModel.samples) { sample in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sample.date, style: .date)
                            .font(.subheadline)
                        Text(String(format: "HRV RMSSD: %.1f ms", sample.hrvRMSSDMilli))
                            .font(.body)
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("WHOOP HRV")
        }
    }
}

#Preview {
    ContentView()
}
