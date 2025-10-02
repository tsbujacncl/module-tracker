import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/repositories/firestore_repository.dart';
import 'package:module_tracker/repositories/local_repository.dart';

// Firestore repository provider (using Firebase)
final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  return FirestoreRepository();
});

// Local repository provider (using Hive) - kept for future offline mode
final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return LocalRepository();
});