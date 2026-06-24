import 'dart:typed_data';

import 'admin_preview_url_io.dart'
    if (dart.library.js_interop) 'admin_preview_url_web.dart'
    as impl;

/// Creates a temporary playable URL from raw bytes.
/// On web produces a blob URL; on native writes a temp file.
Future<String> createPreviewUrl(Uint8List bytes, String mimeType) =>
    impl.createPreviewUrl(bytes, mimeType);

/// Releases the URL created by [createPreviewUrl].
void revokePreviewUrl(String url) => impl.revokePreviewUrl(url);
