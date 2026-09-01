#ifndef FLUTTER_PLUGIN_AWESOME_NOTIFICATIONS_PLUGIN_H_
#define FLUTTER_PLUGIN_AWESOME_NOTIFICATIONS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <map>
#include <string>

namespace awesome_notifications {

class AwesomeNotificationsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AwesomeNotificationsPlugin();

  virtual ~AwesomeNotificationsPlugin();

  // Disallow copy and assign.
  AwesomeNotificationsPlugin(const AwesomeNotificationsPlugin&) = delete;
  AwesomeNotificationsPlugin& operator=(const AwesomeNotificationsPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ShowNotification(const flutter::EncodableMap& model);
  void CancelNotification(int id, bool cancel_schedule, bool dismiss);
  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_ = nullptr;
  int badge_ = 0;
  std::string language_ = "en";
  std::map<int, flutter::EncodableMap> scheduled_;
  std::map<int, NOTIFYICONDATAW> active_;
};

}  // namespace awesome_notifications

#endif  // FLUTTER_PLUGIN_AWESOME_NOTIFICATIONS_PLUGIN_H_
