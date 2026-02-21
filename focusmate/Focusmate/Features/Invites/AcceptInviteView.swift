import SwiftUI

struct AcceptInviteView: View {
  let code: String
  let inviteService: InviteService
  let onAccepted: (ListDTO) -> Void

  @Environment(AuthStore.self) var auth
  @Environment(\.dismiss) private var dismiss

  @State private var preview: InvitePreviewDTO?
  @State private var isLoading = true
  @State private var isAccepting = false
  @State private var error: FocusmateError?
  @State private var acceptedList: ListDTO?

  var body: some View {
    NavigationStack {
      Group {
        if self.isLoading {
          self.loadingView
        } else if let acceptedList {
          self.successView(list: acceptedList)
        } else if let error {
          self.errorView(error)
        } else if let preview {
          self.invitePreview(preview)
        }
      }
      .navigationTitle("List Invitation")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            self.dismiss()
          }
        }
      }
    }
    .task {
      await self.loadPreview()
    }
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(spacing: DS.Spacing.lg) {
      ProgressView()
        .scaleEffect(1.2)
      Text("Loading invitation...")
        .font(DS.Typography.body)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Invite Preview

  private func invitePreview(_ preview: InvitePreviewDTO) -> some View {
    VStack(spacing: DS.Spacing.xl) {
      Spacer()

      // Icon
      Image(systemName: "envelope.open.fill")
        .scaledFont(size: 60, relativeTo: .largeTitle)
        .foregroundStyle(DS.Colors.accent)

      // Invitation text
      VStack(spacing: DS.Spacing.sm) {
        if let inviterName = preview.inviterName {
          Text("\(inviterName) invited you to")
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
        } else {
          Text("You've been invited to")
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
        }

        Text(preview.listName)
          .scaledFont(size: 24, weight: .bold, design: .rounded, relativeTo: .title)
          .multilineTextAlignment(.center)

        Text("You'll be able to \(preview.roleDisplayName) tasks in this list")
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, DS.Spacing.lg)

      Spacer()

      // Actions
      VStack(spacing: DS.Spacing.md) {
        if self.auth.jwt != nil {
          Button {
            Task { await self.acceptInvite() }
          } label: {
            if self.isAccepting {
              ProgressView()
                .tint(.white)
            } else {
              Text("Join List")
            }
          }
          .buttonStyle(IntentiaPrimaryButtonStyle())
          .disabled(self.isAccepting || !preview.usable)
        } else {
          Text("Sign in to accept this invitation")
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)

          Button("Sign In") {
            self.dismiss()
          }
          .buttonStyle(IntentiaPrimaryButtonStyle())
        }

        if !preview.usable {
          Text("This invitation is no longer valid")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.error)
        }
      }
      .padding(.horizontal, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.xl)
    }
  }

  // MARK: - Success View

  private func successView(list: ListDTO) -> some View {
    VStack(spacing: DS.Spacing.xl) {
      Spacer()

      Image(systemName: "checkmark.circle.fill")
        .scaledFont(size: 80, relativeTo: .largeTitle)
        .foregroundStyle(DS.Colors.success)

      VStack(spacing: DS.Spacing.sm) {
        Text("You joined")
          .font(DS.Typography.body)
          .foregroundStyle(.secondary)

        Text(list.name)
          .scaledFont(size: 24, weight: .bold, design: .rounded, relativeTo: .title)
      }

      Spacer()

      Button("View List") {
        self.onAccepted(list)
        self.dismiss()
      }
      .buttonStyle(IntentiaPrimaryButtonStyle())
      .padding(.horizontal, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.xl)
    }
  }

  // MARK: - Error View

  private func errorView(_ error: FocusmateError) -> some View {
    VStack(spacing: DS.Spacing.xl) {
      Spacer()

      Image(systemName: "exclamationmark.triangle.fill")
        .scaledFont(size: 60, relativeTo: .largeTitle)
        .foregroundStyle(DS.Colors.error)

      VStack(spacing: DS.Spacing.sm) {
        Text("Unable to load invitation")
          .font(DS.Typography.bodyMedium)

        Text(error.message)
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, DS.Spacing.lg)

      Spacer()

      Button("Try Again") {
        Task { await self.loadPreview() }
      }
      .buttonStyle(IntentiaPrimaryButtonStyle())
      .padding(.horizontal, DS.Spacing.lg)
      .padding(.bottom, DS.Spacing.xl)
    }
  }

  // MARK: - Actions

  private func loadPreview() async {
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      self.preview = try await self.inviteService.previewInvite(code: self.code)
    } catch let err as FocusmateError {
      error = err
    } catch {
      self.error = .custom("INVITE_ERROR", "Failed to load invitation")
    }
  }

  private func acceptInvite() async {
    self.isAccepting = true
    self.error = nil
    defer { isAccepting = false }

    do {
      let response = try await inviteService.acceptInvite(code: self.code)
      self.acceptedList = response.list
      HapticManager.success()
    } catch let err as FocusmateError {
      error = err
      HapticManager.error()
    } catch {
      self.error = .custom("INVITE_ERROR", "Failed to join list")
      HapticManager.error()
    }
  }
}
