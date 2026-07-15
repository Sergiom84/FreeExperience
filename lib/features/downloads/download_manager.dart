import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/app_database.dart';
import '../../core/util/app_log.dart';
import '../content/domain/content_item.dart';

enum DownloadState { none, queued, downloading, downloaded, failed }

class DownloadSnapshot {
  const DownloadSnapshot({
    required this.state,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.filePath,
    this.errorCode,
  });

  final DownloadState state;
  final int bytesReceived;
  final int totalBytes;
  final String? filePath;
  final String? errorCode;

  double? get progress => totalBytes <= 0 ? null : bytesReceived / totalBytes;
}

abstract interface class DownloadManager {
  Stream<DownloadSnapshot> watch(String contentId);
  Future<void> download(ContentItem item);
  Future<void> remove(String contentId);
  Future<void> clearAll();
  Future<Uri?> resolve(ContentItem item);
}

class LocalDownloadManager implements DownloadManager {
  LocalDownloadManager({
    required AppDatabase database,
    required Dio dio,
    SupabaseClient? remote,
  }) : _database = database,
       _dio = dio,
       _remote = remote;

  final AppDatabase _database;
  final Dio _dio;
  final SupabaseClient? _remote;
  final Map<String, CancelToken> _cancellations = {};

  @override
  Stream<DownloadSnapshot> watch(String contentId) => _database
      .watchDownload(contentId)
      .map(
        (record) => record == null
            ? const DownloadSnapshot(state: DownloadState.none)
            : _fromRecord(record),
      );

  @override
  Future<Uri?> resolve(ContentItem item) async {
    final record = await _database.downloadFor(item.id);
    if (record?.state == DownloadState.downloaded.name &&
        record?.filePath != null) {
      final stored = record!.filePath!;
      if (stored.startsWith('asset:')) return Uri.parse(stored);
      final file = File(stored);
      if (await file.exists()) return file.uri;
      await _database.removeDownload(item.id);
    }

    final path = item.mediaPath;
    if (path == null) return null;
    if (path.startsWith('storage://')) {
      final remote = _remote;
      if (remote == null) return null;
      final storagePath = path.substring('storage://'.length);
      final signed = await remote.storage
          .from('media')
          .createSignedUrl(storagePath, 4 * 60 * 60);
      return Uri.parse(signed);
    }
    return Uri.parse(path);
  }

  @override
  Future<void> download(ContentItem item) async {
    final media = item.mediaPath;
    if (media == null) {
      await _saveState(item.id, DownloadState.failed, errorCode: 'unavailable');
      throw StateError('Contenido no disponible');
    }
    if (media.startsWith('asset:')) {
      await _database.saveDownload(
        DownloadRecordsCompanion.insert(
          contentId: item.id,
          state: const Value('downloaded'),
          filePath: Value(media),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      return;
    }

    await _saveState(item.id, DownloadState.queued);
    final token = CancelToken();
    _cancellations[item.id] = token;
    try {
      // Reintenta las partes de red (firmar URL + descarga), mismo patrón que
      // la reproducción: un corte puntual no debe dejar la descarga en fallo
      // definitivo.
      for (var attempt = 0; ; attempt++) {
        try {
          await _attemptDownload(item, token);
          return;
        } on Object catch (error, stackTrace) {
          if (token.isCancelled) return;
          if (attempt < 2 && _isTransient(error)) {
            await Future<void>.delayed(
              Duration(milliseconds: 600 * (attempt + 1)),
            );
            continue;
          }
          reportError(error, stackTrace, context: 'DownloadManager.download');
          await _saveState(
            item.id,
            DownloadState.failed,
            errorCode: _errorCode(error),
          );
          rethrow;
        }
      }
    } finally {
      _cancellations.remove(item.id);
    }
  }

  Future<void> _attemptDownload(ContentItem item, CancelToken token) async {
    final source = await resolve(item);
    if (source == null) throw StateError('Contenido no disponible');

    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'downloads'));
    await directory.create(recursive: true);
    final extension = p.extension(source.path).isEmpty
        ? '.m4a'
        : p.extension(source.path);
    final finalPath = p.join(directory.path, '${item.id}$extension');
    final temporaryPath = '$finalPath.part';

    await _saveState(item.id, DownloadState.downloading);
    try {
      await _dio.downloadUri(
        source,
        temporaryPath,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          unawaited(
            _saveState(
              item.id,
              DownloadState.downloading,
              bytesReceived: received,
              totalBytes: total,
            ),
          );
        },
      );
      final temporary = File(temporaryPath);
      if (!await temporary.exists() || await temporary.length() == 0) {
        throw const FileSystemException('empty download');
      }
      final existing = File(finalPath);
      if (await existing.exists()) await existing.delete();
      await temporary.rename(finalPath);
      final size = await File(finalPath).length();
      await _database.saveDownload(
        DownloadRecordsCompanion.insert(
          contentId: item.id,
          state: const Value('downloaded'),
          filePath: Value(finalPath),
          bytesReceived: Value(size),
          totalBytes: Value(size),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } on Object {
      await File(temporaryPath).delete().catchError((_) => File(temporaryPath));
      rethrow;
    }
  }

  /// Fallos de red puntuales que merecen reintento; el resto (cancelación,
  /// respuesta 4xx, disco lleno...) fallan directamente.
  bool _isTransient(Object error) {
    if (error is SocketException) return true;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError ||
        DioExceptionType.unknown => true,
        _ => false,
      };
    }
    return false;
  }

  String _errorCode(Object error) {
    if (error is DioException) return error.type.name;
    if (error is FileSystemException) return 'storage';
    if (error is StateError) return 'unavailable';
    return 'unknown';
  }

  @override
  Future<void> remove(String contentId) async {
    _cancellations.remove(contentId)?.cancel('removed');
    final record = await _database.downloadFor(contentId);
    final path = record?.filePath;
    if (path != null && !path.startsWith('asset:')) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _database.removeDownload(contentId);
  }

  @override
  Future<void> clearAll() async {
    for (final token in _cancellations.values) {
      token.cancel('account-deleted');
    }
    _cancellations.clear();
    final downloads = await _database.allDownloads();
    for (final download in downloads) {
      final path = download.filePath;
      if (path == null || path.startsWith('asset:')) continue;
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException {
          continue;
        }
      }
    }
  }

  Future<void> _saveState(
    String contentId,
    DownloadState state, {
    int bytesReceived = 0,
    int totalBytes = 0,
    String? errorCode,
  }) => _database.saveDownload(
    DownloadRecordsCompanion.insert(
      contentId: contentId,
      state: Value(state.name),
      bytesReceived: Value(bytesReceived),
      totalBytes: Value(totalBytes),
      errorCode: Value(errorCode),
      updatedAt: DateTime.now().toUtc(),
    ),
  );

  DownloadSnapshot _fromRecord(DownloadRecord record) => DownloadSnapshot(
    state: DownloadState.values.firstWhere(
      (state) => state.name == record.state,
      orElse: () => DownloadState.none,
    ),
    bytesReceived: record.bytesReceived,
    totalBytes: record.totalBytes,
    filePath: record.filePath,
    errorCode: record.errorCode,
  );
}
