import Foundation

/// Centralized ISO8601 date parsing and formatting.
///
/// ## Why this exists
/// ISO8601DateFormatter is expensive to allocate (~2KB per instance) and the codebase
/// had 8 separate instances across 6 files — two distinct configurations duplicated
/// in every DTO that touches dates. Each file-level `private let` avoids per-call
/// allocation but still wastes memory on redundant formatters.
///
/// ## What this changes
/// A single pair of `static let` formatters shared process-wide. ISO8601DateFormatter
/// is thread-safe (it's an NSFormatter subclass that documents concurrent use), so
/// sharing is safe without locking.
///
/// ## Tradeoff
/// All date parsing now routes through one code path. If a future API endpoint returns
/// a non-standard ISO8601 variant, you'd add the new formatter here rather than
/// locally — slightly less encapsulation in exchange for zero duplication.
enum ISO8601Utils {
  static let formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  static let formatterNoFrac = ISO8601DateFormatter()

  /// Parse an ISO8601 string, trying fractional seconds first then without.
  static func parseDate(_ string: String) -> Date? {
    self.formatter.date(from: string) ?? self.formatterNoFrac.date(from: string)
  }

  /// Format a Date to ISO8601 string (with fractional seconds).
  static func formatDate(_ date: Date) -> String {
    self.formatter.string(from: date)
  }

  /// Format a Date to ISO8601 string (without fractional seconds).
  static func formatDateNoFrac(_ date: Date) -> String {
    self.formatterNoFrac.string(from: date)
  }
}
