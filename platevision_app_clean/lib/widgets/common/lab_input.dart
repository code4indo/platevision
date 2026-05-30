import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:platevision_ai/theme/app_colors.dart';
import 'package:platevision_ai/theme/app_spacing.dart';

/// Custom text input styled like lab instrument inputs.
///
/// Features a dark recessed background, monospace font, cyan accent focus
/// ring, optional prefix icon, and optional suffix text/unit.
class LabInput extends StatefulWidget {
  /// Label text displayed above the input.
  final String? label;

  /// Hint text displayed when the input is empty.
  final String? hint;

  /// Text editing controller.
  final TextEditingController? controller;

  /// Optional icon displayed at the start of the input.
  final IconData? prefixIcon;

  /// Optional suffix text or unit displayed at the end.
  final String? suffixText;

  /// Keyboard type for the input.
  final TextInputType? keyboardType;

  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;

  /// Form field validator.
  final FormFieldValidator<String>? validator;

  /// Whether the field is obscured (e.g., for passwords).
  final bool obscureText;

  /// Maximum number of lines.
  final int maxLines;

  /// Whether the field is enabled.
  final bool enabled;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Focus node for external control.
  final FocusNode? focusNode;

  /// Text capitalization.
  final TextCapitalization textCapitalization;

  /// Callback when the field is submitted.
  final ValueChanged<String>? onFieldSubmitted;

  const LabInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixText,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.obscureText = false,
    this.maxLines = 1,
    this.enabled = true,
    this.inputFormatters,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.onFieldSubmitted,
  });

  @override
  State<LabInput> createState() => _LabInputState();
}

class _LabInputState extends State<LabInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          _buildLabel(),
          const SizedBox(height: AppSpacing.xs + 2),
        ],

        // Input field
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          validator: widget.validator,
          obscureText: widget.obscureText,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
            letterSpacing: 0.5,
            color: widget.enabled
                ? AppColors.textPrimary
                : AppColors.disabled,
          ),
          cursorColor: AppColors.accentPrimary,
          cursorWidth: 2,
          cursorHeight: 18,
          decoration: _buildInputDecoration(),
        ),
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Text(
          widget.label!.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: _isFocused
                ? AppColors.accentPrimary
                : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration() {
    // Determine border colors based on focus state
    final borderColor = _isFocused
        ? AppColors.borderAccent
        : AppColors.borderSubtle;
    final borderWidth = _isFocused ? 2.0 : 1.0;

    return InputDecoration(
      filled: true,
      fillColor: widget.enabled ? AppColors.bgInput : AppColors.disabledBackground,
      hoverColor: AppColors.bgCardHover,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPaddingH,
        vertical: widget.maxLines > 1 ? AppSpacing.md : AppSpacing.sm + 4,
      ),
      hintText: widget.hint,
      hintStyle: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
      // Prefix icon
      prefixIcon: widget.prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.sm,
              ),
              child: Icon(
                widget.prefixIcon,
                size: 18,
                color: _isFocused
                    ? AppColors.accentPrimary
                    : AppColors.textTertiary,
              ),
            )
          : null,
      prefixIconConstraints: widget.prefixIcon != null
          ? const BoxConstraints(minWidth: 42, minHeight: 0)
          : null,
      // Suffix text
      suffixText: widget.suffixText,
      suffixStyle: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _isFocused
            ? AppColors.accentPrimary.withOpacity(0.7)
            : AppColors.textTertiary,
        letterSpacing: 0.5,
      ),
      // Borders
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(
          color: AppColors.borderSubtle,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(
          color: AppColors.borderAccent,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(
          color: AppColors.borderError,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 2,
        ),
      ),
      // Focus ring glow effect via box shadow
      isDense: false,
      isCollapsed: false,
      errorStyle: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.error,
      ),
    );
  }
}
