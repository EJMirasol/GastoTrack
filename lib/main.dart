import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/local_cache_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cacheService = LocalCacheService();
  await cacheService.initialize();

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [localCacheServiceProvider.overrideWithValue(cacheService)],
      child: const GastoTrackApp(),
    ),
  );
}
