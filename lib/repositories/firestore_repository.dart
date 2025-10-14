import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/task_completion.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== SEMESTER OPERATIONS ==========

  /// Get user's semesters
  Stream<List<Semester>> getUserSemesters(String userId) {
    print('DEBUG REPO: Setting up semester stream for user: $userId');

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('semesters')
        .orderBy('startDate', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          print('DEBUG REPO: Semester stream emitted - count: ${snapshot.docs.length}, from cache: ${snapshot.metadata.isFromCache}');
          return snapshot.docs.map((doc) => Semester.fromFirestore(doc)).toList();
        });
  }

  /// Get a specific semester with retry logic for eventual consistency
  Future<Semester?> getSemester(String userId, String semesterId) async {
    // Try up to 3 times with increasing delays to handle Firestore eventual consistency
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 300 * attempt));
        print('DEBUG REPO: Retry attempt $attempt for semester $semesterId');
      }

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('semesters')
          .doc(semesterId)
          .get();

      if (doc.exists) {
        print('DEBUG REPO: Semester found on attempt ${attempt + 1}');
        return Semester.fromFirestore(doc);
      }
    }

    print('DEBUG REPO: Semester $semesterId not found after 3 attempts');
    return null;
  }

  /// Create a new semester
  Future<String> createSemester(String userId, Semester semester) async {
    print('DEBUG REPO: Creating semester for user: $userId');
    print('DEBUG REPO: Semester name: ${semester.name}');

    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('semesters')
        .add(semester.toFirestore());

    print('DEBUG REPO: Semester created with ID: ${docRef.id}');
    print('DEBUG REPO: Verifying write...');

    // Verify the write by reading it back
    final verifyDoc = await docRef.get();
    print('DEBUG REPO: Write verification - exists: ${verifyDoc.exists}');

    return docRef.id;
  }

  /// Update semester
  Future<void> updateSemester(
      String userId, String semesterId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('semesters')
        .doc(semesterId)
        .update(data);
  }

  // ========== MODULE OPERATIONS ==========

  /// Get all modules for a user
  Stream<List<Module>> getUserModules(String userId, {bool? activeOnly}) {
    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .orderBy('createdAt', descending: false);

    if (activeOnly == true) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots(includeMetadataChanges: true).map((snapshot) =>
        snapshot.docs.map((doc) => Module.fromFirestore(doc)).toList());
  }

  /// Get modules for a specific semester
  Stream<List<Module>> getModulesBySemester(
      String userId, String semesterId, {bool? activeOnly}) {
    print('DEBUG REPO: Setting up modules stream for user: $userId, semester: $semesterId');

    var query = _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .where('semesterId', isEqualTo: semesterId);

    if (activeOnly == true) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      print('DEBUG REPO: Modules stream emitted - count: ${snapshot.docs.length}, from cache: ${snapshot.metadata.isFromCache}');
      return snapshot.docs.map((doc) => Module.fromFirestore(doc)).toList();
    });
  }

  /// Create a new module
  Future<String> createModule(String userId, Module module) async {
    print('DEBUG REPO: Creating module for user: $userId');
    print('DEBUG REPO: Module name: ${module.name}, Semester ID: ${module.semesterId}');

    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .add(module.toFirestore());

    print('DEBUG REPO: Module created with ID: ${docRef.id}');
    print('DEBUG REPO: Verifying write...');

    // Verify the write by reading it back
    final verifyDoc = await docRef.get();
    print('DEBUG REPO: Write verification - exists: ${verifyDoc.exists}');

    return docRef.id;
  }

  /// Update module
  Future<void> updateModule(
      String userId, String moduleId, Module module) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .update(module.toFirestore());
  }

  /// Archive/unarchive module
  Future<void> toggleModuleArchive(
      String userId, String moduleId, bool isActive) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .update({'isActive': isActive});
  }

  /// Auto-archive all modules for a semester
  Future<void> autoArchiveSemesterModules(String userId, String semesterId) async {
    final batch = _firestore.batch();

    // Get all active modules for this semester
    final modulesSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .where('semesterId', isEqualTo: semesterId)
        .where('isActive', isEqualTo: true)
        .get();

    // Archive each module
    for (final doc in modulesSnapshot.docs) {
      batch.update(doc.reference, {'isActive': false});
    }

    await batch.commit();
  }

  /// Delete module and all its subcollections
  Future<void> deleteModule(String userId, String moduleId) async {
    final batch = _firestore.batch();

    // Delete all recurring tasks
    final recurringTasksSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .get();

    for (final doc in recurringTasksSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete all assessments
    final assessmentsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .get();

    for (final doc in assessmentsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete all task completions
    final completionsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .get();

    for (final doc in completionsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the module itself
    final moduleRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId);
    batch.delete(moduleRef);

    // Commit all deletions
    await batch.commit();
  }

  // ========== RECURRING TASK OPERATIONS ==========

  /// Get recurring tasks for a module
  Stream<List<RecurringTask>> getRecurringTasks(
      String userId, String moduleId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs
            .map((doc) => RecurringTask.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Create recurring task
  Future<String> createRecurringTask(
      String userId, String moduleId, RecurringTask task) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .add(task.toFirestore());
    return docRef.id;
  }

  /// Delete recurring task
  Future<void> deleteRecurringTask(
      String userId, String moduleId, String taskId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .doc(taskId)
        .delete();
  }

  /// Update recurring task
  Future<void> updateRecurringTask(
      String userId, String moduleId, String taskId, RecurringTask task) async {
    final data = task.toFirestore();
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('recurringTasks')
        .doc(taskId)
        .update(data);
  }

  // ========== ASSESSMENT OPERATIONS ==========

  /// Get assessments for a module
  Stream<List<Assessment>> getAssessments(String userId, String moduleId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Assessment.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Create assessment
  Future<String> createAssessment(
      String userId, String moduleId, Assessment assessment) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .add(assessment.toFirestore());
    return docRef.id;
  }

  /// Update assessment
  Future<void> updateAssessment(
      String userId, String semesterId, String moduleId, String assessmentId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .doc(assessmentId)
        .update(data);
  }

  /// Delete assessment
  Future<void> deleteAssessment(
      String userId, String moduleId, String assessmentId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('assessments')
        .doc(assessmentId)
        .delete();
  }

  // ========== TASK COMPLETION OPERATIONS ==========

  /// Get task completions for a module and week
  Stream<List<TaskCompletion>> getTaskCompletions(
      String userId, String moduleId, int weekNumber) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .where('weekNumber', isEqualTo: weekNumber)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskCompletion.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Get all task completions for a module
  Stream<List<TaskCompletion>> getAllTaskCompletions(
      String userId, String moduleId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskCompletion.fromFirestore(doc, moduleId))
            .toList());
  }

  /// Create or update task completion
  /// Uses a deterministic document ID to prevent race conditions
  Future<void> upsertTaskCompletion(
      String userId, String moduleId, TaskCompletion completion) async {
    // Use a composite document ID: taskId_weekNumber
    // This prevents race conditions by ensuring only one document per task+week
    final docId = '${completion.taskId}_w${completion.weekNumber}';

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .doc(docId);

    // Use set with merge to create or update atomically
    // This is safe for concurrent calls - no race condition possible
    await docRef.set(completion.toFirestore(), SetOptions(merge: false));
  }

  /// Batch create task completions for a week
  Future<void> createWeeklyTaskCompletions(
      String userId, String moduleId, List<TaskCompletion> completions) async {
    final batch = _firestore.batch();

    for (final completion in completions) {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('modules')
          .doc(moduleId)
          .collection('taskCompletions')
          .doc();
      batch.set(docRef, completion.toFirestore());
    }

    await batch.commit();
  }

  // ========== USER PREFERENCES OPERATIONS ==========

  /// Get user preferences document reference
  DocumentReference _getUserPrefsDoc(String userId) {
    return _firestore.collection('users').doc(userId).collection('settings').doc('preferences');
  }

  /// Get user preferences stream
  Stream<Map<String, dynamic>?> getUserPreferences(String userId) {
    print('DEBUG REPO: Setting up user preferences stream for user: $userId');
    return _getUserPrefsDoc(userId).snapshots().map((doc) {
      if (doc.exists) {
        print('DEBUG REPO: User preferences loaded from Firestore');
        return doc.data() as Map<String, dynamic>?;
      } else {
        print('DEBUG REPO: No user preferences found in Firestore');
        return null;
      }
    });
  }

  /// Save user preferences to Firestore
  Future<void> saveUserPreferences(String userId, Map<String, dynamic> preferences) async {
    print('DEBUG REPO: Saving user preferences to Firestore for user: $userId');
    print('DEBUG REPO: Preferences: $preferences');

    try {
      await _getUserPrefsDoc(userId).set(preferences, SetOptions(merge: true));
      print('DEBUG REPO: User preferences saved successfully');
    } catch (e) {
      print('DEBUG REPO: Error saving user preferences: $e');
      rethrow;
    }
  }

  /// Update specific user preference fields
  Future<void> updateUserPreferences(String userId, Map<String, dynamic> updates) async {
    print('DEBUG REPO: Updating user preferences for user: $userId');
    print('DEBUG REPO: Updates: $updates');

    try {
      await _getUserPrefsDoc(userId).update(updates);
      print('DEBUG REPO: User preferences updated successfully');
    } catch (e) {
      print('DEBUG REPO: Error updating user preferences: $e');
      // If document doesn't exist, create it
      if (e.toString().contains('NOT_FOUND')) {
        await saveUserPreferences(userId, updates);
      } else {
        rethrow;
      }
    }
  }

  /// Get user preferences once (for initial load)
  Future<Map<String, dynamic>?> getUserPreferencesOnce(String userId) async {
    print('DEBUG REPO: Getting user preferences once for user: $userId');
    try {
      final doc = await _getUserPrefsDoc(userId).get();
      if (doc.exists) {
        print('DEBUG REPO: User preferences found in Firestore');
        return doc.data() as Map<String, dynamic>?;
      } else {
        print('DEBUG REPO: No user preferences document found');
        return null;
      }
    } catch (e) {
      print('DEBUG REPO: Error getting user preferences: $e');
      return null;
    }
  }
}