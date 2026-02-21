import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = HRVViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Refreshing HRV...")
                } else if viewModel.requiresLogin {
                    VStack(spacing: 12) {
                        Text("Connect WHOOP once to enable automatic HRV refresh.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)

                        Button("Login to WHOOP") {
                            if let loginURL = viewModel.loginURL {
                                openURL(loginURL)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("I Have Logged In, Refresh") {
                            Task { await viewModel.refreshHRV() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if !viewModel.samples.isEmpty {
                    List(viewModel.samples) { sample in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sample.date, style: .date)
                                .font(.subheadline)
                            Text(String(format: "HRV RMSSD: %.1f ms", sample.hrvRMSSDMilli))
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                } else {
                    Text("No HRV values found yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Your HRV")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await viewModel.refreshHRV() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .task {
            await viewModel.refreshHRV()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refreshHRV() }
            }
        }
        .alert("Notice", isPresented: Binding(
            get: { viewModel.errorMessage != nil && !viewModel.requiresLogin },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
}
