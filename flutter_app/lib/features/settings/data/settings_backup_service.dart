import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/app_state.dart';

/// The set of `AppData` buckets included in an export/import round-trip.
const settingsBackupKeys = ['settings', 'weight', 'history', 'sessions', 'diet', 'water', 'activity', 'plan'];

/// Thrown by [SettingsBackupService.pickImportPayload] when the picked file
/// isn't valid JSON — distinct from returning `null` (user cancelled the
/// picker), so the screen can show the right message for each.
class InvalidBackupFileException implements Exception {}

/// Export/import of a user's full profile as a portable JSON file — pulled
/// out of the Settings screen's State since it's real data-layer work
/// (payload assembly, file I/O, share sheet) with no UI of its own beyond
/// the loading spinner and confirm dialog the screen still owns.
class SettingsBackupService {
  /// Always the JSON payload (not the raw native .sqlite file) so what
  /// Export produces is exactly what Import (JSON-only, every platform)
  /// can read back — a native-only raw-db export used to be paired with
  /// a JSON-only import, so round-tripping a native export silently
  /// failed to parse.
  Future<void> export(AppState app) async {
    final data = app.data;
    final payload = {
      'user': app.user?.name,
      'settings': data.settings,
      'weight': data.weight,
      'history': data.history,
      'sessions': data.sessions,
      'diet': data.diet,
      'water': data.water,
      'activity': data.activity,
      'plan': data.plan,
      'foods': app.foods.map((f) => {'name': f.name, 'kcal': f.kcal, 'protein': f.protein, 'carb': f.carb, 'fat': f.fat, 'fiber': f.fiber}).toList(),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'cuttracker_export.json', mimeType: 'application/json')],
      text: 'CutTracker data export',
    );
  }

  /// Opens the file picker and parses the chosen file. Returns `null` if the
  /// user cancelled; throws [InvalidBackupFileException] if the file isn't
  /// valid JSON.
  Future<Map<String, dynamic>?> pickImportPayload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw InvalidBackupFileException();
    }
  }

  /// Overwrites every bucket present in [payload] and re-adds any exported
  /// food-library rows. Caller is responsible for confirming with the user
  /// first — this applies unconditionally.
  Future<void> applyImport(AppController controller, Map<String, dynamic> payload) async {
    for (final key in settingsBackupKeys) {
      if (payload[key] != null) await controller.update(key, (_) => payload[key]);
    }
    final foods = payload['foods'];
    if (foods is List) {
      for (final food in foods) {
        final row = Map<String, dynamic>.from(food as Map);
        await controller.addFood(
          row['name'] as String,
          (row['kcal'] as num).toDouble(),
          (row['protein'] as num).toDouble(),
          (row['carb'] as num?)?.toDouble() ?? 0,
          (row['fat'] as num?)?.toDouble() ?? 0,
          (row['fiber'] as num?)?.toDouble() ?? 0,
        );
      }
    }
  }
}
