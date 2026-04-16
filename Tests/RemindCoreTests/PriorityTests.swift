import Testing

@testable import RemindCore

@MainActor
struct PriorityTests {
  @Test("EventKit priority mapping")
  func mapping() {
    #expect(ReminderPriority(eventKitValue: 0) == .none)
    #expect(ReminderPriority(eventKitValue: 1) == .high)
    #expect(ReminderPriority(eventKitValue: 5) == .medium)
    #expect(ReminderPriority(eventKitValue: 9) == .low)
    #expect(ReminderPriority.high.eventKitValue == 1)
    #expect(ReminderPriority.medium.eventKitValue == 5)
    #expect(ReminderPriority.low.eventKitValue == 9)
  }
}
