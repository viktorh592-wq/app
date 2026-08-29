import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';

/// Lime search bar — matches screenshots (design_tokens.md).
class SearchBarV2 extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearchTap;
  final bool autofocus;

  const SearchBarV2({
    super.key,
    this.controller,
    this.hintText = 'Введите для поиска',
    this.onChanged,
    this.onSearchTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
      decoration: BoxDecoration(
        color: DesignTokens.limeAccent.withOpacity(0.85),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        style: DesignTokens.body(),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: DesignTokens.body(color: DesignTokens.textSecondary),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(
              Icons.search,
              color: DesignTokens.textPrimary,
              size: 24,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
