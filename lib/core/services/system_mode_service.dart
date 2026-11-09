import 'package:flutter/material.dart';
import 'package:agency_head/core/network/api_service.dart';

class SystemModeService extends ChangeNotifier {
  static final SystemModeService instance = SystemModeService._internal();
  SystemModeService._internal();

  bool _isInactiveMode = false;
  String _modeLabel = 'Active (Data Visible)';
  bool _canUpdate = true;
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isInactiveMode => _isInactiveMode;
  String get modeLabel => _modeLabel;
  bool get canUpdate => _canUpdate;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Check if data should be hidden for this user session
  /// (Non-managers have data hidden when Inactive Mode is active)
  bool shouldHideDataForUser({required bool isManager}) {
    if (!isManager && _isInactiveMode) {
      return true;
    }
    return false;
  }

  /// Fetch the latest mode from the backend
  Future<void> fetchMode() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.getInactiveMode();
      if (response['status'] == true && response['data'] != null) {
        final data = response['data'];
        final rawInactive = data['inactive_mode'];
        _isInactiveMode = rawInactive == true || rawInactive == 1 || rawInactive == '1' || rawInactive == 'true';
        _modeLabel = data['mode_label']?.toString() ?? (_isInactiveMode ? 'Inactive (Data Hidden)' : 'Active (Data Visible)');
        if (data['can_update'] != null) {
          final rawCan = data['can_update'];
          _canUpdate = rawCan == true || rawCan == 1 || rawCan == '1' || rawCan == 'true';
        }
      }
    } catch (_) {
      // Soft fallback to current state
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update the system mode (Active vs Inactive)
  Future<bool> setMode(bool inactiveMode) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.updateMode(inactiveMode: inactiveMode);
      if (response['status'] == true) {
        _isInactiveMode = inactiveMode;
        _modeLabel = response['data']?['mode_label']?.toString() ??
            (inactiveMode ? 'Inactive (Data Hidden)' : 'Active (Data Visible)');
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle mode between Active and Inactive
  Future<bool> toggleMode() async {
    return await setMode(!_isInactiveMode);
  }
}

