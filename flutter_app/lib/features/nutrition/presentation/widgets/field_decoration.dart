import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';

/// The standard bordered/filled text-field look used across every Log Food
/// sub-sheet (Manual entry, Browse foods' edit sheet) — was copy-pasted
/// identically in three State classes.
InputDecoration appFieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: T.faint),
      filled: true,
      fillColor: T.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: T.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: T.accent)),
    );
