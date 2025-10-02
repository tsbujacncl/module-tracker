# Architecture Overview

## Tech Stack
- **Framework:** Flutter 3.9+
- **State Management:** Riverpod
- **Backend:** Firebase (Auth + Firestore)
- **UI:** Material 3 with custom gradient theme

## Project Structure
```
lib/
├── models/          # Data models (Semester, Module, Assessment, etc.)
├── providers/       # Riverpod providers for state management
├── repositories/    # Firestore data access layer
├── screens/         # UI screens
│   ├── auth/       # Login/Register
│   ├── home/       # Main dashboard
│   ├── module/     # Module creation/editing
│   └── semester/   # Semester setup
├── services/        # Business logic (AuthService, etc.)
├── utils/          # Helper functions
└── widgets/        # Reusable UI components

## Key Design Decisions

### State Management
- Using Riverpod StreamProviders for real-time Firestore data
- Removed autoDispose from main providers to prevent disposal during navigation
- Cached semester in module form to avoid race conditions

### Data Persistence
- Firestore persistence enabled with unlimited cache
- Data loads from cache first, then updates from network
- Ensures offline support and fast initial load

### Theme
- Cyan/blue gradient color scheme (#0EA5E9, #06B6D4, #10B981)
- Google Fonts: Poppins (headings), Inter (body)
- Monday-first calendar locale (en_GB)

## Firebase Structure
```
users/{userId}/
  ├── semesters/{semesterId}
  └── modules/{moduleId}/
      ├── recurringTasks/{taskId}
      ├── assessments/{assessmentId}
      └── taskCompletions/{completionId}
```

## Important Notes
- Always check `mounted` before setState or Navigator operations
- Use debug logging extensively for troubleshooting
- Reset loading states before navigation to prevent stuck buttons
