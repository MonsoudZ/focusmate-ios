import SwiftUI

#if DEBUG

struct DebugNotificationView: View {
    @StateObject private var helper = NotificationTestHelper.shared
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
                    Text(permissionStatus)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Scheduled")
                    Spacer()
                    Text("\(helper.scheduledNotifications.count)")
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
                    TextField("Task ID", text: $testTaskId)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                HStack {
                    Text("Delay (seconds)")
                    Spacer()
                    TextField("Seconds", text: $testDelay)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            // MARK: - Quick Test Notifications
            Section("Fire Test Notification") {
                Button("Due Soon") {
                    fireNotification(.dueSoon)
                }

                Button("Due Now") {
                    fireNotification(.dueNow)
                }

                Button("Overdue") {
                    fireNotification(.overdue)
                }

                Button("Escalation Start") {
                    fireNotification(.escalationStart)
                }

                Button("Escalation Warning") {
                    fireNotification(.escalationWarning)
                }

                Button("Morning Briefing") {
                    fireNotification(.morningBriefing)
                }

                Button("Nudge (Remote Simulation)") {
                    fireNotification(.nudge)
                }
            }

            // MARK: - Simulate Taps (Deep Link Testing)
            Section("Simulate Notification Tap") {
                Button("Tap Task Notification") {
                    helper.simulateTaskNotificationTap(taskId: taskId)
                }

                Button("Tap Morning Briefing") {
                    helper.simulateMorningBriefingTap()
                }

                Button("Tap Nudge Push") {
                    helper.simulateNudgePush(taskId: taskId)
                }
            }

            // MARK: - Scheduled Notifications
            Section("Pending Notifications (\(helper.scheduledNotifications.count))") {
                if helper.scheduledNotifications.isEmpty {
                    Text("No pending notifications")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(helper.scheduledNotifications) { notification in
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
                                helper.cancelNotification(id: notification.id)
                            }
                        }
                    }
                }
            }

            // MARK: - Actions
            Section {
                Button("Refresh Pending List") {
                    Task { await helper.refreshScheduledNotifications() }
                }

                Button("Clear All Notifications", role: .destructive) {
                    showingClearConfirmation = true
                }
            }
        }
        .navigationTitle("Notification Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            permissionStatus = await helper.checkPermissionStatus()
            await helper.refreshScheduledNotifications()
        }
        .refreshable {
            permissionStatus = await helper.checkPermissionStatus()
            await helper.refreshScheduledNotifications()
        }
        .alert("Clear All?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                helper.clearAllNotifications()
            }
        } message: {
            Text("This will remove all pending and delivered notifications.")
        }
    }

    // MARK: - Helpers

    private var taskId: Int {
        Int(testTaskId) ?? 999
    }

    private var delay: TimeInterval {
        TimeInterval(testDelay) ?? 5
    }

    private enum NotificationType {
        case dueSoon, dueNow, overdue, escalationStart, escalationWarning, morningBriefing, nudge
    }

    private func fireNotification(_ type: NotificationType) {
        let id = taskId
        let delaySeconds = delay

        switch type {
        case .dueSoon:
            helper.scheduleDueSoonTest(taskId: id, delaySeconds: delaySeconds)
        case .dueNow:
            helper.scheduleDueNowTest(taskId: id, delaySeconds: delaySeconds)
        case .overdue:
            helper.scheduleOverdueTest(taskId: id, delaySeconds: delaySeconds)
        case .escalationStart:
            helper.scheduleEscalationStartTest(taskId: id, delaySeconds: delaySeconds)
        case .escalationWarning:
            helper.scheduleEscalationWarningTest(taskId: id, delaySeconds: delaySeconds)
        case .morningBriefing:
            helper.scheduleMorningBriefingTest(delaySeconds: delaySeconds)
        case .nudge:
            helper.scheduleNudgeTest(taskId: id, delaySeconds: delaySeconds)
        }
    }
}

#endif
