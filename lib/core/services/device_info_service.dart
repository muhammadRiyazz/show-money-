import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to provide platform and persistent device ID required by the login API.
/// Backend specification:
/// - email: User's email address (Required)
/// - password: User's password (Required)
/// - platform: Must be sent as "android" or "ios" (Required)
/// - device_id: Unique hardware ID fetched automatically by app (Required)
/// - device_name: Device model name (e.g. "Samsung Galaxy S22", defaults to "Unknown Mobile Device")
class DeviceInfoService {
  static const String _deviceIdKey = 'app_unique_device_id';

  /// Returns "ios" or "android" as strictly required by backend API:
  /// Must be sent as "android" or "ios"
  static String getPlatform() {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        return 'ios';
      }
    }
    return 'android';
  }

  /// Returns a persistent hardware/app installation unique ID.
  /// If not yet generated, creates a persistent unique ID and saves it to SharedPreferences.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      final random = math.Random();
      final part1 = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
      final part2 = random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final part3 = random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final part4 = random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      deviceId = 'dnd-$part1-$part2-$part3-$part4';
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  /// Returns the human-readable device model name.
  static String getDeviceName() {
    if (kIsWeb) return 'Web Browser Client';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android Mobile Device';
      case TargetPlatform.iOS:
        return 'iPhone / iOS Device';
      case TargetPlatform.windows:
        return 'Windows Desktop Client';
      case TargetPlatform.macOS:
        return 'macOS Desktop Client';
      case TargetPlatform.linux:
        return 'Linux Client';
      default:
        return 'Unknown Mobile Device';
    }
  }

  /// Builds the full login payload matching the updated backend requirements:
  /// - email (Required, String)
  /// - password (Required, String)
  /// - platform (Required, String: "android" or "ios")
  /// - device_id (Required, String)
  /// - device_name (Optional, String)
  static Future<Map<String, dynamic>> buildLoginPayload({
    required String email,
    required String password,
  }) async {
    final deviceId = await getDeviceId();
    return {
      'email': email.trim(),
      'password': password,
      'platform': getPlatform(),
      'device_id': deviceId,
      'device_name': getDeviceName(),
    };
  }
}
