/// Agora RTC configuration for real two-way video calling.
///
/// To configure your Agora App ID:
/// 1. Create a project at https://console.agora.io
/// 2. Pass it at compile/run time via:
///    `flutter run --dart-define=AGORA_APP_ID=YOUR_APP_ID`
///    or set the default in this file for your local environment.
class AgoraConfig {
  /// Agora App ID passed via --dart-define or fallback constant
  static const String appId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: 'aab8b72e693f4c6ea3b9e4a3b8d1b111',
  );

  /// Optional token if project has App Certificate enabled.
  /// If using Testing Mode (App ID only), token can remain empty string ''.
  static const String token = String.fromEnvironment(
    'AGORA_TOKEN',
    defaultValue: '',
  );

  /// Checks whether an App ID is properly configured.
  static bool get isConfigured => appId.isNotEmpty && appId != 'YOUR_AGORA_APP_ID';
}
