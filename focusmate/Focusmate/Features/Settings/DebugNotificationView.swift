import SwiftUI

#if DEBUG

  struct DebugNotificationView: View {
    let helper = NotificationTestHelper.shared
    @State private var permissionStatus = "Checking..."
    @State private var testTaskId = "999"
    @State private var testDelay = "5"
    @State private var showingClearConfirmation = false

    var body: some View {
      List {
        // MARK: - Status Section

        Section("Status") {
          HStack {
            Text("Permission")
            Spacer()
            Text(self.permissionStatus)
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("Scheduled")
            Spacer()
            Text("\(self.helper.scheduledNotifications.count)")
              .foregroundStyle(.secondary)
          }

          if let lastRoute = helper.lastSimulatedRoute {
            HStack {
              Text("Last Simulated")
              Spacer()
              Text(lastRoute)
                .foregroundStyle(.secondary)
            }
          }
        }

        // MARK: - Test Configuration

        Section("Test Configuration") {
          HStack {
            Text("Task ID")
            Spacer()
            TextField("Task ID", text: self.$testTaskId)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .frame(width: 100)
          }

          HStack {
            Text("Delay (seconds)")
            Spacer()
            TextField("Seconds", text: self.$testDelay)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .frame(width: 100)
          }
        }

        // MARK: - Quick Test Notifications

        Section("Fire Test Notification") {
          Button("Due Soon") {
            self.fireNotification(.dueSoon)
          }

          Button("Due Now") {
            self.fireNotification(.dueNow)
          }

          Button("Overdue") {
            self.fireNotification(.overdue)
          }

          Button("Escalation Start") {
            self.fireNotification(.escalationStart)
          }

          Button("Escalation Warning") {
            self.fireNotification(.escalationWarning)
          }

          Button("Morning Briefing") {
            self.fireNotification(.morningBriefing)
          }

          Button("Nudge (Remote Simulation)") {
            self.fireNotification(.nudge)
          }
        }

        // MARK: - Simulate Taps (Deep Link Testing)

        Section("Simulate Notification Tap") {
          Button("Tap Task Notification") {
            self.helper.simulateTaskNotificationTap(taskId: self.taskId)
          }

          Button("Tap Morning Briefing") {
            self.helper.simulateMorningBriefingTap()
          }

          Button("Tap Nudge Push") {
            self.helper.simulateNudgePush(taskId: self.taskId)
          }
        }

        // MARK: - Scheduled Notifications

        Section("Pending Notifications (\(self.helper.scheduledNotifications.count))") {
          if self.helper.scheduledNotifications.isEmpty {
            Text("No pending notifications")
              .foregroundStyle(.secondary)
          } else {
            ForEach(self.helper.scheduledNotifications) { notification in
              VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                  .font(.headline)
                Text(notification.body)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                HStack {
                  Text(notification.id)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                  Spacer()
                  Text(notification.timeUntilFire)
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
              }
              .swipeActions {
                Button("Cancel", role: .destructive) {
                  self.helper.cancelNotification(id: notification.id)
                }
              }
            }
          }
        }

        // MARK: - Actions

        Section {
          Button("Refresh Pending List") {
            Task { await self.helper.refreshScheduledNotifications() }
          }

          Button("Clear All Notifications", role: .destructive) {
            self.showingClearConfirmation = true
          }
        }
      }
      .navigationTitle("Notification Debug")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        self.permissionStatus = await self.helper.checkPermissionStatus()
        await self.helper.refreshScheduledNotifications()
      }
      .refreshable {
        self.permissionStatus = await self.helper.checkPermissionStatus()
        await self.helper.refreshScheduledNotifications()
      }
      .alert("Clear All?", isPresented: self.$showingClearConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Clear", role: .destructive) {
          self.helper.clearAllNotifications()
        }
      } message: {
        Text("This will remove all pending and delivered notifications.")
      }
    }

    // MARK: - Helpers

    private var taskId: Int {
      Int(self.testTaskId) ?? 999
    }

    private var delay: TimeInterval {
      TimeInterval(self.testDelay) ?? 5
    }

    private enum NotificationType {
      case dueSoon, dueNow, overdue, escalationStart, escalationWarning, morningBriefing, nudge
    }

    private func fireNotification(_ type: NotificationType) {
      let id = self.taskId
      let delaySeconds = self.delay

      switch type {
      case .dueSoon:
        self.helper.scheduleDueSoonTest(taskId: id, delaySeconds: delaySeconds)
      case .dueNow:
        self.helper.scheduleDueNowTest(taskId: id, delaySeconds: delaySeconds)
      case .overdue:
        self.helper.scheduleOverdueTest(taskId: id, delaySeconds: delaySeconds)
      case .escalationStart:
        self.helper.scheduleEscalationStartTest(taskId: id, delaySeconds: delaySeconds)
      case .escalationWarning:
        self.helper.scheduleEscalationWarningTest(taskId: id, delaySeconds: delaySeconds)
      case .morningBriefing:
        self.helper.scheduleMorningBriefingTest(delaySeconds: delaySeconds)
      case .nudge:
        self.helper.scheduleNudgeTest(taskId: id, delaySeconds: delaySeconds)
      }
    }
  }

#endif
