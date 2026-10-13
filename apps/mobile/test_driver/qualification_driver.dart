import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final output = Platform.environment['DM_EVIDENCE_DIRECTORY'];
    if (output == null || output.isEmpty) {
      throw StateError(
        'Set DM_EVIDENCE_DIRECTORY to an ignored evidence directory',
      );
    }
    if (data == null) throw StateError('No completed qualification data');
    final directory = await Directory(output).create(recursive: true);
    final file = File(
      '${directory.path}/qualification-${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    stdout.writeln(
      'Qualification evidence written (synthetic data; check physical/build flags before claiming qualification)',
    );
  },
);
