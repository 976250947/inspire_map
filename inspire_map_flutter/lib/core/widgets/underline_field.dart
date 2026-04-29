// Editorial underline input field.
// Bottom-border style with optional right action text.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class UnderlineField extends StatelessWidget {
  final String label;
  final String? placeholder;
  final String? actionText;
  final VoidCallback? onAction;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;

  const UnderlineField({
    super.key,
    required this.label,
    this.placeholder,
    this.actionText,
    this.onAction,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.08 * 11,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: AppColors.inkFaint,
                  ),
                  contentPadding: EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                    right: actionText != null ? 80 : 0,
                  ),
                  isDense: true,
                  filled: false,
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.rule),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.rule),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.ink),
                  ),
                ),
              ),
              if (actionText != null)
                GestureDetector(
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      actionText!.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.08 * 11,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
