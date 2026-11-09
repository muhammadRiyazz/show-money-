import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/services/system_mode_service.dart';
import 'package:agency_head/core/responsive/responsive_layout.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemModeService.instance.addListener(_onModeChanged);
    _loadUser();
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

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  String _getRoleTitle() {
    if (_user == null) return 'Agency Staff';
    final name = _user!['group_name']?.toString() ?? '';
    if (name.isNotEmpty) return name;

    final groupId = int.tryParse(_user!['group_id']?.toString() ?? '0') ?? 0;
    if (groupId == 6 || groupId == 1) return 'Agency Head / Manager';
    if (groupId == 5) return 'Office Executive';
    if (groupId == 4) return 'Field Executive';
    if (groupId == 2) return 'Accounts Staff';
    return 'Staff Member';
  }

  Color _getRoleColor() {
    final groupId = int.tryParse(_user?['group_id']?.toString() ?? '0') ?? 0;
    if (groupId == 6 || groupId == 1) return AppColors.primary;
    if (groupId == 5) return AppColors.accent;
    if (groupId == 4) return const Color(0xFFF59E0B);
    if (groupId == 2) return AppColors.success;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = _user?['name'] ?? 'Agency User';
    final email = _user?['email'] ?? 'user@agency.com';
    final roleTitle = _getRoleTitle();
    final roleColor = _getRoleColor();
    final createdAt = (_user?['created_at']?.toString().split(' ').first) ?? 'Active';
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile & Account',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          maxWidth: 680,
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: roleColor.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: roleColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, size: 14, color: roleColor),
                                const SizedBox(width: 6),
                                Text(
                                  roleTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: roleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Account Details Info
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      title: 'Role Assignment',
                      subtitle: roleTitle,
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                    _buildInfoTile(
                      icon: Icons.calendar_today_rounded,
                      title: 'Member Since',
                      subtitle: createdAt,
                    ),
                    const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                    _buildInfoTile(
                      icon: Icons.verified_rounded,
                      title: 'Account Status',
                      subtitle: 'Active & Verified',
                      trailingColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. System Administration & Inactive Mode Control
              _buildSystemAccessControlCard(context),
              const SizedBox(height: 24),

              // 4. Logout Action
              OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out of Agency Head'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? trailingColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: trailingColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SYSTEM ACCESS & INACTIVE MODE CONTROL (Manager Option)
  // =========================================================================
  Widget _buildSystemAccessControlCard(BuildContext context) {
    return ListenableBuilder(
      listenable: SystemModeService.instance,
      builder: (context, _) {
        final modeService = SystemModeService.instance;
        final isInactive = modeService.isInactiveMode;
        final isManager = _isManager;

        if (isManager) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isInactive ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                width: isInactive ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isInactive
                      ? const Color(0xFFD97706).withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isInactive
                                ? const Color(0xFFFEF3C7)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isInactive ? Icons.visibility_off_rounded : Icons.admin_panel_settings_rounded,
                            color: isInactive ? const Color(0xFFD97706) : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'System Access & Privacy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isInactive ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isInactive ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInactive ? Icons.circle : Icons.check_circle_rounded,
                            size: 10,
                            color: isInactive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isInactive ? 'Inactive (Data Hidden)' : 'Active (Visible)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isInactive ? const Color(0xFF92400E) : const Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Disable Full Access (Inactive Mode)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                const Text(
                  'When enabled, all spreadsheets, candidate leads, and dashboard metrics are completely hidden from staff and field executives.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isInactive ? 'Mode: Data Hidden' : 'Mode: Full Access Visible',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isInactive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: modeService.isLoading
                          ? null
                          : () => _showSystemModeDialog(context, isCurrentlyInactive: isInactive),
                      icon: modeService.isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              isInactive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 15,
                            ),
                      label: Text(
                        isInactive ? 'Restore Full Access' : 'Disable Full Access',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInactive ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.push('/history'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'View All Audit & Change History (700+ records)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Non-managers should never see any inactive/deactivated notice
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _showSystemModeDialog(BuildContext context, {required bool isCurrentlyInactive}) async {
    final willEnableInactive = !isCurrentlyInactive;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              willEnableInactive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: willEnableInactive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                willEnableInactive ? 'Disable Full Access?' : 'Enable Full Access?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          willEnableInactive
              ? 'Are you sure you want to activate Inactive Mode?\n\nAll spreadsheet records, candidate leads, and dashboard metrics will be completely hidden for field executives and staff members.'
              : 'Are you sure you want to restore Full Access?\n\nAll spreadsheet records, candidate leads, and dashboard metrics will become visible to authorized staff members.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willEnableInactive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willEnableInactive ? 'Disable Access (Hide Data)' : 'Enable Access (Show Data)'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await SystemModeService.instance.setMode(willEnableInactive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  willEnableInactive ? Icons.visibility_off_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    success
                        ? (willEnableInactive
                            ? 'System switched to Inactive Mode (Data Hidden)'
                            : 'Full data access restored (Data Visible)')
                        : 'Failed to update system mode.',
                  ),
                ),
              ],
            ),
            backgroundColor: willEnableInactive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
