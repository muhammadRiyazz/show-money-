import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:agency_head/core/theme/app_colors.dart';
import 'package:agency_head/core/services/auth_service.dart';
import 'package:agency_head/core/services/device_info_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;

  // Live on-screen API Logging state
  Map<String, dynamic>? _liveRequestPayload;
  Map<String, dynamic>? _liveResponsePayload;
  int? _requestDurationMs;
  int _activeLogTab = 0; // 0 = Request Payload, 1 = Response Data
  Timer? _redirectTimer;
  int _redirectCountdown = 3;
  bool _loginSucceeded = false;
  String? _targetRoute;

  @override
  void initState() {
    super.initState();
    _loadSavedEmailAndInitRequestPreview();
  }

  Future<void> _loadSavedEmailAndInitRequestPreview() async {
    final savedEmail = await AuthService.getRememberedEmail();
    final defaultEmail = (savedEmail != null && savedEmail.isNotEmpty)
        ? savedEmail
        : 'manager@gmail.com';

    if (mounted) {
      setState(() {
        _emailController.text = defaultEmail;
        _rememberMe = true;
      });
      _updateRequestPreview();
    }
  }

  Future<void> _updateRequestPreview() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final payload = await DeviceInfoService.buildLoginPayload(
      email: email.isNotEmpty ? email : 'manager@gmail.com',
      password: password.isNotEmpty ? password : '••••••••',
    );
    if (mounted) {
      setState(() {
        _liveRequestPayload = payload;
      });
    }
  }

  Future<void> _handleLogin() async {
    _redirectTimer?.cancel();
    setState(() {
      _errorMessage = null;
      _loginSucceeded = false;
      _liveResponsePayload = null;
      _requestDurationMs = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Build exact live payload to show on UI immediately
    final requestPayload = await DeviceInfoService.buildLoginPayload(
      email: email,
      password: password,
    );

    setState(() {
      _liveRequestPayload = requestPayload;
      _isLoading = true;
      _activeLogTab = 1; // switch to Response tab to see incoming result
    });

    final stopwatch = Stopwatch()..start();

    try {
      final response = await AuthService.login(email, password);
      stopwatch.stop();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _requestDurationMs = stopwatch.elapsedMilliseconds;
        _liveResponsePayload = response;
      });

      if (response['status'] == true) {
        await AuthService.setRememberedEmail(_rememberMe ? email : null);

        final user = await AuthService.getUser();
        final groupId = int.tryParse(user?['group_id']?.toString() ?? '0') ?? 0;
        final isManager = groupId == 6 || groupId == 1;
        final userName = user?['name']?.toString() ?? 'User';
        final route = isManager ? '/dashboard' : '/sheets';

        setState(() {
          _loginSucceeded = true;
          _targetRoute = route;
          _redirectCountdown = 3;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Welcome back, $userName!')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Allow 3 seconds so the user can inspect the live response log on the UI
        _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_redirectCountdown <= 1) {
            timer.cancel();
            context.go(route);
          } else {
            setState(() {
              _redirectCountdown--;
            });
          }
        });
      } else {
        final message = response['message']?.toString() ?? 'Invalid email or password.';
        setState(() {
          _errorMessage = message;
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _requestDurationMs = stopwatch.elapsedMilliseconds;
        _errorMessage = 'An error occurred during authentication.';
        _liveResponsePayload = {
          'status': false,
          'error': e.toString(),
          'message': 'Failed to connect to backend server.',
        };
      });
    }
  }

  void _copyToClipboard(String content, String label) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1040 : 540,
              ),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildLoginFormCard(),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 12,
                          child: _buildLiveLogCard(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLoginFormCard(),
                        const SizedBox(height: 20),
                        _buildLiveLogCard(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. LOGIN FORM CARD
  // =========================================================================
  Widget _buildLoginFormCard() {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand Logo & Heading
            Center(
              child: Image.asset(
                'assets/logo/logo_full_blue.png',
                height: 52,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo/logo_icon_blue.png', width: 32, height: 32),
                      const SizedBox(width: 8),
                      const Text(
                        'Danada Loans',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Financial Management & Lead Tracking Portal',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Role indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRolePill('Manager', Icons.shield_rounded, const Color(0xFF2563EB)),
                  Container(width: 1, height: 14, color: const Color(0xFFCBD5E1)),
                  _buildRolePill('Office Staff', Icons.business_center_rounded, const Color(0xFF7C3AED)),
                  Container(width: 1, height: 14, color: const Color(0xFFCBD5E1)),
                  _buildRolePill('Field Exec', Icons.directions_walk_rounded, const Color(0xFF059669)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF991B1B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Success Redirect Alert
            if (_loginSucceeded && _targetRoute != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Login verified! Redirecting in $_redirectCountdown s...',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _redirectTimer?.cancel();
                        context.go(_targetRoute!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                      ),
                      child: const Text('Go Now ➜', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Email Field
            const Text(
              'Email Address',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
              onChanged: (_) => _updateRequestPreview(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Please enter your email.';
                if (!value.contains('@') || !value.contains('.')) return 'Please enter a valid email.';
                return null;
              },
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
              decoration: InputDecoration(
                hintText: 'e.g. manager@gmail.com',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.primary, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Password Field
            const Text(
              'Password',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              onChanged: (_) => _updateRequestPreview(),
              validator: (value) => (value == null || value.isEmpty) ? 'Please enter your password.' : null,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 18),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Remember Me
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: _isLoading ? null : (val) => setState(() => _rememberMe = val ?? false),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
                  child: const Text('Remember email on this device', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sign In Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Authenticating...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : const Text('Sign In to Danada Loans', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),

            // Footer Info
            const Center(
              child: Text(
                'Danada Loans • Web App & Desktop Ready',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. LIVE ON-SCREEN API LOG CARD (REQUEST & RESPONSE)
  // =========================================================================
  Widget _buildLiveLogCard() {
    final statusColor = _isLoading
        ? const Color(0xFFF59E0B) // Amber
        : (_liveResponsePayload != null
            ? (_liveResponsePayload!['status'] == true
                ? const Color(0xFF10B981) // Green
                : const Color(0xFFEF4444)) // Red
            : const Color(0xFF64748B)); // Slate

    final statusText = _isLoading
        ? 'Sending Request...'
        : (_liveResponsePayload != null
            ? (_liveResponsePayload!['status'] == true
                ? '200 OK • Success'
                : 'Rejected / Failed')
            : 'Ready to Test');

    final requestJsonStr = _liveRequestPayload != null
        ? const JsonEncoder.withIndent('  ').convert({
            'url': 'https://tictechnologies.in/stage/showmoney/api/login',
            'method': 'POST',
            'headers': {'Content-Type': 'application/json'},
            'body': _liveRequestPayload,
          })
        : '// Type your email & password to generate payload...';

    final responseJsonStr = _liveResponsePayload != null
        ? const JsonEncoder.withIndent('  ').convert(_liveResponsePayload)
        : (_isLoading
            ? '// Waiting for backend response from server...\n// POST api/login in progress'
            : '// No response yet.\n// Tap "Sign In" above to execute API call.');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark terminal slate
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Console Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                // Terminal window buttons
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(width: 14),
                const Text(
                  'API Network Inspector',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                const Spacer(),
                // Live Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      if (_requestDurationMs != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${_requestDurationMs}ms)',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Request vs Response Tab Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1E293B).withValues(alpha: 0.6),
            child: Row(
              children: [
                _buildConsoleTabPill(
                  index: 0,
                  label: '📡 REQUEST LOG',
                  isActive: _activeLogTab == 0,
                  badge: _liveRequestPayload?['platform']?.toString().toUpperCase(),
                ),
                const SizedBox(width: 8),
                _buildConsoleTabPill(
                  index: 1,
                  label: '📥 RESPONSE LOG',
                  isActive: _activeLogTab == 1,
                  badge: _liveResponsePayload != null
                      ? (_liveResponsePayload!['status'] == true ? '200' : 'ERR')
                      : null,
                ),
                const Spacer(),
                // Copy current active tab button
                InkWell(
                  onTap: () {
                    final content = _activeLogTab == 0 ? requestJsonStr : responseJsonStr;
                    _copyToClipboard(content, _activeLogTab == 0 ? 'Request JSON' : 'Response JSON');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy_rounded, size: 12, color: Color(0xFFE2E8F0)),
                        SizedBox(width: 4),
                        Text('Copy', style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFFE2E8F0))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Monospace Code Log Window
          Container(
            height: 310,
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: SelectableText(
                _activeLogTab == 0 ? requestJsonStr : responseJsonStr,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.45,
                  color: _activeLogTab == 0
                      ? const Color(0xFF38BDF8) // Cyan for request
                      : (_liveResponsePayload?['status'] == true
                          ? const Color(0xFF4ADE80) // Green for successful response
                          : const Color(0xFFF87171)), // Red for failed response
                ),
              ),
            ),
          ),

          // Log Summary Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _activeLogTab == 0
                        ? 'Payload sent to POST api/login with platform="${_liveRequestPayload?['platform'] ?? 'web'}"'
                        : (_liveResponsePayload != null
                            ? 'Server Message: "${_liveResponsePayload!['message'] ?? 'N/A'}"'
                            : 'Ready. Submit credentials to view live response.'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleTabPill({
    required int index,
    required String label,
    required bool isActive,
    String? badge,
  }) {
    return InkWell(
      onTap: () => setState(() => _activeLogTab = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRolePill(String label, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
