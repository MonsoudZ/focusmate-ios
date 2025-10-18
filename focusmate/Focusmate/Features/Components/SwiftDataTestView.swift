import SwiftUI
import SwiftData

struct SwiftDataTestView: View {
    @EnvironmentObject var swiftDataManager: SwiftDataManager
    @EnvironmentObject var deltaSyncService: DeltaSyncService
    @State private var testResults: [String] = []
    @State private var isRunningTest = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("SwiftData Integration Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if isRunningTest {
                    ProgressView("Running tests...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Button("Run SwiftData Test") {
                            runSwiftDataTest()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Test Delta Sync Parameters") {
                            testDeltaSyncParameters()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Test Full Sync") {
                            runFullSyncTest()
                        }
                        .buttonStyle(.bordered)
                        
                        if !testResults.isEmpty {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(testResults, id: \.self) { result in
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
        isRunningTest = true
        testResults = []
        
        Task {
            let testService = SwiftDataTestService(swiftDataManager: swiftDataManager)
            await testService.testSwiftDataIntegration()
            
            await MainActor.run {
                isRunningTest = false
                testResults.append("✅ SwiftData integration test completed")
            }
        }
    }
    
    private func testDeltaSyncParameters() {
        testResults.append("🧪 Testing delta sync parameters...")
        
        let testService = SwiftDataTestService(swiftDataManager: swiftDataManager)
        testService.testDeltaSyncParameters()
        
        testResults.append("✅ Delta sync parameters test completed")
    }
    
    private func runFullSyncTest() {
        testResults.append("🧪 Testing full sync...")
        
        Task {
            do {
                try await deltaSyncService.syncAll()
                await MainActor.run {
                    testResults.append("✅ Full sync test completed successfully")
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ Full sync test failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    SwiftDataTestView()
        .environmentObject(SwiftDataManager.shared)
        .environmentObject(DeltaSyncService(
            apiClient: APIClient(tokenProvider: { nil }),
            swiftDataManager: SwiftDataManager.shared
        ))
}
