import Foundation
import Testing

@testable import RemindCore

@MainActor
struct DateParsingTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }()

  @Test("Relative date parsing")
  func relativeDates() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let today = DateParsing.parseUserDate("today", now: now, calendar: calendar)
    let tomorrow = DateParsing.parseUserDate("tomorrow", now: now, calendar: calendar)
    let yesterday = DateParsing.parseUserDate("yesterday", now: now, calendar: calendar)

    #expect(today == calendar.startOfDay(for: now))
    #expect(tomorrow == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
    #expect(yesterday == calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)))
  }

  @Test("ISO 8601 parsing")
  func isoParsing() {
    let input = "2026-01-03T12:34:56Z"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test("Formatted date parsing")
  func formattedParsing() {
    let input = "2026-01-03 10:30"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test("Format display output")
  func displayFormatting() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let output = DateParsing.formatDisplay(date, calendar: calendar)
    #expect(output.isEmpty == false)
  }
}
