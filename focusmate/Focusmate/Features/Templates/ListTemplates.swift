import Foundation
import SwiftUI

// MARK: - List Type

enum ListType: String, CaseIterable {
  case tasks
  case checklist
  case habitTracker = "habit_tracker"

  var displayName: String {
    switch self {
    case .tasks: return "Tasks"
    case .checklist: return "Checklist"
    case .habitTracker: return "Habit Tracker"
    }
  }
}

// MARK: - Template Task

struct TemplateTask {
  let title: String
  let isRecurring: Bool
  let recurrencePattern: String?
  let recurrenceInterval: Int?
  let recurrenceDays: [Int]?

  static func daily(_ title: String) -> TemplateTask {
    TemplateTask(
      title: title,
      isRecurring: true,
      recurrencePattern: "daily",
      recurrenceInterval: 1,
      recurrenceDays: nil
    )
  }

  static func weekly(_ title: String) -> TemplateTask {
    TemplateTask(
      title: title,
      isRecurring: true,
      recurrencePattern: "weekly",
      recurrenceInterval: 1,
      recurrenceDays: nil
    )
  }

  static func oneTime(_ title: String) -> TemplateTask {
    TemplateTask(
      title: title,
      isRecurring: false,
      recurrencePattern: nil,
      recurrenceInterval: nil,
      recurrenceDays: nil
    )
  }
}

// MARK: - Template Category

enum TemplateCategory: String, CaseIterable {
  case habits = "Habit Trackers"
  case accountability = "Accountability"
  case checklists = "Checklists"

  var icon: String {
    switch self {
    case .habits: return "repeat"
    case .accountability: return "checkmark.shield.fill"
    case .checklists: return "checklist"
    }
  }
}

// MARK: - List Template

struct ListTemplate: Identifiable {
  let id: String
  let name: String
  let description: String
  let icon: String
  let color: String
  let listType: ListType
  let category: TemplateCategory
  let tasks: [TemplateTask]
}

// MARK: - Template Catalog

enum TemplateCatalog {
  static let all: [ListTemplate] = [
    // MARK: - Habit Trackers
    ListTemplate(
      id: "morning-routine",
      name: "Morning Routine",
      description: "Start your day with intention",
      icon: "sunrise.fill",
      color: "orange",
      listType: .habitTracker,
      category: .habits,
      tasks: [
        .daily("Make bed"),
        .daily("Drink a glass of water"),
        .daily("Stretch or exercise"),
        .daily("Shower and get dressed"),
        .daily("Eat breakfast"),
        .daily("Review today's tasks"),
      ]
    ),
    ListTemplate(
      id: "evening-wind-down",
      name: "Evening Wind-Down",
      description: "Prepare for restful sleep",
      icon: "moon.stars.fill",
      color: "purple",
      listType: .habitTracker,
      category: .habits,
      tasks: [
        .daily("Put phone on charger"),
        .daily("Tidy up living space"),
        .daily("Prep tomorrow's outfit"),
        .daily("Brush teeth and skincare"),
        .daily("Journal or reflect"),
        .daily("Lights out by bedtime"),
      ]
    ),
    ListTemplate(
      id: "medication-tracker",
      name: "Medication Tracker",
      description: "Never miss a dose",
      icon: "pills.fill",
      color: "red",
      listType: .habitTracker,
      category: .habits,
      tasks: [
        .daily("Morning medication"),
        .daily("Afternoon medication"),
        .daily("Evening medication"),
        .weekly("Refill pill organizer"),
      ]
    ),
    ListTemplate(
      id: "sleep-hygiene",
      name: "Sleep Hygiene",
      description: "Build better sleep habits",
      icon: "bed.double.fill",
      color: "teal",
      listType: .habitTracker,
      category: .habits,
      tasks: [
        .daily("No caffeine after 2pm"),
        .daily("Screen-free 30 min before bed"),
        .daily("Dim lights in evening"),
        .daily("Set consistent bedtime alarm"),
        .daily("Wind-down activity (read, stretch)"),
      ]
    ),

    // MARK: - Accountability Tasks
    ListTemplate(
      id: "weekly-adulting",
      name: "Weekly Adulting",
      description: "Keep life on track",
      icon: "house.fill",
      color: "blue",
      listType: .tasks,
      category: .accountability,
      tasks: [
        .weekly("Do laundry"),
        .weekly("Grocery shop"),
        .weekly("Clean kitchen and bathroom"),
        .weekly("Take out trash and recycling"),
        .weekly("Review budget and bills"),
      ]
    ),
    ListTemplate(
      id: "relationship-checkin",
      name: "Relationship Check-In",
      description: "Nurture the people who matter",
      icon: "heart.fill",
      color: "pink",
      listType: .tasks,
      category: .accountability,
      tasks: [
        .weekly("Text a friend you haven't talked to"),
        .weekly("Plan a date or hangout"),
        .weekly("Call a family member"),
        .weekly("Write a thank-you or kind note"),
        .weekly("Check in on someone who's struggling"),
      ]
    ),
    ListTemplate(
      id: "financial-responsibilities",
      name: "Financial Responsibilities",
      description: "Stay on top of money",
      icon: "dollarsign.circle.fill",
      color: "green",
      listType: .tasks,
      category: .accountability,
      tasks: [
        .weekly("Check bank account balances"),
        .weekly("Review upcoming bills"),
        .weekly("Log expenses or receipts"),
        .weekly("Review subscriptions"),
      ]
    ),
    ListTemplate(
      id: "work-day-structure",
      name: "Work Day Structure",
      description: "Stay focused and productive",
      icon: "briefcase.fill",
      color: "yellow",
      listType: .tasks,
      category: .accountability,
      tasks: [
        .daily("Review calendar and priorities"),
        .daily("Deep work block (2 hours)"),
        .daily("Respond to messages and emails"),
        .daily("End-of-day review and plan tomorrow"),
        .daily("Close all work tabs and apps"),
      ]
    ),

    // MARK: - Checklists
    ListTemplate(
      id: "grocery-run",
      name: "Grocery Run",
      description: "Quick shopping list to reuse",
      icon: "cart.fill",
      color: "green",
      listType: .checklist,
      category: .checklists,
      tasks: [
        .oneTime("Fruits and vegetables"),
        .oneTime("Protein (meat, eggs, tofu)"),
        .oneTime("Dairy and alternatives"),
        .oneTime("Grains and bread"),
        .oneTime("Snacks"),
        .oneTime("Household essentials"),
      ]
    ),
    ListTemplate(
      id: "appointment-prep",
      name: "Appointment Prep",
      description: "Get ready for any appointment",
      icon: "calendar.badge.clock",
      color: "teal",
      listType: .checklist,
      category: .checklists,
      tasks: [
        .oneTime("Confirm date, time, and location"),
        .oneTime("Gather documents or records"),
        .oneTime("Write down questions to ask"),
        .oneTime("Set reminder for the day before"),
        .oneTime("Plan transportation"),
      ]
    ),
  ]

  static func grouped() -> [(category: TemplateCategory, templates: [ListTemplate])] {
    TemplateCategory.allCases.compactMap { category in
      let templates = all.filter { $0.category == category }
      guard !templates.isEmpty else { return nil }
      return (category: category, templates: templates)
    }
  }

  static func previewTemplates() -> [ListTemplate] {
    // One from each category for empty-state discovery
    TemplateCategory.allCases.compactMap { category in
      all.first { $0.category == category }
    }
  }
}
