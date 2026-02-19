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
          if self.isLoading {
            ProgressView()
          } else if self.notificationsEnabled {
            Text("Enabled")
              .foregroundStyle(DS.Colors.success)
          } else {
            Button("Enable in Settings") {
              self.openSettings()
            }
            .font(.subheadline)
          }
        }
      } footer: {
        if !self.notificationsEnabled, !self.isLoading {
          Text("Notifications are disabled. Enable them in Settings to receive reminders.")
        }
      }

      if self.notificationsEnabled {
        Section {
          Button {
            let newValue = !(dueSoonReminders && self.overdueAlerts && self.morningBriefing)
            self.dueSoonReminders = newValue
            self.overdueAlerts = newValue
            self.morningBriefing = newValue
          } label: {
            HStack {
              Text("All Reminders")
                .foregroundStyle(.primary)
              Spacer()
              Text(self.dueSoonReminders && self.overdueAlerts && self.morningBriefing ? "On" : "Off")
                .foregroundStyle(.secondary)
            }
          }
        }

        Section("Reminders") {
          Toggle("Due Soon Reminders", isOn: self.$dueSoonReminders)
          Toggle("Overdue Alerts", isOn: self.$overdueAlerts)
          Toggle("Morning Briefing", isOn: self.$morningBriefing)
        }

        Section {
          Text("Due Soon: 1 hour before task is due")
          Text("Overdue: 1 hour after task is due")
          Text("Morning Briefing: Daily at 8:00 AM")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
    }
    .surfaceFormBackground()
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      self.checkNotificationStatus()
    }
  }

  private func checkNotificationStatus() {
    Task {
      let settings = await UNUserNotificationCenter.current().notificationSettings()
      await MainActor.run {
        self.notificationsEnabled = settings.authorizationStatus == .authorized
        self.isLoading = false
      }
    }
  }

  private func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }
}
