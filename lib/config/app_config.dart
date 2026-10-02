 import 'package:flutter/foundation.dart';

class AppConfig {
  static const String sampleAssetPath =
      'assets/images/sample_product_label.jpg';

  static const String sampleMissingMessage =
      'Sample product image not found. Add:\nassets/images/sample_product_label.jpg';

  // ====== Path B: Local-First Mobile Mode (no PC backend required!) ======
  //
  // Override with flutter build / run flag:
  //   --dart-define=GEMINI_API_KEY=AQ.xxxxxxxxxxxxxxxx
  // If empty string, fallback to the embedded default (same key as in
  // cyber_nova_backend/.env — so the APK works out of the box).
  static const String _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _embeddedDefaultKey = '';

  static String get geminiApiKey {
    if (_envGeminiKey.trim().isNotEmpty) return _envGeminiKey.trim();
    return _embeddedDefaultKey;
  }

  /// Which Gemini model to use. Supports override via --dart-define.
  /// Default gemini-3.6-flash has the strongest OCR / text-extraction
  /// capability for reading small MRP, net-quantity, and date fields.
  static const String _envModel = String.fromEnvironment('GEMINI_MODEL');
  static String get geminiModel {
    if (_envModel.trim().isNotEmpty) return _envModel.trim();
    return 'gemini-3.6-flash';
  }

  /// If true, the app uses local Path B services (Gemini REST + on-device
  /// rule engine) by default, and only falls back to PC backend if the
  /// local scan fails AND backend is healthy.
  static const bool preferLocalMode = true;

  // ====== Legacy PC Backend (kept as fallback / optional) ======
  /// Override with `--dart-define=BACKEND_URL=http://192.168.1.10:8000`
  static const String _envUrl = String.fromEnvironment('BACKEND_URL');

  static String backendBaseUrl = _envUrl.isNotEmpty
      ? _envUrl
      : _defaultBackendUrl();

  static String _defaultBackendUrl() {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  static String get scanEndpoint => '$backendBaseUrl/api/inspection/scan';
  static String get healthEndpoint => '$backendBaseUrl/api/health';
  static String get saveInspectionEndpoint => '$backendBaseUrl/api/inspection/save';
  static String listInspectionsEndpoint({int limit = 50}) =>
      '$backendBaseUrl/api/inspection/list?limit=$limit';
  static String getInspectionEndpoint(String reportId) =>
      '$backendBaseUrl/api/inspection/${Uri.encodeComponent(reportId)}';

  // ====== Google Gemini REST endpoint (Path B) ======
  static String get geminiV1GenerateContent =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${geminiModel}:generateContent?key=${geminiApiKey}';
}
