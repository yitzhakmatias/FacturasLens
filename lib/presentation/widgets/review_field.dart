import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Standard outlined field for the review/edit form. Suspect values (empty or
/// clearly defaulted OCR output) get an amber marker so the user notices they
/// still need attention; editing the field is what clears the suspect state
/// (the caller recomputes `suspect` from the current text on every rebuild).
class ReviewField extends StatelessWidget {
  const ReviewField({
    super.key,
    required this.controller,
    required this.label,
    this.suspect = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.onTap,
    this.readOnly = false,
    this.suffixIcon,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final bool suspect;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? suffixIcon;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: label,
        helperText: suspect ? 'Verifica este dato' : null,
        helperStyle: const TextStyle(color: AppColors.review),
        prefixIcon: suspect
            ? const Icon(Icons.warning_amber_rounded, color: AppColors.review)
            : null,
        suffixIcon: suffixIcon,
        enabledBorder: suspect
            ? const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.review),
              )
            : null,
      ),
    );
  }
}
