import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../content/domain/content_item.dart';

/// Lightweight view of a catalogue row for the admin list (any status).
class AdminContentRow {
  const AdminContentRow({
    required this.id,
    required this.title,
    required this.status,
    this.author,
    this.coverUrl,
    this.createdAt,
    this.durationSeconds = 0,
  });

  final String id;
  final String title;
  final String status;
  final String? author;
  final String? coverUrl;
  final DateTime? createdAt;
  final int durationSeconds;
}

/// Full snapshot of an existing item, used to prefill the editor.
class AdminContentDetail {
  const AdminContentDetail({
    required this.kind,
    required this.title,
    required this.status,
    required this.hasMedia,
    this.author,
    this.body,
    this.externalUrl,
    this.coverPath,
    this.mediaSignedUrl,
  });

  final ContentKind kind;
  final String title;
  final String status;
  final bool hasMedia;
  final String? author;
  final String? body;
  final String? externalUrl;
  final String? coverPath;

  /// Signed URL valid 1 h, suitable for inline preview in the editor.
  final String? mediaSignedUrl;
}

/// Everything the wizard collects before persisting.
class ContentDraftInput {
  const ContentDraftInput({
    required this.kind,
    required this.title,
    this.author,
    this.body,
    this.externalUrl,
    this.coverBytes,
    this.coverFilename,
    this.mediaBytes,
    this.mediaFilename,
    this.mediaDurationSeconds,
  });

  final ContentKind kind;
  final String title;
  final String? author;
  final String? body;
  final String? externalUrl;
  final Uint8List? coverBytes;
  final String? coverFilename;
  final Uint8List? mediaBytes;
  final String? mediaFilename;

  /// Pre-detected duration from the in-wizard preview player (video only).
  final int? mediaDurationSeconds;
}

class AdminContentRepository {
  AdminContentRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _remote {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    return client;
  }

  Future<List<AdminContentRow>> listByKind(ContentKind kind) async {
    final rows = await _remote
        .from('content_items')
        .select(
          'id, title, status, author, cover_path, duration_seconds, created_at',
        )
        .eq('kind', kind.databaseValue)
        .order('sort_order');
    return rows.map((row) {
      final coverPath = row['cover_path'] as String?;
      final created = row['created_at'] as String?;
      return AdminContentRow(
        id: row['id'] as String,
        title: row['title'] as String,
        status: row['status'] as String,
        author: row['author'] as String?,
        coverUrl: (coverPath == null || coverPath.isEmpty)
            ? null
            : (coverPath.startsWith('http')
                  ? coverPath
                  : coverPublicUrl(coverPath)),
        createdAt: created == null ? null : DateTime.tryParse(created),
        durationSeconds: row['duration_seconds'] as int? ?? 0,
      );
    }).toList();
  }

  Future<AdminContentDetail> getDetail(String id) async {
    final row = await _remote
        .from('content_items')
        .select('*, media_assets(kind, storage_path)')
        .eq('id', id)
        .single();
    final media = (row['media_assets'] as List<dynamic>? ?? const []);
    String? mediaSignedUrl;
    if (media.isNotEmpty) {
      final storagePath =
          (media.first as Map<dynamic, dynamic>)['storage_path'] as String?;
      if (storagePath != null) {
        try {
          mediaSignedUrl = await _remote.storage
              .from('media')
              .createSignedUrl(storagePath, 3600);
        } on Object {
          // preview URL is best-effort
        }
      }
    }
    return AdminContentDetail(
      kind: ContentKindLabel.parse(row['kind'] as String),
      title: row['title'] as String,
      status: row['status'] as String,
      hasMedia: media.isNotEmpty,
      author: row['author'] as String?,
      body: row['body'] as String?,
      externalUrl: row['external_url'] as String?,
      coverPath: row['cover_path'] as String?,
      mediaSignedUrl: mediaSignedUrl,
    );
  }

  String coverPublicUrl(String path) =>
      _remote.storage.from('covers').getPublicUrl(path);

  /// Deletes a catalogue item and its storage objects. The media_assets row is
  /// removed by the ON DELETE CASCADE on content_id; storage cleanup is
  /// best-effort because orphaned objects are harmless.
  Future<void> delete(String id) async {
    await _removeStorageFolder('covers', id);
    await _removeStorageFolder('media', id);
    await _remote.from('content_items').delete().eq('id', id);
  }

  Future<void> _removeStorageFolder(String bucket, String id) async {
    try {
      final objects = await _remote.storage.from(bucket).list(path: id);
      if (objects.isEmpty) return;
      final paths = objects.map((object) => '$id/${object.name}').toList();
      await _remote.storage.from(bucket).remove(paths);
    } on Object {
      // best-effort cleanup
    }
  }

  /// Creates ([existingId] null) or updates a catalogue item, then sets its
  /// status. Uploads happen before the status flips to published because the
  /// publish trigger requires a cover and the matching media asset to exist.
  Future<String> submit(
    ContentDraftInput input, {
    required bool publish,
    String? existingId,
  }) async {
    final fields = {
      'title': input.title.trim(),
      'author': _trimToNull(input.author),
      'body': _trimToNull(input.body),
      'external_url': _trimToNull(input.externalUrl),
    };

    final String id;
    if (existingId == null) {
      final nextOrder = await _nextSortOrder(input.kind);
      final inserted = await _remote
          .from('content_items')
          .insert({
            ...fields,
            'kind': input.kind.databaseValue,
            'status': 'draft',
            'sort_order': nextOrder,
          })
          .select('id')
          .single();
      id = inserted['id'] as String;
    } else {
      id = existingId;
      await _remote.from('content_items').update(fields).eq('id', id);
    }

    if (input.coverBytes != null) {
      final prepared = _prepareCover(input.coverBytes!, input.coverFilename);
      final path = '$id/cover.${prepared.ext}';
      await _remote.storage
          .from('covers')
          .uploadBinary(
            path,
            prepared.bytes,
            fileOptions: FileOptions(contentType: prepared.mime, upsert: true),
          );
      await _remote
          .from('content_items')
          .update({'cover_path': path})
          .eq('id', id);
    }

    if (input.mediaBytes != null) {
      final isVideo = input.kind == ContentKind.video;
      final ext = _extension(
        input.mediaFilename,
        fallback: isVideo ? 'mp4' : 'mp3',
      );
      final path = '$id/${isVideo ? 'video' : 'audio'}.$ext';
      final mime = mediaMime(ext, isVideo: isVideo);
      await _remote.storage
          .from('media')
          .uploadBinary(
            path,
            input.mediaBytes!,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );
      final duration =
          (input.mediaDurationSeconds != null &&
              input.mediaDurationSeconds! > 0)
          ? input.mediaDurationSeconds!
          : await _detectDuration(path, isVideo: isVideo);
      await _remote.from('media_assets').upsert({
        'content_id': id,
        'kind': isVideo ? 'video' : 'audio',
        'storage_path': path,
        'mime_type': mime,
        'bytes': input.mediaBytes!.length,
        'duration_seconds': duration,
      }, onConflict: 'content_id,kind');
      await _remote
          .from('content_items')
          .update({'duration_seconds': duration})
          .eq('id', id);
    }

    await _remote
        .from('content_items')
        .update({'status': publish ? 'published' : 'draft'})
        .eq('id', id);
    return id;
  }

  Future<int> _nextSortOrder(ContentKind kind) async {
    final rows = await _remote
        .from('content_items')
        .select('sort_order')
        .eq('kind', kind.databaseValue)
        .order('sort_order', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['sort_order'] as int? ?? 0) + 1;
  }

  Future<int> _detectDuration(String path, {required bool isVideo}) async {
    if (isVideo) return 0;
    final player = AudioPlayer();
    try {
      final url = await _remote.storage
          .from('media')
          .createSignedUrl(path, 600);
      final duration = await player.setUrl(url);
      return duration?.inSeconds ?? 0;
    } on Object {
      return 0;
    } finally {
      await player.dispose();
    }
  }

  /// Decodes, resizes (longest side <= 1600) and re-encodes covers as JPEG so
  /// they stay well under the bucket limit. Falls back to the original bytes for
  /// formats the decoder cannot read (e.g. HEIC).
  _PreparedCover _prepareCover(Uint8List bytes, String? filename) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return _fallbackCover(bytes, filename);
      final fits = decoded.width <= 1600 && decoded.height <= 1600;
      final resized = fits
          ? decoded
          : (decoded.width >= decoded.height
                ? img.copyResize(decoded, width: 1600)
                : img.copyResize(decoded, height: 1600));
      return _PreparedCover(
        bytes: img.encodeJpg(resized, quality: 82),
        ext: 'jpg',
        mime: 'image/jpeg',
      );
    } on Object {
      return _fallbackCover(bytes, filename);
    }
  }

  _PreparedCover _fallbackCover(Uint8List bytes, String? filename) {
    final ext = _extension(filename, fallback: 'jpg');
    return _PreparedCover(bytes: bytes, ext: ext, mime: _imageMime(ext));
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _extension(String? filename, {required String fallback}) {
    if (filename == null || !filename.contains('.')) return fallback;
    final ext = filename.split('.').last.toLowerCase();
    return ext.isEmpty ? fallback : ext;
  }

  static String _imageMime(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  static String mediaMime(String ext, {required bool isVideo}) {
    if (isVideo) {
      return switch (ext) {
        'mov' => 'video/quicktime',
        'webm' => 'video/webm',
        _ => 'video/mp4',
      };
    }
    return switch (ext) {
      'm4a' => 'audio/x-m4a',
      'aac' || 'mp4' => 'audio/mp4',
      _ => 'audio/mpeg',
    };
  }
}

class _PreparedCover {
  const _PreparedCover({
    required this.bytes,
    required this.ext,
    required this.mime,
  });

  final Uint8List bytes;
  final String ext;
  final String mime;
}

final adminContentRepositoryProvider = Provider<AdminContentRepository>(
  (ref) => AdminContentRepository(ref.watch(supabaseClientProvider)),
);

final adminItemsProvider =
    FutureProvider.family<List<AdminContentRow>, ContentKind>(
      (ref, kind) => ref.watch(adminContentRepositoryProvider).listByKind(kind),
    );
