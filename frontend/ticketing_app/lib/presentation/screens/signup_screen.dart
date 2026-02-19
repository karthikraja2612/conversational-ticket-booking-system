import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/state/auth_state.dart';
import '../animations/fade_slide_transition.dart';
import '../widgets/common/gradient_button.dart';
import 'home_screen.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Enhanced gradient background
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.2,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.22),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.08,
            right: -size.width * 0.15,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryDark.withValues(alpha: 0.2),
                      AppColors.primaryDark.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      FadeSlideTransition(
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Header
                          FadeSlideTransition(
                            duration: const Duration(milliseconds: 700),
                            delay: const Duration(milliseconds: 100),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.15),
                                        AppColors.primary.withValues(alpha: 0.08),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person_add_rounded,
                                    color: AppColors.primary,
                                    size: 42,
                                  ),
                                ),
                                const SizedBox(height: 24),
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
                                Text(
                                  'Join us and start booking amazing events',
                                  style: AppTextStyles.body2.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Form Card
                          FadeSlideTransition(
                            duration: const Duration(milliseconds: 700),
                            delay: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Consumer<AuthState>(
                                builder: (context, auth, _) {
                                  return Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        _buildTextField(
                                          controller: _nameController,
                                          label: 'Full Name',
                                          hint: 'John Doe',
                                          icon: Icons.person_outline_rounded,
                                          validator: (v) {
                                            if (v == null || v.trim().length < 2) {
                                              return 'Name must be at least 2 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 18),
                                        _buildTextField(
                                          controller: _emailController,
                                          label: 'Email Address',
                                          hint: 'your.email@example.com',
                                          icon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Email is required';
                                            }
                                            if (!RegExp(
                                                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                                .hasMatch(v.trim())) {
                                              return 'Enter a valid email';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 18),
                                        _buildTextField(
                                          controller: _passwordController,
                                          label: 'Password',
                                          hint: '••••••••',
                                          icon: Icons.lock_outline_rounded,
                                          isPassword: true,
                                          obscure: _obscurePassword,
                                          onToggleObscure: () => setState(
                                              () => _obscurePassword = !_obscurePassword),
                                          validator: (v) {
                                            if (v == null || v.isEmpty) {
                                              return 'Password is required';
                                            }
                                            if (v.length < 6) {
                                              return 'Minimum 6 characters required';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 18),
                                        _buildTextField(
                                          controller: _confirmController,
                                          label: 'Confirm Password',
                                          hint: '••••••••',
                                          icon: Icons.lock_outline_rounded,
                                          isPassword: true,
                                          obscure: _obscureConfirm,
                                          onToggleObscure: () => setState(
                                              () => _obscureConfirm = !_obscureConfirm),
                                          validator: (v) {
                                            if (v != _passwordController.text) {
                                              return 'Passwords do not match';
                                            }
                                            return null;
                                          },
                                        ),
                                        
                                        if (auth.phase == AuthPhase.error &&
                                            auth.errorMessage != null)
                                          Container(
                                            margin: const EdgeInsets.only(top: 16),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.error.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.error_outline_rounded,
                                                  color: AppColors.error,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    auth.errorMessage!,
                                                    style: AppTextStyles.caption.copyWith(
                                                      color: AppColors.error,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        
                                        const SizedBox(height: 32),
                                        GradientButton(
                                          text: 'Create Account',
                                          onPressed: auth.isLoading ? null : _handleSignup,
                                          isLoading: auth.isLoading,
                                          icon: Icons.arrow_forward_rounded,
                                          width: double.infinity,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 28),
                          
                          // Sign In Link
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
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.15),
                                          AppColors.primary.withValues(alpha: 0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Sign In',
                                      style: AppTextStyles.body2.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? obscure : false,
          keyboardType: keyboardType,
          validator: validator,
          style: AppTextStyles.body1.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body2.copyWith(
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 12),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceLight.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.borderSubtle.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.borderSubtle.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
        ),
      ],
    );
  }
}