import Flutter
import UIKit
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import SwiftUI
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "rest/alarms",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        Task { @MainActor in
          await RestAlarmBridge.shared.handle(call, result: result)
        }
        return
      }
      #endif
      if call.method == "status" {
        result(["alarms": [], "permissions": ["unsupported"]])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct RestAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
struct RestSnoozeIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Snooze REST alarm"
  static let supportedModes: IntentModes = .background
  static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(title: "Alarm")
  var systemID: String

  init() {}

  init(systemID: UUID) {
    self.systemID = systemID.uuidString
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    if let id = UUID(uuidString: systemID) {
      try await RestAlarmBridge.shared.snooze(systemID: id)
    }
    return .result()
  }
}

@available(iOS 26.0, *)
@MainActor
private final class RestAlarmBridge {
  static let shared = RestAlarmBridge()
  private let manager = AlarmManager.shared
  private let storageKey = "restWakeAlarms"
  private var changing = false
  private var activeAlarms = Set<UUID>()
  private var lastRing = 0

  private struct SavedAlarm: Codable {
    let id: UUID
    let hour: Int
    let minute: Int
    let days: [Int]
    var scheduleID: UUID?
    var snoozeID: UUID?
    var finishBeforeMinutes: Int?
    var fadeMinutes: Int?
    var oneTimeDate: Date?
    var snoozedUntil: Date?

    var systemIDs: [UUID] { [scheduleID, snoozeID].compactMap { $0 } }
  }

  private enum AlarmFailure: String, Error {
    case invalid = "alarmInvalid"
    case permission = "iosRequired"
    case busy = "alarmBusy"
  }

  func handle(_ call: FlutterMethodCall, result: FlutterResult) async {
    let args = call.arguments as? [String: Any] ?? [:]
    let id = (args["id"] as? String).flatMap(UUID.init(uuidString:))
    do {
      switch call.method {
      case "setLanguage":
        guard let labels = args["labels"] as? [String: String] else {
          throw AlarmFailure.invalid
        }
        UserDefaults.standard.set(labels, forKey: "restAlarmLabels")
        result(nil)
      case "status":
        result(try status())
      case "allow":
        if manager.authorizationState == .denied {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(url)
          }
        } else {
          _ = try await manager.requestAuthorization()
        }
        result(nil)
      case "save":
        guard let hour = args["hour"] as? Int, (0...23).contains(hour),
              let minute = args["minute"] as? Int, (0...59).contains(minute),
              let days = args["days"] as? [Int],
              days.allSatisfy({ (1...7).contains($0) }),
              let enabled = args["enabled"] as? Bool else {
          throw AlarmFailure.invalid
        }
        let finishBefore = args["finishBeforeMinutes"] as? Int
        let fade = args["fadeMinutes"] as? Int
        guard (0...720).contains(finishBefore ?? 0), (0...120).contains(fade ?? 0) else {
          throw AlarmFailure.invalid
        }
        try await save(SavedAlarm(
          id: id ?? UUID(), hour: hour, minute: minute, days: days,
          finishBeforeMinutes: finishBefore, fadeMinutes: fade
        ), enabled: enabled)
        result(nil)
      case "stop", "delete", "snooze":
        guard let alarm = try read().first(where: { $0.id == id }) else {
          throw AlarmFailure.invalid
        }
        if call.method == "delete" {
          try change {
            try cancelSystemAlarms(alarm)
            try write(read().filter { $0.id != alarm.id })
          }
        } else if let activeID = try activeID(for: alarm) {
          if call.method == "snooze" {
            try await snooze(systemID: activeID)
          } else {
            try change { try manager.stop(id: activeID) }
          }
        } else if call.method == "stop", let snoozeID = alarm.snoozeID {
          try change {
            if try manager.alarms.contains(where: { $0.id == snoozeID }) {
              try manager.cancel(id: snoozeID)
            }
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      let code = (error as? AlarmFailure)?.rawValue ?? "alarm"
      result(FlutterError(code: code, message: nil, details: nil))
    }
  }

  private func read() throws -> [SavedAlarm] {
    guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
    return try JSONDecoder().decode([SavedAlarm].self, from: data)
  }

  private func write(_ records: [SavedAlarm]) throws {
    UserDefaults.standard.set(try JSONEncoder().encode(records), forKey: storageKey)
  }

  private func status() throws -> [String: Any] {
    let authorized = manager.authorizationState == .authorized
    let registered = authorized ? try manager.alarms : []
    let ids = Set(registered.map(\.id))
    let active = Set(registered.filter { $0.state == .alerting }.map(\.id))
    let now = Date()
    if !active.subtracting(activeAlarms).isEmpty { lastRing = milliseconds(now) }
    activeAlarms = active
    let records = try read()
    let permissions = switch manager.authorizationState {
    case .authorized: [String]()
    case .denied: ["iosSettings"]
    default: ["ios"]
    }
    var status: [String: Any] = [
      "alarms": records.map { alarm -> [String: Any] in
        let enabled = alarm.scheduleID.map(ids.contains) ?? false
        let snoozed = alarm.snoozeID.map { ids.contains($0) && !active.contains($0) } ?? false
        var serialized: [String: Any] = [
          "id": alarm.id.uuidString,
          "hour": alarm.hour,
          "minute": alarm.minute,
          "days": alarm.days,
          "enabled": enabled,
          "snoozed": snoozed
        ]
        if enabled {
          serialized["nextAt"] = (alarm.oneTimeDate ?? nextOccurrence(for: alarm, after: now))
            .map(milliseconds)
        }
        if snoozed { serialized["snoozedUntil"] = alarm.snoozedUntil.map(milliseconds) }
        serialized["finishBeforeMinutes"] = alarm.finishBeforeMinutes
        serialized["fadeMinutes"] = alarm.fadeMinutes
        return serialized
      },
      "permissions": permissions,
      "lastRing": lastRing
    ]
    if let ringing = records.first(where: { $0.systemIDs.contains(where: active.contains) }) {
      status["ringing"] = ringing.id.uuidString
    }
    return status
  }

  private func milliseconds(_ date: Date) -> Int {
    Int(date.timeIntervalSince1970 * 1000)
  }

  private func nextOccurrence(for alarm: SavedAlarm, after date: Date) -> Date? {
    let calendar = Calendar.autoupdatingCurrent
    if alarm.days.isEmpty {
      return calendar.nextDate(
        after: date, matching: DateComponents(hour: alarm.hour, minute: alarm.minute, second: 0),
        matchingPolicy: .nextTimePreservingSmallerComponents
      )
    }
    return alarm.days.compactMap { day in
      calendar.nextDate(
        after: date,
        matching: DateComponents(hour: alarm.hour, minute: alarm.minute, second: 0, weekday: day % 7 + 1),
        matchingPolicy: .nextTimePreservingSmallerComponents
      )
    }.min()
  }

  private func activeID(for alarm: SavedAlarm) throws -> UUID? {
    try manager.alarms.first {
      $0.state == .alerting && alarm.systemIDs.contains($0.id)
    }?.id
  }

  private func cancelSystemAlarms(_ alarm: SavedAlarm) throws {
    if manager.authorizationState != .authorized { return }
    let registered = Set(try manager.alarms.map(\.id))
    for id in alarm.systemIDs where registered.contains(id) {
      try manager.cancel(id: id)
    }
  }

  private func change(_ mutation: () throws -> Void) throws {
    guard !changing else { throw AlarmFailure.busy }
    try mutation()
  }

  private func save(_ input: SavedAlarm, enabled: Bool) async throws {
    guard !changing else { throw AlarmFailure.busy }
    changing = true
    defer { changing = false }
    var records = try read()
    let previous = records.first { $0.id == input.id }
    var alarm = input

    if enabled {
      if manager.authorizationState == .notDetermined {
        _ = try await manager.requestAuthorization()
      }
      guard manager.authorizationState == .authorized else { throw AlarmFailure.permission }

      let weekdays: [Locale.Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
      ]
      let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
      let schedule: Alarm.Schedule
      if alarm.days.isEmpty {
        guard let next = nextOccurrence(for: alarm, after: Date()) else { throw AlarmFailure.invalid }
        alarm.oneTimeDate = next
        schedule = .fixed(next)
      } else {
        schedule = .relative(.init(time: time, repeats: .weekly(alarm.days.map { weekdays[$0 - 1] })))
      }
      let systemID = UUID()
      try await scheduleAlarm(id: systemID, schedule: schedule)
      alarm.scheduleID = systemID
    }
    do {
      if let previous { try cancelSystemAlarms(previous) }
      records.removeAll { $0.id == alarm.id }
      records.append(alarm)
      try write(records)
    } catch {
      if let id = alarm.scheduleID { try? manager.cancel(id: id) }
      throw error
    }
  }

  func snooze(systemID: UUID) async throws {
    guard !changing else { throw AlarmFailure.busy }
    changing = true
    defer { changing = false }
    var records = try read()
    guard let index = records.firstIndex(where: { $0.systemIDs.contains(systemID) }),
          try activeID(for: records[index]) == systemID else { return }

    let newID = UUID()
    let until = Date().addingTimeInterval(9 * 60)
    try await scheduleAlarm(id: newID, schedule: .fixed(until))
    do {
      // The alarm might have been dismissed on the system UI during scheduling.
      guard try activeID(for: records[index]) == systemID else {
        try manager.cancel(id: newID)
        return
      }
      if let otherSnooze = records[index].snoozeID, otherSnooze != systemID,
         try manager.alarms.contains(where: { $0.id == otherSnooze }) {
        try manager.cancel(id: otherSnooze)
      }
      // Stopping an alert leaves its recurring schedule intact.
      try manager.stop(id: systemID)
      records[index].snoozeID = newID
      records[index].snoozedUntil = until
      try write(records)
    } catch {
      try? manager.cancel(id: newID)
      throw error
    }
  }

  private func scheduleAlarm(id: UUID, schedule: Alarm.Schedule) async throws {
    let labels = UserDefaults.standard.dictionary(forKey: "restAlarmLabels") as? [String: String]
    func label(_ key: String, _ fallback: String) -> LocalizedStringResource {
      LocalizedStringResource(stringLiteral: labels?[key] ?? fallback)
    }
    let alert = AlarmPresentation.Alert(
      title: label("alarmTitle", "REST alarm"),
      stopButton: AlarmButton(text: label("stop", "Stop"), textColor: .white, systemImageName: "stop.circle"),
      secondaryButton: AlarmButton(text: label("snooze", "Snooze"), textColor: .white, systemImageName: "zzz"),
      secondaryButtonBehavior: .custom
    )
    let attributes = AlarmAttributes(
      presentation: AlarmPresentation(alert: alert),
      metadata: RestAlarmMetadata(),
      tintColor: .indigo
    )
    _ = try await manager.schedule(
      id: id,
      configuration: AlarmManager.AlarmConfiguration(
        schedule: schedule,
        attributes: attributes,
        secondaryIntent: RestSnoozeIntent(systemID: id),
        sound: .default
      )
    )
  }
}
#endif
