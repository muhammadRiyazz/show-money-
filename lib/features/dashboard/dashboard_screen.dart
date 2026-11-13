import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/network/api_service.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';
import 'package:agency_head/core/services/system_mode_service.dart';
import 'package:agency_head/features/sheets/widgets/analytics_progress_graph.dart';
import 'package:shimmer/shimmer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboardStats;
  List<dynamic> _sheets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemModeService.instance.addListener(_onModeChanged);
    _fetchDashboardData();
  }

  void _onModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SystemModeService.instance.removeListener(_onModeChanged);
    super.dispose();
  }

  bool get _isManager {
    final groupId = int.tryParse(_user?['group_id']?.toString() ?? '0') ?? 0;
    return groupId == 6 || groupId == 1;
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await AuthService.getUser();
      final userId = user != null ? int.tryParse(user['id'].toString()) ?? 3 : 3;
      final groupId = user != null ? int.tryParse(user['group_id'].toString()) ?? 6 : 6;
      final role = user?['group_name']?.toString();

      // Fetch sheets list and dashboard stats in parallel
      final results = await Future.wait([
        ApiService.getSheets(userId, groupId, role),
        ApiService.getDashboardStats(userId),
      ]);

      final sheetsRes = results[0];
      final statsRes = results[1];

      if (!mounted) return;

      Map<String, dynamic>? stats;
      if (statsRes['status'] == true && statsRes['data'] != null) {
        stats = statsRes['data'];
      }

      List<dynamic> sheetsList = [];
      if (sheetsRes['status'] == true && sheetsRes['data'] != null) {
        sheetsList = sheetsRes['data'];
      }

      setState(() {
        _user = user;
        _sheets = sheetsList;
        _dashboardStats = stats;
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

  String _formatCurrency(int amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)} K';
    }
    return '₹$amount';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isInactive = SystemModeService.instance.isInactiveMode;
    final hideData = SystemModeService.instance.shouldHideDataForUser(isManager: _isManager);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo/logo_icon_blue.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'Home Dashboard',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Manager HQ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Manager Mode Chip
          if (_isManager) ...[
            _buildManagerSystemModeChip(context, isInactive),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Backup & Export All Data',
              icon: const Icon(Icons.cloud_download_rounded, color: AppColors.primary),
              onPressed: () => context.push('/backup'),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: 'Refresh Dashboard',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _fetchDashboardData,
          ),
          if (isDesktop) ...[
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/sheets'),
                icon: const Icon(Icons.table_chart_rounded, size: 17),
                label: const Text('Open Sheets'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? _buildLoadingShimmer(isDesktop)
          : _error != null
              ? _buildErrorState()
              : hideData
                  ? _buildDataHiddenState()
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Welcome & Greeting Banner
                          _buildWelcomeBanner(isDesktop),
                          const SizedBox(height: 18),

                          // 2. The 5 Manager Financial KPI Boxes (Refactored)
                          _buildFinancialKpiBoxes(isDesktop),
                          const SizedBox(height: 18),

                          // 3. The Dedicated Monthly Performance & Progress Graph
                          _buildMonthlyAnalyticsSection(isDesktop),
                          const SizedBox(height: 20),

                          // 4. Quick Action Shortcuts & Workspaces Preview
                          _buildQuickActionsAndWorkspaces(isDesktop),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  // =========================================================================
  // WELCOME BANNER
  // =========================================================================
  Widget _buildWelcomeBanner(bool isDesktop) {
    final userName = _user?['name']?.toString() ?? 'Manager';
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
            Color(0xFF3B82F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dateStr.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back, $userName 👋',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Danada Loans Central Command: Live tracking for lead inflow, advance collections, and monthly pipeline growth.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 5 FINANCIAL KPI BOXES (MANAGER ONLY)
  // Total Leads | Today Leads | Today Advance | Total Advance | Total Amount Received
  // =========================================================================
  Widget _buildFinancialKpiBoxes(bool isDesktop) {
    final summary = _dashboardStats?['summary'];

    // 1. Total Leads
    int computedLeads = 0;
    for (var s in _sheets) {
      computedLeads += int.tryParse((s['total_rows'] ?? s['total_leads'] ?? '0').toString()) ?? 0;
    }
    final totalLeadsInt = int.tryParse(summary?['total_leads']?.toString() ?? '') ?? computedLeads;
    final totalLeadsStr = totalLeadsInt.toString();

    // 2. Today Leads
    final rawTodayLeads = summary?['today_leads'] ?? summary?['today_lead'] ?? summary?['new_today'];
    final todayLeadsInt = int.tryParse(rawTodayLeads?.toString() ?? '') ?? 0;
    final todayLeadsStr = todayLeadsInt.toString();

    // 3. Today Advance
    final rawTodayAdv = summary?['today_advance'] ?? summary?['today_advance_amount'] ?? summary?['advance_today'];
    final todayAdvInt = int.tryParse(rawTodayAdv?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
    final todayAdvStr = _formatCurrency(todayAdvInt);

    // 4. Total Advance
    final rawTotalAdv = summary?['total_advance'] ?? summary?['total_advance_amount'] ?? summary?['advance_total'];
    final totalAdvInt = int.tryParse(rawTotalAdv?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
    final totalAdvStr = _formatCurrency(totalAdvInt);

    // 5. Total Amount Received
    final rawTotalAmt = summary?['total_amount'] ??
        summary?['total_amount_received'] ??
        summary?['total_received'] ??
        summary?['gross_amount'];
    final totalAmtInt = int.tryParse(rawTotalAmt?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
    final totalAmtStr = _formatCurrency(totalAmtInt);

    final cards = [
      _buildKpiCard(
        title: 'Total Leads',
        value: totalLeadsStr,
        subtitle: 'Candidate lead pool',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
        badge: 'All Leads',
      ),
      _buildKpiCard(
        title: 'Today Leads',
        value: todayLeadsStr,
        subtitle: 'New inflow today',
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFFF59E0B),
        badge: 'Today',
      ),
      _buildKpiCard(
        title: 'Today Advance',
        value: todayAdvStr,
        subtitle: 'Collected today',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
        badge: 'Today',
      ),
      _buildKpiCard(
        title: 'Total Advance',
        value: totalAdvStr,
        subtitle: 'Cumulative advance pool',
        icon: Icons.payments_rounded,
        color: const Color(0xFF0EA5E9),
        badge: 'Advance',
      ),
      _buildKpiCard(
        title: 'Total Amount Received',
        value: totalAmtStr,
        subtitle: 'Gross revenue & loans',
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFF6366F1),
        badge: 'Total Funds',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: c,
          ),
        )).toList(),
      );
    } else {
      // Mobile 2 + 2 + 1 non-overflow layout
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 8),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 8),
              Expanded(child: cards[3]),
            ],
          ),
          const SizedBox(height: 8),
          cards[4],
        ],
      );
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MONTHLY VIEW & INFLOW TREND GRAPH SECTION
  // =========================================================================
  Widget _buildMonthlyAnalyticsSection(bool isDesktop) {
    final summary = _dashboardStats?['summary'];

    int computedLeads = 0;
    for (var s in _sheets) {
      computedLeads += int.tryParse((s['total_rows'] ?? s['total_leads'] ?? '0').toString()) ?? 0;
    }
    final totalLeadsInt = int.tryParse(summary?['total_leads']?.toString() ?? '') ?? computedLeads;

    final statusCounts = summary?['status_counts'] is Map
        ? Map<String, dynamic>.from(summary!['status_counts'])
        : <String, dynamic>{};

    final newCount = (statusCounts['new'] ?? (computedLeads > 0 ? computedLeads.toString() : '0')).toString();
    final paidCount = (statusCounts['paid'] ?? '0').toString();
    final newCountInt = int.tryParse(newCount) ?? 0;
    final paidCountInt = int.tryParse(paidCount) ?? 0;
    final inProgressCountInt = int.tryParse(
            statusCounts['in_progress']?.toString() ??
            statusCounts['contacted']?.toString() ??
            '') ??
        math.max(0, totalLeadsInt - newCountInt - paidCountInt);

    // Monthly data if provided by backend
    final rawMonthly = _dashboardStats?['monthly_stats'] ?? _dashboardStats?['months'] ?? summary?['monthly_stats'];
    List<Map<String, dynamic>>? monthlyStatsList;
    if (rawMonthly is List && rawMonthly.isNotEmpty) {
      monthlyStatsList = rawMonthly.map((item) {
        return {
          'month': (item['month'] ?? item['name'] ?? '').toString(),
          'short_month': (item['short_month'] ?? item['short'] ?? item['month'] ?? '').toString(),
          'leads': int.tryParse((item['leads'] ?? item['count'] ?? '0').toString()) ?? 0,
          'advance': int.tryParse((item['advance'] ?? item['advance_amount'] ?? '0').toString()) ?? 0,
          'is_current': item['is_current'] == true || item['current'] == true,
          'is_previous': item['is_previous'] == true || item['previous'] == true,
        };
      }).toList();
    }

    final rawTodayLeads = summary?['today_leads'] ?? summary?['today_lead'] ?? summary?['new_today'];
    final todayLeadsInt = int.tryParse(rawTodayLeads?.toString() ?? '') ?? 0;

    final rawTodayAdv = summary?['today_advance'] ?? summary?['today_advance_amount'] ?? summary?['advance_today'];
    final todayAdvInt = int.tryParse(rawTodayAdv?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;

    final rawTotalAdv = summary?['total_advance'] ?? summary?['total_advance_amount'] ?? summary?['advance_total'];
    final totalAdvInt = int.tryParse(rawTotalAdv?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;

    final rawTotalAmt = summary?['total_amount'] ??
        summary?['total_amount_received'] ??
        summary?['total_received'] ??
        summary?['gross_amount'];
    final totalAmtInt = int.tryParse(rawTotalAmt?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;

    return AnalyticsProgressGraph(
      totalLeads: totalLeadsInt,
      newCount: newCountInt,
      inProgressCount: inProgressCountInt,
      closedCount: paidCountInt,
      todayLeads: todayLeadsInt,
      todayAdvance: todayAdvInt,
      totalAdvance: totalAdvInt,
      totalAmount: totalAmtInt,
      monthlyData: monthlyStatsList,
      title: 'Monthly Performance & Inflow Analysis',
      subtitle: 'Month-by-month lead trends, advance inflow & conversion efficiency',
      initialExpanded: true,
    );
  }

  // =========================================================================
  // QUICK ACTIONS & WORKSPACES PREVIEW
  // =========================================================================
  Widget _buildQuickActionsAndWorkspaces(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Workspaces & Actions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/sheets'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('View All Sheets'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_sheets.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No sheets created yet. Tap "New Sheet" to start organizing leads.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : 1,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 110,
            ),
            itemCount: math.min(6, _sheets.length),
            itemBuilder: (context, index) {
              final s = _sheets[index];
              final id = s['id']?.toString() ?? '';
              final title = (s['title'] ?? s['name'] ?? 'Untitled Sheet').toString();
              final leadsCount = (s['total_rows'] ?? s['total_leads'] ?? '0').toString();

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.push('/sheet/$id'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$leadsCount Total Leads',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // =========================================================================
  // MANAGER SYSTEM ACCESS CHIP
  // =========================================================================
  Widget _buildManagerSystemModeChip(BuildContext context, bool isInactive) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isInactive ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInactive ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showSystemModeDialog(context, isInactive),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isInactive ? Icons.shield_outlined : Icons.shield_rounded,
                size: 14,
                color: isInactive ? AppColors.error : AppColors.success,
              ),
              const SizedBox(width: 5),
              Text(
                isInactive ? 'Inactive (Hidden)' : 'Active (Visible)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isInactive ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSystemModeDialog(BuildContext context, bool currentIsInactive) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentIsInactive ? 'Restore Full Access?' : 'Hide Staff Access?'),
        content: Text(
          currentIsInactive
              ? 'This will make all sheets and lead records visible to staff members.'
              : 'This will temporarily hide all sheets from non-manager staff.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SystemModeService.instance.toggleMode();
              setState(() {});
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SHIMMER LOADING
  // =========================================================================
  Widget _buildLoadingShimmer(bool isDesktop) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 16),
            Container(height: 110, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 16),
            Container(height: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
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
              _error ?? 'Error loading dashboard',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchDashboardData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataHiddenState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.visibility_off_rounded, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'Inactive Mode Enabled',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Dashboard and sheets are temporarily hidden.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
