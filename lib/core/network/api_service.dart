import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:agency_head/core/services/device_info_service.dart';

class ApiService {
  static const String baseUrl = 'https://tictechnologies.in/stage/showmoney/api';

  // ==========================================
  // Comprehensive API Logging Helpers
  // ==========================================
  static void _logRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer();
    buffer.writeln('\n========================== [API REQUEST START] ==========================');
    buffer.writeln('🌐 METHOD: $method');
    buffer.writeln('🔗 URL: $url');
    buffer.writeln('🕒 TIME: $timestamp');
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('📋 HEADERS: ${jsonEncode(headers)}');
    }
    if (body != null) {
      buffer.writeln('📦 REQUEST PAYLOAD:');
      try {
        buffer.writeln(const JsonEncoder.withIndent('  ').convert(body));
      } catch (_) {
        buffer.writeln(body.toString());
      }
    }
    buffer.writeln('========================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.Request', time: DateTime.now());
    debugPrint(text);
  }

  static void _logResponse({
    required String method,
    required String url,
    required int statusCode,
    required int durationMs,
    required String responseBody,
  }) {
    final buffer = StringBuffer();
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '⚠️';

    buffer.writeln('\n========================== [API RESPONSE START] =========================');
    buffer.writeln('$icon STATUS: $statusCode');
    buffer.writeln('🌐 METHOD: $method');
    buffer.writeln('🔗 URL: $url');
    buffer.writeln('⏱ DURATION: ${durationMs}ms');
    buffer.writeln('📥 RESPONSE BODY:');
    try {
      final decoded = jsonDecode(responseBody);
      buffer.writeln(const JsonEncoder.withIndent('  ').convert(decoded));
    } catch (_) {
      buffer.writeln(responseBody);
    }
    buffer.writeln('========================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.Response', time: DateTime.now());
    debugPrint(text);
  }

  static void _logError({
    required String method,
    required String url,
    required int durationMs,
    required dynamic error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('\n=========================== [API ERROR START] ===========================');
    buffer.writeln('❌ FAILED: $method $url (⏱ ${durationMs}ms)');
    buffer.writeln('💥 EXCEPTION: $error');
    if (stackTrace != null) {
      buffer.writeln('🔍 STACKTRACE:\n$stackTrace');
    }
    buffer.writeln('========================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.Error', error: error, stackTrace: stackTrace, time: DateTime.now());
    debugPrint(text);
  }

  // ==========================================
  // Dedicated Logging for Authentication (Login Request & Response)
  // ==========================================
  static void _logAuthRequest({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) {
    final buffer = StringBuffer();
    final url = '$baseUrl/$endpoint';
    final maskedPassword = payload['password'] != null
        ? '•••••••• (${payload['password'].toString().length} chars)'
        : 'N/A';

    buffer.writeln('\n🔐 ===================== [LOGIN REQUEST START] =====================');
    buffer.writeln('📡 ACTION      : User Authentication');
    buffer.writeln('🌐 URL         : $url');
    buffer.writeln('🔌 ENDPOINT    : POST api/$endpoint');
    buffer.writeln('👤 EMAIL       : ${payload['email']}');
    buffer.writeln('🔒 PASSWORD    : $maskedPassword');
    buffer.writeln('📱 PLATFORM    : ${payload['platform']}');
    buffer.writeln('🆔 DEVICE ID   : ${payload['device_id']}');
    buffer.writeln('💻 DEVICE NAME : ${payload['device_name']}');
    buffer.writeln('🕒 TIMESTAMP   : ${DateTime.now().toIso8601String()}');
    buffer.writeln('📦 FULL JSON PAYLOAD:');
    try {
      buffer.writeln(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (_) {
      buffer.writeln(payload.toString());
    }
    buffer.writeln('====================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.Login.Request');
    debugPrint(text);
  }

  static void _logAuthResponse({
    required String endpoint,
    required Map<String, dynamic> response,
    int? durationMs,
  }) {
    final buffer = StringBuffer();
    final status = response['status'] == true;
    final icon = status ? '✅' : '❌';
    final message = response['message']?.toString() ?? 'No message returned';

    buffer.writeln('\n🔐 ===================== [LOGIN RESPONSE START] ====================');
    buffer.writeln('$icon STATUS       : ${status ? 'SUCCESS' : 'FAILED / REJECTED'}');
    buffer.writeln('🔌 ENDPOINT     : POST api/$endpoint');
    if (durationMs != null) {
      buffer.writeln('⏱️ DURATION     : ${durationMs}ms');
    }
    buffer.writeln('💬 MESSAGE      : $message');

    // Extract user info if present
    final user = response['data']?['user'] ?? response['data'] ?? response['user'];
    if (user is Map) {
      buffer.writeln('👤 USER ID      : ${user['id']}');
      buffer.writeln('📛 USER NAME    : ${user['name']}');
      buffer.writeln('👥 GROUP ID     : ${user['group_id']} (${user['group_name'] ?? 'Role'})');
      buffer.writeln('📧 USER EMAIL   : ${user['email']}');
      buffer.writeln('🔑 TOKEN        : ${user['token'] ?? response['data']?['token'] ?? response['token'] ?? 'None'}');
    }

    buffer.writeln('📦 FULL JSON RESPONSE:');
    try {
      buffer.writeln(const JsonEncoder.withIndent('  ').convert(response));
    } catch (_) {
      buffer.writeln(response.toString());
    }
    buffer.writeln('====================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.Login.Response');
    debugPrint(text);
  }

  // ==========================================
  // Dedicated Logging for Fetch Sheets & Fetch Leads
  // ==========================================
  static void _logFetchSheetsRequest({
    required int userId,
    int? groupId,
    String? role,
    required bool isManager,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('\n📊 ===================== [FETCH SHEETS REQUEST] =====================');
    buffer.writeln('👤 User ID   : $userId');
    buffer.writeln('👥 Group ID  : ${groupId ?? 'Not specified'}');
    buffer.writeln('🏷️ User Role : ${role ?? (isManager ? 'Manager' : 'Staff')}');
    buffer.writeln('📡 Target    : ${isManager ? 'POST api/get_all_sheets' : 'GET api/get_sheets?user_id=$userId${groupId != null ? '&group_id=$groupId' : ''}'}');
    buffer.writeln('🕒 Timestamp : ${DateTime.now().toIso8601String()}');
    buffer.writeln('====================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.FetchSheets');
    debugPrint(text);
  }

  static void _logFetchSheetsResponse({
    required bool success,
    required dynamic rawData,
    String? message,
  }) {
    final buffer = StringBuffer();
    final count = rawData is List ? rawData.length : (rawData is Map && rawData['sheets'] is List ? (rawData['sheets'] as List).length : 0);
    final icon = success ? '✅' : '❌';

    buffer.writeln('\n📊 ===================== [FETCH SHEETS RESPONSE] ====================');
    buffer.writeln('$icon STATUS       : ${success ? 'SUCCESS' : 'FAILED'}');
    buffer.writeln('🔢 TOTAL SHEETS   : $count');
    if (message != null) {
      buffer.writeln('💬 MESSAGE        : $message');
    }
    if (rawData is List && rawData.isNotEmpty) {
      buffer.writeln('📑 SHEETS LIST    :');
      for (int i = 0; i < rawData.length; i++) {
        final s = rawData[i];
        if (s is Map) {
          final id = s['id'] ?? s['sheet_id'] ?? 'N/A';
          final title = s['title'] ?? s['name'] ?? 'Untitled';
          final rows = s['total_rows'] ?? s['total_leads'] ?? '0';
          buffer.writeln('   #${i + 1} | ID: $id | "$title" | Leads: $rows');
        }
      }
    }
    buffer.writeln('====================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.FetchSheets');
    debugPrint(text);
  }

  static void _logFetchLeadsRequest({
    required int sheetId,
    required int userId,
    String? role,
    required String endpoint,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('\n🎯 ====================== [FETCH LEADS REQUEST] =====================');
    buffer.writeln('📑 Sheet ID   : $sheetId');
    buffer.writeln('👤 User ID    : $userId');
    buffer.writeln('🏷️ Role       : ${role ?? 'Not specified'}');
    buffer.writeln('📡 Endpoint   : $endpoint');
    buffer.writeln('🕒 Timestamp  : ${DateTime.now().toIso8601String()}');
    buffer.writeln('====================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.FetchLeads');
    debugPrint(text);
  }

  static void _logFetchLeadsResponse({
    required bool success,
    required int sheetId,
    Map<String, dynamic>? sheetData,
    String? message,
  }) {
    final buffer = StringBuffer();
    final icon = success ? '✅' : '❌';
    final title = sheetData?['title'] ?? 'Sheet #$sheetId';
    final rows = sheetData?['rows'] is List ? (sheetData!['rows'] as List) : <dynamic>[];
    final columns = sheetData?['columns'] is List ? (sheetData!['columns'] as List) : <dynamic>[];

    buffer.writeln('\n🎯 ===================== [FETCH LEADS RESPONSE] =====================');
    buffer.writeln('$icon STATUS       : ${success ? 'SUCCESS' : 'FAILED'}');
    buffer.writeln('📑 SHEET ID       : $sheetId ("$title")');
    buffer.writeln('👥 TOTAL LEADS    : ${rows.length}');
    buffer.writeln('📊 COLUMNS        : ${columns.length}');
    if (message != null) {
      buffer.writeln('💬 MESSAGE        : $message');
    }

    if (rows.isNotEmpty) {
      buffer.writeln('📋 SAMPLE LEADS PREVIEW (First ${rows.length > 5 ? 5 : rows.length}):');
      for (int i = 0; i < (rows.length > 5 ? 5 : rows.length); i++) {
        final r = rows[i];
        if (r is Map) {
          final rowId = r['id'] ?? r['row_id'] ?? 'N/A';
          final status = r['status'] ?? 'new';
          final leadName = r['lead_name'] ?? r['name'] ?? r['data']?['Student Name'] ?? r['data']?['Name'] ?? 'Lead #$rowId';
          buffer.writeln('   #${i + 1} | Row ID: $rowId | Lead: $leadName | Status: $status');
        }
      }
    }
    buffer.writeln('====================================================================\n');

    final text = buffer.toString();
    developer.log(text, name: 'ApiService.FetchLeads');
    debugPrint(text);
  }

  static Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final url = '$baseUrl/$endpoint';
    final headers = {'Content-Type': 'application/json'};
    final stopwatch = Stopwatch()..start();

    _logRequest(method: 'POST', url: url, headers: headers, body: body);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      stopwatch.stop();

      _logResponse(
        method: 'POST',
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        responseBody: response.body,
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'status': true, 'data': decoded};
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
        method: 'POST',
        url: url,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _postForm(String endpoint, Map<String, dynamic> body) async {
    final url = '$baseUrl/$endpoint';
    final formBody = body.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
    final stopwatch = Stopwatch()..start();

    _logRequest(method: 'POST (FORM)', url: url, headers: headers, body: formBody);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: formBody,
      );
      stopwatch.stop();

      _logResponse(
        method: 'POST (FORM)',
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        responseBody: response.body,
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'status': true, 'data': decoded};
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
        method: 'POST (FORM)',
        url: url,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _get(String endpoint) async {
    final url = '$baseUrl/$endpoint';
    final stopwatch = Stopwatch()..start();

    _logRequest(method: 'GET', url: url);

    try {
      final response = await http.get(Uri.parse(url));
      stopwatch.stop();

      _logResponse(
        method: 'GET',
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        responseBody: response.body,
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'status': true, 'data': decoded};
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
        method: 'GET',
        url: url,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==========================================
  // A. Authentication (Unified, Manager, Accounts Login)
  // ==========================================

  /// 1. Unified Login (For Field Executives, Backend Staff, Accounts, Manager)
  /// Endpoint: POST api/login
  /// Requires: email, password, platform ("android"|"ios"), device_id, device_name
  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? platform,
    String? deviceId,
    String? deviceName,
  }) async {
    final payload = await DeviceInfoService.buildLoginPayload(email: email, password: password);
    if (platform != null) payload['platform'] = platform;
    if (deviceId != null) payload['device_id'] = deviceId;
    if (deviceName != null) payload['device_name'] = deviceName;

    _logAuthRequest(endpoint: 'login', payload: payload);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _post('login', payload);
      stopwatch.stop();
      _logAuthResponse(endpoint: 'login', response: response, durationMs: stopwatch.elapsedMilliseconds);
      return response;
    } catch (e) {
      stopwatch.stop();
      _logAuthResponse(
        endpoint: 'login',
        response: {'status': false, 'message': 'HTTP or network exception: $e'},
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  /// 2. Manager Login (group_id = 6)
  /// Endpoint: POST api/manager_login
  /// Requires: email, password, platform ("android"|"ios"), device_id, device_name
  static Future<Map<String, dynamic>> managerLogin(
    String email,
    String password, {
    String? platform,
    String? deviceId,
    String? deviceName,
  }) async {
    final payload = await DeviceInfoService.buildLoginPayload(email: email, password: password);
    if (platform != null) payload['platform'] = platform;
    if (deviceId != null) payload['device_id'] = deviceId;
    if (deviceName != null) payload['device_name'] = deviceName;

    _logAuthRequest(endpoint: 'manager_login', payload: payload);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _post('manager_login', payload);
      stopwatch.stop();
      _logAuthResponse(endpoint: 'manager_login', response: response, durationMs: stopwatch.elapsedMilliseconds);
      return response;
    } catch (e) {
      stopwatch.stop();
      _logAuthResponse(
        endpoint: 'manager_login',
        response: {'status': false, 'message': 'HTTP or network exception: $e'},
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  /// 3. Accounts Login (group_id = 2)
  /// Endpoint: POST api/accounts_login
  /// Requires: email, password, platform ("android"|"ios"), device_id, device_name
  static Future<Map<String, dynamic>> accountsLogin(
    String email,
    String password, {
    String? platform,
    String? deviceId,
    String? deviceName,
  }) async {
    final payload = await DeviceInfoService.buildLoginPayload(email: email, password: password);
    if (platform != null) payload['platform'] = platform;
    if (deviceId != null) payload['device_id'] = deviceId;
    if (deviceName != null) payload['device_name'] = deviceName;

    _logAuthRequest(endpoint: 'accounts_login', payload: payload);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _post('accounts_login', payload);
      stopwatch.stop();
      _logAuthResponse(endpoint: 'accounts_login', response: response, durationMs: stopwatch.elapsedMilliseconds);
      return response;
    } catch (e) {
      stopwatch.stop();
      _logAuthResponse(
        endpoint: 'accounts_login',
        response: {'status': false, 'message': 'HTTP or network exception: $e'},
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  // ==========================================
  // B. Staff Management (Field Exec, Backend Staff)
  // ==========================================

  /// 1. Create Field Executive & Backend Staff
  /// Endpoint: POST api/create_staff
  /// Allowed group_id: 4 (Field Executive), 5 (Backend Staff)
  static Future<Map<String, dynamic>> createStaff({
    required String name,
    required String email,
    required String password,
    required int groupId,
  }) async {
    developer.log(
      'API [Staff] Create Staff: name=$name, email=$email, group_id=$groupId',
      name: 'ApiService.Staff',
    );
    return await _post('create_staff', {
      'name': name,
      'email': email,
      'password': password,
      'group_id': groupId,
    });
  }

  /// 2. Get Staff List with optional query filters
  /// Endpoint: GET api/get_staff
  /// Optional filters: ?group_id=4, ?group_id=5, ?status=1, ?status=0
  static Future<Map<String, dynamic>> getStaff({int? groupId, int? status}) async {
    developer.log(
      'API [Staff] Get Staff List: group_id=$groupId, status=$status',
      name: 'ApiService.Staff',
    );
    final queryParams = <String>[];
    if (groupId != null) queryParams.add('group_id=$groupId');
    if (status != null) queryParams.add('status=$status');

    final endpoint = queryParams.isNotEmpty
        ? 'get_staff?${queryParams.join('&')}'
        : 'get_staff';

    return await _get(endpoint);
  }

  /// 3. Get Single Staff Details
  /// Endpoint: GET api/get_staff_details?id={id}
  static Future<Map<String, dynamic>> getStaffDetails(int id) async {
    developer.log('API [Staff] Get Staff Details for id=$id', name: 'ApiService.Staff');
    return await _get('get_staff_details?id=$id');
  }

  /// 4. Deactivate / Activate Staff
  /// Endpoint: POST api/update_staff_status (or POST api/deactivate_staff)
  /// status: 0 = Deactivate, 1 = Activate
  static Future<Map<String, dynamic>> updateStaffStatus({
    required int id,
    int? status,
  }) async {
    developer.log(
      'API [Staff] Update Staff Status: id=$id, status=$status',
      name: 'ApiService.Staff',
    );
    final body = <String, dynamic>{'id': id};
    if (status != null) {
      body['status'] = status;
    }
    return await _post('update_staff_status', body);
  }

  /// 5. Update Staff Profile
  /// Endpoint: POST api/update_staff
  static Future<Map<String, dynamic>> updateStaff({
    required int id,
    String? name,
    String? email,
    String? password,
    int? groupId,
    int? status,
  }) async {
    developer.log(
      'API [Staff] Update Staff Profile: id=$id, name=$name, email=$email, group_id=$groupId, status=$status',
      name: 'ApiService.Staff',
    );
    final body = <String, dynamic>{'id': id};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (groupId != null) body['group_id'] = groupId;
    if (status != null) body['status'] = status;

    return await _post('update_staff', body);
  }

  // ==========================================
  // C. Dashboard Stats
  // Endpoint: GET api/dashboard_stats?user_id={id}
  // ==========================================
  static Future<Map<String, dynamic>> getDashboardStats(int userId) async {
    developer.log('API [Dashboard] Get Dashboard Stats for user_id=$userId', name: 'ApiService.Dashboard');
    return await _get('dashboard_stats?user_id=$userId');
  }

  // ==========================================
  // D. Sheet Operations
  // ==========================================

  /// 1. Create Sheet (Managers, Field Executives, Backend Staff)
  /// Endpoint: POST api/create_sheet
  static Future<Map<String, dynamic>> createSheet({
    required String title,
    required int createdBy,
    String? description,
    bool useMasterColumns = true,
    List<int>? assignTo,
    List<dynamic>? extraColumns,
    List<Map<String, dynamic>>? leads,
  }) async {
    developer.log(
      'API [Sheets] Create Sheet: title="$title", created_by=$createdBy, use_master=$useMasterColumns, leadsCount=${leads?.length ?? 0}',
      name: 'ApiService.Sheets',
    );
    final body = <String, dynamic>{
      'title': title,
      'created_by': createdBy,
      'description': description ?? '',
      'use_master_columns': useMasterColumns,
      'assign_to': assignTo ?? [createdBy],
      'extra_columns': extraColumns ?? [],
    };
    if (leads != null && leads.isNotEmpty) {
      body['leads'] = leads;
    }
    return await _post('create_sheet', body);
  }

  /// 1.1 Manager see all sheets
  /// Endpoint: POST api/get_all_sheets
  static Future<Map<String, dynamic>> getAllSheets({int? userId}) async {
    developer.log('API [Sheets] POST get_all_sheets (Manager)', name: 'ApiService.Sheets');
    final body = <String, dynamic>{};
    if (userId != null && userId > 0) {
      body['user_id'] = userId;
    }
    return await _post('get_all_sheets', body);
  }

  /// 3.2 Staff Sheet List (Field Executive, Backend Staff, Accounts)
  /// Endpoint: GET api/get_sheets?user_id={id}&group_id={groupId}
  static Future<Map<String, dynamic>> getStaffSheets(int userId, [int? groupId]) async {
    developer.log('API [Sheets] GET get_sheets for user_id=$userId, group_id=$groupId', name: 'ApiService.Sheets');
    final query = (groupId != null && groupId > 0)
        ? 'user_id=$userId&group_id=$groupId'
        : 'user_id=$userId';
    return await _get('get_sheets?$query');
  }

  /// Get Sheets for Logged-In User
  /// Manager: POST api/get_all_sheets
  /// Accounts: GET api/get_sheets?user_id={id}&group_id=2 (Automatic all sheets)
  /// Field Exec / Staff: GET api/get_sheets?user_id={id}&group_id={groupId}
  static Future<Map<String, dynamic>> getSheets(int userId, [int? groupId, String? role]) async {
    final isManager = (groupId != null && (groupId == 6 || groupId == 1)) ||
        (role != null && (role.toLowerCase().contains('manager') || role.toLowerCase().contains('admin')));

    _logFetchSheetsRequest(
      userId: userId,
      groupId: groupId,
      role: role,
      isManager: isManager,
    );

    Map<String, dynamic> res;
    if (isManager) {
      try {
        final allRes = await getAllSheets(userId: userId);
        if (allRes['status'] == true && allRes['data'] != null) {
          res = allRes;
        } else {
          res = await getStaffSheets(userId, groupId);
        }
      } catch (e) {
        developer.log('API [Sheets] get_all_sheets fallback to get_sheets: $e', name: 'ApiService.Sheets');
        res = await getStaffSheets(userId, groupId);
      }
    } else {
      res = await getStaffSheets(userId, groupId);
    }

    _logFetchSheetsResponse(
      success: res['status'] == true,
      rawData: res['data'],
      message: res['message']?.toString(),
    );

    return res;
  }

  /// Alias for getSheets
  static Future<Map<String, dynamic>> fetchSheets({
    required int userId,
    int? groupId,
    String? role,
  }) => getSheets(userId, groupId, role);

  /// 1.2 & 3.3 & 5.2 To see sheets separately & fetch leads (Role-Filtered, for all users)
  /// Endpoint: POST api/sheet_details
  /// Request Body: sheet_id, user_id, role (Accounts / Feild Executive / BackEnd Staff / Manager)
  static Future<Map<String, dynamic>> getSheetDetails({
    required int sheetId,
    required int userId,
    String? role,
  }) async {
    final endpoint = 'api/sheet_details?sheet_id=$sheetId${userId > 0 ? '&user_id=$userId' : ''}${role != null && role.isNotEmpty ? '&role=$role' : ''}';
    _logFetchLeadsRequest(
      sheetId: sheetId,
      userId: userId,
      role: role,
      endpoint: endpoint,
    );

    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'user_id': userId,
    };
    if (role != null && role.isNotEmpty) {
      body['role'] = role;
    }

    Map<String, dynamic>? result;

    // Primary: GET api/sheet_details?sheet_id={sheet_id} (Required by backend)
    try {
      final getRes = await _get('sheet_details?sheet_id=$sheetId${userId > 0 ? '&user_id=$userId' : ''}${role != null && role.isNotEmpty ? '&role=$role' : ''}');
      if (getRes['status'] == true) {
        result = getRes;
      }
    } catch (_) {}

    // Fallback: POST Form
    if (result == null) {
      try {
        final res = await _postForm('sheet_details', body);
        if (res['status'] == true) {
          result = res;
        }
      } catch (_) {}
    }

    // Fallback: POST JSON
    if (result == null) {
      try {
        final jsonRes = await _post('sheet_details', body);
        if (jsonRes['status'] == true) {
          result = jsonRes;
        }
      } catch (_) {}
    }

    result ??= {'status': false, 'message': 'Failed to load sheet details.'};

    final isSuccess = result['status'] == true;
    final sheetData = result['data'] is Map ? Map<String, dynamic>.from(result['data']) : null;

    _logFetchLeadsResponse(
      success: isSuccess,
      sheetId: sheetId,
      sheetData: sheetData,
      message: result['message']?.toString(),
    );

    return result;
  }

  /// Alias for getSheetDetails to fetch leads
  static Future<Map<String, dynamic>> fetchLeads({
    required int sheetId,
    required int userId,
    String? role,
  }) => getSheetDetails(sheetId: sheetId, userId: userId, role: role);

  /// Alias for getSheetDetails to get leads
  static Future<Map<String, dynamic>> getLeads({
    required int sheetId,
    required int userId,
    String? role,
  }) => getSheetDetails(sheetId: sheetId, userId: userId, role: role);

  /// 1.3 Add Row / Lead to Sheet (Manager)
  /// Endpoint: POST api/add_row
  static Future<Map<String, dynamic>> addRow({
    required int sheetId,
    required int createdBy,
    int? assignedTo,
    String status = 'new',
    required Map<String, dynamic> data,
  }) async {
    developer.log(
      'API [Rows] Add Row: sheet_id=$sheetId, created_by=$createdBy, assigned_to=$assignedTo',
      name: 'ApiService.Rows',
    );
    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'created_by': createdBy,
      'status': status,
      'data': data,
    };
    if (assignedTo != null && assignedTo > 0) {
      body['assigned_to'] = assignedTo;
    }
    return await _post('add_row', body);
  }

  /// 4. Assign Sheet to Field Executive or Office Executive
  /// Endpoint: POST api/assign_sheet (or api/assign_to_staff)
  static Future<Map<String, dynamic>> assignSheetToStaff({
    required int sheetId,
    required int userId,
    required int assignedBy,
  }) async {
    developer.log(
      'API [Sheets] Assign Sheet to Staff: sheet_id=$sheetId, staff_user_id=$userId, assigned_by=$assignedBy',
      name: 'ApiService.Sheets',
    );
    return await _post('assign_sheet', {
      'sheet_id': sheetId,
      'user_id': userId,
      'assigned_by': assignedBy,
    });
  }

  /// 5. Assign Sheet to Accounts
  /// Endpoint: POST api/assign_to_accounts
  /// Request Body: sheet_id, accounts_user_id, assigned_by
  static Future<Map<String, dynamic>> assignSheetToAccounts({
    required int sheetId,
    required int accountsUserId,
    required int assignedBy,
  }) async {
    developer.log(
      'API [Sheets] Assign Sheet to Accounts: sheet_id=$sheetId, accounts_user_id=$accountsUserId, assigned_by=$assignedBy',
      name: 'ApiService.Sheets',
    );
    return await _post('assign_to_accounts', {
      'sheet_id': sheetId,
      'accounts_user_id': accountsUserId,
      'user_id': accountsUserId,
      'assigned_by': assignedBy,
    });
  }

  /// 1.4 & 3.4 & 5.3 Update Row Fields & Status (for all users)
  /// Endpoint: POST api/update_row
  /// Body: action="update_row", row_id, user_id, role, data, status
  static Future<Map<String, dynamic>> updateRow({
    required int rowId,
    required Map<String, dynamic> data,
    int? userId,
    String? status,
    String? role,
  }) async {
    developer.log(
      'API [Rows] Update Row: row_id=$rowId, user_id=$userId, role=$role, status=$status',
      name: 'ApiService.Rows',
    );
    final body = <String, dynamic>{
      'action': 'update_row',
      'row_id': rowId,
      'data': data,
    };
    if (userId != null && userId > 0) {
      body['user_id'] = userId;
    }
    if (status != null && status.isNotEmpty) {
      body['status'] = status;
    }
    if (role != null && role.isNotEmpty) {
      body['role'] = role;
    }
    return await _post('update_row', body);
  }

  /// Single Cell Update (for direct Excel inline grid editing)
  /// Endpoint: POST api/update_cell
  /// Body: row_id, column_key, value, user_id
  static Future<Map<String, dynamic>> updateCell({
    required int rowId,
    required String columnKey,
    required String value,
    int? userId,
    int? sheetId,
    int? createdBy,
    int? assignedTo,
  }) async {
    developer.log(
      'API [Rows] Update Cell: row_id=$rowId, column_key=$columnKey, value="$value", user_id=$userId',
      name: 'ApiService.Rows',
    );
    final body = <String, dynamic>{
      'row_id': rowId,
      'column_key': columnKey,
      'value': value,
    };
    if (userId != null && userId > 0) {
      body['user_id'] = userId;
    }
    if (rowId == 0) {
      if (sheetId != null) body['sheet_id'] = sheetId;
      if (createdBy != null) body['created_by'] = createdBy;
      if (assignedTo != null) body['assigned_to'] = assignedTo;
    }
    return await _post('update_cell', body);
  }

  /// 3.3 Fetch Edit History for Manager (Dedicated Endpoints - Option B)
  /// Sheet-level History: GET api/sheet_history?sheet_id={sheet_id}&limit={limit}&offset={offset}
  static Future<Map<String, dynamic>> getSheetHistory({
    required int sheetId,
    int limit = 50,
    int offset = 0,
  }) async {
    developer.log(
      'API [History] Get Sheet History: sheet_id=$sheetId, limit=$limit, offset=$offset',
      name: 'ApiService.History',
    );
    return await _get('sheet_history?sheet_id=$sheetId&limit=$limit&offset=$offset');
  }

  /// Row / Lead-level History: GET api/row_history?row_id={row_id}
  static Future<Map<String, dynamic>> getRowHistory({
    required int rowId,
  }) async {
    developer.log('API [History] Get Row History: row_id=$rowId', name: 'ApiService.History');
    return await _get('row_history?row_id=$rowId');
  }

  static Future<Map<String, dynamic>> updateRowStatus({
    required int rowId,
    required String status,
  }) async {
    developer.log(
      'API [Rows] Update Row Status: row_id=$rowId, status=$status',
      name: 'ApiService.Rows',
    );
    return await _post('update_row_status', {
      'row_id': rowId,
      'status': status,
    });
  }

  static Future<Map<String, dynamic>> updateColumn({
    required int columnId,
    required String columnName,
  }) async {
    developer.log(
      'API [Columns] Update Column: column_id=$columnId, column_name="$columnName"',
      name: 'ApiService.Columns',
    );
    return await _post('update_column', {
      'column_id': columnId,
      'column_name': columnName,
    });
  }

  static Future<Map<String, dynamic>> addColumn({
    required int sheetId,
    required String columnName,
    required String columnType,
    List<String>? options,
  }) async {
    developer.log(
      'API [Columns] Add Column: sheet_id=$sheetId, column_name="$columnName", type=$columnType',
      name: 'ApiService.Columns',
    );
    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'column_name': columnName,
      'column_type': columnType,
    };
    if (options != null && options.isNotEmpty) {
      body['options'] = options;
    }
    return await _post('add_column', body);
  }

  static Future<Map<String, dynamic>> shareSheet({
    required int sheetId,
    required List<int> userIds,
    required int assignedBy,
    required String role,
  }) async {
    developer.log(
      'API [Sheets] Share Sheet: sheet_id=$sheetId, user_ids=$userIds, role=$role',
      name: 'ApiService.Sheets',
    );
    return await _post('share_sheet', {
      'sheet_id': sheetId,
      'user_ids': userIds,
      'assigned_by': assignedBy,
      'role': role,
    });
  }

  // ==========================================
  // System Audit History & Inactive Mode Endpoints
  // ==========================================

  /// 6. Show all history
  /// Endpoint: POST api/all_history
  static Future<Map<String, dynamic>> getAllHistory({
    int? limit,
    int? offset,
    String? search,
    int? sheetId,
  }) async {
    developer.log('API [History] POST all_history', name: 'ApiService.History');
    final body = <String, dynamic>{};
    if (limit != null) body['limit'] = limit;
    if (offset != null) body['offset'] = offset;
    if (search != null && search.isNotEmpty) body['search'] = search;
    if (sheetId != null && sheetId > 0) body['sheet_id'] = sheetId;
    return await _post('all_history', body);
  }

  /// 7. Get Mode (Active vs Inactive)
  /// Endpoint: POST api/inactive_mode
  static Future<Map<String, dynamic>> getInactiveMode() async {
    developer.log('API [Mode] POST inactive_mode', name: 'ApiService.Mode');
    return await _post('inactive_mode', {});
  }

  /// 8. Update Mode
  /// Endpoint: POST api/update_mode
  /// Body: inactive_mode: 1 or 0 (Form-encoded)
  static Future<Map<String, dynamic>> updateMode({required bool inactiveMode}) async {
    developer.log(
      'API [Mode] POST update_mode: inactive_mode=${inactiveMode ? 1 : 0}',
      name: 'ApiService.Mode',
    );
    return await _postForm('update_mode', {
      'inactive_mode': inactiveMode ? 1 : 0,
    });
  }
}
