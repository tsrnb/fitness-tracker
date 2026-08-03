import 'package:flutter/material.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/widgets/atoms.dart';

/// A labeled text field (or, when [date] is set, a tap-to-pick date row) —
/// the standard editable-value row used across every Settings sub-page.
Widget settingsTextField(
  BuildContext context, {
  required String label,
  required String value,
  required ValueChanged<String> onChange,
  bool num = false,
  bool date = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        date
            ? GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(value) ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) onChange(picked.toIso8601String().substring(0, 10));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: T.surface2, border: Border.all(color: T.line), borderRadius: BorderRadius.circular(12)),
                  child: Text(value, style: mono(fontSize: 16, color: T.text)),
                ),
              )
            : TextField(
                controller: TextEditingController.fromValue(TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length))),
                onChanged: onChange,
                keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                style: TextStyle(color: T.text, fontSize: 16, fontFamily: num ? monoFont : null),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: T.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: T.accent)),
                ),
              ),
      ],
    ),
  );
}

/// A labeled row of pill options for a string-valued setting.
Widget settingsSegmented(String label, String value, List<MapEntry<String, String>> opts, ValueChanged<String> onChange) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opts.map((o) {
            final active = value == o.key;
            return GestureDetector(
              onTap: () => onChange(o.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? T.hero : T.surface2,
                  border: Border.all(color: active ? T.hero : T.line),
                  borderRadius: BorderRadius.circular(T.pill),
                ),
                child: Text(o.value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.text)),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

/// Same as [settingsSegmented] but for an int-valued setting formatted per-option.
Widget settingsSegmentedInt(String label, int value, List<int> opts, String Function(int) fmt, ValueChanged<int> onChange) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opts.map((o) {
            final active = value == o;
            return GestureDetector(
              onTap: () => onChange(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? T.hero : T.surface2,
                  border: Border.all(color: active ? T.hero : T.line),
                  borderRadius: BorderRadius.circular(T.pill),
                ),
                child: Text(fmt(o), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? Colors.white : T.text)),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

/// A labeled numeric stepper field for one macro goal, meant to sit two-up in a `Row`.
Widget settingsMacroField(String label, String value, ValueChanged<String> onChange) {
  return Expanded(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          NumIn(value: value, onChange: onChange, suffix: 'g'),
        ],
      ),
    ),
  );
}

Widget settingsSaveButton(VoidCallback onSave) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PrimaryButton(
        onTap: onSave,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome, size: 17),
          SizedBox(width: 8),
          Text('Save & recalculate plan'),
        ]),
      ),
    );
