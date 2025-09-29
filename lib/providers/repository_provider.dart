import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/repositories/firestore_repository.dart';

// Firestore repository provider
final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  return FirestoreRepository();
});