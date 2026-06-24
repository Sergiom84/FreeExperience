import 'dart:typed_data';

import 'file_pick_io.dart'
    if (dart.library.js_interop) 'file_pick_web.dart'
    as impl;

typedef PickedFile = ({Uint8List bytes, String name});

Future<PickedFile?> pickFile(String accept) => impl.pickFile(accept);

// iOS Safari-safe button: user taps the real HTML input directly.
typedef FilePickerButton = impl.FilePickerButton;
