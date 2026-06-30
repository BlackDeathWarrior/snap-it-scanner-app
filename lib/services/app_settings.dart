import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight wrapper over SharedPreferences for app settings.
/// Currently stores the optional Anthropic API key that enables the
/// "identify from photo" (Google-Lens-style) visual lookup.
class AppSettings {
  static const _kAnthropicKey = 'anthropic_api_key';

  Future<String?> getAnthropicKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kAnthropicKey);
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  Future<void> setAnthropicKey(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_kAnthropicKey);
    } else {
      await prefs.setString(_kAnthropicKey, value.trim());
    }
  }
}
