import SwiftUI

struct EscalationBadge: View {
  let urgency: EscalationUrgency
  let count: Int?

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: self.urgencyIcon)
        .font(.caption)

      if let count, count > 0 {
        Text("\(count)")
          .font(.caption)
          .fontWeight(.medium)
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(self.urgencyColor.opacity(0.2))
    .foregroundColor(self.urgencyColor)
    .clipShape(Capsule())
  }

  private var urgencyIcon: String {
    switch self.urgency {
    case .low: return "info.circle"
    case .medium: return "exclamationmark.circle"
    case .high: return "exclamationmark.triangle"
    case .critical: return "exclamationmark.triangle.fill"
    }
  }

  private var urgencyColor: Color {
    switch self.urgency {
    case .low: return .green
    case .medium: return .yellow
    case .high: return .orange
    case .critical: return .red
    }
  }
}

struct EscalationStatusBadge: View {
  let status: EscalationStatus

  var body: some View {
    Text(self.status.rawValue.capitalized)
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(self.statusColor.opacity(0.2))
      .foregroundColor(self.statusColor)
      .clipShape(Capsule())
  }

  private var statusColor: Color {
    switch self.status {
    case .open: return .orange
    case .resolved: return .green
    case .dismissed: return .gray
    }
  }
}

struct BlockingIndicator: View {
  let isBlocking: Bool
  let reason: String?

  var body: some View {
    if self.isBlocking {
      HStack(spacing: 4) {
        Image(systemName: "hand.raised.fill")
          .foregroundColor(.red)
          .font(.caption)

        if let reason {
          Text(reason)
            .font(.caption)
            .foregroundColor(.red)
            .lineLimit(1)
        } else {
          Text("Blocking")
            .font(.caption)
            .foregroundColor(.red)
        }
      }
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Color.red.opacity(0.1))
      .clipShape(Capsule())
    }
  }
}

struct ExplanationTypeBadge: View {
  let type: ExplanationType

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: self.type.icon)
        .font(.caption)

      Text(self.type.rawValue)
        .font(.caption)
        .fontWeight(.medium)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(self.typeColor.opacity(0.2))
    .foregroundColor(self.typeColor)
    .clipShape(Capsule())
  }

  private var typeColor: Color {
    switch self.type {
    case .missedDeadline: return .red
    case .delayed: return .orange
    case .blocked: return .purple
    case .reassigned: return .blue
    case .completedLate: return .green
    case .other: return .gray
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    HStack {
      EscalationBadge(urgency: .low, count: nil)
      EscalationBadge(urgency: .medium, count: 2)
      EscalationBadge(urgency: .high, count: 5)
      EscalationBadge(urgency: .critical, count: 1)
    }

    HStack {
      EscalationStatusBadge(status: .open)
      EscalationStatusBadge(status: .resolved)
      EscalationStatusBadge(status: .dismissed)
    }

    HStack {
      BlockingIndicator(isBlocking: false, reason: nil)
      BlockingIndicator(isBlocking: true, reason: "Waiting for approval")
      BlockingIndicator(isBlocking: true, reason: nil)
    }

    HStack {
      ExplanationTypeBadge(type: .missedDeadline)
      ExplanationTypeBadge(type: .delayed)
      ExplanationTypeBadge(type: .blocked)
      ExplanationTypeBadge(type: .reassigned)
      ExplanationTypeBadge(type: .completedLate)
    }
  }
  .padding()
}
