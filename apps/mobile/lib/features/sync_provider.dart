import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/coordinator.dart';

final syncCoordinatorProvider = Provider<SyncCoordinator?>((ref) => null);
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final coordinator = ref.watch(syncCoordinatorProvider);
  if (coordinator == null) {
    yield const SyncStatus(SyncPhase.savedLocally);
    return;
  }
  yield coordinator.status;
  yield* coordinator.statuses;
});
