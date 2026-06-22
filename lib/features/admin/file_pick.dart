import 'dart:typed_data';

import 'file_pick_io.dart'
    if (dart.library.js_interop) 'file_pick_web.dart'
    as impl;

typedef PickedFile = ({Uint8List bytes, String name});

/// Opens the platform file chooser filtered by [accept] (e.g. 'image/*').
/// Returns null when the user cancels.
Future<PickedFile?> pickFile(String accept) => impl.pickFile(accept);
