import SwiftUI
import UserNotifications
import FamilyControls

struct OnboardingPermissionsPage: View {
    let onNext: () -> Void

    @State private var notificationStatus: PermissionStatus = .notRequested
    @State private var screenTimeStatus: PermissionStatus = .notRequested
    @State private var calendarStatus: PermissionStatus = .notRequested

    enum PermissionStatus {
        case notRequested, granted, denied

        var icon: String {
            switch self {
            case .notRequested: return "circle"
            case .granted: return "checkmark.circle.fill"
            case .denied: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .notRequested: return .secondary
            case .granted: return DS.Colors.success
            case .denied: return .secondary
            }
        }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                Text("Get Set Up")
                    .font(DS.Typography.largeTitle)

                Text("These permissions help Intentia work best.\nYou can change them later in Settings.")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DS.Spacing.lg) {
                permissionRow(
                    icon: DS.Icon.bell,
                    title: "Notifications",
                    description: "Get reminders for due tasks and daily briefings.",
                    status: notificationStatus,
                    action: requestNotifications
                )

                permissionRow(
                    icon: DS.Icon.shield,
                    title: "Screen Time",
                    description: "Required to block distracting apps.",
                    status: screenTimeStatus,
                    action: requestScreenTime
                )

                permissionRow(
                    icon: "calendar",
                    title: "Calendar",
                    description: "Sync tasks to your calendar for better planning.",
                    status: calendarStatus,
                    action: requestCalendar
                )
            }

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())
        }
        .padding(DS.Spacing.xl)
        .task {
            await checkExistingPermissions()
        }
    }

    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        status: PermissionStatus,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Colors.accent)
                .frame(width: DS.Size.iconXL, height: DS.Size.iconXL)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.bodyMedium)

                Text(description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status == .notRequested {
                Button("Enable") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Image(systemName: status.icon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(status.color)
            }
        }
        .card()
    }

    private func checkExistingPermissions() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatus = .granted
        case .denied:
            notificationStatus = .denied
        default:
            break
        }

        if ScreenTimeService.shared.isAuthorized {
            screenTimeStatus = .granted
        }

        if CalendarService.shared.checkPermission() {
            calendarStatus = .granted
        }
    }

    private func requestNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await MainActor.run {
                    notificationStatus = granted ? .granted : .denied
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                        AppSettings.shared.didRequestPushPermission = true
                        AppSettings.shared.didRequestNotificationsPermission = true
                    }
                }
            } catch {
                await MainActor.run {
                    notificationStatus = .denied
                }
            }
        }
    }

    private func requestScreenTime() {
        Task {
            do {
                try await ScreenTimeService.shared.requestAuthorization()
                await MainActor.run {
                    screenTimeStatus = .granted
                    AppSettings.shared.didRequestScreenTimePermission = true
                }
            } catch {
                await MainActor.run {
                    screenTimeStatus = .denied
                }
            }
        }
    }

    private func requestCalendar() {
        Task {
            let granted = await CalendarService.shared.requestPermission()
            await MainActor.run {
                calendarStatus = granted ? .granted : .denied
                if granted {
                    AppSettings.shared.didRequestCalendarPermission = true
                }
            }
        }
    }
}
