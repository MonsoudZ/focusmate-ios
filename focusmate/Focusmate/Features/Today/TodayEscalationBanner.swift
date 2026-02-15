import SwiftUI

/// Escalation status banners for TodayView
///
/// Design concept: These banners represent **system state feedback** - they inform
/// the user about the escalation state machine's current position. The state machine
/// transitions: Normal → Grace Period → Blocking, and these banners reflect that.
/// A fourth state — "authorization revoked" — appears when Screen Time access is
/// removed during an active escalation. This gives the user a recovery path instead
/// of silently returning to "normal" with no explanation.
///
/// Priority: blocking > grace period > revoked. If blocking is somehow active
/// alongside revocation, blocking is more actionable.
struct TodayEscalationBanner: View {
    let isBlocking: Bool
    let isInGracePeriod: Bool
    let gracePeriodRemaining: String?
    let authorizationWasRevoked: Bool
    var onRevocationBannerTapped: (() -> Void)?

    var body: some View {
        if isBlocking {
            blockingBanner
        } else if isInGracePeriod {
            gracePeriodBanner
        } else if authorizationWasRevoked {
            revocationBanner
        }
    }

    // MARK: - Blocking Banner

    private var blockingBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icon.lock)
                .font(DS.Typography.title3)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Apps Blocked")
                    .font(DS.Typography.bodyMedium)
                Text("Complete your overdue tasks to unlock")
                    .font(DS.Typography.caption)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(DS.Spacing.md)
        .background(
            LinearGradient(
                colors: [DS.Colors.error, DS.Colors.error.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apps are blocked. Complete your overdue tasks to unlock.")
    }

    // MARK: - Grace Period Banner

    private var gracePeriodBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icon.timer)
                .font(DS.Typography.title3)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Grace Period")
                    .font(DS.Typography.bodyMedium)
                Text("Apps will be blocked in \(gracePeriodRemaining ?? "...")")
                    .font(DS.Typography.caption)
            }
            Spacer()
        }
        .foregroundStyle(.black)
        .padding(DS.Spacing.md)
        .background(
            LinearGradient(
                colors: [DS.Colors.warning, DS.Colors.warning.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Grace period active. Apps will be blocked in \(gracePeriodRemaining ?? "unknown time").")
    }

    // MARK: - Revocation Banner

    private var revocationBanner: some View {
        Button {
            onRevocationBannerTapped?()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icon.shield)
                    .font(DS.Typography.title3)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Screen Time Access Revoked")
                        .font(DS.Typography.bodyMedium)
                    Text("App blocking is disabled. Tap to fix in Settings.")
                        .font(DS.Typography.caption)
                }
                Spacer()
                Image(systemName: DS.Icon.chevronRight)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(.black)
            .padding(DS.Spacing.md)
            .background(
                LinearGradient(
                    colors: [DS.Colors.warning, DS.Colors.warning.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Screen Time access revoked. App blocking is disabled. Tap to fix in Settings.")
        .accessibilityAddTraits(.isButton)
    }
}
