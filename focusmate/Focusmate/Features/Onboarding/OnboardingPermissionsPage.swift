import SwiftUI
import UserNotifications
import FamilyControls

struct OnboardingPermissionsPage: View {
    let onNext: () -> Void

    @State private var notificationStatus: PermissionStatus = .notRequested
    @State private var screenTimeStatus: PermissionStatus = .notRequested
    @State private var calendarStatus: PermissionStatus = .notRequested
    @State private var showingAppSelection = false

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
        .sheet(isPresented: $showingAppSelection) {
            OnboardingAppSelectionSheet()
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
                    // Show app selection sheet after successful authorization
                    showingAppSelection = true
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

// MARK: - App Selection Sheet

struct OnboardingAppSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var screenTime = ScreenTimeService.shared
    @State private var showingPicker = false
    @State private var selection = FamilyActivitySelection()

    private let recommendedCategories = [
        ("Social", "person.2.fill", "Instagram, TikTok, Twitter, Facebook"),
        ("Games", "gamecontroller.fill", "Mobile games and gaming apps"),
        ("Entertainment", "play.tv.fill", "YouTube, Netflix, streaming apps"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Header
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "apps.iphone")
                            .font(.system(size: 50))
                            .foregroundStyle(DS.Colors.accent)

                        Text("Choose Apps to Block")
                            .font(DS.Typography.title2)

                        Text("When you have overdue tasks, these apps will be blocked to help you focus.")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.lg)

                    // Recommendations
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("We recommend blocking:")
                            .font(DS.Typography.bodyMedium)
                            .padding(.horizontal, DS.Spacing.md)

                        VStack(spacing: DS.Spacing.sm) {
                            ForEach(recommendedCategories, id: \.0) { category in
                                recommendationRow(
                                    title: category.0,
                                    icon: category.1,
                                    examples: category.2
                                )
                            }
                        }
                    }

                    // Selection button
                    VStack(spacing: DS.Spacing.sm) {
                        Button {
                            selection.applicationTokens = screenTime.selectedApps
                            selection.categoryTokens = screenTime.selectedCategories
                            showingPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Select Apps & Categories")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IntentiaPrimaryButtonStyle())

                        if screenTime.hasSelections {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Colors.success)
                                Text("\(screenTime.selectedApps.count) apps and \(screenTime.selectedCategories.count) categories selected")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, DS.Spacing.md)

                    // Info box
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(DS.Colors.accent)
                        Text("You can change these anytime in Settings → App Blocking.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .padding(DS.Spacing.xl)
            }
            .surfaceBackground()
            .navigationTitle("App Blocking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
            .onChange(of: selection) { _, newValue in
                screenTime.updateSelections(
                    apps: newValue.applicationTokens,
                    categories: newValue.categoryTokens
                )
            }
        }
    }

    private func recommendationRow(title: String, icon: String, examples: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.bodyMedium)
                Text(examples)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .padding(.horizontal, DS.Spacing.md)
    }
}
