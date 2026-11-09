import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/network/api_service.dart';
import 'package:agency_head/core/models/all_history_item.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';
import 'package:shimmer/shimmer.dart';

class AllHistoryScreen extends StatefulWidget {
  const AllHistoryScreen({super.key});

  @override
  State<AllHistoryScreen> createState() => _AllHistoryScreenState();
}

class _AllHistoryScreenState extends State<AllHistoryScreen> {
  List<AllHistoryItem> _historyItems = [];
  bool _isLoading = true;
  String? _error;
  int _totalRecords = 0;

  // Search and Filter states
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSheetFilter = 'All';
  String _selectedActionFilter = 'all'; // all, updated, added, cleared

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getAllHistory();
      if (!mounted) return;

      if (response['status'] == true && response['data'] != null) {
        final rawList = response['data'] as List;
        final items = rawList
            .map((item) => AllHistoryItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        setState(() {
          _historyItems = items;
          _totalRecords = int.tryParse(response['total_records']?.toString() ?? '') ?? items.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load system history';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<String> get _distinctSheets {
    final set = <String>{};
    for (var item in _historyItems) {
      if (item.sheetTitle.trim().isNotEmpty) {
        set.add(item.sheetTitle.trim());
      }
    }
    return ['All', ...set.toList()..sort()];
  }

  List<AllHistoryItem> get _filteredItems {
    var list = _historyItems;

    // Filter by Sheet
    if (_selectedSheetFilter != 'All') {
      list = list.where((item) => item.sheetTitle.trim() == _selectedSheetFilter).toList();
    }

    // Filter by Action
    if (_selectedActionFilter == 'added') {
      list = list.where((item) => item.oldValue.isEmpty && item.newValue.isNotEmpty).toList();
    } else if (_selectedActionFilter == 'updated') {
      list = list.where((item) => item.oldValue.isNotEmpty && item.newValue.isNotEmpty).toList();
    } else if (_selectedActionFilter == 'cleared') {
      list = list.where((item) => item.oldValue.isNotEmpty && item.newValue.isEmpty).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((item) {
        return item.userName.toLowerCase().contains(q) ||
            item.sheetTitle.toLowerCase().contains(q) ||
            item.columnName.toLowerCase().contains(q) ||
            item.oldValue.toLowerCase().contains(q) ||
            item.newValue.toLowerCase().contains(q) ||
            item.summaryText.toLowerCase().contains(q) ||
            item.formattedDate.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  int get _uniqueUsersCount {
    final users = <String>{};
    for (var h in _historyItems) {
      if (h.userName.isNotEmpty) users.add(h.userName);
    }
    return users.length;
  }

  int get _uniqueSheetsCount {
    final sheets = <int>{};
    for (var h in _historyItems) {
      if (h.sheetId > 0) sheets.add(h.sheetId);
    }
    return sheets.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Audit & History',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 10),
            if (!_isLoading && _historyItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '$_totalRecords logs',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh History',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _fetchHistory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveContainer(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Summary Stats Banner
            _buildSummaryStats(isDesktop),
            const SizedBox(height: 16),

            // Search & Filter Card
            _buildSearchAndFilterCard(isDesktop),
            const SizedBox(height: 16),

            // Main List View of History Logs
            Expanded(
              child: _isLoading
                  ? _buildShimmer(isDesktop)
                  : _error != null
                      ? _buildErrorState()
                      : filtered.isEmpty
                          ? _buildEmptyState()
                          : _buildHistoryListView(filtered, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TOP KPI STATS SUMMARY
  // =========================================================================
  Widget _buildSummaryStats(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildKpiCard(
            title: 'Total Edits',
            value: _totalRecords.toString(),
            subtitle: 'Recorded modifications',
            icon: Icons.track_changes_rounded,
            color: const Color(0xFF3B82F6),
          ),
          _buildKpiCard(
            title: 'Sheets Affected',
            value: _uniqueSheetsCount.toString(),
            subtitle: 'Spreadsheet workbooks',
            icon: Icons.table_chart_rounded,
            color: const Color(0xFF10B981),
          ),
          _buildKpiCard(
            title: 'Team Contributors',
            value: _uniqueUsersCount.toString(),
            subtitle: 'Managers & executives',
            icon: Icons.group_rounded,
            color: const Color(0xFFF59E0B),
          ),
          _buildKpiCard(
            title: 'Latest Update',
            value: _historyItems.isNotEmpty ? _historyItems.first.formattedDate.split(',').first : 'None',
            subtitle: _historyItems.isNotEmpty ? _historyItems.first.userName : 'No records',
            icon: Icons.access_time_filled_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ];

        if (isDesktop) {
          return Row(
            children: cards
                .map((card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: card,
                      ),
                    ))
                .toList(),
          );
        }

        // Mobile / Tablet 2x2 grid
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards.map((card) {
            final cardWidth = (constraints.maxWidth - 10) / 2;
            return SizedBox(width: cardWidth, child: card);
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SEARCH & FILTER CONTROLS
  // =========================================================================
  Widget _buildSearchAndFilterCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by user, sheet, column, values, or summary...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
            },
          ),
          const SizedBox(height: 12),

          // Filters Row: Sheet Dropdown + Action Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Sheet Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSheetFilter,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      items: _distinctSheets.map((sheetTitle) {
                        return DropdownMenuItem<String>(
                          value: sheetTitle,
                          child: Text(
                            sheetTitle == 'All' ? 'All Worksheets' : 'Sheet: $sheetTitle',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedSheetFilter = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Action Filter Chips
                _buildActionChip('All Changes', 'all', Icons.all_inclusive_rounded),
                const SizedBox(width: 6),
                _buildActionChip('Modified', 'updated', Icons.edit_note_rounded),
                const SizedBox(width: 6),
                _buildActionChip('Added New', 'added', Icons.add_circle_outline_rounded),
                const SizedBox(width: 6),
                _buildActionChip('Cleared', 'cleared', Icons.remove_circle_outline_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, String value, IconData icon) {
    final isSelected = _selectedActionFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedActionFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HISTORY LIST VIEW
  // =========================================================================
  Widget _buildHistoryListView(List<AllHistoryItem> items, bool isDesktop) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildHistoryCard(items[index], isDesktop);
      },
    );
  }

  Widget _buildHistoryCard(AllHistoryItem item, bool isDesktop) {
    final hasOldValue = item.oldValue.trim().isNotEmpty;
    final hasNewValue = item.newValue.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: User Avatar, Name, Sheet Badge, Timestamp
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  item.userName.isNotEmpty ? item.userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.userName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Log #${item.id}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          item.formattedDate.isNotEmpty ? item.formattedDate : item.createdAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sheet Pill Badge
              InkWell(
                onTap: item.sheetId > 0 ? () => context.push('/sheet/${item.sheetId}') : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_chart_rounded, size: 13, color: Color(0xFF2563EB)),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          item.sheetTitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.rowIndex > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '#${item.rowIndex}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Middle: Column Changed & Old vs New Values Comparison Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Column Name Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.view_column_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        item.columnName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Old Value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OLD VALUE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasOldValue ? item.oldValue : '(empty)',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: hasOldValue ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                          decoration: hasOldValue ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                ),

                // New Value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW VALUE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasNewValue ? item.newValue : '(empty)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: hasNewValue ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom: Natural language Summary Text
          if (item.summaryText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.summaryText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // STATES: ERROR, EMPTY, SHIMMER
  // =========================================================================
  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchHistory,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No logs matching search' : 'No history logs found',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cell modifications, lead additions, and status edits will be recorded here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(bool isDesktop) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

