import SwiftUI

/// Settings view for managing app integrations
struct IntegrationsSettingsView: View {
  @StateObject private var calendarService = CalendarIntegrationService.shared
  @StateObject private var remindersService = RemindersIntegrationService.shared
  @StateObject private var siriService = SiriShortcutsService.shared

  @EnvironmentObject var appState: AppState
  @State private var showingCalendarPermissionAlert = false
  @State private var showingRemindersPermissionAlert = false
  @State private var isSyncing = false

  var body: some View {
    SwiftUI.List {
      // Calendar Integration Section
      Section {
        HStack {
          Image(systemName: "calendar")
            .foregroundColor(.blue)
            .font(.title2)
            .frame(width: 32)

          VStack(alignment: .leading, spacing: 4) {
            Text("Calendar Integration")
              .font(.headline)
            Text("Sync tasks to iOS Calendar")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Toggle("", isOn: $calendarService.isEnabled)
            .labelsHidden()
            .disabled(!calendarService.isAuthorized)
            .onChange(of: calendarService.isEnabled) { _, enabled in
              if enabled {
                Task {
                  await syncToCalendar()
                }
              }
            }
        }

        if !calendarService.isAuthorized {
          Button {
            Task {
              let granted = await calendarService.requestAccess()
              if !granted {
                showingCalendarPermissionAlert = true
              }
            }
          } label: {
            Label("Grant Calendar Access", systemImage: "lock.open")
              .foregroundColor(.blue)
          }
        }

        if calendarService.isEnabled && calendarService.isAuthorized {
          Button {
            Task {
              await syncToCalendar()
            }
          } label: {
            if isSyncing {
              HStack {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
                Text("Syncing...")
              }
            } else {
              Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
          }
          .disabled(isSyncing)
        }
      } header: {
        Text("Calendar")
      } footer: {
        Text("Tasks with due dates will be created as calendar events in a dedicated Focusmate calendar.")
      }

      // Reminders Integration Section
      Section {
        HStack {
          Image(systemName: "checklist")
            .foregroundColor(.orange)
            .font(.title2)
            .frame(width: 32)

          VStack(alignment: .leading, spacing: 4) {
            Text("Reminders Integration")
              .font(.headline)
            Text("Sync tasks to iOS Reminders")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Toggle("", isOn: $remindersService.isEnabled)
            .labelsHidden()
            .disabled(!remindersService.isAuthorized)
            .onChange(of: remindersService.isEnabled) { _, enabled in
              if enabled {
                Task {
                  await syncToReminders()
                }
              }
            }
        }

        if !remindersService.isAuthorized {
          Button {
            Task {
              let granted = await remindersService.requestAccess()
              if !granted {
                showingRemindersPermissionAlert = true
              }
            }
          } label: {
            Label("Grant Reminders Access", systemImage: "lock.open")
              .foregroundColor(.orange)
          }
        }

        if remindersService.isEnabled && remindersService.isAuthorized {
          Button {
            Task {
              await syncToReminders()
            }
          } label: {
            if isSyncing {
              HStack {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
                Text("Syncing...")
              }
            } else {
              Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
          }
          .disabled(isSyncing)
        }
      } header: {
        Text("Reminders")
      } footer: {
        Text("Tasks will be synced to a dedicated Focusmate list in the Reminders app.")
      }

      // Siri Shortcuts Section
      Section {
        HStack {
          Image(systemName: "waveform")
            .foregroundColor(.purple)
            .font(.title2)
            .frame(width: 32)

          VStack(alignment: .leading, spacing: 4) {
            Text("Siri Shortcuts")
              .font(.headline)
            Text("Use voice commands with Siri")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Button {
          siriService.donateCommonShortcuts()
        } label: {
          Label("Setup Siri Shortcuts", systemImage: "plus.circle")
        }

        NavigationLink(destination: SiriShortcutsGuideView()) {
          Label("View Siri Commands", systemImage: "info.circle")
        }

        if siriService.donatedShortcutsCount > 0 {
          HStack {
            Text("Donated Shortcuts")
              .foregroundColor(.secondary)
            Spacer()
            Text("\(siriService.donatedShortcutsCount)")
              .foregroundColor(.purple)
          }
        }
      } header: {
        Text("Siri")
      } footer: {
        Text("Create shortcuts for common actions like creating tasks, completing tasks, and viewing your task list. Say 'Hey Siri' followed by your command.")
      }

      // Sync Information
      Section {
        VStack(alignment: .leading, spacing: 12) {
          Label("Automatic Sync", systemImage: "arrow.triangle.2.circlepath.circle")
            .font(.headline)

          Text("Tasks are automatically synced when:")
            .font(.subheadline)
            .foregroundColor(.secondary)

          VStack(alignment: .leading, spacing: 8) {
            BulletPoint(text: "A task is created or updated")
            BulletPoint(text: "A task is marked as complete")
            BulletPoint(text: "A task is deleted")
            BulletPoint(text: "Integration is first enabled")
          }
        }
        .padding(.vertical, 8)
      } header: {
        Text("Sync Behavior")
      }
    }
    .navigationTitle("Integrations")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Calendar Permission Required", isPresented: $showingCalendarPermissionAlert) {
      Button("OK", role: .cancel) {}
      Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
    } message: {
      Text("Please enable Calendar access in Settings to sync tasks to your calendar.")
    }
    .alert("Reminders Permission Required", isPresented: $showingRemindersPermissionAlert) {
      Button("OK", role: .cancel) {}
      Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
    } message: {
      Text("Please enable Reminders access in Settings to sync tasks to the Reminders app.")
    }
  }

  // MARK: - Sync Methods

  private func syncToCalendar() async {
    isSyncing = true

    do {
      // Fetch all lists
      let lists = try await appState.listService.fetchLists()

      // Fetch items from all lists
      var allTasks: [Item] = []
      for list in lists {
        let items = try await appState.itemService.fetchItems(listId: list.id)
        allTasks.append(contentsOf: items)
      }

      // Sync to calendar
      try await calendarService.syncTasksToCalendar(allTasks)

      Logger.info("Synced \(allTasks.count) tasks to calendar", category: .ui)
    } catch {
      Logger.error("Calendar sync failed", error: error, category: .ui)
    }

    isSyncing = false
  }

  private func syncToReminders() async {
    isSyncing = true

    do {
      // Fetch all lists
      let lists = try await appState.listService.fetchLists()

      // Fetch items from all lists
      var allTasks: [Item] = []
      for list in lists {
        let items = try await appState.itemService.fetchItems(listId: list.id)
        allTasks.append(contentsOf: items)
      }

      // Sync to reminders
      try await remindersService.syncTasksToReminders(allTasks)

      Logger.info("Synced \(allTasks.count) tasks to reminders", category: .ui)
    } catch {
      Logger.error("Reminders sync failed", error: error, category: .ui)
    }

    isSyncing = false
  }
}

// MARK: - Supporting Views

struct BulletPoint: View {
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text("•")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
      Text(text)
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
  }
}

struct SiriShortcutsGuideView: View {
  var body: some View {
    SwiftUI.List {
      Section {
        ShortcutExample(
          phrase: "Hey Siri, create task in Inbox",
          description: "Opens task creation for the specified list"
        )
        ShortcutExample(
          phrase: "Hey Siri, show my tasks",
          description: "Opens your task list"
        )
        ShortcutExample(
          phrase: "Hey Siri, complete [task name]",
          description: "Marks the specified task as complete"
        )
      } header: {
        Text("Available Commands")
      } footer: {
        Text("These shortcuts will be suggested by Siri after you use them a few times.")
      }

      Section {
        VStack(alignment: .leading, spacing: 12) {
          Text("To create custom shortcuts:")
            .font(.subheadline)
            .fontWeight(.medium)

          VStack(alignment: .leading, spacing: 8) {
            BulletPoint(text: "Open the Shortcuts app")
            BulletPoint(text: "Tap the '+' button to create a new shortcut")
            BulletPoint(text: "Search for 'Focusmate' actions")
            BulletPoint(text: "Add actions and customize your phrase")
          }
        }
        .padding(.vertical, 8)
      } header: {
        Text("Custom Shortcuts")
      }
    }
    .navigationTitle("Siri Commands")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct ShortcutExample: View {
  let phrase: String
  let description: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(phrase)
        .font(.headline)
        .foregroundColor(.purple)

      Text(description)
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Preview

#Preview {
  NavigationView {
    IntegrationsSettingsView()
      .environmentObject(AppState())
  }
}
