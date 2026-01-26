import Foundation
import EventKit
import UIKit

final class CalendarService {
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    private let calendarName = "Intentia"

    // MARK: - Cache
    private var cachedCalendar: EKCalendar?
    private var cachedEvents: [EKEvent] = []
    private var eventsCacheTimestamp: Date = .distantPast
    private let eventsCacheTTL: TimeInterval = 2.0

    private init() {}
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                Logger.info("Calendar permission: \(granted ? "granted" : "denied")", category: .general)
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                Logger.info("Calendar permission: \(granted ? "granted" : "denied")", category: .general)
                return granted
            }
        } catch {
            Logger.error("Calendar permission error", error: error, category: .general)
            return false
        }
    }
    
    func checkPermission() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }
    // MARK: - Cache Helpers

    private func getCachedCalendar() -> EKCalendar? {
        if let cached = cachedCalendar { return cached }
        let calendars = eventStore.calendars(for: .event)
        cachedCalendar = calendars.first(where: { $0.title == calendarName })
        return cachedCalendar
    }

    private func getCachedEvents(for calendar: EKCalendar) -> [EKEvent] {
        if Date().timeIntervalSince(eventsCacheTimestamp) < eventsCacheTTL {
            return cachedEvents
        }
        let predicate = eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-30 * 24 * 3600),
            end: Date().addingTimeInterval(30 * 24 * 3600),
            calendars: [calendar]
        )
        cachedEvents = eventStore.events(matching: predicate)
        eventsCacheTimestamp = Date()
        return cachedEvents
    }

    private func invalidateEventsCache() {
        eventsCacheTimestamp = .distantPast
    }

    // MARK: - Calendar Management

    private func getOrCreateCalendar() -> EKCalendar? {
        // Check if Intentia calendar already exists
        if let existing = getCachedCalendar() {
            return existing
        }
        
        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarName
        calendar.cgColor = UIColor.systemBlue.cgColor
        
        // Try sources in order of preference
        let sources = eventStore.sources
        
        // 1. Try local source first (always allows calendar creation)
        if let localSource = sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        }
        // 2. Try iCloud
        else if let iCloudSource = sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            calendar.source = iCloudSource
        }
        // 3. Try any calDAV source
        else if let calDAVSource = sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = calDAVSource
        }
        // 4. Use default calendar's source
        else if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = defaultSource
        }
        else {
            Logger.error("No calendar source found", error: nil, category: .general)
            return nil
        }
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            Logger.info("Created Intentia calendar with source: \(calendar.source?.title ?? "unknown")", category: .general)
            cachedCalendar = calendar
            return calendar
        } catch {
            Logger.error("Failed to create calendar", error: error, category: .general)
            
            // Fallback: use default calendar instead of creating one
            if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
                Logger.info("Using default calendar instead: \(defaultCalendar.title)", category: .general)
                return defaultCalendar
            }
            
            return nil
        }
    }
    
    // MARK: - Event Management
    
    func addTaskToCalendar(_ task: TaskDTO) {
        Logger.debug("Adding task to calendar: \(task.title)", category: .general)
        
        guard checkPermission() else {
            Logger.error("Calendar: No permission", error: nil, category: .general)
            return
        }
        
        guard let dueDate = task.dueDate else {
            Logger.error("Calendar: No due date for task", error: nil, category: .general)
            return
        }
        
        guard let calendar = getOrCreateCalendar() else {
            Logger.error("Calendar: Could not get or create calendar", error: nil, category: .general)
            return
        }
        
        // Remove existing event for this task first
        removeTaskFromCalendar(taskId: task.id)
        
        let event = EKEvent(eventStore: eventStore)
        event.title = task.title
        event.notes = task.note ?? "Created by Intentia"
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(3600) // 1 hour duration
        event.calendar = calendar
        
        // Add alarm 1 hour before
        event.addAlarm(EKAlarm(relativeOffset: -3600))
        
        // Store task ID in URL field for later reference
        event.url = URL(string: "intentia://task/\(task.id)")
        
        do {
            try eventStore.save(event, span: .thisEvent)
            Logger.debug("Successfully added task to calendar: \(task.title)", category: .general)
        } catch {
            Logger.error("Failed to add task to calendar", error: error, category: .general)
        }
    }
    
    func removeTaskFromCalendar(taskId: Int) {
        guard checkPermission() else { return }

        guard let calendar = getCachedCalendar() else { return }

        let events = getCachedEvents(for: calendar)
        let taskURL = URL(string: "intentia://task/\(taskId)")

        for event in events where event.url == taskURL {
            do {
                try eventStore.remove(event, span: .thisEvent)
                invalidateEventsCache()
                Logger.debug("Removed task from calendar: \(taskId)", category: .general)
            } catch {
                Logger.error("Failed to remove task from calendar", error: error, category: .general)
            }
        }
    }
    
    func updateTaskInCalendar(_ task: TaskDTO) {
        // Simply remove and re-add
        removeTaskFromCalendar(taskId: task.id)
        if !task.isCompleted, task.dueDate != nil {
            addTaskToCalendar(task)
        }
    }
}
