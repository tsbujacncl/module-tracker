import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/shared_module.dart';

class ModuleShareService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _sharesCollection =
      FirebaseFirestore.instance.collection('shared_modules');

  /// Generate a random 6-character code (e.g., "ABC123")
  String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude confusing chars
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Share a module and return the share code
  Future<String> shareModule({
    required Module module,
    required List<Assessment> assessments,
    required List<RecurringTask> tasks,
    required String userId,
  }) async {
    // Generate unique code (retry if collision)
    String code = _generateShareCode();
    int attempts = 0;
    while (attempts < 5) {
      final existing = await _sharesCollection.doc(code).get();
      if (!existing.exists) break;
      code = _generateShareCode();
      attempts++;
    }

    // Create shared module
    final sharedModule = SharedModule(
      id: code,
      moduleCode: module.code,
      moduleName: module.name,
      moduleColor: module.colorValue != null
          ? '#${module.colorValue!.toRadixString(16).padLeft(8, '0').substring(2)}'
          : '#3B82F6', // Default blue color
      assessments:
          assessments.map((a) => SharedAssessment.fromAssessment(a)).toList(),
      tasks: tasks.map((t) => SharedTask.fromRecurringTask(t)).toList(),
      sharedBy: userId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)), // 30 day expiry
    );

    // Save to Firestore
    await _sharesCollection.doc(code).set(sharedModule.toFirestore());

    return code;
  }

  /// Get shared module by code
  Future<SharedModule?> getSharedModule(String code) async {
    try {
      final doc = await _sharesCollection.doc(code.toUpperCase()).get();
      if (!doc.exists) return null;

      final sharedModule = SharedModule.fromFirestore(doc);

      // Check if expired
      if (sharedModule.expiresAt.isBefore(DateTime.now())) {
        return null;
      }

      return sharedModule;
    } catch (e) {
      print('Error fetching shared module: $e');
      return null;
    }
  }

  /// Increment import count when someone imports
  Future<void> incrementImportCount(String code) async {
    try {
      await _sharesCollection.doc(code.toUpperCase()).update({
        'importCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing import count: $e');
    }
  }

  /// Delete expired shares (call periodically or via cloud function)
  Future<void> cleanupExpiredShares() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final expiredDocs = await _sharesCollection
          .where('expiresAt', isLessThan: now)
          .limit(100)
          .get();

      final batch = _firestore.batch();
      for (final doc in expiredDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error cleaning up expired shares: $e');
    }
  }

  /// Share multiple modules as a bundle and return the share code
  Future<String> shareMultipleModules({
    required List<Module> modules,
    required Map<String, List<Assessment>> assessmentsByModule,
    required Map<String, List<RecurringTask>> tasksByModule,
    required String userId,
  }) async {
    // Generate unique code (retry if collision)
    String code = _generateShareCode();
    int attempts = 0;
    while (attempts < 5) {
      final existing = await _sharesCollection.doc(code).get();
      if (!existing.exists) break;
      code = _generateShareCode();
      attempts++;
    }

    // Create shared module info for each module
    final sharedModules = modules.map((module) {
      final assessments = assessmentsByModule[module.id] ?? [];
      final tasks = tasksByModule[module.id] ?? [];

      return SharedModuleInfo(
        moduleCode: module.code,
        moduleName: module.name,
        moduleColor: module.colorValue != null
            ? '#${module.colorValue!.toRadixString(16).padLeft(8, '0').substring(2)}'
            : '#3B82F6',
        credits: module.credits,
        assessments:
            assessments.map((a) => SharedAssessment.fromAssessment(a)).toList(),
        tasks: tasks.map((t) => SharedTask.fromRecurringTask(t)).toList(),
      );
    }).toList();

    // Create bundle
    final bundle = SharedModuleBundle(
      id: code,
      modules: sharedModules,
      sharedBy: userId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    // Save to Firestore
    await _sharesCollection.doc(code).set(bundle.toFirestore());

    return code;
  }

  /// Get shared bundle by code
  Future<SharedModuleBundle?> getSharedBundle(String code) async {
    try {
      final doc = await _sharesCollection.doc(code.toUpperCase()).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || data['isBundle'] != true) return null;

      final bundle = SharedModuleBundle.fromFirestore(doc);

      // Check if expired
      if (bundle.expiresAt.isBefore(DateTime.now())) {
        return null;
      }

      return bundle;
    } catch (e) {
      print('Error fetching shared bundle: $e');
      return null;
    }
  }

  /// Determine if a share code is a bundle or single module
  Future<bool> isBundle(String code) async {
    try {
      final doc = await _sharesCollection.doc(code.toUpperCase()).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['isBundle'] == true;
    } catch (e) {
      print('Error checking share type: $e');
      return false;
    }
  }

  /// Generate shareable text message
  String generateShareMessage(String moduleCode, String moduleName, String code) {
    return '''Check out my $moduleCode module setup!

Module: $moduleName
Includes: Assessments & Tasks

Import it here:
https://moduletracker.app/share/$code

Shared via Module Tracker''';
  }

  /// Generate shareable text message for multiple modules
  String generateBundleShareMessage(List<Module> modules, String code) {
    final moduleCount = modules.length;
    final moduleNames = modules.take(3).map((m) => m.code).join(', ');
    final extra = moduleCount > 3 ? ' +${moduleCount - 3} more' : '';

    return '''Check out my module setup!

Modules: $moduleNames$extra
Total: $moduleCount module${moduleCount != 1 ? 's' : ''}

Import them here:
https://moduletracker.app/share/$code

Shared via Module Tracker''';
  }
}
