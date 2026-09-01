#include "include/awesome_notifications/awesome_notifications_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <cstring>
#include <ctime>
#include <map>
#include <string>

#define AWESOME_NOTIFICATIONS_PLUGIN(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), awesome_notifications_plugin_get_type(), AwesomeNotificationsPlugin))

struct _AwesomeNotificationsPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
  GApplication* application;
  GHashTable* models;
  GHashTable* timers;
  gint badge;
  gchar* language;
};
G_DEFINE_TYPE(AwesomeNotificationsPlugin, awesome_notifications_plugin, g_object_get_type())

static FlValue* lookup(FlValue* map, const char* key) { return map && fl_value_get_type(map) == FL_VALUE_TYPE_MAP ? fl_value_lookup_string(map, key) : nullptr; }
static const gchar* string_value(FlValue* map, const char* key, const gchar* fallback = "") { FlValue* v = lookup(map, key); return v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING ? fl_value_get_string(v) : fallback; }
static gint64 int_value(FlValue* map, const char* key, gint64 fallback = 0) { FlValue* v = lookup(map, key); return v && fl_value_get_type(v) == FL_VALUE_TYPE_INT ? fl_value_get_int(v) : fallback; }
static bool bool_value(FlValue* map, const char* key, bool fallback = false) { FlValue* v = lookup(map, key); return v && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL ? fl_value_get_bool(v) : fallback; }
static FlMethodResponse* success(FlValue* value = nullptr) { return FL_METHOD_RESPONSE(fl_method_success_response_new(value)); }

static FlValue* event_content(FlValue* content) {
  FlValue* event = fl_value_new_map();
  if (content && fl_value_get_type(content) == FL_VALUE_TYPE_MAP) for (size_t i = 0; i < fl_value_get_length(content); ++i) fl_value_set_take(event, fl_value_ref(fl_value_get_map_key(content, i)), fl_value_ref(fl_value_get_map_value(content, i)));
  fl_value_set_string_take(event, "createdSource", fl_value_new_string("Local"));
  fl_value_set_string_take(event, "createdLifeCycle", fl_value_new_string("FOREGROUND"));
  fl_value_set_string_take(event, "displayedLifeCycle", fl_value_new_string("FOREGROUND"));
  return event;
}

static void emit(AwesomeNotificationsPlugin* self, const char* method, FlValue* content) {
  g_autoptr(FlValue) event = event_content(content);
  fl_method_channel_invoke_method(self->channel, method, event, nullptr, nullptr, nullptr);
}

static void display(AwesomeNotificationsPlugin* self, FlValue* model) {
  FlValue* content = lookup(model, "content"); if (!content) return;
  gint64 id = int_value(content, "id");
  GNotification* notification = g_notification_new(string_value(content, "title"));
  g_notification_set_body(notification, string_value(content, "body"));
  const gchar* icon_path = string_value(content, "icon", nullptr);
  if (icon_path && g_str_has_prefix(icon_path, "file://")) { g_autoptr(GFile) file = g_file_new_for_uri(icon_path); g_autoptr(GIcon) icon = g_file_icon_new(file); g_notification_set_icon(notification, icon); }
  FlValue* buttons = lookup(model, "actionButtons");
  if (buttons && fl_value_get_type(buttons) == FL_VALUE_TYPE_LIST) for (size_t i = 0; i < fl_value_get_length(buttons); ++i) { FlValue* b = fl_value_get_list_value(buttons, i); if (bool_value(b, "enabled", true)) g_notification_add_button(notification, string_value(b, "label", string_value(b, "key")), "app.awesome-notification"); }
  if (self->application) g_application_send_notification(self->application, std::to_string(id).c_str(), notification);
  g_object_unref(notification); emit(self, "notificationDisplayed", content);
}

struct TimerData { AwesomeNotificationsPlugin* plugin; FlValue* model; gint id; bool repeats; };
static gboolean timer_cb(gpointer data) { TimerData* timer = static_cast<TimerData*>(data); display(timer->plugin, timer->model); if (!timer->repeats) { g_hash_table_remove(timer->plugin->models, GINT_TO_POINTER(timer->id)); g_hash_table_remove(timer->plugin->timers, GINT_TO_POINTER(timer->id)); } return timer->repeats ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE; }
static void timer_free(gpointer data) { TimerData* timer = static_cast<TimerData*>(data); fl_value_unref(timer->model); g_object_unref(timer->plugin); delete timer; }

static void cancel_id(AwesomeNotificationsPlugin* self, gint id, bool pending, bool delivered) {
  if (pending) { gpointer timer = g_hash_table_lookup(self->timers, GINT_TO_POINTER(id)); if (timer) g_source_remove(GPOINTER_TO_UINT(timer)); g_hash_table_remove(self->timers, GINT_TO_POINTER(id)); g_hash_table_remove(self->models, GINT_TO_POINTER(id)); }
  if (delivered && self->application) g_application_withdraw_notification(self->application, std::to_string(id).c_str());
}

static void handle(AwesomeNotificationsPlugin* self, FlMethodCall* call) {
  const gchar* method = fl_method_call_get_name(call); FlValue* args = fl_method_call_get_args(call); g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "getPlatformVersion") == 0) { struct utsname u = {}; uname(&u); g_autofree gchar* version = g_strdup_printf("Linux %s", u.release); response = success(fl_value_new_string(version)); }
  else if (strcmp(method, "initialize") == 0 || strcmp(method, "setEventHandles") == 0) response = success(fl_value_new_bool(true));
  else if (strcmp(method, "createNewNotification") == 0) {
    FlValue* content = lookup(args, "content"); gint id = static_cast<gint>(int_value(content, "id")); emit(self, "notificationCreated", content); FlValue* schedule = lookup(args, "schedule");
    if (!schedule) display(self, args); else { gint64 seconds = int_value(schedule, "interval", 0); if (seconds <= 0) seconds = 1; bool repeats = bool_value(schedule, "repeats"); TimerData* data = new TimerData{AWESOME_NOTIFICATIONS_PLUGIN(g_object_ref(self)), fl_value_ref(args), id, repeats}; guint source = g_timeout_add_seconds_full(G_PRIORITY_DEFAULT, static_cast<guint>(seconds), timer_cb, data, timer_free); g_hash_table_insert(self->models, GINT_TO_POINTER(id), fl_value_ref(args)); g_hash_table_insert(self->timers, GINT_TO_POINTER(id), GUINT_TO_POINTER(source)); }
    response = success(fl_value_new_bool(true));
  } else if (strcmp(method, "listAllSchedules") == 0) { FlValue* list = fl_value_new_list(); GHashTableIter iter; gpointer value; g_hash_table_iter_init(&iter, self->models); while (g_hash_table_iter_next(&iter, nullptr, &value)) fl_value_append_take(list, fl_value_ref(static_cast<FlValue*>(value))); response = success(list); }
  else if (strcmp(method, "cancelSchedule") == 0 || strcmp(method, "dismissNotification") == 0 || strcmp(method, "cancelNotification") == 0) { cancel_id(self, static_cast<gint>(fl_value_get_int(args)), strcmp(method, "dismissNotification") != 0, strcmp(method, "cancelSchedule") != 0); response = success(); }
  else if (strcmp(method, "cancelAllSchedules") == 0 || strcmp(method, "cancelAllNotifications") == 0) { GHashTableIter iter; gpointer key; g_hash_table_iter_init(&iter, self->timers); while (g_hash_table_iter_next(&iter, &key, nullptr)) g_source_remove(GPOINTER_TO_UINT(g_hash_table_lookup(self->timers, key))); g_hash_table_remove_all(self->timers); g_hash_table_remove_all(self->models); if (strcmp(method, "cancelAllNotifications") == 0 && self->application) g_application_withdraw_notification(self->application, nullptr); response = success(); }
  else if (strcmp(method, "dismissAllNotifications") == 0) { if (self->application) g_application_withdraw_notification(self->application, nullptr); response = success(); }
  else if (strcmp(method, "getAllActiveNotificationIds") == 0) { response = success(fl_value_new_list()); }
  else if (strcmp(method, "isNotificationActive") == 0) response = success(fl_value_new_bool(false));
  else if (strcmp(method, "isNotificationAllowed") == 0) response = success(fl_value_new_bool(self->application != nullptr));
  else if (strcmp(method, "requestNotifications") == 0 || strcmp(method, "checkPermissions") == 0 || strcmp(method, "shouldShowRationale") == 0) response = success(fl_value_new_list());
  else if (strcmp(method, "getInitialAction") == 0) response = success();
  else if (strcmp(method, "getBadgeCount") == 0) response = success(fl_value_new_int(self->badge));
  else if (strcmp(method, "setBadgeCount") == 0) { self->badge = args && fl_value_get_type(args) == FL_VALUE_TYPE_INT ? fl_value_get_int(args) : 0; response = success(); }
  else if (strcmp(method, "incBadgeCount") == 0) response = success(fl_value_new_int(++self->badge));
  else if (strcmp(method, "decBadgeCount") == 0) { self->badge = MAX(0, self->badge - 1); response = success(fl_value_new_int(self->badge)); }
  else if (strcmp(method, "resetBadge") == 0) { self->badge = 0; response = success(); }
  else if (strcmp(method, "getLocalTimeZoneIdentifier") == 0) { g_autoptr(GTimeZone) zone = g_time_zone_new_local(); response = success(fl_value_new_string(g_time_zone_get_identifier(zone))); }
  else if (strcmp(method, "getUtcTimeZoneIdentifier") == 0) response = success(fl_value_new_string("UTC"));
  else if (strcmp(method, "getAppLifeCycle") == 0) response = success(fl_value_new_string("FOREGROUND"));
  else if (strcmp(method, "setLocalization") == 0) { g_free(self->language); self->language = g_strdup(args && fl_value_get_type(args) == FL_VALUE_TYPE_STRING ? fl_value_get_string(args) : "en"); response = success(fl_value_new_bool(true)); }
  else if (strcmp(method, "getLocalization") == 0) response = success(fl_value_new_string(self->language));
  else if (strcmp(method, "setNotificationChannel") == 0 || strcmp(method, "showNotificationPage") == 0 || strcmp(method, "showAlarmPage") == 0 || strcmp(method, "showGlobalDndPage") == 0) response = success();
  else if (strcmp(method, "removeNotificationChannel") == 0) response = success(fl_value_new_bool(true));
  else if (strcmp(method, "getDrawableData") == 0 || strcmp(method, "getNextDate") == 0) response = success();
  else if (strstr(method, "ByChannelKey") || strstr(method, "ByGroupKey")) response = success();
  else response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(call, response, nullptr);
}

static void dispose(GObject* object) { auto* self = AWESOME_NOTIFICATIONS_PLUGIN(object); g_clear_object(&self->channel); g_clear_object(&self->application); g_clear_pointer(&self->models, g_hash_table_unref); g_clear_pointer(&self->timers, g_hash_table_unref); g_clear_pointer(&self->language, g_free); G_OBJECT_CLASS(awesome_notifications_plugin_parent_class)->dispose(object); }
static void awesome_notifications_plugin_class_init(AwesomeNotificationsPluginClass* klass) { G_OBJECT_CLASS(klass)->dispose = dispose; }
static void awesome_notifications_plugin_init(AwesomeNotificationsPlugin* self) { self->models = g_hash_table_new_full(g_direct_hash, g_direct_equal, nullptr, reinterpret_cast<GDestroyNotify>(fl_value_unref)); self->timers = g_hash_table_new(g_direct_hash, g_direct_equal); self->badge = 0; self->language = g_strdup("en"); GApplication* app = g_application_get_default(); self->application = app ? G_APPLICATION(g_object_ref(app)) : nullptr; }
static void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer data) { handle(AWESOME_NOTIFICATIONS_PLUGIN(data), call); }
void awesome_notifications_plugin_register_with_registrar(FlPluginRegistrar* registrar) { auto* plugin = AWESOME_NOTIFICATIONS_PLUGIN(g_object_new(awesome_notifications_plugin_get_type(), nullptr)); g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new(); plugin->channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar), "awesome_notifications", FL_METHOD_CODEC(codec)); fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref); g_object_unref(plugin); }
