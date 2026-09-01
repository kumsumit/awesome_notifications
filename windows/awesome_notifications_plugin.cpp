#include "awesome_notifications_plugin.h"

#include <VersionHelpers.h>
#include <flutter/standard_method_codec.h>
#include <algorithm>
#include <chrono>
#include <sstream>

namespace awesome_notifications {
namespace {
constexpr wchar_t kWindowClass[] = L"AwesomeNotificationsHiddenWindow";
constexpr UINT kCallbackMessage = WM_APP + 41;

const flutter::EncodableValue* Get(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key)); return it == map.end() ? nullptr : &it->second;
}
const flutter::EncodableMap* Map(const flutter::EncodableValue* value) { return value ? std::get_if<flutter::EncodableMap>(value) : nullptr; }
std::string String(const flutter::EncodableMap& map, const char* key) { auto* value = Get(map, key); auto* string = value ? std::get_if<std::string>(value) : nullptr; return string ? *string : ""; }
int Int(const flutter::EncodableMap& map, const char* key) { auto* value = Get(map, key); if (!value) return 0; if (auto* v = std::get_if<int32_t>(value)) return *v; if (auto* v = std::get_if<int64_t>(value)) return static_cast<int>(*v); return 0; }
bool Bool(const flutter::EncodableMap& map, const char* key) { auto* value = Get(map, key); auto* boolean = value ? std::get_if<bool>(value) : nullptr; return boolean && *boolean; }
std::wstring Wide(const std::string& text) { if (text.empty()) return {}; int size = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0); std::wstring result(size, 0); MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, result.data(), size); result.pop_back(); return result; }
flutter::EncodableMap Event(const flutter::EncodableMap& content) { auto result = content; result[flutter::EncodableValue("createdSource")] = flutter::EncodableValue("Local"); result[flutter::EncodableValue("createdLifeCycle")] = flutter::EncodableValue("FOREGROUND"); result[flutter::EncodableValue("displayedLifeCycle")] = flutter::EncodableValue("FOREGROUND"); return result; }
}

void AwesomeNotificationsPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<AwesomeNotificationsPlugin>();
  plugin->channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(registrar->messenger(), "awesome_notifications", &flutter::StandardMethodCodec::GetInstance());
  plugin->channel_->SetMethodCallHandler([pointer = plugin.get()](const auto& call, auto result) { pointer->HandleMethodCall(call, std::move(result)); });
  registrar->AddPlugin(std::move(plugin));
}

AwesomeNotificationsPlugin::AwesomeNotificationsPlugin() {
  WNDCLASSW wc{}; wc.lpfnWndProc = WindowProc; wc.hInstance = GetModuleHandle(nullptr); wc.lpszClassName = kWindowClass; RegisterClassW(&wc);
  window_ = CreateWindowExW(0, kWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, wc.hInstance, this);
}
AwesomeNotificationsPlugin::~AwesomeNotificationsPlugin() { for (auto& item : active_) Shell_NotifyIconW(NIM_DELETE, &item.second); if (window_) DestroyWindow(window_); }

LRESULT CALLBACK AwesomeNotificationsPlugin::WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  auto* self = reinterpret_cast<AwesomeNotificationsPlugin*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (message == WM_NCCREATE) { self = static_cast<AwesomeNotificationsPlugin*>(reinterpret_cast<CREATESTRUCT*>(lparam)->lpCreateParams); SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self)); }
  if (!self) return DefWindowProc(hwnd, message, wparam, lparam);
  if (message == WM_TIMER) { auto it = self->scheduled_.find(static_cast<int>(wparam)); if (it != self->scheduled_.end()) { auto model = it->second; auto* schedule = Map(Get(model, "schedule")); bool repeats = schedule && Bool(*schedule, "repeats"); self->ShowNotification(model); if (!repeats) { self->scheduled_.erase(it); KillTimer(hwnd, wparam); } } return 0; }
  if (message == kCallbackMessage) { int id = static_cast<int>(wparam); auto active = self->active_.find(id); if (lparam == NIN_BALLOONUSERCLICK || lparam == WM_LBUTTONUP) { auto scheduled = self->scheduled_.find(id); flutter::EncodableMap event; if (scheduled != self->scheduled_.end()) if (auto* content = Map(Get(scheduled->second, "content"))) event = Event(*content); self->channel_->InvokeMethod("defaultAction", std::make_unique<flutter::EncodableValue>(event)); } if (lparam == NIN_BALLOONHIDE || lparam == NIN_BALLOONTIMEOUT) { if (active != self->active_.end()) { Shell_NotifyIconW(NIM_DELETE, &active->second); self->active_.erase(active); } } return 0; }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

void AwesomeNotificationsPlugin::ShowNotification(const flutter::EncodableMap& model) {
  auto* content = Map(Get(model, "content")); if (!content) return; int id = Int(*content, "id");
  NOTIFYICONDATAW data{}; data.cbSize = sizeof(data); data.hWnd = window_; data.uID = static_cast<UINT>(id); data.uFlags = NIF_INFO | NIF_MESSAGE | NIF_ICON; data.uCallbackMessage = kCallbackMessage; data.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
  auto title = Wide(String(*content, "title")), body = Wide(String(*content, "body")); wcsncpy_s(data.szInfoTitle, title.c_str(), _TRUNCATE); wcsncpy_s(data.szInfo, body.c_str(), _TRUNCATE); data.dwInfoFlags = NIIF_USER | NIIF_LARGE_ICON; data.uTimeout = 10000;
  auto old = active_.find(id); if (old != active_.end()) Shell_NotifyIconW(NIM_DELETE, &old->second); Shell_NotifyIconW(NIM_ADD, &data); active_[id] = data;
  channel_->InvokeMethod("notificationDisplayed", std::make_unique<flutter::EncodableValue>(Event(*content)));
}

void AwesomeNotificationsPlugin::CancelNotification(int id, bool schedule, bool delivered) { if (schedule) { KillTimer(window_, id); scheduled_.erase(id); } if (delivered) { auto it = active_.find(id); if (it != active_.end()) { Shell_NotifyIconW(NIM_DELETE, &it->second); active_.erase(it); } } }

void AwesomeNotificationsPlugin::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& name = call.method_name(); const auto* args = call.arguments();
  if (name == "getPlatformVersion") { std::ostringstream out; out << "Windows " << (IsWindows10OrGreater() ? "10+" : "8.1 or earlier"); result->Success(flutter::EncodableValue(out.str())); }
  else if (name == "initialize" || name == "setEventHandles") result->Success(flutter::EncodableValue(true));
  else if (name == "createNewNotification") { auto* model = Map(args); auto* content = model ? Map(Get(*model, "content")) : nullptr; if (!model || !content) { result->Error("INVALID_ARGUMENT", "content is required"); return; } channel_->InvokeMethod("notificationCreated", std::make_unique<flutter::EncodableValue>(Event(*content))); auto* schedule = Map(Get(*model, "schedule")); if (!schedule) ShowNotification(*model); else { int id = Int(*content, "id"), seconds = std::max(1, Int(*schedule, "interval")); scheduled_[id] = *model; SetTimer(window_, id, static_cast<UINT>(seconds * 1000), nullptr); } result->Success(flutter::EncodableValue(true)); }
  else if (name == "listAllSchedules") { flutter::EncodableList list; for (auto& item : scheduled_) list.emplace_back(item.second); result->Success(flutter::EncodableValue(list)); }
  else if (name == "getAllActiveNotificationIds") { flutter::EncodableList list; for (auto& item : active_) list.emplace_back(item.first); result->Success(flutter::EncodableValue(list)); }
  else if (name == "isNotificationActive") { int id = args && std::get_if<int32_t>(args) ? std::get<int32_t>(*args) : 0; result->Success(flutter::EncodableValue(active_.count(id) != 0)); }
  else if (name == "cancelSchedule" || name == "dismissNotification" || name == "cancelNotification") { int id = args && std::get_if<int32_t>(args) ? std::get<int32_t>(*args) : 0; CancelNotification(id, name != "dismissNotification", name != "cancelSchedule"); result->Success(); }
  else if (name == "cancelAllSchedules" || name == "cancelAllNotifications") { for (auto& item : scheduled_) KillTimer(window_, item.first); scheduled_.clear(); if (name == "cancelAllNotifications") { for (auto& item : active_) Shell_NotifyIconW(NIM_DELETE, &item.second); active_.clear(); } result->Success(); }
  else if (name == "dismissAllNotifications") { for (auto& item : active_) Shell_NotifyIconW(NIM_DELETE, &item.second); active_.clear(); result->Success(); }
  else if (name == "isNotificationAllowed") result->Success(flutter::EncodableValue(true));
  else if (name == "requestNotifications" || name == "checkPermissions" || name == "shouldShowRationale") result->Success(flutter::EncodableValue(flutter::EncodableList{}));
  else if (name == "getInitialAction" || name == "getDrawableData" || name == "getNextDate") result->Success();
  else if (name == "getBadgeCount") result->Success(flutter::EncodableValue(badge_));
  else if (name == "setBadgeCount") { badge_ = args && std::get_if<int32_t>(args) ? std::get<int32_t>(*args) : 0; result->Success(); }
  else if (name == "incBadgeCount") result->Success(flutter::EncodableValue(++badge_));
  else if (name == "decBadgeCount") result->Success(flutter::EncodableValue(badge_ = std::max(0, badge_ - 1)));
  else if (name == "resetBadge") { badge_ = 0; result->Success(); }
  else if (name == "getLocalTimeZoneIdentifier") result->Success(flutter::EncodableValue("local"));
  else if (name == "getUtcTimeZoneIdentifier") result->Success(flutter::EncodableValue("UTC"));
  else if (name == "getAppLifeCycle") result->Success(flutter::EncodableValue("FOREGROUND"));
  else if (name == "setLocalization") { if (args) if (auto* value = std::get_if<std::string>(args)) language_ = *value; result->Success(flutter::EncodableValue(true)); }
  else if (name == "getLocalization") result->Success(flutter::EncodableValue(language_));
  else if (name == "removeNotificationChannel") result->Success(flutter::EncodableValue(true));
  else if (name == "setNotificationChannel" || name == "showNotificationPage" || name == "showAlarmPage" || name == "showGlobalDndPage" || name.find("ByChannelKey") != std::string::npos || name.find("ByGroupKey") != std::string::npos) result->Success();
  else result->NotImplemented();
}
}  // namespace awesome_notifications
