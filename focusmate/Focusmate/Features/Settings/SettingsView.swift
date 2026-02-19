import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.router) private var router
  @State private var showingSignOutConfirmation = false
  @State private var calendarPermissionGranted = CalendarService.shared.checkPermission()
  @State private var calendarSyncEnabled = AppSettings.shared.calendarSyncEnabled

  private var user: UserDTO? {
    self.appState.auth.currentUser
  }

  var body: some View {
    List {
      // MARK: - Profile Header

      Section {
        Button {
          self.presentEditProfile()
        } label: {
          HStack(spacing: DS.Spacing.lg) {
            Avatar(self.user?.name ?? self.user?.email, size: DS.Size.avatarLarge)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
              Text(self.user?.name ?? "No Name")
                .font(DS.Typography.headline)
            }

            Spacer()

            Image(systemName: DS.Icon.chevronRight)
              .font(DS.Typography.footnote)
              .foregroundStyle(.tertiary)
          }
          .padding(.vertical, DS.Spacing.sm)
        }
        .foregroundStyle(.primary)
      }

      // MARK: - Account

      if self.user?.hasPassword == true {
        Section("Account") {
          Button {
            self.presentChangePassword()
          } label: {
            SettingsRow("Change Password", icon: "lock")
          }
        }
      }

      // MARK: - Preferences

      Section("Preferences") {
        Button {
          self.router.push(.notificationSettings, in: .settings)
        } label: {
          SettingsRow("Notifications", icon: DS.Icon.bell)
        }

        Button {
          self.router.push(.appBlockingSettings, in: .settings)
        } label: {
          SettingsRow("App Blocking", icon: DS.Icon.shield)
        }

        if self.calendarPermissionGranted {
          Toggle(isOn: self.$calendarSyncEnabled) {
            Label("Calendar Sync", systemImage: "calendar")
          }
          .onChange(of: self.calendarSyncEnabled) { _, newValue in
            AppSettings.shared.calendarSyncEnabled = newValue
          }
        } else {
          HStack {
            Label("Calendar Sync", systemImage: "calendar")
            Spacer()
            Button("Enable") {
              self.requestCalendarAccess()
            }
            .font(DS.Typography.subheadline)
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }
      }

      // MARK: - About

      Section {
        HStack {
          Label("Version", systemImage: DS.Icon.info)
          Spacer()
          Text(self.appVersion)
            .foregroundStyle(.secondary)
        }

        Button {
          self.replayOnboarding()
        } label: {
          SettingsRow("Replay Onboarding", icon: "arrow.counterclockwise")
        }

        if let privacyURL = URL(string: "https://intentia.app/privacy") {
          Link(destination: privacyURL) {
            SettingsRow("Privacy Policy", icon: "hand.raised", external: true)
          }
        }

        if let termsURL = URL(string: "https://intentia.app/terms") {
          Link(destination: termsURL) {
            SettingsRow("Terms of Service", icon: "doc.text", external: true)
          }
        }
      }

      // MARK: - Sign Out

      Section {
        Button {
          self.showingSignOutConfirmation = true
        } label: {
          HStack {
            Spacer()
            Text("Sign Out")
            Spacer()
          }
        }
        .foregroundStyle(DS.Colors.error)
      }

      // MARK: - Delete Account

      Section {
        Button(role: .destructive) {
          self.presentDeleteAccount()
        } label: {
          HStack {
            Spacer()
            Text("Delete Account")
            Spacer()
          }
        }
      } footer: {
        Text("Permanently delete your account and all data.")
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .surfaceFormBackground()
    .navigationTitle("Settings")
    .alert("Sign Out", isPresented: self.$showingSignOutConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Sign Out", role: .destructive) {
        Task { await self.appState.signOut() }
      }
    } message: {
      Text("Are you sure you want to sign out?")
    }
  }

  // MARK: - Sheet Presentation

  private func presentEditProfile() {
    guard let user else { return }
    self.router.present(.editProfile(user))
  }

  private func presentChangePassword() {
    self.router.present(.changePassword)
  }

  private func presentDeleteAccount() {
    self.router.present(.deleteAccount)
  }

  // MARK: - Helpers

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  }

  private func replayOnboarding() {
    // @AppStorage in RootView observes the same UserDefaults key,
    // so flipping this directly triggers the onboarding flow — no
    // notification side-channel needed.
    AppSettings.shared.hasCompletedOnboarding = false
  }

  private func requestCalendarAccess() {
    Task {
      let granted = await CalendarService.shared.requestPermission()
      await MainActor.run {
        self.calendarPermissionGranted = granted
        if granted {
          AppSettings.shared.didRequestCalendarPermission = true
          AppSettings.shared.calendarSyncEnabled = true
          self.calendarSyncEnabled = true
        }
      }
    }
  }
}

// MARK: - Settings Row Helper

private struct SettingsRow: View {
  let title: String
  let icon: String
  let external: Bool

  init(_ title: String, icon: String, external: Bool = false) {
    self.title = title
    self.icon = icon
    self.external = external
  }

  var body: some View {
    HStack {
      Label(self.title, systemImage: self.icon)
      Spacer()
      Image(systemName: self.external ? DS.Icon.externalLink : DS.Icon.chevronRight)
        .font(DS.Typography.footnote)
        .foregroundStyle(.tertiary)
    }
    .foregroundStyle(.primary)
  }
}
