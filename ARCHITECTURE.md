# Module Tracker - Architecture Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture Pattern](#architecture-pattern)
3. [Project Structure](#project-structure)
4. [Data Flow](#data-flow)
5. [Core Components](#core-components)
6. [State Management](#state-management)
7. [Firebase Integration](#firebase-integration)
8. [Key Design Decisions](#key-design-decisions)

---

## Overview

Module Tracker is a Flutter application that helps university students manage their weekly tasks across multiple modules. The app uses a **clean architecture** approach with clear separation of concerns between data, business logic, and UI layers.

### Technology Stack
- **Framework**: Flutter 3.35.2
- **State Management**: Riverpod 2.6.1
- **Backend**: Firebase (Firestore + Authentication)
- **Language**: Dart 3.9.0

---

## Architecture Pattern

The application follows a **layered architecture** pattern:

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│    (Screens, Widgets, UI Logic)     │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│      State Management Layer         │
│      (Providers - Riverpod)         │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│        Business Logic Layer         │
│    (Services, Utilities)            │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│          Data Layer                 │
│   (Repositories, Models)            │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│      External Services              │
│   (Firebase, Firestore)             │
└─────────────────────────────────────┘
```

---

## Project Structure

```
lib/
├── models/                    # Data models (pure Dart classes)
│   ├── semester.dart         # Semester with date ranges
│   ├── module.dart           # Module/course information
│   ├── recurring_task.dart   # Weekly tasks (lectures, labs, etc.)
│   ├── assessment.dart       # Coursework and exams
│   └── task_completion.dart  # Task status tracking
│
├── providers/                # Riverpod providers (state management)
│   ├── auth_provider.dart           # Authentication state
│   ├── semester_provider.dart       # Semester and week state
│   ├── module_provider.dart         # Module data streams
│   └── repository_provider.dart     # Repository instances
│
├── repositories/             # Data access layer
│   └── firestore_repository.dart    # Firestore CRUD operations
│
├── services/                 # Business logic services
│   └── auth_service.dart            # Authentication logic
│
├── utils/                    # Utility functions
│   └── date_utils.dart              # Date and week calculations
│
├── screens/                  # UI screens (pages)
│   ├── auth/
│   │   ├── login_screen.dart        # Login page
│   │   └── register_screen.dart     # Registration page
│   ├── home/
│   │   └── home_screen.dart         # Main calendar view
│   ├── module/
│   │   └── module_form_screen.dart  # Create/edit module
│   └── semester/
│       └── semester_setup_screen.dart # Semester configuration
│
├── widgets/                  # Reusable UI components
│   ├── module_card.dart             # Module display card
│   └── week_navigation_bar.dart     # Week selector
│
├── firebase_options.dart     # Firebase configuration
└── main.dart                 # App entry point
```

---

## Data Flow

### Read Flow (Displaying Data)

```
User Interaction
    ↓
Screen/Widget
    ↓
ref.watch(provider)  ← Riverpod Provider
    ↓
Repository Method (Stream/Future)
    ↓
Firestore Query
    ↓
Model.fromFirestore() ← Deserialize data
    ↓
Provider emits new state
    ↓
UI rebuilds automatically
```

### Write Flow (Saving Data)

```
User Action (e.g., tap "Save")
    ↓
Screen validates input
    ↓
Create Model instance
    ↓
ref.read(repositoryProvider)
    ↓
Repository.createXxx(model)
    ↓
model.toFirestore() ← Serialize data
    ↓
Firestore saves document
    ↓
Firestore stream automatically updates
    ↓
Providers emit new state
    ↓
UI rebuilds with new data
```

---

## Core Components

### 1. Models (`lib/models/`)

**Purpose**: Represent data structures and handle serialization/deserialization.

**Key Models**:

#### Semester
```dart
class Semester {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfWeeks;

  // Firestore serialization
  factory Semester.fromFirestore(DocumentSnapshot doc);
  Map<String, dynamic> toFirestore();
}
```

- Represents an academic semester
- Stores start/end dates (always Monday-Sunday)
- Auto-calculates number of weeks
- Used to determine current week number

#### Module
```dart
class Module {
  final String id;
  final String userId;
  final String name;
  final String code;
  final String semesterId;
  final bool isActive;
}
```

- Represents a university course/module
- Linked to a semester
- Can be archived (isActive = false)

#### RecurringTask
```dart
class RecurringTask {
  final String id;
  final String moduleId;
  final RecurringTaskType type;  // lecture, lab, tutorial, flashcards, custom
  final int dayOfWeek;           // 1-7 (Monday = 1)
  final String? time;            // Optional: "09:00"
  final String name;
}
```

- Defines tasks that repeat weekly
- Linked to a module
- Can have scheduled times (e.g., lectures at 9 AM)

#### Assessment
```dart
class Assessment {
  final String id;
  final String moduleId;
  final String name;
  final AssessmentType type;  // coursework or exam
  final DateTime dueDate;
  final double weighting;     // Percentage (0-100)
  final int weekNumber;       // Calculated from dueDate
  final double? score;        // Optional grade
}
```

- Represents graded work (coursework/exams)
- Weighting must sum to 100% per module (validated in UI)
- Week number calculated automatically from due date

#### TaskCompletion
```dart
class TaskCompletion {
  final String id;
  final String moduleId;
  final String taskId;         // References RecurringTask or Assessment
  final int weekNumber;
  final TaskStatus status;     // notStarted, inProgress, complete
  final DateTime? completedAt;
}
```

- Tracks completion status for a specific task in a specific week
- One completion record per task per week
- Stores completion timestamp

### 2. Repositories (`lib/repositories/`)

**Purpose**: Abstract Firestore operations and provide clean data access API.

**FirestoreRepository** (`firestore_repository.dart`):

```dart
class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Semester operations
  Stream<List<Semester>> getUserSemesters(String userId);
  Future<String> createSemester(String userId, Semester semester);

  // Module operations
  Stream<List<Module>> getUserModules(String userId, {bool? activeOnly});
  Stream<List<Module>> getModulesBySemester(String userId, String semesterId);
  Future<String> createModule(String userId, Module module);

  // Task operations
  Stream<List<RecurringTask>> getRecurringTasks(String userId, String moduleId);
  Future<String> createRecurringTask(...);

  // Assessment operations
  Stream<List<Assessment>> getAssessments(String userId, String moduleId);
  Future<String> createAssessment(...);

  // Completion operations
  Stream<List<TaskCompletion>> getTaskCompletions(String userId, String moduleId, int weekNumber);
  Future<void> upsertTaskCompletion(...);  // Create or update
}
```

**Key Features**:
- All read operations return **Streams** (real-time updates)
- Write operations return **Futures** (async operations)
- User-scoped queries (all data filtered by userId)
- Type-safe API (uses models, not raw maps)

### 3. Services (`lib/services/`)

**Purpose**: Encapsulate business logic that doesn't fit in repositories.

**AuthService** (`auth_service.dart`):

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges;
  User? get currentUser;

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password);
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<UserCredential?> signInAnonymously();
}
```

- Wraps Firebase Authentication
- Handles errors and converts them to user-friendly messages
- Provides reactive auth state stream

### 4. Providers (`lib/providers/`)

**Purpose**: Manage application state using Riverpod.

#### Auth Providers (`auth_provider.dart`)

```dart
// Service instance
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user (derived from auth state)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});
```

#### Semester Providers (`semester_provider.dart`)

```dart
// All semesters stream
final semestersProvider = StreamProvider<List<Semester>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);
  if (user == null) return Stream.value([]);
  return repository.getUserSemesters(user.uid);
});

// Current/active semester
final currentSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semestersProvider);
  return semesters.when(
    data: (list) => list.isNotEmpty ? list.first : null,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Current week number
final currentWeekNumberProvider = Provider<int>((ref) {
  final semester = ref.watch(currentSemesterProvider);
  if (semester == null) return 1;

  final now = DateTime.now();
  final daysSinceStart = now.difference(semester.startDate).inDays;
  final weekNumber = (daysSinceStart / 7).floor() + 1;

  return weekNumber.clamp(1, semester.numberOfWeeks);
});

// Selected week (for navigation)
final selectedWeekNumberProvider = StateProvider<int>((ref) {
  return ref.watch(currentWeekNumberProvider);
});
```

#### Module Providers (`module_provider.dart`)

```dart
// Active modules stream
final activeModulesProvider = StreamProvider<List<Module>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);
  if (user == null) return Stream.value([]);
  return repository.getUserModules(user.uid, activeOnly: true);
});

// Recurring tasks for a specific module (family provider)
final recurringTasksProvider = StreamProvider.family<List<RecurringTask>, String>((ref, moduleId) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);
  if (user == null) return Stream.value([]);
  return repository.getRecurringTasks(user.uid, moduleId);
});

// Task completions for module + week (family provider with named parameters)
final taskCompletionsProvider = StreamProvider.family<
  List<TaskCompletion>,
  ({String moduleId, int weekNumber})
>((ref, params) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);
  if (user == null) return Stream.value([]);
  return repository.getTaskCompletions(user.uid, params.moduleId, params.weekNumber);
});
```

**Provider Types**:
- `Provider` - Simple computed values (never changes unless dependencies change)
- `StateProvider` - Mutable state (can be changed directly)
- `StreamProvider` - Async streams (real-time data from Firestore)
- `FutureProvider` - Async futures (one-time async operations)
- `.family` - Provider that takes parameters (e.g., moduleId)

### 5. Utilities (`lib/utils/`)

**DateUtils** (`date_utils.dart`):

```dart
class DateUtils {
  // Calculate week number from semester start
  static int getWeekNumber(DateTime date, DateTime semesterStart);

  // Get Monday of current week
  static DateTime getMonday(DateTime date);

  // Get Sunday of current week
  static DateTime getSunday(DateTime date);

  // Get date for a specific week number
  static DateTime getDateForWeek(int weekNumber, DateTime semesterStart);

  // Calculate number of weeks between dates
  static int calculateWeeksBetween(DateTime start, DateTime end);

  // Get all dates for a week (Monday-Sunday)
  static List<DateTime> getDatesForWeek(DateTime weekStart);

  // Check if date is today
  static bool isToday(DateTime date);

  // Check if two dates are in the same week
  static bool isSameWeek(DateTime date1, DateTime date2);
}
```

---

## State Management

### Riverpod Provider Pattern

**Why Riverpod?**
- Compile-safe (errors caught at compile time)
- No BuildContext needed
- Easy testing
- Automatic disposal
- Handles async data elegantly

### Common Patterns

#### 1. Watching Providers (UI rebuilds on change)

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch a provider - rebuilds when data changes
    final modules = ref.watch(activeModulesProvider);

    // Handle async data with .when()
    return modules.when(
      data: (list) => ListView.builder(...),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

#### 2. Reading Providers (one-time read, no rebuild)

```dart
// In event handlers, use ref.read()
onPressed: () async {
  final repository = ref.read(firestoreRepositoryProvider);
  await repository.createModule(userId, module);
}
```

#### 3. Invalidating Providers (force refresh)

```dart
// Trigger a refresh
ref.invalidate(activeModulesProvider);

// Or use RefreshIndicator widget
RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(activeModulesProvider);
  },
  child: ListView(...),
)
```

#### 4. Modifying State

```dart
// For StateProvider, modify directly
ref.read(selectedWeekNumberProvider.notifier).state = 5;

// Or use .update()
ref.read(selectedWeekNumberProvider.notifier).update((state) => state + 1);
```

### Provider Dependencies

Providers can depend on other providers, creating a reactive dependency graph:

```
currentUserProvider
    ↓
semestersProvider ──→ currentSemesterProvider
                            ↓
                      currentWeekNumberProvider
                            ↓
                      selectedWeekNumberProvider
```

When `currentUserProvider` changes (e.g., user logs out), all dependent providers automatically update.

---

## Firebase Integration

### Firestore Data Structure

```
users/
  {userId}/
    semesters/
      {semesterId}/
        - name: "Semester 1 2024/25"
        - startDate: Timestamp
        - endDate: Timestamp
        - numberOfWeeks: 12
        - createdAt: Timestamp

    modules/
      {moduleId}/
        - userId: {userId}
        - name: "Computer Science"
        - code: "CS101"
        - semesterId: {semesterId}
        - isActive: true
        - createdAt: Timestamp

        recurringTasks/
          {taskId}/
            - type: "lecture"
            - dayOfWeek: 1  (Monday)
            - time: "09:00"
            - name: "Introduction to CS"

        assessments/
          {assessmentId}/
            - name: "Midterm Exam"
            - type: "exam"
            - dueDate: Timestamp
            - weighting: 40.0
            - weekNumber: 6
            - score: null

        taskCompletions/
          {completionId}/
            - taskId: {taskId}
            - weekNumber: 3
            - status: "complete"
            - completedAt: Timestamp
```

### Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

### Real-time Synchronization

All Firestore queries use `.snapshots()` which provides real-time updates:

```dart
// This stream automatically emits new data when Firestore changes
Stream<List<Module>> getUserModules(String userId) {
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('modules')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Module.fromFirestore(doc))
          .toList());
}
```

**Benefits**:
- No manual refresh needed
- Multi-device sync (changes on one device appear on others instantly)
- Offline support (Firestore caches data locally)

---

## Key Design Decisions

### 1. Why Streams over Futures?

**Streams** are used for reading data because:
- Real-time updates (no manual refresh)
- Multi-device synchronization
- Firestore's `.snapshots()` is optimized for this
- Riverpod's `StreamProvider` handles loading/error states automatically

**Futures** are used for write operations because:
- One-time operations (create, update, delete)
- Need confirmation of success/failure
- Can show loading indicators during operation

### 2. Week-Based Task Management

Tasks are not stored per week. Instead:
- **RecurringTasks** define what tasks happen each week
- **TaskCompletions** track status for each task in each week
- This avoids creating redundant task instances

Example:
```
RecurringTask: "CS Lecture" (every Monday)
  → TaskCompletion: Week 1, status: complete
  → TaskCompletion: Week 2, status: inProgress
  → TaskCompletion: Week 3, status: notStarted
```

### 3. Upsert Pattern for Task Completions

```dart
Future<void> upsertTaskCompletion(...) async {
  // Check if completion already exists
  final existing = await query
      .where('taskId', isEqualTo: taskId)
      .where('weekNumber', isEqualTo: weekNumber)
      .get();

  if (existing.docs.isNotEmpty) {
    // Update existing
    await doc.update(completion.toFirestore());
  } else {
    // Create new
    await collection.add(completion.toFirestore());
  }
}
```

This ensures:
- No duplicate completions per task per week
- First tap creates completion
- Subsequent taps update status

### 4. Separation of Concerns

**Models** don't know about:
- Firestore (except serialization methods)
- UI logic
- Business rules

**Repositories** don't know about:
- UI
- Specific business logic (just CRUD operations)

**Providers** don't know about:
- How data is stored
- UI widgets

**Screens** don't know about:
- Firestore structure
- How providers work internally

This makes the code:
- Testable (can mock each layer)
- Maintainable (changes in one layer don't affect others)
- Reusable (services/repositories can be used in different apps)

### 5. Provider Composition

Instead of one giant provider, we use many small providers that compose:

```dart
// Small, focused providers
final currentUserProvider = ...;
final semestersProvider = ...;
final currentSemesterProvider = ...;

// Composed provider (depends on others)
final currentWeekNumberProvider = Provider<int>((ref) {
  final semester = ref.watch(currentSemesterProvider);
  // Calculate week from semester
  return calculateWeek(semester);
});
```

Benefits:
- Each provider has single responsibility
- Easy to understand and test
- Automatic caching and memoization
- Efficient rebuilds (only affected widgets rebuild)

### 6. Family Providers for Parameterized Data

When you need data that depends on a parameter (e.g., tasks for a specific module):

```dart
// Without .family (wrong approach)
// You'd need a provider for each module ID

// With .family (correct approach)
final recurringTasksProvider = StreamProvider.family<List<RecurringTask>, String>(
  (ref, moduleId) {
    // Use moduleId to fetch data
    return repository.getRecurringTasks(userId, moduleId);
  }
);

// Usage
final tasks = ref.watch(recurringTasksProvider('module123'));
```

This allows:
- One provider definition for all modules
- Automatic caching per moduleId
- Type-safe parameters

---

## Data Flow Examples

### Example 1: User Completes a Task

1. **User taps task** in `ModuleCard` widget
2. Widget calls `onStatusChanged` callback
3. Callback creates new `TaskCompletion` with updated status:
   ```dart
   onStatusChanged: (newStatus) async {
     final user = ref.read(currentUserProvider);
     final repository = ref.read(firestoreRepositoryProvider);

     final completion = TaskCompletion(
       id: existingCompletion?.id ?? '',
       moduleId: module.id,
       taskId: task.id,
       weekNumber: currentWeek,
       status: newStatus,
       completedAt: newStatus == TaskStatus.complete ? DateTime.now() : null,
     );

     await repository.upsertTaskCompletion(user.uid, module.id, completion);
   }
   ```
4. Repository updates Firestore document
5. Firestore stream emits new data
6. `taskCompletionsProvider` receives update
7. `ModuleCard` rebuilds with new status
8. **UI shows updated icon/color automatically**

### Example 2: Creating a New Module

1. **User fills form** in `ModuleFormScreen`
2. User taps "Create Module" button
3. Form validates input
4. Screen creates `Module` instance:
   ```dart
   final module = Module(
     id: '',
     userId: user.uid,
     name: nameController.text,
     code: codeController.text,
     semesterId: currentSemester.id,
     isActive: true,
     createdAt: DateTime.now(),
   );
   ```
5. Call repository to create:
   ```dart
   final moduleId = await repository.createModule(user.uid, module);
   ```
6. Create recurring tasks and assessments for the module
7. Repository saves all to Firestore
8. Firestore streams emit updates
9. `activeModulesProvider` receives new module
10. **Home screen automatically shows new module** (no manual refresh)

### Example 3: Week Navigation

1. **User taps "Next Week"** button in `WeekNavigationBar`
2. Button calls `onWeekChanged(currentWeek + 1)`
3. Callback updates state provider:
   ```dart
   onWeekChanged: (week) {
     ref.read(selectedWeekNumberProvider.notifier).state = week;
   }
   ```
4. `selectedWeekNumberProvider` emits new value
5. `ModuleCard` widgets watch this provider
6. Cards call `taskCompletionsProvider` with new week number:
   ```dart
   final completions = ref.watch(
     taskCompletionsProvider((moduleId: module.id, weekNumber: selectedWeek))
   );
   ```
7. Provider fetches completions for new week from Firestore
8. **UI shows tasks for new week automatically**

---

## Testing Strategy

### Unit Tests (Models, Utils)

```dart
test('DateUtils calculates week number correctly', () {
  final semesterStart = DateTime(2024, 9, 2);  // Monday
  final currentDate = DateTime(2024, 9, 16);   // 2 weeks later

  final weekNumber = DateUtils.getWeekNumber(currentDate, semesterStart);

  expect(weekNumber, 3);
});
```

### Widget Tests (UI Components)

```dart
testWidgets('ModuleCard displays task status', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recurringTasksProvider(moduleId).overrideWith(...),
      ],
      child: MaterialApp(
        home: ModuleCard(module: testModule, weekNumber: 1),
      ),
    ),
  );

  expect(find.text('CS Lecture'), findsOneWidget);
  expect(find.byIcon(Icons.check_circle), findsOneWidget);
});
```

### Integration Tests (Repository + Firestore)

```dart
test('FirestoreRepository creates and retrieves module', () async {
  final repository = FirestoreRepository();
  final module = Module(...);

  final moduleId = await repository.createModule(userId, module);

  final modules = await repository
      .getUserModules(userId)
      .first;

  expect(modules, contains(module));
});
```

---

## Performance Considerations

### 1. Firestore Query Optimization

- Use `.where()` to filter data server-side
- Limit results with `.limit()`
- Create indexes for compound queries
- Use pagination for large datasets (not implemented yet)

### 2. Provider Caching

Riverpod automatically caches provider results:
- Same parameters = same cached result
- No redundant API calls
- Memory-efficient (unused providers are disposed)

### 3. Selective Rebuilds

Only widgets that `watch` a provider rebuild when it changes:

```dart
// This rebuilds when modules change
final modules = ref.watch(activeModulesProvider);

// This doesn't rebuild (just reads once)
final repository = ref.read(firestoreRepositoryProvider);
```

### 4. Offline Support

Firestore automatically:
- Caches data locally
- Works offline (reads from cache)
- Queues writes when offline
- Syncs when back online

---

## Future Enhancements

### 1. Notifications
- Add `flutter_local_notifications` integration
- Create `NotificationService` in `services/`
- Schedule notifications for upcoming deadlines
- Add weekend reminder logic

### 2. Module Detail View
- Create `module_detail_screen.dart`
- Show all assessments with grades
- Display task completion statistics
- Add edit/archive functionality

### 3. Archive System
- Add `ArchivedModulesScreen`
- Filter archived modules in queries
- Add "Reactivate" functionality
- Show historical completion data

### 4. Grade Calculator
- Calculate current grade based on completed assessments
- Project final grade based on remaining weightings
- Show grade breakdown chart

### 5. Statistics & Analytics
- Task completion rate per module
- Most/least completed task types
- Time spent per module (with timer)
- Weekly progress trends

---

## Troubleshooting

### Provider Not Updating

**Problem**: UI doesn't rebuild when data changes

**Solutions**:
1. Make sure you're using `ref.watch()` not `ref.read()`
2. Check that provider returns a Stream/Future
3. Verify Firestore security rules allow reading

### Firestore Permission Denied

**Problem**: "Missing or insufficient permissions"

**Solutions**:
1. Check user is authenticated
2. Verify security rules in Firebase Console
3. Ensure data is user-scoped (uses userId)

### Provider Disposed Error

**Problem**: "Provider was disposed"

**Solutions**:
1. Don't call `ref.read()` in `build()` method
2. Use `ref.watch()` for reactive data
3. Ensure widget is properly mounted

---

## Conclusion

This architecture provides:
- ✅ Clean separation of concerns
- ✅ Type-safe state management
- ✅ Real-time data synchronization
- ✅ Testable components
- ✅ Scalable structure for future features

The combination of **Riverpod** for state management and **Firebase** for backend provides a robust, production-ready foundation that can scale from a single user to thousands of users with minimal code changes.