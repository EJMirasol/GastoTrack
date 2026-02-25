import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConvexService {
  static const String deploymentUrl =
      'https://blissful-basilisk-23.convex.cloud';

  Future<T?> query<T>(String name, Map<String, dynamic> args) async {
    return null;
  }

  Future<String?> mutation(String name, Map<String, dynamic> args) async {
    return null;
  }
}

final convexServiceProvider = Provider<ConvexService>((ref) {
  return ConvexService();
});
