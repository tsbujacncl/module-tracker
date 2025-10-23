# Module Tracker

![Version](https://img.shields.io/badge/version-0.9-blue.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20Web-lightgrey.svg)
![Status](https://img.shields.io/badge/status-pre--release-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

A beautiful, intuitive, and **completely free** Flutter application designed for UK university students to effortlessly manage their modules, assignments, and weekly tasks across semesters.

**Perfect for all degree programs** - whether you're studying Computer Science, Medicine, Engineering, Business, Arts, or any other field, Module Tracker adapts to your unique academic structure.

> 🚧 **Pre-Release Status**: Module Tracker is currently in version 0.9 and undergoing final testing before official release on the App Store, Google Play, and web hosting. Currently optimised for UK universities with plans to expand internationally.

## Why Module Tracker?

✨ **Easy & Intuitive** - No learning curve, just open and start organizing

📱 **Cross-Platform** - Seamlessly sync between your phone, tablet, and computer

💰 **Completely Free** - Full feature access with no subscriptions, hidden costs, or ads. Forever.

🎯 **Built for UK Students** - Designed around UK grading systems and academic structure

📊 **Progress at a Glance** - The easiest way to track your module performance and stay on top of your studies

## 📲 Download

**Coming Soon to:**

- 🍎 **App Store** - iPhone & iPad
- 🤖 **Google Play** - Android phones & tablets
- 🌐 **Web App** - Access from any browser

*Currently in final testing before release. Star this repo to get notified!*

## 📋 Table of Contents

- [Features](#-features)
- [Usage Guide](#-usage-guide)
- [Privacy & Data](#-privacy--data)
- [Platform Support](#-platform-support)
- [Upcoming Features](#-upcoming-features)
- [For Developers](#-for-developers)
- [Developer](#-developer)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

### 📚 Academic Management

- **Semester Management**: Create and organise academic semesters with start/end dates
- **Module Tracking**: Add modules with custom colours, codes, and detailed information
- **Weekly Calendar View**: Beautiful calendar interface with drag-to-complete functionality
- **Task Tracking**: Monitor tasks across multiple states (Not Started, In Progress, Complete)
- **Assessment Management**: Track coursework and exams with weightings, due dates, and scores
- **Automatic Archiving**: Old semesters are automatically archived when they end

### 🎨 Customisation

- **Theme Options**: Light, Dark, or System Default (with device-specific icons)
- **Custom Event Colours**: Personalise colours for lectures, labs, and assignments
- **Grade Display Formats**: Choose between Percentage, Letter grades, or GPA
- **Flexible Week Start**: Set calendar to start on Monday or Sunday
- **Responsive Design**: Optimised for phones, tablets, and desktop

### 📊 Academic Insights

- **Progress Tracking Made Easy**: The simplest way to visualise your module performance at a glance
- **Grade Calculator**: Track your progress towards target grades with UK grading standards (40% Pass, 70% First)
- **Module Statistics**: View overall performance across modules with colour-coded progress indicators
- **This Week's Tasks**: Quick overview of pending work on your home screen
- **Completion Percentages**: See exactly how much of each module you've completed
- **Birthday Celebrations**: Fun birthday reminders with confetti

### 🔄 Sync & Sharing

- **Cross-Device Sync**: Seamlessly synchronise your data across all your devices
- **Module Sharing**: Share module templates with friends via QR codes
- **Cloud Backup**: Your data is safely stored in the cloud

### 🔔 Smart Features

- **Notifications**: Reminders for upcoming deadlines (customisable timing)
- **Automatic Week Detection**: Always shows your current week
- **Bulk Task Operations**: Complete multiple tasks at once with drag selection
- **Archive System**: Keep your workspace clean by archiving old modules

## 📖 Usage Guide

### First Time Setup

1. **Create Account**:
   - Sign up with email/password
   - Or use Google Sign-In for quick access

2. **Personalise Your Profile**:
   - Set your name in Settings
   - Add your birthday for special celebrations
   - Choose your preferred theme (Light/Dark/System)

3. **Create Your First Semester**:
   - Navigate to Semesters page
   - Add semester with start and end dates
   - The app automatically calculates weeks

4. **Add Your Modules**:
   - Click the green [+] button
   - Enter module name and code
   - Add weekly recurring tasks:
     - Lectures, Labs, Tutorials
     - Flashcard reviews, Custom tasks
   - Add assessments with due dates and weightings

### Daily Usage

1. **View This Week's Tasks**:
   - Open the app to see your current week
   - Drag over multiple tasks to mark them complete
   - Tap individual tasks to cycle through states:
     - ⭕ Not Started → 🔄 In Progress → ✅ Complete

2. **Navigate Weeks**:
   - Use arrow buttons to move between weeks
   - Or tap the week selector to jump to any week

3. **Track Your Progress**:
   - View module cards showing completion percentages
   - Check your overall grade progress
   - See upcoming assignment deadlines

4. **Customise Your Experience**:
   - Go to Settings to adjust:
     - Theme, colours, grade format
     - Week start day, notification preferences
     - Target grade for motivation

## 🔒 Privacy & Data

Your privacy and data security are paramount:

### Data Storage

- **Cloud Sync**: Your data is securely stored on Firebase (Google Cloud Platform)
- **Local Cache**: Local storage for offline access and faster loading
- **Encryption**: All data transmitted is encrypted using HTTPS/TLS

### Privacy Commitment

- ✅ **No Data Selling**: We will never sell, rent, or share your personal data with third parties
- ✅ **No Advertisements**: Completely ad-free experience
- ✅ **No Tracking**: No third-party analytics or tracking beyond essential Firebase services
- ✅ **Data Ownership**: Your data belongs to you
- ✅ **Right to Deletion**: Delete your account and all associated data at any time from Settings
- ✅ **GDPR Compliant**: Built with GDPR principles in mind for European users

### What Data We Store

- Account information (email, name, birthday - optional)
- Academic data (semesters, modules, tasks, assessments)
- App preferences (theme, notifications, customisation settings)
- Task completion history for progress tracking

### Data Access

- Only you can access your data (secured by Firebase Authentication)
- Firestore security rules ensure users can only read/write their own data
- No admin or developer access to your academic information

### Why Is It Free?

Module Tracker is a passion project built to help students succeed. There are no plans for:

- ❌ Paid subscriptions or premium tiers
- ❌ In-app purchases
- ❌ Advertisements
- ❌ Data monetisation

If you find Module Tracker helpful, consider [supporting the development](https://buymeacoffee.com/tyrbujac) - but it's completely optional!

For questions about data privacy or support, contact: **support@tyrbujac.com**

## 📱 Platform Support

### Officially Supported Platforms

- **iOS**: iPhone and iPad (coming to App Store)
- **Android**: Phones and Tablets (coming to Google Play Store)
- **Web**: All modern browsers (Chrome, Safari, Firefox, Edge) - coming soon

### Minimum Requirements

- **iOS**: iOS 12.0 or later
- **Android**: Android 5.0 (Lollipop) or later
- **Web**: Modern browser with JavaScript enabled
- **Internet**: Required for initial sync, offline mode available for viewing

### Cross-Platform Features

All features work consistently across all platforms:

- ✅ Full feature parity
- ✅ Real-time synchronisation
- ✅ Responsive design optimised for each screen size
- ✅ Native performance and feel

## 🚀 Upcoming Features

- **v1.1**: Grading system selector (UK/US/ECTS/Custom)
- **v1.1**: Multiple language support
- **v1.1**: Timetable import from university systems
- **v1.1**: Dynamic weekly timetable (different schedule each week)
- Desktop apps (Windows, macOS, Linux) - under consideration
- Progressive Web App (PWA) for offline-first experience
- Widget support for iOS and Android home screens

---

## 🛠️ For Developers

### Prerequisites

- Flutter SDK (3.35.2 or later)
- Dart SDK (3.9.0 or later)
- Firebase account
- Android Studio / Xcode (for mobile development)
- Chrome (for web development)

### Setup Instructions

#### 1. Install Dependencies

```bash
flutter pub get
```

#### 2. Firebase Configuration

**Step 1: Create Firebase Project**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use existing)
3. Give it a name like "Module Tracker"

**Step 2: Install FlutterFire CLI**

```bash
dart pub global activate flutterfire_cli
```

**Step 3: Configure Firebase**

```bash
flutterfire configure
```

This will:

- Prompt you to select your Firebase project
- Ask which platforms to configure (select Android, iOS, Web, macOS)
- Generate `lib/firebase_options.dart` with your actual Firebase configuration

**Step 4: Enable Firebase Services**

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

#### 3. Run the Application

**Web**

```bash
flutter run -d chrome
```

**Android**

```bash
flutter run -d android
```

**macOS**

```bash
flutter run -d macos
```

### Tech Stack

- **Framework**: Flutter 3.35.2+
- **Language**: Dart 3.9.0+
- **State Management**: Riverpod
- **Backend**: Firebase (Auth, Firestore)
- **Local Storage**: Hive
- **UI Components**:
  - Google Fonts
  - Material Design 3
  - Custom animations and transitions
- **Additional Features**:
  - QR Code generation/scanning
  - URL launching
  - Notifications (local & scheduled)

### Project Structure

```text
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

### Data Models

**Semester**

- Name, start date, end date
- Auto-calculated number of weeks
- Current week detection

**Module**

- Name, code
- Belongs to a semester
- Active/Archived status

**Recurring Task**

- Type (lecture, lab, tutorial, flashcards, custom)
- Day of week
- Optional time
- Auto-generates weekly instances

**Assessment**

- Type (coursework, exam)
- Due date, weighting percentage
- Optional score tracking
- Week number (calculated from due date)

**Task Completion**

- Links to recurring task or assessment
- Week number
- Status (not started, in progress, complete)
- Completion timestamp

### Troubleshooting

**Firebase Not Configured**

If you see placeholder Firebase errors:

1. Run `flutterfire configure`
2. Select your Firebase project
3. Choose platforms to support
4. Restart the app

**Build Errors**

```bash
flutter clean
flutter pub get
flutter run
```

**Firestore Permission Denied**

Check that:

1. User is logged in
2. Firestore security rules are set up correctly
3. Authentication is enabled in Firebase Console

### Design Philosophy

Module Tracker is built with a focus on:

- **User Experience**: Intuitive navigation and smooth animations
- **Accessibility**: Responsive design for all screen sizes
- **Performance**: Optimised for fast loading and smooth scrolling
- **British English**: Proper spelling (colours, organise, etc.)
- **Clean Architecture**: Separation of concerns with clear data flow

---

## 👨‍💻 Developer

**Designed and Built by Tyr**

- Website: [tyrbujac.com](https://tyrbujac.com)
- Support: [Buy Me a Coffee](https://buymeacoffee.com/tyrbujac)
- Email: support@tyrbujac.com

## 🤝 Contributing

This is a personal project for educational and productivity purposes. While this repository is primarily for personal use, you're welcome to:

- Fork the project for your own use
- Submit bug reports via GitHub Issues
- Suggest new features or improvements
- Share feedback on the user experience

## 📄 License

This project is open source and available under the MIT License.

---

**Made with ❤️ for university students**

*Enjoying the app? Consider [supporting the development](https://buymeacoffee.com/tyrbujac)!*
