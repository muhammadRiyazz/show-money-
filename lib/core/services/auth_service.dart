import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agency_head/core/network/api_service.dart';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _rememberEmailKey = 'remember_login_email';

  /// Check if a user session exists in local storage
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userKey);
  }

  /// Get the currently logged-in user map normalized with direct fields (id, name, group_id, etc.)
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      try {
        final decoded = jsonDecode(userStr);
        if (decoded is Map<String, dynamic>) {
          // If stored object has a nested 'user' dictionary, unwrap it
          if (decoded['user'] is Map<String, dynamic>) {
            final flatUser = Map<String, dynamic>.from(decoded['user']);
            if (decoded['token'] != null && flatUser['token'] == null) {
              flatUser['token'] = decoded['token'];
            }
            return flatUser;
          }
          return decoded;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Get remembered email for pre-filling on login screen
  static Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberEmailKey);
  }

  /// Save or clear remembered email
  static Future<void> setRememberedEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email != null && email.trim().isNotEmpty) {
      await prefs.setString(_rememberEmailKey, email.trim());
    } else {
      await prefs.remove(_rememberEmailKey);
    }
  }

  /// Authenticate user credentials across unified, manager, or accounts endpoints
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim();
    _logAuthStep('🚀 [AuthService] Initiating login sequence for: $cleanEmail');

    try {
      Map<String, dynamic> response;

      // 1. First attempt unified login
      try {
        _logAuthStep('🌐 [AuthService] Step 1: Attempting POST api/login (Unified)...');
        response = await ApiService.login(cleanEmail, password);
        _logAuthStep('📥 [AuthService] Step 1 Response: status=${response['status']}, message=${response['message']}');
      } catch (e) {
        _logAuthStep('⚠️ [AuthService] Step 1 Error: $e. Falling back to manager_login...');
        response = await ApiService.managerLogin(cleanEmail, password);
        _logAuthStep('📥 [AuthService] Step 2 (Fallback) Response: status=${response['status']}, message=${response['message']}');
      }

      // 2. If status was false, also check manager_login as fallback
      if (response['status'] != true) {
        try {
          _logAuthStep('🔄 [AuthService] Unified returned status=false. Step 2: Attempting POST api/manager_login...');
          final mgrRes = await ApiService.managerLogin(cleanEmail, password);
          _logAuthStep('📥 [AuthService] manager_login Response: status=${mgrRes['status']}, message=${mgrRes['message']}');
          if (mgrRes['status'] == true) {
            response = mgrRes;
          }
        } catch (e) {
          _logAuthStep('⚠️ [AuthService] manager_login error: $e');
        }
      }

      // 3. If still false, check accounts_login as fallback
      if (response['status'] != true) {
        try {
          _logAuthStep('🔄 [AuthService] Step 3: Attempting POST api/accounts_login fallback...');
          final accRes = await ApiService.accountsLogin(cleanEmail, password);
          _logAuthStep('📥 [AuthService] accounts_login Response: status=${accRes['status']}, message=${accRes['message']}');
          if (accRes['status'] == true) {
            response = accRes;
          }
        } catch (e) {
          _logAuthStep('⚠️ [AuthService] accounts_login error: $e');
        }
      }

      // 4. On successful authentication, normalize and persist user session
      if (response['status'] == true) {
        Map<String, dynamic>? userMap;

        if (response['data'] is Map<String, dynamic>) {
          if (response['data']['user'] is Map<String, dynamic>) {
            userMap = Map<String, dynamic>.from(response['data']['user']);
            if (response['data']['token'] != null) {
              userMap['token'] = response['data']['token'];
            }
          } else {
            userMap = Map<String, dynamic>.from(response['data']);
          }
        } else if (response['user'] is Map<String, dynamic>) {
          userMap = Map<String, dynamic>.from(response['user']);
        }

        if (userMap != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, jsonEncode(userMap));

          final token = userMap['token'] ?? response['token'] ?? response['data']?['token'];
          if (token != null) {
            await prefs.setString(_tokenKey, token.toString());
          }

          _logAuthStep(
            '✅ [AuthService] Session successfully saved!\n'
            '   ID       : ${userMap['id']}\n'
            '   Name     : ${userMap['name']}\n'
            '   Email    : ${userMap['email']}\n'
            '   Group ID : ${userMap['group_id']} (${userMap['group_name'] ?? 'Role'})\n'
            '   Token    : ${token != null ? 'Present' : 'None'}',
          );
        }
      } else {
        _logAuthStep('❌ [AuthService] Authentication rejected: ${response['message']}');
      }

      return response;
    } catch (e, stack) {
      _logAuthStep('💥 [AuthService] Critical login failure: $e\n$stack');
      return {'status': false, 'message': 'Login failed: $e'};
    }
  }

  static void _logAuthStep(String message) {
    developer.log(message, name: 'AuthService');
    debugPrint(message);
  }

  /// Logout and clear saved session
  static Future<void> logout() async {
    _logAuthStep('🚪 [AuthService] User session logged out. Clearing local storage.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }

  /// Check if the currently logged-in user has permission to create sheets.
  /// Field Executives (group_id = 4) and Backend Staff (group_id = 5) with can_create_sheet == true,
  /// or Managers/Admins (group_id = 6 or 1).
  static Future<bool> canCreateSheet() async {
    final user = await getUser();
    if (user == null) return false;
    final can = user['can_create_sheet'];
    if (can == true || can == 1 || can == '1' || can == 'true') {
      return true;
    }
    final groupId = int.tryParse(user['group_id']?.toString() ?? '0') ?? 0;
    return groupId == 6 || groupId == 1 || groupId == 4 || groupId == 5;
  }
}
