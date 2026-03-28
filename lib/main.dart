import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/local_cache_service.dart';
import 'core/services/convex_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cacheService = LocalCacheService();
  await cacheService.initialize();

  final convexService = ConvexService();
  final savedCookie = cacheService.getSetting<String>('session_cookie');
  if (savedCookie != null) {
    convexService.setSessionCookie(savedCookie);
  }

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        localCacheServiceProvider.overrideWithValue(cacheService),
        convexServiceProvider.overrideWithValue(convexService),
      ],
      child: const GastoTrackApp(),
    ),
  );
}
