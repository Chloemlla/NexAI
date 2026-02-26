/// Build configuration injected at compile time
abstract final class BuildConfig {
  static const int versionCode = int.fromEnvironment(
    'nexai.code',
    defaultValue: 1,
  );

  static const String versionName = String.fromEnvironment(
    'nexai.name',
    defaultValue: 'SNAPSHOT',
  );

  static const int buildTime = int.fromEnvironment(
    'nexai.time',
    defaultValue: 0,
  );

  static const String commitHash = String.fromEnvironment(
    'nexai.hash',
    defaultValue: 'N/A',
  );

  static const String shortHash = String.fromEnvironment(
    'nexai.short',
    defaultValue: 'N/A',
  );

  static String get fullVersion => '$versionName+$versionCode';
}
