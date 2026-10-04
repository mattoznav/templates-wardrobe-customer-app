import 'dart:io' show Platform;

/// Backend address. Override with `--dart-define=API_URL=https://shop.example.com/api`.
///
/// Without it, the app talks to the backend on this computer: the iOS simulator
/// reaches it at localhost, the Android emulator at 10.0.2.2.
String get apiUrl {
  const fromBuild = String.fromEnvironment('API_URL');
  if (fromBuild.isNotEmpty) return fromBuild;
  return Platform.isAndroid ? 'http://10.0.2.2:8001/api' : 'http://localhost:8001/api';
}

/// Shown on the Stripe payment sheet.
const merchantName = String.fromEnvironment('MERCHANT_NAME', defaultValue: 'Halden');
