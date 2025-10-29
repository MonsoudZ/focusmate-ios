import SwiftData
import SwiftUI

struct SwiftDataTestView: View {
  @EnvironmentObject var swiftDataManager: SwiftDataManager
  // @EnvironmentObject var deltaSyncService: DeltaSyncService // Temporarily disabled
  @State private var testResults: [String] = []
  @State private var isRunningTest = false

  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        Text("SwiftData Integration Test")
          .font(.title2)
          .fontWeight(.bold)

        if self.isRunningTest {
          ProgressView("Running tests...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          VStack(spacing: 16) {
            Button("Run SwiftData Test") {
              self.runSwiftDataTest()
            }
            .buttonStyle(.borderedProminent)

            Button("Test Delta Sync Parameters") {
              self.testDeltaSyncParameters()
            }
            .buttonStyle(.bordered)

            Button("Test Full Sync") {
              self.runFullSyncTest()
            }
            .buttonStyle(.bordered)

            if !self.testResults.isEmpty {
              ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                  ForEach(self.testResults, id: \.self) { result in
                    Text(result)
                      .font(.caption)
                      .foregroundColor(result.contains("✅") ? .green : result.contains("❌") ? .red : .primary)
                  }
                }
              }
              .frame(maxHeight: 300)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(8)
            }
          }
        }

        Spacer()
      }
      .padding()
      .navigationTitle("SwiftData Test")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func runSwiftDataTest() {
    self.isRunningTest = true
    self.testResults = []

    Task {
      let testService = SwiftDataTestService(swiftDataManager: swiftDataManager)
      await testService.testSwiftDataIntegration()

      await MainActor.run {
        self.isRunningTest = false
        self.testResults.append("✅ SwiftData integration test completed")
      }
    }
  }

  func testDeltaSyncParameters() {
    self.testResults.append("🧪 Testing delta sync parameters...")

    let testService = SwiftDataTestService(swiftDataManager: swiftDataManager)
    testService.testDeltaSyncParameters()

    self.testResults.append("✅ Delta sync parameters test completed")
  }

  private func runFullSyncTest() {
    self.testResults.append("🧪 Testing full sync...")

    Task {
      do {
        // TODO: Implement sync when DeltaSyncService is re-enabled
        // try await self.deltaSyncService.syncAll()
        await MainActor.run {
          self.testResults.append("✅ Full sync test completed successfully (placeholder)")
        }
      } catch {
        await MainActor.run {
          self.testResults.append("❌ Full sync test failed: \(error.localizedDescription)")
        }
      }
    }
  }
}

#Preview {
  SwiftDataTestView()
    .environmentObject(SwiftDataManager.shared)
    // .environmentObject(DeltaSyncService( // Temporarily disabled
    //   apiClient: APIClient(tokenProvider: { nil }),
    //   swiftDataManager: SwiftDataManager.shared
    // ))
}
