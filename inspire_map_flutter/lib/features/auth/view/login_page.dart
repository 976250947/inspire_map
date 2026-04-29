import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../viewmodel/auth_viewmodel.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.length != 11) {
      _showMessage('请输入 11 位手机号');
      return;
    }
    if (password.length < 6) {
      _showMessage('密码至少需要 6 位');
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    final success = _isRegisterMode
        ? await notifier.register(phone: phone, password: password)
        : await notifier.login(phone: phone, password: password);

    if (!mounted) {
      return;
    }

    if (success) {
      context.go(AppRouter.onboarding);
      return;
    }

    _showMessage(ref.read(authProvider).errorMessage ?? '登录失败，请稍后重试');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Text(
                  _isRegisterMode ? 'STEP 00 · 注册' : 'STEP 00 · 登录',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isRegisterMode ? '创建账号' : '欢迎回来',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode ? '注册后即可保存你的足迹和行程灵感' : '绑定手机号，保存你的足迹和行程',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 40),
                _buildLabel('手机号'),
                const SizedBox(height: 10),
                _buildUnderlineField(
                  controller: _phoneController,
                  hintText: '输入手机号',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                _buildLabel('密码'),
                const SizedBox(height: 10),
                _buildUnderlineField(
                  controller: _passwordController,
                  hintText: _isRegisterMode ? '设置密码' : '输入密码',
                  obscureText: true,
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.34),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          authState.isLoading
                              ? '处理中...'
                              : (_isRegisterMode ? '确认注册' : '确认登录'),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.paper,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                      });
                    },
                    child: Text(
                      _isRegisterMode ? '没有账号？立即登录' : '没有账号？立即注册',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppRouter.onboarding),
                    child: Text(
                      '跳过，先逛逛',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.rule)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '其他登录方式',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.rule)),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialLoginButton(
                      svgAsset: 'assets/icons/wechat.svg',
                      label: '微信',
                      backgroundColor: Color(0xFFE7F7EC),
                      iconColor: Color(0xFF31C15B),
                    ),
                    SizedBox(width: 28),
                    _SocialLoginButton(
                      svgAsset: 'assets/icons/qq.svg',
                      label: 'QQ',
                      backgroundColor: Color(0xFFE8F5FD),
                      iconColor: Color(0xFF2FA8F7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.inkSoft,
      ),
    );
  }

  Widget _buildUnderlineField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? prefixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 13,
          color: AppColors.inkFaint,
        ),
        prefixText: prefixText == null ? null : '$prefixText  ',
        prefixStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.inkSoft,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.inkMid, width: 1.2),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final String svgAsset;
  final String label;
  final Color backgroundColor;
  final Color iconColor;

  const _SocialLoginButton({
    required this.svgAsset,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              svgAsset,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: AppColors.inkFaint,
          ),
        ),
      ],
    );
  }
}
