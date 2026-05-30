import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LinearStyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final bool autofocus;

  const LinearStyledTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixIcon,
    this.prefixIcon,
    this.validator,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: LinearColors.textSecondary),
        hintText: hintText,
        hintStyle: const TextStyle(color: LinearColors.textQuaternary),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: LinearColors.fillSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinearRadius.standard),
          borderSide: const BorderSide(color: LinearColors.borderStandard),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinearRadius.standard),
          borderSide: const BorderSide(color: LinearColors.borderStandard),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LinearRadius.standard),
          borderSide: const BorderSide(
            color: LinearColors.accentInteractive,
            width: 2,
          ),
        ),
      ),
      validator: validator,
    );
  }
}

class HostPortRow extends StatelessWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final String hostLabel;
  final String portLabel;
  final String? hostHint;
  final String? portHint;
  final String? Function(String?)? hostValidator;
  final String? Function(String?)? portValidator;

  const HostPortRow({
    super.key,
    required this.hostController,
    required this.portController,
    required this.hostLabel,
    this.portLabel = '端口',
    this.hostHint,
    this.portHint,
    this.hostValidator,
    this.portValidator,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: LinearStyledTextField(
            controller: hostController,
            labelText: hostLabel,
            hintText: hostHint,
            validator: hostValidator,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LinearStyledTextField(
            controller: portController,
            labelText: portLabel,
            hintText: portHint,
            keyboardType: TextInputType.number,
            validator: portValidator ??
                (value) {
                  if (value == null || value.isEmpty) return '请输入端口';
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return '端口号无效';
                  }
                  return null;
                },
          ),
        ),
      ],
    );
  }
}

String? portValidator(String? value, String label) {
  if (value == null || value.isEmpty) return '请输入$label';
  final port = int.tryParse(value);
  if (port == null || port < 1 || port > 65535) return '端口号无效';
  return null;
}
