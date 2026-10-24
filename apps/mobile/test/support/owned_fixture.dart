import 'dart:io';

import 'package:path/path.dart' as path;

Future<void> deleteOwnedTemporaryDirectory(
  Directory directory,
  String prefix,
) async {
  final resolved = await directory.resolveSymbolicLinks();
  final temp = await Directory.systemTemp.resolveSymbolicLinks();
  if (path.dirname(resolved) != temp ||
      !path.basename(resolved).startsWith(prefix)) {
    throw StateError('Refusing cleanup outside the owned temporary fixture.');
  }
  await Directory(resolved).delete(recursive: true);
}
