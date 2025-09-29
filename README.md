# Module Tracker

A Flutter application to help university students manage their weekly tasks across multiple modules.

## Features

- **Semester Management**: Create and manage academic semesters with start/end dates
- **Module Tracking**: Add modules with recurring weekly tasks and graded assessments
- **Weekly Calendar View**: Visual weekly view with task completion tracking
- **Task Status**: Track tasks as Not Started, In Progress, or Complete
- **Assessment Management**: Track coursework and exams with weightings and due dates
- **Cross-Device Sync**: Firebase backend for seamless synchronization

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.35.2 or later)
- Dart SDK (3.9.0 or later)
- Firebase account
- Android Studio / Xcode (for mobile development)
- Chrome (for web development)

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Configuration

#### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use existing)
3. Give it a name like "Module Tracker"

#### Step 2: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

#### Step 3: Configure Firebase

```bash
flutterfire configure
```

This will:
- Prompt you to select your Firebase project
- Ask which platforms to configure (select Android, iOS, Web, macOS)
- Generate `lib/firebase_options.dart` with your actual Firebase configuration

#### Step 4: Enable Firebase Services

In Firebase Console:

1. **Authentication**:
   - Go to Authentication > Sign-in method
   - Enable "Email/Password"
   - Enable "Anonymous" (for testing)

2. **Firestore Database**:
   - Go to Firestore Database
   - Click "Create database"
   - Start in test mode (or production mode with rules below)

3. **Firestore Security Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 4. Run the Application

#### Web
```bash
flutter run -d chrome
```

#### Android
```bash
flutter run -d android
```

#### macOS
```bash
flutter run -d macos
```

## Project Structure

```
lib/
├── models/              # Data models (Module, Semester, Task, etc.)
├── providers/           # Riverpod state management providers
├── repositories/        # Firestore data access layer
├── screens/            # UI screens
│   ├── auth/           # Login/Register screens
│   ├── home/           # Main calendar view
│   ├── module/         # Module management
│   └── semester/       # Semester setup
├── services/           # Business logic services (Auth, etc.)
├── utils/              # Utility functions (date helpers)
├── widgets/            # Reusable UI components
└── main.dart           # App entry point
```

## Usage Guide

### First Time Setup

1. **Create Account**: Sign up with email/password or continue as guest
2. **Create Semester**: Set up your current semester with start/end dates
3. **Add Modules**: Add your university modules with:
   - Module name and code
   - Weekly recurring tasks (lectures, labs, tutorials, flashcards)
   - Assessments with due dates and weightings

### Daily Usage

1. **View Weekly Tasks**: See all your tasks for the current week
2. **Update Task Status**: Tap tasks to cycle through:
   - ❌ Not Started → 🔄 In Progress → ✅ Complete
3. **Navigate Weeks**: Use the week navigation bar to move between weeks
4. **Track Assessments**: See upcoming deadlines for coursework and exams

## Data Models

### Semester
- Name, start date, end date
- Auto-calculated number of weeks
- Current week detection

### Module
- Name, code
- Belongs to a semester
- Active/Archived status

### Recurring Task
- Type (lecture, lab, tutorial, flashcards, custom)
- Day of week
- Optional time
- Auto-generates weekly instances

### Assessment
- Type (coursework, exam)
- Due date, weighting percentage
- Optional score tracking
- Week number (calculated from due date)

### Task Completion
- Links to recurring task or assessment
- Week number
- Status (not started, in progress, complete)
- Completion timestamp

## Future Enhancements

- [ ] Notifications for upcoming deadlines
- [ ] Weekend reminders for incomplete tasks
- [ ] Module detail view with assessment list
- [ ] Archive system for old modules
- [ ] Grade calculator
- [ ] Statistics and insights
- [ ] Dark mode
- [ ] Export data functionality

## Troubleshooting

### Firebase Not Configured

If you see placeholder Firebase errors:
1. Run `flutterfire configure`
2. Select your Firebase project
3. Choose platforms to support
4. Restart the app

### Build Errors

```bash
flutter clean
flutter pub get
flutter run
```

### Firestore Permission Denied

Check that:
1. User is logged in
2. Firestore security rules are set up correctly
3. Authentication is enabled in Firebase Console

## Contributing

This is a personal project for educational purposes. Feel free to fork and customize for your own use.

## License

This project is open source and available under the MIT License.