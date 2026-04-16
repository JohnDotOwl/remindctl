import Testing

@testable import RemindCore

@MainActor
struct ErrorsTests {
  @Test("Error descriptions")
  func descriptions() {
    #expect(RemindCoreError.accessDenied.localizedDescription.contains("Reminders"))
    #expect(RemindCoreError.writeOnlyAccess.localizedDescription.contains("write-only"))
    #expect(RemindCoreError.listNotFound("Work").localizedDescription.contains("Work"))
    #expect(RemindCoreError.reminderNotFound("abc").localizedDescription.contains("abc"))
    #expect(RemindCoreError.ambiguousIdentifier("a", matches: ["1", "2"]).localizedDescription.contains("matches"))
    #expect(RemindCoreError.invalidIdentifier("x").localizedDescription.contains("Invalid identifier"))
    #expect(RemindCoreError.invalidDate("bad").localizedDescription.contains("Invalid date"))
    #expect(RemindCoreError.unsupported("nope").localizedDescription.contains("nope"))
    #expect(RemindCoreError.operationFailed("fail").localizedDescription.contains("fail"))
  }
}
