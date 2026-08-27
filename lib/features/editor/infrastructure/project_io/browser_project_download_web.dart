import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadFldawProject(Uint8List bytes, String fileName) {
  final objectUrl = web.URL.createObjectURL(
    web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/vnd.fldaw.project+zip'),
    ),
  );
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    // Let the click consume the URL before releasing it, without retaining a
    // permanent Blob URL for large projects.
    Future<void>.delayed(
      const Duration(seconds: 1),
      () => web.URL.revokeObjectURL(objectUrl),
    );
  }
}
