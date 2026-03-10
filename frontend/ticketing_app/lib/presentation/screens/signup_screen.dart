import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/state/admin_state.dart';
import '../../domain/state/auth_state.dart';
import '../../domain/state/booking_state.dart';
import '../../domain/state/chat_state.dart';
import '../animations/fade_slide_transition.dart';
import '../widgets/common/gradient_button.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';

enum _AccountType { user, admin }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  _AccountType _accountType = _AccountType.user;

  bool get _isAdmin => _accountType == _AccountType.admin;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchType(_AccountType type) {
    if (_accountType == type) return;
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmController.clear();
    context.read<AuthState>().clearError();
    context.read<AdminState>().clearError();
    setState(() => _accountType = type);
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isAdmin) {
      final adminState = context.read<AdminState>();
      adminState.clearError();
      final ok = await adminState.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          (route) => false,
        );
      }
    } else {
      final auth = context.read<AuthState>();
      auth.clearError();
      final ok = await auth.signup(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      if (ok) {
        context.read<BookingState>().setAuthToken(auth.token);
        context.read<BookingState>().setCurrentUserId(auth.userId);
        context.read<ChatState>().setAuthToken(auth.token);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accentColor = _isAdmin ? AppColors.warning : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated ambient glow
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.2,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.22),
                      accentColor.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    FadeSlideTransition(
                      duration: const Duration(milliseconds: 700),
                      child: Column(
                        children: [
                          Text(
                            'Create Account',
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isAdmin
                                  ? 'Register as Admin to manage events'
                                  : 'Join TicketBot and start booking',
                              key: ValueKey(_isAdmin),
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Role Selector ──────────────────────────────────────
                    FadeSlideTransition(
                      duration: const Duration(milliseconds: 700),
                      delay: const Duration(milliseconds: 60),
                      child: _RoleSelector(
                        selected: _accountType,
                        onChanged: _switchType,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Form card ──────────────────────────────────────────
                    FadeSlideTransition(
                      duration: const Duration(milliseconds: 700),
                      delay: const Duration(milliseconds: 100),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Form(
                            key: _formKey,
                            child: _isAdmin
                                ? _buildAdminFields()
                                : _buildUserFields(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Sign in link ───────────────────────────────────────
                    FadeSlideTransition(
                      duration: const Duration(milliseconds: 700),
                      delay: const Duration(milliseconds: 300),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.read<AuthState>().clearError();
                              context.read<AdminState>().clearError();
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Sign In',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User fields ───────────────────────────────────────────────────────────

  Widget _buildUserFields() {
    return Consumer<AuthState>(
      builder: (_, auth, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            capitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _field(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          const SizedBox(height: 16),
          _field(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            suffixIcon: _visibilityBtn(
              _obscurePassword,
              () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _field(
            controller: _confirmController,
            label: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            suffixIcon: _visibilityBtn(
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          _errorBox(auth.errorMessage),
          const SizedBox(height: 28),
          GradientButton(
            text: 'Create User Account',
            onPressed: auth.isLoading ? null : _handleSignup,
            isLoading: auth.isLoading,
            icon: Icons.arrow_forward_rounded,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  // ── Admin fields ──────────────────────────────────────────────────────────

  Widget _buildAdminFields() {
    return Consumer<AdminState>(
      builder: (_, admin, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Admin accounts have full access to manage events, venues and analytics.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _emailController,
            label: 'Admin Email',
            icon: Icons.admin_panel_settings_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
            accentColor: AppColors.warning,
          ),
          const SizedBox(height: 16),
          _field(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            suffixIcon: _visibilityBtn(
              _obscurePassword,
              () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            accentColor: AppColors.warning,
            validator: (v) {
              if (v == null || v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _field(
            controller: _confirmController,
            label: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            suffixIcon: _visibilityBtn(
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            accentColor: AppColors.warning,
            validator: (v) {
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          _errorBox(admin.error),
          const SizedBox(height: 28),
          GradientButton(
            text: 'Create Admin Account',
            onPressed: admin.isLoading ? null : _handleSignup,
            isLoading: admin.isLoading,
            gradient: AppColors.warningGradient,
            icon: Icons.shield_rounded,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final valid =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            .hasMatch(v.trim());
    if (!valid) return 'Enter a valid email';
    return null;
  }

  Widget _visibilityBtn(bool obscure, VoidCallback onTap) {
    return IconButton(
      icon: Icon(obscure
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined),
      onPressed: onTap,
    );
  }

  Widget _errorBox(String? msg) {
    if (msg == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    Color accentColor = AppColors.primary,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      autocorrect: false,
      style: AppTextStyles.body1,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

// ── Role Selector Widget ──────────────────────────────────────────────────

class _RoleSelector extends StatelessWidget {
  final _AccountType selected;
  final void Function(_AccountType) onChanged;

  const _RoleSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          _tab(_AccountType.user, Icons.person_rounded, 'User Account',
              AppColors.primary),
          _tab(_AccountType.admin, Icons.shield_rounded, 'Admin Account',
              AppColors.warning),
        ],
      ),
    );
  }

  Widget _tab(
      _AccountType type, IconData icon, String label, Color color) {
    final active = selected == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                active ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(color: color.withValues(alpha: 0.4))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? color : AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.h4.copyWith(
                  color: active ? color : AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}