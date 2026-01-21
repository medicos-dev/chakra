import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // 1. Create the notification channel (CRITICAL for Android 13+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chakra_vpn_notification', // id
    'Chakra VPN Service', // title
    description: 'This channel is used for VPN status.', // description
    importance: Importance.low, // low so it doesn't make noise every time
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Prevent crash on boot/init
      isForegroundMode: true,
      notificationChannelId: 'chakra_vpn_notification',
      initialNotificationTitle: 'Chakra is connecting',
      initialNotificationContent: 'Setting up secure tunnel...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('updateNotification').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: event?['title'] ?? 'Chakra VPN',
        content: event?['content'] ?? 'Protected',
      );
    }
  });

  // Ensure initial notification is set
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Chakra VPN",
      content: "Chakra is protecting you",
    );
  }
}
