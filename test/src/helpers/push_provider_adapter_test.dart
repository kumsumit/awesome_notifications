import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushProviderAdapter', () {
    test('maps Firebase message data into an Awesome notification model', () {
      final mapped = PushProviderAdapter.fromFirebaseMessage(
        data: {
          'notificationId': '42',
          'title': 'Incoming order',
          'body': 'Tap to review',
          'imageUrl': 'https://example.com/order.png',
          'orderId': 123,
          'ignoredObject': {'nested': true},
        },
        channelKey: 'orders',
      );

      final model = NotificationModel().fromMap(mapped);

      expect(model, isNotNull);
      expect(model!.content!.id, 42);
      expect(model.content!.channelKey, 'orders');
      expect(model.content!.title, 'Incoming order');
      expect(model.content!.body, 'Tap to review');
      expect(model.content!.bigPicture, 'https://example.com/order.png');
      expect(model.content!.createdSource, NotificationSource.Firebase);
      expect(model.content!.payload, {'orderId': '123'});
    });

    test('preserves Awesome formatted Firebase payloads', () {
      final mapped = PushProviderAdapter.fromFirebaseMessage(
        data: {
          'content': json.encode({
            'id': 99,
            'channelKey': 'chat',
            'title': 'Chat message',
            'body': 'Hello',
          }),
          'actionButtons': json.encode([
            {'key': 'reply', 'label': 'Reply'},
          ]),
          'conversationId': 'abc',
        },
        channelKey: 'fallback',
      );

      final model = NotificationModel().fromMap(mapped);

      expect(model, isNotNull);
      expect(model!.content!.id, 99);
      expect(model.content!.channelKey, 'chat');
      expect(model.content!.createdSource, NotificationSource.Firebase);
      expect(model.actionButtons, hasLength(1));
      expect(model.actionButtons!.first.key, 'reply');
      expect(model.content!.payload, {'conversationId': 'abc'});
    });

    test(
      'maps OneSignal additional data into an Awesome notification model',
      () {
        final mapped = PushProviderAdapter.fromOneSignal(
          additionalData: {
            'notificationId': 7,
            'alert': 'Your delivery is nearby',
            'route': '/delivery',
            'priority': true,
          },
          channelKey: 'delivery',
          title: 'Delivery update',
        );

        final model = NotificationModel().fromMap(mapped);

        expect(model, isNotNull);
        expect(model!.content!.id, 7);
        expect(model.content!.title, 'Delivery update');
        expect(model.content!.body, 'Your delivery is nearby');
        expect(model.content!.createdSource, NotificationSource.OneSignal);
        expect(model.content!.payload, {
          'route': '/delivery',
          'priority': 'true',
        });
      },
    );
  });
}
