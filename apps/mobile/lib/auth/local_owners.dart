import 'dart:io';

import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../data/workout_repository.dart';
import '../domain/rest_timer.dart';
import 'configuration.dart';

class LocalOwner {
  final TrainingDatabase database;
  final WorkoutRepository repository;
  LocalOwner(this.database, this.repository);
  Future<void> close() async {
    repository.dispose();
    await database.close();
  }
}

class LocalOwnerStores {
  final Directory directory;
  final RestClock? restClock;
  LocalOwnerStores(this.directory, {this.restClock});
  Future<bool> exists(String owner) async {
    if (!Uuid.isValidUUID(fromString: owner)) {
      throw const AuthFailure('wrong_owner');
    }
    return File('${directory.path}/owner-$owner.sqlite').exists();
  }

  Future<LocalOwner> open(String verifiedOwner, {bool existing = false}) async {
    if (!Uuid.isValidUUID(fromString: verifiedOwner) ||
        verifiedOwner != verifiedOwner.toLowerCase()) {
      throw const AuthFailure('wrong_owner');
    }
    await directory.create(recursive: true);
    final file = File('${directory.path}/owner-$verifiedOwner.sqlite');
    if (existing && !await file.exists()) {
      throw const AuthFailure('local_identity_unavailable');
    }
    final database = TrainingDatabase.open(file);
    return LocalOwner(
      database,
      WorkoutRepository(database, verifiedOwner, restClock: restClock),
    );
  }
}
