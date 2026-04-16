import Foundation
import SQLite3

struct SectionResolver {
  private let fileManager: FileManager
  private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func resolveSectionNames(for reminderIDs: [String]) -> [String: String] {
    guard !reminderIDs.isEmpty else { return [:] }
    guard let databaseURL = findDatabase() else { return [:] }
    guard let db = openDatabase(at: databaseURL) else { return [:] }
    defer { sqlite3_close(db) }
    return loadSectionNames(from: db, reminderIDs: reminderIDs)
  }

  private func findDatabase() -> URL? {
    guard let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
      return nil
    }

    let candidateRoots: [URL] = [
      libraryURL.appendingPathComponent("Reminders/Container_v1/Stores", isDirectory: true),
      libraryURL.appendingPathComponent("Reminders/Container/Stores", isDirectory: true),
      libraryURL.appendingPathComponent("Reminders/Stores", isDirectory: true),
      libraryURL.appendingPathComponent(
        "Group Containers/group.com.apple.reminders/Container_v1/Stores",
        isDirectory: true
      ),
      libraryURL.appendingPathComponent(
        "Group Containers/group.com.apple.reminders/Container/Stores",
        isDirectory: true
      ),
      libraryURL.appendingPathComponent(
        "Group Containers/group.com.apple.reminders/Stores",
        isDirectory: true
      ),
    ]

    var latestURL: URL?
    var latestDate: Date?

    for root in candidateRoots where fileManager.fileExists(atPath: root.path) {
      guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      ) else { continue }

      for case let fileURL as URL in enumerator {
        guard fileURL.lastPathComponent.hasPrefix("Data-"),
              fileURL.pathExtension == "sqlite"
        else { continue }
        guard let values = try? fileURL.resourceValues(
          forKeys: [.contentModificationDateKey, .isRegularFileKey]
        ),
          values.isRegularFile == true
        else { continue }
        let modified = values.contentModificationDate ?? .distantPast
        if let latestDate, modified <= latestDate { continue }
        latestDate = modified
        latestURL = fileURL
      }
    }

    return latestURL
  }

  private func openDatabase(at url: URL) -> OpaquePointer? {
    var db: OpaquePointer?
    let flags = SQLITE_OPEN_READONLY
    if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
      if db != nil { sqlite3_close(db) }
      return nil
    }
    sqlite3_busy_timeout(db, 2000)
    return db
  }

  // swiftlint:disable:next function_body_length cyclomatic_complexity
  private func loadSectionNames(from db: OpaquePointer, reminderIDs: [String]) -> [String: String] {
    let reminderIDSet = Set(reminderIDs)

    let reminderColumns = columns(in: "ZREMCDREMINDER", db: db)
    guard !reminderColumns.isEmpty else { return [:] }
    guard reminderColumns.contains("ZLIST") else { return [:] }

    let reminderIdentifierCandidates = [
      "ZDACALENDARITEMUNIQUEIDENTIFIER",
      "ZREMINDERIDENTIFIER",
      "ZCKIDENTIFIER",
    ]
    let identifierColumns = reminderIdentifierCandidates.filter { reminderColumns.contains($0) }
    guard !identifierColumns.isEmpty else { return [:] }

    let selectColumns = identifierColumns + ["ZLIST"]
    let reminderIDList = Array(reminderIDSet)
    let placeholders = Array(repeating: "?", count: reminderIDList.count).joined(separator: ", ")

    let queryParts = identifierColumns.map { "\($0) IN (\(placeholders))" }
    let reminderQuery = "SELECT \(selectColumns.joined(separator: ", ")) " +
      "FROM ZREMCDREMINDER WHERE \(queryParts.joined(separator: " OR "))"

    guard let statement = prepare(db: db, query: reminderQuery) else { return [:] }
    defer { sqlite3_finalize(statement) }

    bindReminderIDs(statement, reminderIDs: reminderIDList, columnCount: identifierColumns.count)

    let reminderData = extractReminderData(statement, reminderIDs: reminderIDSet, columns: identifierColumns)
    guard !reminderData.listPKs.isEmpty else { return [:] }

    let memberToGroupID = loadMemberships(db: db, reminderData: reminderData)
    let sectionsByGroupID = loadSections(db: db, listPKs: reminderData.listPKs)

    return buildResults(reminderData: reminderData, memberToGroupID: memberToGroupID, sectionsByGroupID: sectionsByGroupID)
  }

  private func bindReminderIDs(
    _ statement: OpaquePointer,
    reminderIDs: [String],
    columnCount: Int
  ) {
    var bindIndex: Int32 = 1
    for _ in 0..<columnCount {
      for reminderID in reminderIDs {
        sqlite3_bind_text(statement, bindIndex, reminderID, -1, sqliteTransient)
        bindIndex += 1
      }
    }
  }

  private func extractReminderData(
    _ statement: OpaquePointer,
    reminderIDs: Set<String>,
    columns: [String]
  ) -> ReminderData {
    var reminderToMemberID: [String: String] = [:]
    var reminderToListPK: [String: Int64] = [:]
    var listPKs: Set<Int64> = []

    while sqlite3_step(statement) == SQLITE_ROW {
      var identifiers: [String] = []
      var memberID: String?
      for (index, column) in columns.enumerated() {
        if let rawValue = stringValue(statement, index: Int32(index)) {
          let value = rawValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if !value.isEmpty {
            identifiers.append(value)
            if column == "ZDACALENDARITEMUNIQUEIDENTIFIER" {
              memberID = value
            }
          }
        }
      }

      guard let matchedIdentifier = identifiers.first(where: { reminderIDs.contains($0) }) else { continue }
      if memberID == nil { memberID = matchedIdentifier }

      let listIndex = Int32(columns.count)
      guard sqlite3_column_type(statement, listIndex) != SQLITE_NULL else { continue }
      let listPK = sqlite3_column_int64(statement, listIndex)

      guard let memberID else { continue }
      reminderToMemberID[matchedIdentifier] = memberID
      reminderToListPK[matchedIdentifier] = listPK
      listPKs.insert(listPK)
    }

    return ReminderData(
      reminderToMemberID: reminderToMemberID,
      reminderToListPK: reminderToListPK,
      listPKs: listPKs
    )
  }

  private func loadMemberships(db: OpaquePointer, reminderData: ReminderData) -> [String: String] {
    let memberIDs = Set(reminderData.reminderToMemberID.values)
    var memberToGroupID: [String: String] = [:]

    let listPKList = Array(reminderData.listPKs)
    let placeholders = Array(repeating: "?", count: listPKList.count).joined(separator: ", ")
    let listQuery = "SELECT Z_PK, ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA " +
      "FROM ZREMCDBASELIST WHERE Z_PK IN (\(placeholders))"

    guard let statement = prepare(db: db, query: listQuery) else { return [:] }
    defer { sqlite3_finalize(statement) }

    var bindIndex: Int32 = 1
    for listPK in listPKList {
      sqlite3_bind_int64(statement, bindIndex, listPK)
      bindIndex += 1
    }

    while sqlite3_step(statement) == SQLITE_ROW {
      let data = extractData(statement, index: 1)
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let memberships = json["memberships"] as? [[String: Any]]
      else { continue }

      for membership in memberships {
        guard let memberID = membership["memberID"] as? String,
              let groupID = membership["groupID"] as? String
        else { continue }
        if memberIDs.contains(memberID) {
          memberToGroupID[memberID] = groupID
        }
      }
    }

    return memberToGroupID
  }

  private func loadSections(db: OpaquePointer, listPKs: Set<Int64>) -> [String: String] {
    let sectionColumns = columns(in: "ZREMCDBASESECTION", db: db)
    guard sectionColumns.contains("ZCKIDENTIFIER"),
          sectionColumns.contains("ZDISPLAYNAME")
    else { return [:] }

    var sectionsByGroupID: [String: String] = [:]
    let listPKList = Array(listPKs)
    let placeholders = Array(repeating: "?", count: listPKList.count).joined(separator: ", ")

    var sectionQuery = "SELECT ZCKIDENTIFIER, ZDISPLAYNAME FROM ZREMCDBASESECTION"
    if sectionColumns.contains("ZLIST") {
      sectionQuery += " WHERE ZLIST IN (\(placeholders))"
    }

    guard let statement = prepare(db: db, query: sectionQuery) else { return [:] }
    defer { sqlite3_finalize(statement) }

    if sectionColumns.contains("ZLIST") {
      var bindIndex: Int32 = 1
      for listPK in listPKList {
        sqlite3_bind_int64(statement, bindIndex, listPK)
        bindIndex += 1
      }
    }

    while sqlite3_step(statement) == SQLITE_ROW {
      guard let rawGroupID = stringValue(statement, index: 0),
            let rawName = stringValue(statement, index: 1)
      else { continue }
      let groupID = rawGroupID.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      let name = rawName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      guard !groupID.isEmpty, !name.isEmpty else { continue }
      sectionsByGroupID[groupID] = name
    }

    return sectionsByGroupID
  }

  private func buildResults(
    reminderData: ReminderData,
    memberToGroupID: [String: String],
    sectionsByGroupID: [String: String]
  ) -> [String: String] {
    var results: [String: String] = [:]
    for (reminderID, memberID) in reminderData.reminderToMemberID {
      if let groupID = memberToGroupID[memberID], let name = sectionsByGroupID[groupID] {
        results[reminderID] = name
      }
    }
    return results
  }

  private func extractData(_ statement: OpaquePointer, index: Int32) -> Data? {
    if let blob = blobValue(statement, index: index) {
      return blob
    }
    if let text = stringValue(statement, index: index) {
      return text.data(using: .utf8)
    }
    return nil
  }

  private func columns(in table: String, db: OpaquePointer) -> Set<String> {
    let query = "PRAGMA table_info(\(table))"
    guard let statement = prepare(db: db, query: query) else { return [] }
    defer { sqlite3_finalize(statement) }

    var columns: Set<String> = []
    while sqlite3_step(statement) == SQLITE_ROW {
      if let name = stringValue(statement, index: 1) {
        columns.insert(name)
      }
    }
    return columns
  }

  private func prepare(db: OpaquePointer, query: String) -> OpaquePointer? {
    var statement: OpaquePointer?
    if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
      return nil
    }
    return statement
  }

  private func stringValue(_ statement: OpaquePointer, index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let cString = sqlite3_column_text(statement, index)
    else { return nil }
    return String(cString: cString)
  }

  private func blobValue(_ statement: OpaquePointer, index: Int32) -> Data? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let bytes = sqlite3_column_blob(statement, index)
    else { return nil }
    let length = Int(sqlite3_column_bytes(statement, index))
    return Data(bytes: bytes, count: length)
  }
}

private struct ReminderData {
  let reminderToMemberID: [String: String]
  let reminderToListPK: [String: Int64]
  let listPKs: Set<Int64>
}
