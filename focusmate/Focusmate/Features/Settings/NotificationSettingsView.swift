import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var notificationsEnabled = false
    @State private var isLoading = true
    
    @AppStorage("dueSoonReminders") private var dueSoonReminders = true
    @AppStorage("overdueAlerts") private var overdueAlerts = true
    @AppStorage("morningBriefing") private var morningBriefing = true
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Notifications")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else if notificationsEnabled {
                        Text("Enabled")
                            .foregroundStyle(DS.Colors.success)
                    } else {
                        Button("Enable in Settings") {
                            openSettings()
                        }
                        .font(.subheadline)
                    }
                }
            } footer: {
                if !notificationsEnabled && !isLoading {
                    Text("Notifications are disabled. Enable them in Settings to receive reminders.")
                }
            }
            
            if notificationsEnabled {
                Section {
                    Button {
                        let newValue = !(dueSoonReminders && overdueAlerts && morningBriefing)
                        dueSoonReminders = newValue
                        overdueAlerts = newValue
                        morningBriefing = newValue
                    } label: {
                        HStack {
                            Text("All Reminders")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(dueSoonReminders && overdueAlerts && morningBriefing ? "On" : "Off")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Reminders") {
                    Toggle("Due Soon Reminders", isOn: $dueSoonReminders)
                    Toggle("Overdue Alerts", isOn: $overdueAlerts)
                    Toggle("Morning Briefing", isOn: $morningBriefing)
                }
                
                Section {
                    Text("Due Soon: 15 minutes before task is due")
                    Text("Overdue: When a task becomes overdue")
                    Text("Morning Briefing: Daily at 8:00 AM")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkNotificationStatus()
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
                isLoading = false
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
