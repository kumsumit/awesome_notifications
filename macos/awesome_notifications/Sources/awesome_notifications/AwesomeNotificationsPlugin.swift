import Cocoa
import FlutterMacOS
import UserNotifications

@available(macOS 10.14, *)
public final class AwesomeNotificationsPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private var channel: FlutterMethodChannel?
  private var initialAction: [String: Any]?
  private var channels: [String: [String: Any]] = [:]
  private var language = Locale.current.languageCode ?? "en"
  private let schedulesKey = "awesome_notifications.schedules"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "awesome_notifications", binaryMessenger: registrar.messenger)
    let plugin = AwesomeNotificationsPlugin(); plugin.channel = channel; plugin.center.delegate = plugin
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion": result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "initialize":
      let values = (call.arguments as? [String: Any])?["initializeChannels"] as? [[String: Any]] ?? []
      values.forEach { if let key = $0["channelKey"] as? String { channels[key] = $0 } }; result(true)
    case "setEventHandles": result(true)
    case "createNewNotification": create(call.arguments, result)
    case "isNotificationAllowed": center.getNotificationSettings { result($0.authorizationStatus == .authorized || $0.authorizationStatus == .provisional) }
    case "requestNotifications": center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in result(ok ? [] : ["Alert", "Sound", "Badge"]) }
    case "checkPermissions": center.getNotificationSettings { settings in result(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional ? [] : (((call.arguments as? [String: Any])?["permissions"] as? [String]) ?? [])) }
    case "shouldShowRationale": result([])
    case "getInitialAction": result(initialAction); if call.arguments as? Bool == true { initialAction = nil }
    case "listAllSchedules": result(Array(loadSchedules().values))
    case "isNotificationActive": activeIds { result($0.contains(call.arguments as? Int ?? 0)) }
    case "getAllActiveNotificationIds": activeIds { result($0) }
    case "dismissNotification", "cancelNotification": remove(call.arguments as? Int, true, true); result(nil)
    case "cancelSchedule": remove(call.arguments as? Int, true, false); result(nil)
    case "dismissAllNotifications": center.removeAllDeliveredNotifications(); result(nil)
    case "cancelAllSchedules": center.removeAllPendingNotificationRequests(); saveSchedules([:]); result(nil)
    case "cancelAllNotifications": center.removeAllDeliveredNotifications(); center.removeAllPendingNotificationRequests(); saveSchedules([:]); result(nil)
    case "dismissNotificationsByChannelKey": removeMatching(call.arguments as? String, "channelKey", false, true); result(nil)
    case "cancelSchedulesByChannelKey": removeMatching(call.arguments as? String, "channelKey", true, false); result(nil)
    case "cancelNotificationsByChannelKey": removeMatching(call.arguments as? String, "channelKey", true, true); result(nil)
    case "dismissNotificationsByGroupKey": removeMatching(call.arguments as? String, "groupKey", false, true); result(nil)
    case "cancelSchedulesByGroupKey": removeMatching(call.arguments as? String, "groupKey", true, false); result(nil)
    case "cancelNotificationsByGroupKey": removeMatching(call.arguments as? String, "groupKey", true, true); result(nil)
    case "setNotificationChannel": if let value = call.arguments as? [String: Any], let key = value["channelKey"] as? String { channels[key] = value }; result(nil)
    case "removeNotificationChannel": result(channels.removeValue(forKey: call.arguments as? String ?? "") != nil)
    case "getBadgeCount": result(badge())
    case "setBadgeCount": setBadge(call.arguments as? Int ?? 0); result(nil)
    case "incBadgeCount": let n = badge() + 1; setBadge(n); result(n)
    case "decBadgeCount": let n = max(0, badge() - 1); setBadge(n); result(n)
    case "resetBadge": setBadge(0); result(nil)
    case "getLocalTimeZoneIdentifier": result(TimeZone.current.identifier)
    case "getUtcTimeZoneIdentifier": result("UTC")
    case "getAppLifeCycle": result(NSApplication.shared.isActive ? "FOREGROUND" : "BACKGROUND")
    case "setLocalization": language = call.arguments as? String ?? Locale.current.languageCode ?? "en"; result(true)
    case "getLocalization": result(language)
    case "getDrawableData": drawable(call.arguments as? String, result)
    case "getNextDate": result(nextDate(call.arguments))
    case "showNotificationPage": if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") { NSWorkspace.shared.open(url) }; result(nil)
    case "showAlarmPage", "showGlobalDndPage": result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func create(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard let model = arguments as? [String: Any], let value = model["content"] as? [String: Any], let id = value["id"] as? Int else { result(FlutterError(code: "INVALID_ARGUMENT", message: "content.id is required", details: nil)); return }
    let content = UNMutableNotificationContent(); content.title = value["title"] as? String ?? ""; content.body = value["body"] as? String ?? ""; content.subtitle = value["summary"] as? String ?? ""; content.userInfo = model
    content.sound = (value["customSound"] as? String).map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
    configureActions(model, content, id)
    let trigger = makeTrigger(model["schedule"] as? [String: Any]); emit("notificationCreated", event(value))
    center.add(UNNotificationRequest(identifier: String(id), content: content, trigger: trigger)) { error in
      if let error = error { result(FlutterError(code: "NOTIFICATION_ERROR", message: error.localizedDescription, details: nil)); return }
      if trigger != nil { var saved = self.loadSchedules(); saved[String(id)] = model; self.saveSchedules(saved) }; result(true)
    }
  }

  private func makeTrigger(_ schedule: [String: Any]?) -> UNNotificationTrigger? {
    guard let schedule = schedule else { return nil }; let repeats = schedule["repeats"] as? Bool ?? false
    if let seconds = (schedule["interval"] as? NSNumber)?.doubleValue { return UNTimeIntervalNotificationTrigger(timeInterval: max(repeats ? 60 : 1, seconds), repeats: repeats) }
    var c = DateComponents(); c.timeZone = TimeZone(identifier: schedule["timeZone"] as? String ?? TimeZone.current.identifier); c.year = schedule["year"] as? Int; c.month = schedule["month"] as? Int; c.day = schedule["day"] as? Int; c.hour = schedule["hour"] as? Int; c.minute = schedule["minute"] as? Int; c.second = schedule["second"] as? Int
    if let weekday = schedule["weekday"] as? Int { c.weekday = weekday == 7 ? 1 : weekday + 1 }; return UNCalendarNotificationTrigger(dateMatching: c, repeats: repeats)
  }

  private func configureActions(_ model: [String: Any], _ content: UNMutableNotificationContent, _ id: Int) {
    let buttons = model["actionButtons"] as? [[String: Any]] ?? []; if buttons.isEmpty { return }
    let actions: [UNNotificationAction] = buttons.compactMap { b in guard b["enabled"] as? Bool ?? true else { return nil }; let key = b["key"] as? String ?? UUID().uuidString, title = b["label"] as? String ?? key; var options: UNNotificationActionOptions = []; if b["isDangerousOption"] as? Bool == true { options.insert(.destructive) }; if b["isAuthenticationRequired"] as? Bool == true { options.insert(.authenticationRequired) }; return b["requireInputText"] as? Bool == true ? UNTextInputNotificationAction(identifier: key, title: title, options: options) : UNNotificationAction(identifier: key, title: title, options: options) }
    let name = "awesome_notifications.\(id)"; center.setNotificationCategories([UNNotificationCategory(identifier: name, actions: actions, intentIdentifiers: [], options: [])]); content.categoryIdentifier = name
  }

  public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) { let value = (notification.request.content.userInfo["content"] as? [String: Any]) ?? [:]; emit("notificationDisplayed", event(value)); done([.alert, .sound, .badge]) }
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler done: @escaping () -> Void) { var value = (response.notification.request.content.userInfo["content"] as? [String: Any]) ?? [:]; value["buttonKeyPressed"] = response.actionIdentifier == UNNotificationDefaultActionIdentifier ? nil : response.actionIdentifier; value["buttonKeyInput"] = (response as? UNTextInputNotificationResponse)?.userText; value["actionDate"] = dateString(Date()); value["actionLifeCycle"] = NSApplication.shared.isActive ? "FOREGROUND" : "BACKGROUND"; initialAction = value; emit("defaultAction", value); done() }

  private func activeIds(_ done: @escaping ([Int]) -> Void) { center.getDeliveredNotifications { done($0.compactMap { Int($0.request.identifier) }) } }
  private func remove(_ id: Int?, _ pending: Bool, _ delivered: Bool) { guard let id = id else { return }; let key = String(id); if pending { center.removePendingNotificationRequests(withIdentifiers: [key]); var saved = loadSchedules(); saved.removeValue(forKey: key); saveSchedules(saved) }; if delivered { center.removeDeliveredNotifications(withIdentifiers: [key]) } }
  private func removeMatching(_ value: String?, _ field: String, _ pending: Bool, _ delivered: Bool) { let saved = loadSchedules(), ids = saved.compactMap { ((($0.value["content"] as? [String: Any])?[field] as? String) == value) ? $0.key : nil }; if pending { center.removePendingNotificationRequests(withIdentifiers: ids); var next = saved; ids.forEach { next.removeValue(forKey: $0) }; saveSchedules(next) }; if delivered { center.removeDeliveredNotifications(withIdentifiers: ids) } }
  private func badge() -> Int { NSApplication.shared.dockTile.badgeLabel.flatMap(Int.init) ?? 0 }; private func setBadge(_ n: Int) { NSApplication.shared.dockTile.badgeLabel = n > 0 ? String(n) : nil }
  private func emit(_ name: String, _ value: [String: Any]) { DispatchQueue.main.async { self.channel?.invokeMethod(name, arguments: value) } }
  private func event(_ original: [String: Any]) -> [String: Any] { var v = original; let life = NSApplication.shared.isActive ? "FOREGROUND" : "BACKGROUND"; v["createdSource"] = "Local"; v["createdLifeCycle"] = life; v["displayedLifeCycle"] = life; v["createdDate"] = dateString(Date()); v["displayedDate"] = dateString(Date()); return v }
  private func dateString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; f.timeZone = TimeZone(secondsFromGMT: 0); return f.string(from: date) }
  private func nextDate(_ arguments: Any?) -> String? { guard let schedule = (arguments as? [String: Any])?["schedule"] as? [String: Any] else { return nil }; if let seconds = (schedule["interval"] as? NSNumber)?.doubleValue { return dateString(Date().addingTimeInterval(seconds)) }; return (makeTrigger(schedule) as? UNCalendarNotificationTrigger)?.nextTriggerDate().map(dateString) }
  private func loadSchedules() -> [String: [String: Any]] { guard let data = UserDefaults.standard.data(forKey: schedulesKey), let value = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return [:] }; return value }; private func saveSchedules(_ value: [String: [String: Any]]) { if let data = try? JSONSerialization.data(withJSONObject: value) { UserDefaults.standard.set(data, forKey: schedulesKey) } }
  private func drawable(_ path: String?, _ result: FlutterResult) { guard let name = path?.replacingOccurrences(of: "resource://", with: ""), let url = Bundle.main.url(forResource: name, withExtension: nil), let data = try? Data(contentsOf: url) else { result(nil); return }; result(FlutterStandardTypedData(bytes: data)) }
}

