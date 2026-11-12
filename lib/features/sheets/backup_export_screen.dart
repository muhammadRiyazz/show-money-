import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/network/api_service.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/models/api_spreadsheet_model.dart';
import 'package:agency_head/core/services/platform_helper.dart';
import 'package:agency_head/core/services/backup_export_service.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';

class ExportColumnInfo {
  final String key;
  final String name;
  final bool isSystem;

  ExportColumnInfo({
    required this.key,
    required this.name,
    this.isSystem = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportColumnInfo &&
          runtimeType == other.runtimeType &&
          key.toLowerCase() == other.key.toLowerCase();

  @override
  int get hashCode => key.toLowerCase().hashCode;
}

class BackupExportScreen extends StatefulWidget {
  final String? preselectedSheetId;

  const BackupExportScreen({super.key, this.preselectedSheetId});

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen> {
  bool _isLoading = true;
  String? _error;
  String _loadingMessage = 'Loading sheets & leads data...';

  // Loaded Data
  List<dynamic> _rawSheetsList = [];
  final Map<int, ApiSpreadsheet> _loadedSheets = {};

  // Filter States
  String _selectedDatePreset = 'All Time'; // All Time, Today, Yesterday, Last 7 Days, Last 30 Days, This Month, Custom
  DateTimeRange? _customDateRange;
  int? _selectedSheetId; // null = All Sheets
  String _selectedStatus = 'All'; // All or specific status
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // FULL DATA MODE: When true, all columns discovered across sheets & leads are exported automatically!
  bool _exportAllColumns = true;

  // Selected column keys when custom selection is active
  final Set<String> _selectedColumns = {};

  @override
  void initState() {
    super.initState();
    if (widget.preselectedSheetId != null) {
      _selectedSheetId = int.tryParse(widget.preselectedSheetId!);
    }
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadingMessage = 'Fetching sheets list...';
    });

    try {
      final user = await AuthService.getUser();
      final userId = user != null ? int.tryParse(user['id'].toString()) ?? 3 : 3;
      final groupId = user != null ? int.tryParse(user['group_id'].toString()) ?? 6 : 6;
      final role = user?['group_name']?.toString() ?? 'Manager';

      final sheetsRes = await ApiService.getSheets(userId, groupId, role);

      if (sheetsRes['status'] != true || sheetsRes['data'] == null) {
        if (!mounted) return;
        setState(() {
          _error = sheetsRes['message'] ?? 'Failed to load sheets list';
          _isLoading = false;
        });
        return;
      }

      final rawList = List<dynamic>.from(sheetsRes['data'] ?? []);
      _rawSheetsList = rawList;

      // Fetch details for each sheet
      int loadedCount = 0;
      for (final s in rawList) {
        final sId = int.tryParse(s['id']?.toString() ?? '0') ?? 0;
        if (sId > 0) {
          loadedCount++;
          if (mounted) {
            setState(() {
              _loadingMessage = 'Loading sheet details ($loadedCount of ${rawList.length}): ${s['title'] ?? 'Sheet #$sId'}...';
            });
          }

          try {
            final detailsRes = await ApiService.getSheetDetails(
              sheetId: sId,
              userId: userId,
              role: role,
            );
            if (detailsRes['status'] == true && detailsRes['data'] != null) {
              final parsed = ApiSpreadsheet.fromJson(detailsRes['data']);
              _loadedSheets[sId] = parsed;
            }
          } catch (_) {}
        }
      }

      // Initialize selected columns with all discovered columns
      _syncAllColumns();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _syncAllColumns() {
    final all = _allDiscoveredColumns;
    _selectedColumns.clear();
    for (final col in all) {
      _selectedColumns.add(col.key);
    }
  }

  // =========================================================================
  // DISCOVER ALL COLUMNS ACROSS ALL SHEETS & LEADS (FULL DATA)
  // =========================================================================
  List<ExportColumnInfo> get _allDiscoveredColumns {
    final result = <ExportColumnInfo>[];
    final seen = <String>{};

    void addCol(String key, String name, {bool isSystem = false}) {
      final cleanKey = key.trim();
      final lower = cleanKey.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        result.add(ExportColumnInfo(key: cleanKey, name: name, isSystem: isSystem));
      }
    }

    // 1. Primary Sheet & Lead Details
    addCol('sheet_title', 'Sheet Name', isSystem: true);
    addCol('row_id', 'Row #', isSystem: true);
    addCol('lead_name', 'Lead / Student Name');
    addCol('phone', 'Phone Number');
    addCol('email', 'Email Address');
    addCol('country', 'Country / Location');
    addCol('status', 'Status');
    addCol('assigned_to', 'Assigned Staff', isSystem: true);
    addCol('working_amount', 'Working Amount');
    addCol('agency_name', 'Agency Name');
    addCol('created_at', 'Created Date', isSystem: true);
    addCol('updated_at', 'Last Updated', isSystem: true);

    // 2. Discover all columns declared on sheets
    for (final sheet in _loadedSheets.values) {
      for (final col in sheet.columns) {
        final colName = col.columnName.trim();
        final lower = colName.toLowerCase();
        // Skip duplicate names already covered by standard fields
        if (lower == 'name' ||
            lower == 'lead name' ||
            lower == 'student name' ||
            lower == 'number' ||
            lower == 'phone' ||
            lower == 'phone number' ||
            lower == 'email' ||
            lower == 'email address' ||
            lower == 'country' ||
            lower == 'status' ||
            lower == 'working amount' ||
            lower == 'amount' ||
            lower == 'agency' ||
            lower == 'agency name') {
          continue;
        }
        addCol(col.columnKey.isNotEmpty ? col.columnKey : colName, colName);
      }
    }

    // 3. Discover any extra fields in row.data
    for (final sheet in _loadedSheets.values) {
      for (final row in sheet.rows) {
        for (final entry in row.data.entries) {
          final k = entry.key.trim();
          if (k.isEmpty || k.startsWith('col_')) continue;
          final lower = k.toLowerCase();
          if (lower == 'name' ||
              lower == 'number' ||
              lower == 'phone' ||
              lower == 'email' ||
              lower == 'country' ||
              lower == 'status' ||
              lower == 'created_at' ||
              lower == 'updated_at') {
            continue;
          }
          final formattedName = k
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
              .join(' ');
          addCol(k, formattedName);
        }
      }
    }

    return result;
  }

  // Active export columns based on _exportAllColumns flag
  List<ExportColumnInfo> get _activeExportColumns {
    final all = _allDiscoveredColumns;
    if (_exportAllColumns) {
      return all;
    }
    return all.where((c) => _selectedColumns.contains(c.key)).toList();
  }

  // =========================================================================
  // EXTRACT FULL DATA FOR A CELL
  // =========================================================================
  String _extractCellValue(ApiSpreadsheet sheet, ApiRow row, ExportColumnInfo colInfo) {
    final key = colInfo.key;
    final name = colInfo.name;
    final lowerKey = key.toLowerCase();
    final lowerName = name.toLowerCase();

    // 1. System Metadata
    if (lowerKey == 'sheet_title') return sheet.title;
    if (lowerKey == 'row_id') return row.rowIndex > 0 ? row.rowIndex.toString() : row.id.toString();
    if (lowerKey == 'status') return row.status;
    if (lowerKey == 'assigned_to') return row.assignedToName ?? 'Unassigned';
    if (lowerKey == 'created_at') return formatHistoryDateTime(row.createdAt) ?? row.createdAt ?? '';
    if (lowerKey == 'updated_at') return formatHistoryDateTime(row.updatedAt) ?? row.updatedAt ?? '';

    // 2. Standard Lead Properties
    if (lowerKey == 'lead_name' || lowerName == 'lead / student name' || lowerName == 'lead name' || lowerName == 'name') {
      return row.leadName;
    }
    if (lowerKey == 'phone' || lowerName.contains('phone') || lowerName.contains('number')) {
      return row.phoneNumber;
    }
    if (lowerKey == 'email' || lowerName.contains('email')) {
      return row.leadEmail;
    }
    if (lowerKey == 'country' || lowerName.contains('country')) {
      return row.country;
    }
    if (lowerKey == 'working_amount' || lowerName.contains('working amount') || lowerName == 'amount') {
      return row.workingAmount;
    }
    if (lowerKey == 'agency_name' || lowerName.contains('agency')) {
      return row.agencyName;
    }

    // 3. Search via sheet.columns
    for (final col in sheet.columns) {
      if (col.columnKey.toLowerCase() == lowerKey || col.columnName.toLowerCase() == lowerName) {
        final val = row.getValue(col);
        if (val.isNotEmpty) return val;
      }
    }

    // 4. Search row.data directly
    if (row.data.containsKey(key)) {
      final v = row.data[key]?.toString() ?? '';
      if (v.isNotEmpty) return v;
    }
    if (row.data.containsKey(name)) {
      final v = row.data[name]?.toString() ?? '';
      if (v.isNotEmpty) return v;
    }

    // 5. Case-insensitive search in row.data
    for (final entry in row.data.entries) {
      final k = entry.key.toLowerCase();
      if (k == lowerKey || k == lowerName) {
        final v = entry.value?.toString() ?? '';
        if (v.isNotEmpty) return v;
      }
    }

    return '';
  }

  // =========================================================================
  // DATE RANGE LOGIC
  // =========================================================================
  DateTimeRange? get _effectiveDateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedDatePreset) {
      case 'Today':
        return DateTimeRange(start: todayStart, end: todayEnd);
      case 'Yesterday':
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = todayEnd.subtract(const Duration(days: 1));
        return DateTimeRange(start: yStart, end: yEnd);
      case 'Last 7 Days':
        final start = todayStart.subtract(const Duration(days: 7));
        return DateTimeRange(start: start, end: todayEnd);
      case 'Last 30 Days':
        final start = todayStart.subtract(const Duration(days: 30));
        return DateTimeRange(start: start, end: todayEnd);
      case 'This Month':
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        return DateTimeRange(start: start, end: todayEnd);
      case 'Custom':
        return _customDateRange;
      case 'All Time':
      default:
        return null;
    }
  }

  String get _dateRangeDisplayText {
    final range = _effectiveDateRange;
    if (range == null) return 'All Time';
    final df = DateFormat('dd MMM yyyy');
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day) {
      return df.format(range.start);
    }
    return '${df.format(range.start)} – ${df.format(range.end)}';
  }

  DateTime? _extractRowDate(ApiRow row) {
    final candidates = [
      row.createdAt,
      row.updatedAt,
      row.data['created_at'],
      row.data['date'],
      row.data['Date'],
      row.data['timestamp'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      final str = c.toString().trim();
      if (str.isEmpty || str.toLowerCase() == 'null' || str.startsWith('0000-00-00')) continue;
      final parsed = DateTime.tryParse(str) ?? DateTime.tryParse(str.replaceAll(' ', 'T'));
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  bool _matchesFilters(ApiSpreadsheet sheet, ApiRow row) {
    // 1. Sheet Filter
    if (_selectedSheetId != null && sheet.id != _selectedSheetId) {
      return false;
    }

    // 2. Status Filter
    if (_selectedStatus != 'All') {
      if (row.status.toLowerCase() != _selectedStatus.toLowerCase()) {
        return false;
      }
    }

    // 3. Date Range Filter
    final range = _effectiveDateRange;
    if (range != null) {
      final rowDt = _extractRowDate(row);
      if (rowDt != null) {
        if (rowDt.isBefore(range.start) || rowDt.isAfter(range.end)) {
          return false;
        }
      }
    }

    // 4. Search Query Filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final name = row.leadName.toLowerCase();
      final phone = row.leadPhone.toLowerCase();
      final email = row.leadEmail.toLowerCase();
      final country = row.leadCountry.toLowerCase();
      final sheetTitle = sheet.title.toLowerCase();

      bool foundInCells = false;
      for (final val in row.data.values) {
        if (val?.toString().toLowerCase().contains(q) == true) {
          foundInCells = true;
          break;
        }
      }

      if (!name.contains(q) &&
          !phone.contains(q) &&
          !email.contains(q) &&
          !country.contains(q) &&
          !sheetTitle.contains(q) &&
          !foundInCells) {
        return false;
      }
    }

    return true;
  }

  // Returns list of pairs: [Sheet, Row]
  List<MapEntry<ApiSpreadsheet, ApiRow>> get _filteredRows {
    final list = <MapEntry<ApiSpreadsheet, ApiRow>>[];
    for (final sheet in _loadedSheets.values) {
      for (final row in sheet.rows) {
        if (_matchesFilters(sheet, row)) {
          list.add(MapEntry(sheet, row));
        }
      }
    }
    return list;
  }

  List<String> get _distinctStatuses {
    final set = <String>{'All'};
    for (final sheet in _loadedSheets.values) {
      for (final row in sheet.rows) {
        if (row.status.trim().isNotEmpty) {
          set.add(row.status.trim());
        }
      }
    }
    return set.toList();
  }

  // =========================================================================
  // BUILD HEADERS AND ROWS WITH FULL DATA
  // =========================================================================
  List<String> _buildExportHeaders() {
    return _activeExportColumns.map((c) => c.name).toList();
  }

  List<List<String>> _buildExportRows(List<MapEntry<ApiSpreadsheet, ApiRow>> entries) {
    final cols = _activeExportColumns;
    final rows = <List<String>>[];

    for (final entry in entries) {
      final sheet = entry.key;
      final row = entry.value;
      final cells = <String>[];

      for (final colInfo in cols) {
        cells.add(_extractCellValue(sheet, row, colInfo));
      }

      rows.add(cells);
    }

    return rows;
  }

  // =========================================================================
  // ACTIONS: EXCEL, PDF, GOOGLE SHEETS, JSON
  // =========================================================================
  Future<void> _exportExcel() async {
    final filtered = _filteredRows;
    if (filtered.isEmpty) {
      _showWarningSnackBar('No leads match your current filter settings to export.');
      return;
    }

    final headers = _buildExportHeaders();
    final rows = _buildExportRows(filtered);
    final csvContent = BackupExportService.generateCsv(headers: headers, rows: rows);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'agency_leads_full_backup_$timestamp.csv';

    final savedPath = await PlatformHelper.downloadFile(
      filename,
      csvContent,
      mimeType: 'text/csv;charset=utf-8',
    );

    _showSuccessSnackBar(
      savedPath != null
          ? 'Excel file downloaded successfully! (${rows.length} leads with ${headers.length} columns saved to $savedPath)'
          : 'Excel file downloaded successfully (${rows.length} leads with ${headers.length} columns).',
    );
  }

  Future<void> _exportPdf() async {
    final filtered = _filteredRows;
    if (filtered.isEmpty) {
      _showWarningSnackBar('No leads match your current filter settings to generate PDF.');
      return;
    }

    final headers = _buildExportHeaders();
    final rows = _buildExportRows(filtered);

    final summary = <String, String>{
      'Total Matching Leads': rows.length.toString(),
      'Fields Per Lead': headers.length.toString(),
      'Sheets Included': _selectedSheetId != null ? '1 Sheet' : '${_loadedSheets.length} Sheets',
      'Date Range': _dateRangeDisplayText,
      'Status Filter': _selectedStatus,
    };

    final htmlContent = BackupExportService.generatePrintableHtmlReport(
      title: 'Danada Funds - Complete Leads Report',
      dateRangeText: _dateRangeDisplayText,
      summaryStats: summary,
      headers: headers,
      rows: rows,
    );

    PlatformHelper.printHtml(htmlContent, 'Agency_Full_Leads_Report');

    _showSuccessSnackBar('PDF Print dialog opened! Select "Save as PDF" to save.');
  }

  Future<void> _copyForGoogleSheets() async {
    final filtered = _filteredRows;
    if (filtered.isEmpty) {
      _showWarningSnackBar('No leads match your current filter settings.');
      return;
    }

    final headers = _buildExportHeaders();
    final rows = _buildExportRows(filtered);
    final tsvContent = BackupExportService.generateGoogleSheetsTsv(headers: headers, rows: rows);

    await Clipboard.setData(ClipboardData(text: tsvContent));

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              SizedBox(width: 8),
              Text('Copied Full Data for Google Sheets!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${rows.length} leads with all ${headers.length} columns copied to clipboard.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Text(
                  '👉 Next Step: Open Google Sheets and simply press Ctrl+V (or Cmd+V on Mac) in cell A1. All columns, rows, and data will instantly paste!',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Google Sheets (sheets.new)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D58),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                PlatformHelper.printHtml(
                  '<script>window.location.href="https://sheets.new";</script>',
                  'GoogleSheets',
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportGoogleSheetsCsv() async {
    final filtered = _filteredRows;
    if (filtered.isEmpty) {
      _showWarningSnackBar('No leads match your current filter settings to export.');
      return;
    }

    final headers = _buildExportHeaders();
    final rows = _buildExportRows(filtered);
    final csvContent = BackupExportService.generateCsv(headers: headers, rows: rows);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'google_sheets_full_leads_$timestamp.csv';

    await PlatformHelper.downloadFile(
      filename,
      csvContent,
      mimeType: 'text/csv;charset=utf-8',
    );

    _showSuccessSnackBar('Google Sheets CSV with full data downloaded! Import it via File > Import in Google Sheets.');
  }

  Future<void> _exportJsonBackup() async {
    final filtered = _filteredRows;
    if (filtered.isEmpty) {
      _showWarningSnackBar('No data to export.');
      return;
    }

    final allCols = _allDiscoveredColumns;

    final payload = {
      'app': 'Danada Funds',
      'version': '1.0.0',
      'export_type': 'FULL_DATABASE_BACKUP',
      'export_date': DateTime.now().toIso8601String(),
      'filters_applied': {
        'date_preset': _selectedDatePreset,
        'date_range': _dateRangeDisplayText,
        'sheet_filter_id': _selectedSheetId,
        'status_filter': _selectedStatus,
        'search_query': _searchQuery,
      },
      'total_records': filtered.length,
      'total_sheets': _loadedSheets.length,
      'discovered_columns': allCols.map((c) => {'key': c.key, 'name': c.name, 'is_system': c.isSystem}).toList(),
      'data': filtered.map((entry) {
        final sheet = entry.key;
        final row = entry.value;

        // Collect all extracted values into a clean map
        final extractedMap = <String, dynamic>{};
        for (final col in allCols) {
          extractedMap[col.key] = _extractCellValue(sheet, row, col);
        }

        return {
          'sheet_id': sheet.id,
          'sheet_title': sheet.title,
          'row_id': row.id,
          'row_index': row.rowIndex,
          'status': row.status,
          'created_at': row.createdAt,
          'updated_at': row.updatedAt,
          'assigned_to_id': row.assignedTo,
          'assigned_to_name': row.assignedToName,
          'created_by_id': row.createdBy,
          'created_by_name': row.createdByName,
          'lead_name': row.leadName,
          'lead_phone': row.leadPhone,
          'lead_email': row.leadEmail,
          'lead_country': row.leadCountry,
          'working_amount': row.workingAmount,
          'agency_name': row.agencyName,
          'all_fields': extractedMap,
          'raw_row_data': row.data,
        };
      }).toList(),
    };

    final jsonString = BackupExportService.generateJsonBackup(backupPayload: payload);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'agency_complete_database_backup_$timestamp.json';

    await PlatformHelper.downloadFile(
      filename,
      jsonString,
      mimeType: 'application/json;charset=utf-8',
    );

    _showSuccessSnackBar('Full Database JSON archive downloaded successfully!');
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWarningSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFD97706),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialRange = _customDateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initialRange,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDatePreset = 'Custom';
        _customDateRange = picked;
      });
    }
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final filtered = _filteredRows;
    final activeCols = _activeExportColumns;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Backup & Export Full Data',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh All Sheets',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _loadAllData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13.5),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadAllData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 28 : 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. TOP HEADER BANNER
                      _buildHeaderBanner(filtered.length, activeCols.length),

                      const SizedBox(height: 18),

                      // 2. EXPORT FORMAT CARDS (Excel, PDF, Google Sheets, JSON)
                      _buildExportActionCards(filtered.length),

                      const SizedBox(height: 24),

                      // 3. FILTERING & DATE RANGE CONTROLS (WITH FULL DATA TOGGLE)
                      _buildFilterControls(),

                      const SizedBox(height: 24),

                      // 4. LIVE PREVIEW TABLE WITH ALL COLUMNS
                      _buildLivePreviewTable(filtered, activeCols),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  // 1. TOP HEADER BANNER
  Widget _buildHeaderBanner(int totalMatchingLeads, int totalFields) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'assets/logo/logo_icon_white.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complete Leads & Sheets Backup Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Full data export mode: all custom fields, sheet columns, and metadata included.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 14),

          // Stats row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildWhiteStatBadge(
                label: 'Sheets Loaded',
                val: '${_loadedSheets.length} Sheets',
                icon: Icons.table_chart_rounded,
              ),
              _buildWhiteStatBadge(
                label: 'Matching Leads',
                val: '$totalMatchingLeads Leads',
                icon: Icons.people_alt_rounded,
              ),
              _buildWhiteStatBadge(
                label: 'Fields Per Lead',
                val: '$totalFields Columns',
                icon: Icons.view_column_rounded,
              ),
              _buildWhiteStatBadge(
                label: 'Date Range',
                val: _dateRangeDisplayText,
                icon: Icons.date_range_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteStatBadge({required String label, required String val, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600),
              ),
              Text(
                val,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. EXPORT ACTION CARDS
  Widget _buildExportActionCards(int matchingCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Choose Export / Save Format',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return GridView.count(
              crossAxisCount: isWide ? 4 : (constraints.maxWidth > 480 ? 2 : 1),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 1.4 : 1.7,
              children: [
                // Card 1: Microsoft Excel
                _buildFormatCard(
                  title: 'Microsoft Excel',
                  sub: 'Full lead data spreadsheet with UTF-8 BOM. Opens seamlessly in Excel.',
                  btnLabel: 'Download Excel',
                  icon: Icons.table_view_rounded,
                  color: const Color(0xFF107C41),
                  onTap: _exportExcel,
                ),

                // Card 2: PDF Document
                _buildFormatCard(
                  title: 'PDF Document',
                  sub: 'Executive landscape document with all fields, KPIs & print layout.',
                  btnLabel: 'Save as PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFDC2626),
                  onTap: _exportPdf,
                ),

                // Card 3: Google Sheets
                _buildGoogleSheetsCard(),

                // Card 4: JSON Backup
                _buildFormatCard(
                  title: 'Full Database Backup',
                  sub: 'Complete raw JSON data archive with all schemas, columns, and rows.',
                  btnLabel: 'Download JSON',
                  icon: Icons.data_object_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: _exportJsonBackup,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFormatCard({
    required String title,
    required String sub,
    required String btnLabel,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.download_rounded, size: 14),
              label: Text(btnLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSheetsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.grid_on_rounded, color: Color(0xFF0F9D58), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Google Sheets',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Text(
            'Copy full data for instant 1-click paste (Ctrl+V) into Google Sheets or download CSV.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyForGoogleSheets,
                  icon: const Icon(Icons.copy_rounded, size: 13),
                  label: const Text('Copy TSV', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9D58),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _exportGoogleSheetsCsv,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F9D58),
                  side: const BorderSide(color: Color(0xFF0F9D58)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. FILTERING & DATE RANGE CONTROLS
  Widget _buildFilterControls() {
    final allCols = _allDiscoveredColumns;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '2. Data Filter & Date Range Options',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedDatePreset = 'All Time';
                    _customDateRange = null;
                    _selectedSheetId = null;
                    _selectedStatus = 'All';
                    _searchController.clear();
                    _searchQuery = '';
                    _exportAllColumns = true;
                    _syncAllColumns();
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Reset All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // FULL DATA MODE TOGGLE BANNER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _exportAllColumns ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _exportAllColumns ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _exportAllColumns ? Icons.star_rounded : Icons.tune_rounded,
                  color: _exportAllColumns ? AppColors.primary : const Color(0xFF64748B),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _exportAllColumns
                            ? 'Full Lead Data Mode Active (All ${allCols.length} Columns & Fields Included)'
                            : 'Custom Column Selection (${_selectedColumns.length} of ${allCols.length} Columns)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _exportAllColumns ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _exportAllColumns
                            ? 'Every column, custom field, and metadata value is automatically included in the export.'
                            : 'Choose specifically which fields to include below.',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _exportAllColumns,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _exportAllColumns = val;
                      if (val) {
                        _syncAllColumns();
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Date Range Presets Chips
          const Text(
            'Date Range Filter:',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDatePresetChip('All Time'),
              _buildDatePresetChip('Today'),
              _buildDatePresetChip('Yesterday'),
              _buildDatePresetChip('Last 7 Days'),
              _buildDatePresetChip('Last 30 Days'),
              _buildDatePresetChip('This Month'),
              ActionChip(
                backgroundColor: _selectedDatePreset == 'Custom' ? AppColors.primary : const Color(0xFFF1F5F9),
                avatar: Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: _selectedDatePreset == 'Custom' ? Colors.white : const Color(0xFF64748B),
                ),
                label: Text(
                  _selectedDatePreset == 'Custom' && _customDateRange != null
                      ? _dateRangeDisplayText
                      : 'Custom Date Range...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedDatePreset == 'Custom' ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                onPressed: _pickCustomDateRange,
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 18),

          // Row with Sheet Selector, Status Selector, and Search Box
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildSheetDropdown()),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: _buildStatusDropdown()),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: _buildSearchTextField()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildSheetDropdown(),
                  const SizedBox(height: 12),
                  _buildStatusDropdown(),
                  const SizedBox(height: 12),
                  _buildSearchTextField(),
                ],
              );
            },
          ),

          // Column Selection Expansion (only when custom column mode is active)
          if (!_exportAllColumns) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),
            _buildColumnSelectionExpansion(allCols),
          ],
        ],
      ),
    );
  }

  Widget _buildDatePresetChip(String preset) {
    final isSelected = _selectedDatePreset == preset;
    return ChoiceChip(
      selected: isSelected,
      label: Text(preset),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedDatePreset = preset;
          });
        }
      },
    );
  }

  Widget _buildSheetDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Sheet:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            color: const Color(0xFFF8FAFC),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedSheetId,
              isExpanded: true,
              hint: const Text('All Sheets (Combined Backup)', style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Sheets (Combined Backup)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                ..._loadedSheets.values.map((sheet) {
                  return DropdownMenuItem<int?>(
                    value: sheet.id,
                    child: Text(
                      '${sheet.title} (${sheet.rows.length} leads)',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedSheetId = val;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lead Status:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            color: const Color(0xFFF8FAFC),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              isExpanded: true,
              items: _distinctStatuses.map((st) {
                return DropdownMenuItem<String>(
                  value: st,
                  child: Text(
                    st == 'All' ? 'All Statuses' : st.toUpperCase(),
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedStatus = val;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keyword Search Filter:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by lead name, phone, email...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildColumnSelectionExpansion(List<ExportColumnInfo> allCols) {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          const Icon(Icons.view_column_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'Custom Field Selector (${_selectedColumns.length} of ${allCols.length} columns active)',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedColumns.clear();
                  for (final c in allCols) {
                    _selectedColumns.add(c.key);
                  }
                });
              },
              icon: const Icon(Icons.select_all_rounded, size: 16),
              label: const Text('Select All', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedColumns.clear();
                  // Keep at least lead_name
                  _selectedColumns.add('lead_name');
                });
              },
              icon: const Icon(Icons.deselect_rounded, size: 16),
              label: const Text('Clear All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: allCols.map((col) {
            final key = col.key;
            final isChecked = _selectedColumns.contains(key);
            return FilterChip(
              label: Text(
                col.name,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                  color: isChecked ? AppColors.primary : const Color(0xFF475569),
                ),
              ),
              selected: isChecked,
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedColumns.add(key);
                  } else {
                    if (_selectedColumns.length > 1) {
                      _selectedColumns.remove(key);
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // 4. LIVE PREVIEW TABLE WITH ALL ACTIVE COLUMNS
  Widget _buildLivePreviewTable(
    List<MapEntry<ApiSpreadsheet, ApiRow>> entries,
    List<ExportColumnInfo> cols,
  ) {
    final previewEntries = entries.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.preview_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '3. Full Data Preview (${entries.length} leads • ${cols.length} fields)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Showing first ${previewEntries.length} rows',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (entries.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 44, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text(
                    'No leads match your chosen filters and date range.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Try selecting "All Time" or resetting the status/search filters.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1E3A8A)),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 46,
                  columns: cols.map((col) {
                    return DataColumn(
                      label: Text(
                        col.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  rows: previewEntries.map((e) {
                    final sheet = e.key;
                    final row = e.value;
                    return DataRow(
                      cells: cols.map((col) {
                        final val = _extractCellValue(sheet, row, col);
                        if (col.key == 'status') {
                          return DataCell(_buildStatusPill(val));
                        }
                        return DataCell(
                          Text(
                            val,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: (col.key == 'lead_name' || col.key == 'sheet_title')
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF475569);
    final s = status.toLowerCase();
    if (s.contains('new')) {
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF3730A3);
    } else if (s.contains('contact')) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1E40AF);
    } else if (s.contains('progress')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (s.contains('enrolled') || s.contains('active')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (s.contains('closed') || s.contains('inactive')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.isEmpty ? 'New' : status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
