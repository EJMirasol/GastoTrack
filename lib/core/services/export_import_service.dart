import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'local_cache_service.dart';

class ExportImportService {
  final LocalCacheService _cache;

  const ExportImportService(this._cache);

  Future<String?> exportData() async {
    final data = {
      'transactions': _cache.transactionsBox.values.toList(),
      'budgets': _cache.budgetsBox.values.toList(),
      'categories': _cache.categoriesBox.values.toList(),
      'settings': _cache.settingsBox.toMap(),
      'exportedAt': DateTime.now().toIso8601String(),
      'version': 1,
    };

    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export GastoTrack Data',
      fileName:
          'gastotrack_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      allowedExtensions: ['json'],
      type: FileType.custom,
      bytes: Uint8List.fromList(bytes),
    );

    return result;
  }

  Future<bool> importData() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import GastoTrack Data',
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return false;

    final file = result.files.first;
    if (file.bytes == null) return false;

    final content = utf8.decode(file.bytes!);

    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final version = (data['version'] as num?)?.toInt() ?? 0;
      if (version > 1) return false;

      await _cache.clearTransactions();
      await _cache.clearBudgets();
      await _cache.clearCategories();

      final transactions = data['transactions'] as List<dynamic>?;
      if (transactions != null) {
        for (final t in transactions) {
          if (t is Map<String, dynamic>) {
            await _cache.saveTransaction(t);
          }
        }
      }

      final budgets = data['budgets'] as List<dynamic>?;
      if (budgets != null) {
        for (final b in budgets) {
          if (b is Map<String, dynamic>) {
            await _cache.saveBudget(b);
          }
        }
      }

      final categories = data['categories'] as List<dynamic>?;
      if (categories != null) {
        for (final c in categories) {
          if (c is Map<String, dynamic>) {
            await _cache.saveCategory(c);
          }
        }
      }

      await _cache.saveSetting('has_visited', true);

      return true;
    } catch (_) {
      return false;
    }
  }
}
