import 'dart:convert';

import '../definitions.dart';
import '../enumerators/notification_source.dart';

class PushProviderAdapter {
  static const int _maxNotificationId = 0x7FFFFFFF;

  const PushProviderAdapter._();

  static Map<String, dynamic> fromFirebaseMessage({
    required Map<String, dynamic> data,
    required String channelKey,
    int? id,
    String? title,
    String? body,
    String? imageUrl,
  }) {
    return _fromProviderData(
      data: data,
      channelKey: channelKey,
      source: NotificationSource.Firebase,
      id: id,
      title: title,
      body: body,
      imageUrl: imageUrl,
      bodyKeys: const ['body', 'message'],
      imageKeys: const [
        'bigPicture',
        'image',
        'imageUrl',
        'picture',
        'gcm.notification.image',
      ],
    );
  }

  static Map<String, dynamic> fromOneSignal({
    required Map<String, dynamic> additionalData,
    required String channelKey,
    int? id,
    String? title,
    String? body,
    String? imageUrl,
  }) {
    return _fromProviderData(
      data: additionalData,
      channelKey: channelKey,
      source: NotificationSource.OneSignal,
      id: id,
      title: title,
      body: body,
      imageUrl: imageUrl,
      bodyKeys: const ['body', 'alert', 'message'],
      imageKeys: const [
        'bigPicture',
        'largeIcon',
        'image',
        'imageUrl',
        'picture',
        'ios_attachments',
      ],
    );
  }

  static Map<String, dynamic> _fromProviderData({
    required Map<String, dynamic> data,
    required String channelKey,
    required NotificationSource source,
    required List<String> bodyKeys,
    required List<String> imageKeys,
    int? id,
    String? title,
    String? body,
    String? imageUrl,
  }) {
    final normalizedData = _decodeJsonValues(data);

    if (normalizedData[NOTIFICATION_CONTENT] is Map) {
      return _withProviderFallbacks(
        normalizedData,
        channelKey: channelKey,
        source: source,
        id: id,
        title: title,
        body: body,
        imageUrl: imageUrl,
      );
    }

    final content = <String, dynamic>{
      NOTIFICATION_ID:
          id ?? _readInt(normalizedData, const ['id', 'notificationId']),
      NOTIFICATION_CHANNEL_KEY:
          _readString(normalizedData, const [NOTIFICATION_CHANNEL_KEY]) ??
          channelKey,
      NOTIFICATION_TITLE: title ?? _readString(normalizedData, const ['title']),
      NOTIFICATION_BODY: body ?? _readString(normalizedData, bodyKeys),
      NOTIFICATION_BIG_PICTURE:
          imageUrl ?? _readString(normalizedData, imageKeys),
      NOTIFICATION_CREATED_SOURCE: source.name,
      NOTIFICATION_PAYLOAD: _payloadFromData(normalizedData),
    };

    content[NOTIFICATION_ID] ??= _fallbackId(content);
    content.removeWhere((_, value) => value == null);

    return {
      NOTIFICATION_CONTENT: content,
      if (normalizedData[NOTIFICATION_SCHEDULE] != null)
        NOTIFICATION_SCHEDULE: normalizedData[NOTIFICATION_SCHEDULE],
      if (normalizedData[NOTIFICATION_BUTTONS] != null)
        NOTIFICATION_BUTTONS: normalizedData[NOTIFICATION_BUTTONS],
      if (normalizedData[NOTIFICATION_LOCALIZATIONS] != null)
        NOTIFICATION_LOCALIZATIONS: normalizedData[NOTIFICATION_LOCALIZATIONS],
    };
  }

  static Map<String, dynamic> _withProviderFallbacks(
    Map<String, dynamic> data, {
    required String channelKey,
    required NotificationSource source,
    int? id,
    String? title,
    String? body,
    String? imageUrl,
  }) {
    final content = Map<String, dynamic>.from(
      data[NOTIFICATION_CONTENT] as Map,
    );

    content[NOTIFICATION_ID] ??= id ?? _fallbackId(content);
    content[NOTIFICATION_CHANNEL_KEY] ??= channelKey;
    content[NOTIFICATION_TITLE] ??= title;
    content[NOTIFICATION_BODY] ??= body;
    content[NOTIFICATION_BIG_PICTURE] ??= imageUrl;
    content[NOTIFICATION_CREATED_SOURCE] ??= source.name;
    content[NOTIFICATION_PAYLOAD] ??= _payloadFromData(data);
    content.removeWhere((_, value) => value == null);

    return {...data, NOTIFICATION_CONTENT: content};
  }

  static Map<String, dynamic> _decodeJsonValues(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _decodeJsonValue(value)));
  }

  static dynamic _decodeJsonValue(dynamic value) {
    if (value is! String) return value;

    final trimmed = value.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return value;

    try {
      return json.decode(trimmed);
    } catch (_) {
      return value;
    }
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value != null && value is! Map && value is! Iterable) {
        return value.toString();
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static int _fallbackId(Map<String, dynamic> content) {
    final rawId = Object.hash(
      content[NOTIFICATION_CHANNEL_KEY],
      content[NOTIFICATION_TITLE],
      content[NOTIFICATION_BODY],
      DateTime.now().millisecondsSinceEpoch,
    );
    return rawId.abs() % _maxNotificationId;
  }

  static Map<String, String?> _payloadFromData(Map<String, dynamic> data) {
    final payload = <String, String?>{};

    for (final entry in data.entries) {
      if (_reservedKeys.contains(entry.key)) continue;

      final value = entry.value;
      if (value == null || value is String) {
        payload[entry.key] = value;
      } else if (value is num || value is bool) {
        payload[entry.key] = value.toString();
      }
    }

    return payload;
  }

  static const Set<String> _reservedKeys = {
    NOTIFICATION_CONTENT,
    NOTIFICATION_SCHEDULE,
    NOTIFICATION_BUTTONS,
    NOTIFICATION_LOCALIZATIONS,
    NOTIFICATION_ID,
    'notificationId',
    NOTIFICATION_CHANNEL_KEY,
    NOTIFICATION_TITLE,
    NOTIFICATION_BODY,
    'alert',
    'message',
    NOTIFICATION_BIG_PICTURE,
    NOTIFICATION_LARGE_ICON,
    'image',
    'imageUrl',
    'picture',
    'ios_attachments',
    'gcm.notification.image',
  };
}
