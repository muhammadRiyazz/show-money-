import 'package:agency_head/core/models/api_spreadsheet_model.dart';

class AllHistoryItem {
  final int id;
  final int sheetId;
  final String sheetTitle;
  final int rowId;
  final int rowIndex;
  final String userName;
  final String columnName;
  final String oldValue;
  final String newValue;
  final String createdAt;
  final String formattedDate;
  final String summaryText;
  final String? displayTime;

  const AllHistoryItem({
    required this.id,
    required this.sheetId,
    required this.sheetTitle,
    required this.rowId,
    required this.rowIndex,
    required this.userName,
    required this.columnName,
    required this.oldValue,
    required this.newValue,
    required this.createdAt,
    required this.formattedDate,
    required this.summaryText,
    this.displayTime,
  });

  factory AllHistoryItem.fromJson(Map<String, dynamic> json) {
    // Check multiple possible key names for timestamp
    final rawDate = json['formatted_date'] ??
        json['created_at'] ??
        json['edited_at'] ??
        json['updated_at'] ??
        json['edit_time'] ??
        json['timestamp'] ??
        json['time'] ??
        json['date'] ??
        json['datetime'];

    final formatted = formatHistoryDateTime(rawDate);

    return AllHistoryItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      sheetId: int.tryParse(json['sheet_id']?.toString() ?? '0') ?? 0,
      sheetTitle: (json['sheet_title'] ?? 'Sheet').toString(),
      rowId: int.tryParse(json['row_id']?.toString() ?? '0') ?? 0,
      rowIndex: int.tryParse(json['row_index']?.toString() ?? '0') ?? 0,
      userName: (json['user_name'] ?? 'System User').toString(),
      columnName: (json['column_name'] ?? 'Field').toString(),
      oldValue: (json['old_value'] ?? '').toString(),
      newValue: (json['new_value'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      formattedDate: formatted ?? (json['formatted_date'] ?? '').toString(),
      summaryText: (json['summary_text'] ?? '').toString(),
      displayTime: formatted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'sheet_id': sheetId.toString(),
      'sheet_title': sheetTitle,
      'row_id': rowId.toString(),
      'row_index': rowIndex.toString(),
      'user_name': userName,
      'column_name': columnName,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': createdAt,
      'formatted_date': formattedDate,
      'summary_text': summaryText,
      'display_time': displayTime,
    };
  }
}

