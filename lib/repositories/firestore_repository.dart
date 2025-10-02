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
        .collection('semesters')
        .doc(semesterId)
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
  Future<void> upsertTaskCompletion(
      String userId, String moduleId, TaskCompletion completion) async {
    // Try to find existing completion
    final existingQuery = await _firestore
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .collection('taskCompletions')
        .where('taskId', isEqualTo: completion.taskId)
        .where('weekNumber', isEqualTo: completion.weekNumber)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      // Update existing
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('modules')
          .doc(moduleId)
          .collection('taskCompletions')
          .doc(existingQuery.docs.first.id)
          .update(completion.toFirestore());
    } else {
      // Create new
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('modules')
          .doc(moduleId)
          .collection('taskCompletions')
          .add(completion.toFirestore());
    }
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
}