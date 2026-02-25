class Env {
  static const String convexUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: 'https://blissful-basilisk-23.convex.cloud',
  );

  static const String convexSiteUrl = String.fromEnvironment(
    'CONVEX_SITE_URL',
    defaultValue: 'https://blissful-basilisk-23.convex.site',
  );
}
