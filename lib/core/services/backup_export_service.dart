import 'dart:convert';
import 'package:intl/intl.dart';

class BackupExportService {
  /// Converts headers and rows to a properly escaped CSV string with UTF-8 BOM
  /// so that Microsoft Excel, Google Sheets, and LibreOffice open it flawlessly.
  static String generateCsv({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer();
    // UTF-8 BOM for Microsoft Excel compatibility
    buffer.write('\uFEFF');

    // Headers
    buffer.writeln(headers.map(_escapeCsvCell).join(','));

    // Rows
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvCell).join(','));
    }

    return buffer.toString();
  }

  /// Converts headers and rows into Tab-Separated Values (TSV)
  /// specifically designed for one-click copy and paste into Google Sheets.
  static String generateGoogleSheetsTsv({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeTsvCell).join('\t'));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeTsvCell).join('\t'));
    }
    return buffer.toString();
  }

  /// Generates a styled Excel-compatible HTML spreadsheet (.xls)
  /// which Excel opens with colors, borders, and formatted headers.
  static String generateExcelHtml({
    required String title,
    required String dateRangeText,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final buffer = StringBuffer();

    buffer.write('''
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <style>
    body { font-family: Calibri, Arial, sans-serif; }
    .title { font-size: 16pt; font-weight: bold; color: #1E3A8A; }
    .meta { font-size: 10pt; color: #64748B; }
    th {
      background-color: #1E3A8A;
      color: #FFFFFF;
      font-weight: bold;
      border: 0.5pt solid #0F172A;
      padding: 6px 10px;
      text-align: left;
    }
    td {
      border: 0.5pt solid #CBD5E1;
      padding: 5px 8px;
      vertical-align: top;
    }
    .even-row { background-color: #F8FAFC; }
    .odd-row { background-color: #FFFFFF; }
  </style>
</head>
<body>
  <table>
    <tr>
      <td colspan="${headers.length}" class="title">$title</td>
    </tr>
    <tr>
      <td colspan="${headers.length}" class="meta">Exported on: $nowFormatted &nbsp;|&nbsp; Date Range: $dateRangeText &nbsp;|&nbsp; Total Records: ${rows.length}</td>
    </tr>
    <tr><td colspan="${headers.length}"></td></tr>
    <tr>
''');

    for (final header in headers) {
      buffer.write('      <th>${_escapeHtml(header)}</th>\n');
    }
    buffer.write('    </tr>\n');

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowClass = (i % 2 == 0) ? 'even-row' : 'odd-row';
      buffer.write('    <tr class="$rowClass">\n');
      for (final cell in row) {
        buffer.write('      <td>${_escapeHtml(cell)}</td>\n');
      }
      buffer.write('    </tr>\n');
    }

    buffer.write('''
  </table>
</body>
</html>
''');

    return buffer.toString();
  }

  /// Generates an Executive PDF-Ready Printable HTML Report
  /// with modern styling, summary cards, and automatic print/save dialog.
  static String generatePrintableHtmlReport({
    required String title,
    required String dateRangeText,
    required Map<String, String> summaryStats,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final buffer = StringBuffer();

    buffer.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$title - Agency Data Report</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 24px;
      background-color: #F8FAFC;
      color: #0F172A;
    }
    .no-print {
      position: sticky;
      top: 0;
      z-index: 999;
      background: #1E3A8A;
      color: white;
      padding: 14px 20px;
      border-radius: 10px;
      margin-bottom: 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: 0 4px 12px rgba(30, 58, 138, 0.25);
    }
    .print-btn {
      background: #2563EB;
      color: white;
      border: none;
      padding: 10px 20px;
      font-size: 14px;
      font-weight: 700;
      border-radius: 8px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 8px;
      box-shadow: 0 2px 6px rgba(0,0,0,0.2);
    }
    .print-btn:hover { background: #1D4ED8; }
    .report-card {
      background: white;
      border-radius: 12px;
      padding: 24px;
      border: 1px solid #E2E8F0;
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }
    .header-bar {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 2px solid #E2E8F0;
      padding-bottom: 16px;
      margin-bottom: 20px;
    }
    .brand-title {
      font-size: 22px;
      font-weight: 800;
      color: #1E3A8A;
      margin: 0 0 4px 0;
    }
    .report-subtitle {
      font-size: 13px;
      color: #64748B;
      margin: 0;
    }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
      margin-bottom: 24px;
    }
    .stat-pill {
      background: #F1F5F9;
      border: 1px solid #E2E8F0;
      border-radius: 8px;
      padding: 10px 14px;
    }
    .stat-label {
      font-size: 11px;
      color: #64748B;
      text-transform: uppercase;
      font-weight: 700;
      letter-spacing: 0.5px;
    }
    .stat-val {
      font-size: 18px;
      font-weight: 800;
      color: #0F172A;
      margin-top: 2px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
      margin-top: 8px;
    }
    th {
      background-color: #1E3A8A;
      color: #FFFFFF;
      font-weight: 700;
      text-align: left;
      padding: 8px 10px;
      border: 1px solid #1E3A8A;
      white-space: nowrap;
    }
    td {
      padding: 8px 10px;
      border: 1px solid #E2E8F0;
      vertical-align: top;
      color: #334155;
    }
    tr:nth-child(even) td { background-color: #F8FAFC; }
    tr:hover td { background-color: #F1F5F9; }
    .status-badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 10.5px;
      font-weight: 700;
      text-transform: capitalize;
    }
    .status-new { background: #E0E7FF; color: #3730A3; }
    .status-contacted { background: #DBEAFE; color: #1E40AF; }
    .status-in_progress { background: #FEF3C7; color: #92400E; }
    .status-enrolled, .status-active { background: #DCFCE7; color: #166534; }
    .status-closed, .status-inactive { background: #FEE2E2; color: #991B1B; }

    @media print {
      body { background: white; padding: 0; }
      .no-print { display: none !important; }
      .report-card { border: none; box-shadow: none; padding: 0; }
      @page { size: landscape; margin: 10mm; }
      table { page-break-inside: auto; }
      tr { page-break-inside: avoid; page-break-after: auto; }
      thead { display: table-header-group; }
    }
  </style>
</head>
<body>
  <div class="no-print">
    <div>
      <strong style="font-size: 15px;">📊 Danada Funds Data Backup & Leads Report</strong>
      <div style="font-size: 12px; opacity: 0.9;">Ready to download or print as PDF</div>
    </div>
    <button class="print-btn" onclick="window.print()">
      🖨️ Save as PDF / Print Report
    </button>
  </div>

  <div class="report-card">
    <div class="header-bar">
      <div>
        <h1 class="brand-title">Danada Funds</h1>
        <p class="report-subtitle">Official Data Backup & Leads Export Report</p>
      </div>
      <div style="text-align: right;">
        <div style="font-size: 12px; font-weight: 700; color: #1E3A8A;">CONFIDENTIAL REPORT</div>
        <div style="font-size: 11px; color: #64748B;">Generated on: $nowFormatted</div>
      </div>
    </div>

    <div class="stats-grid">
''');

    summaryStats.forEach((key, val) {
      buffer.write('''
      <div class="stat-pill">
        <div class="stat-label">$key</div>
        <div class="stat-val">$val</div>
      </div>
''');
    });

    buffer.write('''
    </div>

    <table>
      <thead>
        <tr>
''');

    for (final h in headers) {
      buffer.write('          <th>${_escapeHtml(h)}</th>\n');
    }

    buffer.write('''
        </tr>
      </thead>
      <tbody>
''');

    for (final row in rows) {
      buffer.write('        <tr>\n');
      for (int i = 0; i < row.length; i++) {
        final cell = row[i];
        final header = i < headers.length ? headers[i].toLowerCase() : '';
        if (header.contains('status')) {
          final sClass = cell.toLowerCase().replaceAll(' ', '_');
          buffer.write('          <td><span class="status-badge status-$sClass">${_escapeHtml(cell)}</span></td>\n');
        } else {
          buffer.write('          <td>${_escapeHtml(cell)}</td>\n');
        }
      }
      buffer.write('        </tr>\n');
    }

    buffer.write('''
      </tbody>
    </table>
  </div>
</body>
</html>
''');

    return buffer.toString();
  }

  /// Complete raw JSON payload generator
  static String generateJsonBackup({
    required Map<String, dynamic> backupPayload,
  }) {
    return const JsonEncoder.withIndent('  ').convert(backupPayload);
  }

  static String _escapeCsvCell(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }

  static String _escapeTsvCell(String val) {
    return val.replaceAll('\t', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

