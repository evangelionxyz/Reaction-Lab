import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../models/reaction_record.dart';

class StorageService {
  Future<File> _getHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}${AppConstants.historyFileName}');
  }

  Future<List<ReactionRecord>> loadHistory() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) return [];

      final rows = await file.readAsLines();
      final records = <ReactionRecord>[];

      for (final row in rows.reversed.take(50)) {
        if (row.trim().isEmpty) continue;
        try {
          final record = ReactionRecord.fromCsv(
            row,
            normalizer: Formatters.normalizeTimestamp,
          );
          records.add(record);
        } catch (_) {
          // ignore corrupted lines
        }
      }
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> appendRecord(ReactionRecord record) async {
    try {
      final file = await _getHistoryFile();
      await file.writeAsString('${record.csv}\n', mode: FileMode.append);
    } catch (_) {
      // ignore or log
    }
  }

  Future<void> clearHistory() async {
    final file = await _getHistoryFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> saveHistoryAsTxt(List<ReactionRecord> records) async {
    if (records.isEmpty) return null;

    final fileTimestamp = Formatters.formatTimestamp(DateTime.now())
        .replaceAll(' ', '_')
        .replaceAll(':', '-');
    final suggestedName = 'reaction_history_$fileTimestamp.txt';

    final buffer = StringBuffer('History Waktu Reaksi\n\n');
    for (final record in records) {
      buffer.writeln(
        'Waktu reaksi #${record.index} | ${record.timestamp} | ${record.reactionTime} ms',
      );
    }

    final defaultDirectory = await _getDefaultSaveDirectory();
    final bytes = Uint8List.fromList(buffer.toString().codeUnits);

    final saveUri = await FilePicker.saveFile(
      dialogTitle: 'Save reaction history',
      fileName: suggestedName,
      initialDirectory: defaultDirectory,
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      bytes: bytes,
      mimeType: 'text/plain',
    );

    return saveUri?.path ?? saveUri?.toString();
  }

  Future<String?> _getDefaultSaveDirectory() async {
    if (Platform.isAndroid) {
      try {
        final directories = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (directories != null && directories.isNotEmpty) {
          return directories.first.path;
        }
      } catch (_) {}
    }

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads.path;
    } catch (_) {}

    final documents = await getApplicationDocumentsDirectory();
    return documents.path;
  }
}
