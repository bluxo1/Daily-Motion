/// Qualification writes synthetic state and may be externally force-stopped.
/// Verify the native application identity before accessing any test storage.
void requireQualificationInstallation(Map<String, dynamic> device) {
  if (!{'android', 'ios'}.contains(device['platform']) ||
      device['application_id'] is! String ||
      !(device['application_id'] as String).endsWith('.qualification')) {
    throw StateError('A dedicated .qualification installation is required.');
  }
}
