import '../definitions.dart';
import '../enumerators/notification_layout.dart';
import '../enumerators/notification_play_state.dart';
import '../utils/assert_utils.dart';
import 'base_notification_content.dart';

/// Represents the content of a notification with customizable options.
/// If notification has no [body] or [title], it will only be created, but not displayed to the user (background notification).
class NotificationContent extends BaseNotificationContent {
  bool? _hideLargeIconOnExpand;
  int? _badge;
  Duration? _duration;
  NotificationPlayState? _playState;
  String? _ticker;
  double? _progress, _playbackSpeed;

  NotificationLayout? _notificationLayout;

  bool? _displayOnForeground;
  bool? _displayOnBackground;

  bool? _locked;
  bool? _requestPromotedOngoing;
  String? _shortCriticalText;

  /// Returns whether to hide the large icon when the notification is expanded.
  bool? get hideLargeIconOnExpand {
    return _hideLargeIconOnExpand;
  }

  /// Returns the progress value of the notification, if set.
  double? get progress {
    return _progress;
  }

  /// Returns the badge number for the notification.
  int? get badge {
    return _badge;
  }

  /// Returns the ticker text of the notification.
  String? get ticker {
    return _ticker;
  }

  /// Returns the layout type of the notification.
  NotificationLayout? get notificationLayout {
    return _notificationLayout;
  }

  /// Indicates whether the notification is displayed when the app is in the foreground.
  bool? get displayOnForeground {
    return _displayOnForeground;
  }

  /// Indicates whether the notification is displayed when the app is in the background.
  bool? get displayOnBackground {
    return _displayOnBackground;
  }

  /// Indicates whether the notification is locked.
  bool? get locked {
    return _locked;
  }

  /// Requests Android to promote this ongoing notification as a Live Update.
  ///
  /// Android only promotes eligible ongoing notifications and may still ignore
  /// the request when the user or OEM has disabled promoted notifications.
  bool? get requestPromotedOngoing {
    return _requestPromotedOngoing;
  }

  /// Short status text used by Android's promoted notification status chip.
  String? get shortCriticalText {
    return _shortCriticalText;
  }

  /// Returns the play media duration (media player).
  Duration? get duration {
    return _duration;
  }

  /// Returns the play state of the notification  (media player).
  NotificationPlayState? get playState {
    return _playState;
  }

  /// Returns the playback speed for notification (media player).
  double? get playbackSpeed {
    return _playbackSpeed;
  }

  /// Constructs a [NotificationContent] object with various customization options.
  NotificationContent({
    required int super.id,
    required String super.channelKey,
    super.title,
    super.body,
    super.titleLocKey,
    super.bodyLocKey,
    super.titleLocArgs,
    super.bodyLocArgs,
    super.groupKey,
    super.summary,
    super.icon,
    super.largeIcon,
    super.bigPicture,
    super.customSound,
    super.showWhen,
    super.wakeUpScreen,
    super.fullScreenIntent,
    super.criticalAlert,
    super.roundedLargeIcon,
    super.roundedBigPicture,
    super.autoDismissible,
    super.color,
    super.timeoutAfter,
    super.chronometer,
    super.backgroundColor,
    super.actionType,
    NotificationLayout this._notificationLayout = NotificationLayout.Default,
    super.payload,
    super.category,
    bool this._hideLargeIconOnExpand = false,
    bool this._locked = false,
    bool this._requestPromotedOngoing = false,
    this._shortCriticalText,
    this._progress,
    this._badge,
    this._ticker,
    bool this._displayOnForeground = true,
    bool this._displayOnBackground = true,
    this._duration,
    this._playState,
    this._playbackSpeed,
  });

  /// Creates a [NotificationContent] instance from a map of data.
  @override
  NotificationContent? fromMap(Map<String, dynamic> mapData) {
    super.fromMap(mapData);
    _hideLargeIconOnExpand = AwesomeAssertUtils.extractValue<bool>(
      NOTIFICATION_HIDE_LARGE_ICON_ON_EXPAND,
      mapData,
    );

    _progress = AwesomeAssertUtils.extractValue<double>(
      NOTIFICATION_PROGRESS,
      mapData,
    );
    _badge = AwesomeAssertUtils.extractValue<int>(NOTIFICATION_BADGE, mapData);
    _ticker = AwesomeAssertUtils.extractValue<String>(
      NOTIFICATION_TICKER,
      mapData,
    );
    _locked = AwesomeAssertUtils.extractValue<bool>(
      NOTIFICATION_LOCKED,
      mapData,
    );
    _requestPromotedOngoing = AwesomeAssertUtils.extractValue<bool>(
      NOTIFICATION_REQUEST_PROMOTED_ONGOING,
      mapData,
    );
    _shortCriticalText = AwesomeAssertUtils.extractValue<String>(
      NOTIFICATION_SHORT_CRITICAL_TEXT,
      mapData,
    );
    _duration = AwesomeAssertUtils.extractValue<Duration>(
      NOTIFICATION_DURATION,
      mapData,
    );
    _playState = NotificationPlayState.fromMap(
      mapData[NOTIFICATION_PLAY_STATE],
    );

    _playbackSpeed = AwesomeAssertUtils.extractValue<double>(
      NOTIFICATION_PLAYBACK_SPEED,
      mapData,
    );

    _notificationLayout = AwesomeAssertUtils.extractEnum<NotificationLayout>(
      NOTIFICATION_LAYOUT,
      mapData,
      NotificationLayout.values,
    );

    _displayOnForeground = AwesomeAssertUtils.extractValue<bool>(
      NOTIFICATION_DISPLAY_ON_FOREGROUND,
      mapData,
    );

    _displayOnBackground = AwesomeAssertUtils.extractValue<bool>(
      NOTIFICATION_DISPLAY_ON_BACKGROUND,
      mapData,
    );

    try {
      validate();
    } catch (e) {
      return null;
    }

    return this;
  }

  /// Converts the [NotificationContent] instance to a map.
  @override
  Map<String, dynamic> toMap() {
    Map<String, dynamic> dataMap = super.toMap();

    dataMap = dataMap
      ..addAll({
        NOTIFICATION_HIDE_LARGE_ICON_ON_EXPAND: _hideLargeIconOnExpand,
        NOTIFICATION_PROGRESS: _progress,
        NOTIFICATION_BADGE: _badge,
        NOTIFICATION_TICKER: _ticker,
        NOTIFICATION_LOCKED: _locked,
        NOTIFICATION_REQUEST_PROMOTED_ONGOING: _requestPromotedOngoing,
        NOTIFICATION_SHORT_CRITICAL_TEXT: _shortCriticalText,
        NOTIFICATION_LAYOUT: _notificationLayout?.name,
        NOTIFICATION_DISPLAY_ON_FOREGROUND: _displayOnForeground,
        NOTIFICATION_DISPLAY_ON_BACKGROUND: _displayOnBackground,
        NOTIFICATION_DURATION: _duration?.inSeconds,
        NOTIFICATION_PLAY_STATE: _playState?.toMap(),
        NOTIFICATION_PLAYBACK_SPEED: _playbackSpeed,
      });
    return dataMap;
  }

  /// Returns a string representation of the [NotificationContent] instance.
  @override
  String toString() {
    return toMap().toString().replaceAll(',', ',\n');
  }
}
