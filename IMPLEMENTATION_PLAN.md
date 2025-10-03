# Module Tracker - Implementation Plan

## Overview
This document outlines the implementation plan for the remaining features of the Module Tracker app, organized into phases based on priority and dependencies.

---

## ✅ **PHASE 1: Foundation & Cleanup** - **COMPLETED**
*Sets up infrastructure for future features*

**Status:** ✅ Complete
**Completed:** January 2025

### Summary of Completed Work:
- ✅ Created comprehensive design system (`design_tokens.dart`)
- ✅ Built reusable shared components (gradient buttons, loading/error/empty states)
- ✅ Refactored home and login screens to use new components
- ✅ Reviewed and confirmed provider optimization
- ✅ Implemented assessment weighting validation with visual indicators

### Visible Changes:
- Assessment weighting indicator on Assessments screen (green/yellow/red validation)
- Improved empty states with gradient backgrounds
- Consistent loading indicators with messages
- Better error states with retry functionality
- Cleaner, more consistent UI across all screens

---

## **PHASE 1 Details (Archived for Reference):**

### 1.1 Component Extraction & Design System
**Priority: HIGH** - Makes all future work faster

**Files to create:**
- `lib/theme/design_tokens.dart` - Colors, spacing, radii constants
- `lib/widgets/shared/gradient_button.dart`
- `lib/widgets/shared/app_loading_indicator.dart`
- `lib/widgets/shared/app_error_state.dart`
- `lib/widgets/shared/empty_state.dart`

**Files to refactor:**
- `lib/screens/home/home_screen.dart` - Use new components
- `lib/screens/auth/login_screen.dart` - Use gradient buttons
- `lib/screens/semester/semester_setup_screen.dart`

**Tasks:**
- Extract gradient button pattern (used in 5+ places)
- Create consistent spacing scale (4, 8, 12, 16, 24, 32)
- Standardize border radius (8, 12, 16, 24)
- Create standard loading/error/empty states
- Document design tokens

---

### 1.2 Provider Optimization
**Priority: MEDIUM** - Prevents performance degradation

**Files to review:**
- `lib/providers/module_provider.dart`
- `lib/providers/semester_provider.dart`
- Review all `ref.watch` calls in widgets

**Tasks:**
- Identify providers that rebuild unnecessarily
- Convert appropriate StreamProviders to FutureProviders
- Add `.select()` for granular subscriptions
- Consider family providers for assessments
- Add `keepAlive: true` where appropriate
- Profile rebuild frequency in DevTools

---

### 1.3 Assessment Weighting Validation
**Priority: MEDIUM** - Quick win, high user value

**Files to modify:**
- `lib/screens/module/module_form_screen.dart` - Add validation
- `lib/screens/assessments/assessments_screen.dart` - Show warnings
- `lib/widgets/assessment_weighting_indicator.dart` (new widget)

**Tasks:**
- Calculate total weighting on assessment form
- Show warning when ≠ 100%
- Color-code: Green (100%), Yellow (95-99% or 101-105%), Red (<95% or >105%)
- "Quick Fill" button to distribute remaining percentage
- Prominent indicator on assessments screen
- Validation before semester archive

---

## **PHASE 2: Core Features** (2-3 weeks)
*Highest user-facing value*

### 2.1 Task Status Simplification
**Priority: HIGH** - Affects data model, do early

**Decision needed:** Keep 3-state or simplify to 2-state?

**Option A: Simplify to 2-state (Complete/Incomplete)**
- Remove `TaskStatus.inProgress`
- Update `lib/models/task_completion.dart`
- Migrate existing data (in_progress → notStarted)
- Update all UI toggle logic

**Option B: Make in-progress optional**
- Default to 2-state toggle
- Long-press or settings to enable 3-state
- Keep backward compatibility

**Files to modify:**
- `lib/models/task_completion.dart`
- `lib/widgets/weekly_calendar.dart` - Checkbox logic
- `lib/widgets/module_card.dart`
- Database migration function

**Recommendation:** Option A (simpler code, clearer UX)

---

### 2.2 Grade Calculator System
**Priority: HIGH** - Most requested feature

**New files:**
- `lib/models/grade_calculation.dart` - Calculation logic
- `lib/providers/grade_provider.dart` - Grade state management
- `lib/screens/grades/grades_screen.dart` - Main grades view
- `lib/screens/grades/module_grade_card.dart` - Per-module widget
- `lib/screens/grades/what_if_calculator.dart` - "What if" tool
- `lib/widgets/grade_progress_bar.dart` - Visual progress

**Features to implement:**

**2.2.1 Current Module Grade**
- Calculate from completed assessments (markEarned × weighting)
- Handle partial completion (some assessments done)
- Display as percentage and letter grade (A, B+, etc.)
- Show breakdown by assessment

**2.2.2 Semester GPA Calculator**
- Weighted by credits per module
- Support different grading scales (4.0, 5.0, 100%)
- Per-semester and cumulative GPA

**2.2.3 "What If" Calculator**
- Input: target final grade
- Output: required grades on remaining assessments
- Handle impossible scenarios ("You need 110% on final")
- Multiple scenarios (best case, worst case, realistic)

**2.2.4 Progress Visualizations**
- Circular progress indicators per module
- Linear progress bars for semester
- Color-coded by target achievement (on track, at risk, failing)

**Data model additions:**
```dart
class GradeSettings {
  final double targetGrade; // e.g., 70.0 for first class
  final GradeScale scale; // UK, US 4.0, percentage
}

class ModuleGrade {
  final String moduleId;
  final double currentGrade;
  final double projectedGrade;
  final double requiredAverage; // for remaining assessments
  final bool isAchievable;
}
```

**UI Flow:**
1. New "Grades" icon in home screen app bar
2. Shows all modules with current grades
3. Tap module → detailed breakdown
4. "What If" button → calculator dialog
5. Set target grades per module
6. Semester GPA summary at top

---

### 2.3 Module Detail Pages
**Priority: HIGH** - Central hub feature

**New file:**
- `lib/screens/module/module_detail_screen.dart`

**Sections to include:**
1. **Header**
   - Module name, code, credits
   - Current grade (from 2.2)
   - Edit button → module_form_screen
   - Archive button

2. **Statistics Cards**
   - Tasks completed this week
   - Assessments completed / total
   - Current grade + progress bar
   - Upcoming deadlines

3. **Weekly Tasks Tab**
   - All recurring tasks for this module
   - Grouped by day
   - Quick toggle completion for current week
   - Edit/delete tasks

4. **Assessments Tab**
   - All assessments
   - Sortable by date, weighting, type
   - Quick grade entry
   - Pie chart breakdown
   - Weighting validation warnings

5. **Overview Tab** (simple stats)
   - Attendance rate (completed lectures/labs)
   - Assessment completion status
   - Grade trend over semester

**Navigation:**
- Tap module card on home screen → module detail
- Tap module name in weekly calendar → module detail
- Tap module in assessments screen → module detail

---

## **PHASE 3: Enhanced UX** (1-2 weeks)
*Polish and smart features*

### 3.1 Smart Notifications
**Priority: MEDIUM** - Build on existing service

**Files to modify:**
- `lib/services/notification_service.dart` - Extend functionality
- `lib/models/notification_settings.dart` (new) - User preferences
- `lib/screens/settings/settings_screen.dart` - Add notification settings
- `lib/providers/notification_provider.dart` (new)

**Features:**

**3.1.1 Customizable Daily Reminder**
- User picks time (not hardcoded 5pm)
- Option to disable
- Custom message templates

**3.1.2 Assessment Due Alerts**
- Configurable: 1 day, 3 days, 1 week before
- Smart grouping ("3 assessments due this week")
- Don't spam if many assessments same day

**3.1.3 Lecture Reminders**
- "X in 30 mins" (optional)
- Location in notification
- Quick "I'm attending" action

**3.1.4 Weekend Planning Reminder**
- Sunday evening: "Review your week ahead"
- Shows upcoming deadlines

**Settings UI:**
```
Settings > Notifications
├─ Daily Task Reminder
│  ├─ Enabled ✓
│  ├─ Time: 17:00
│  └─ Days: Mon-Fri
├─ Assessment Alerts
│  ├─ 1 day before ✓
│  ├─ 3 days before ✓
│  └─ 1 week before □
└─ Lecture Reminders
   ├─ Enabled □
   └─ Minutes before: 30
```

---

### 3.2 Assessment TBC Handling
**Priority: LOW** - Nice polish

**Files to modify:**
- `lib/screens/module/module_form_screen.dart` - Better TBC UI
- `lib/screens/assessments/assessments_screen.dart` - TBC section
- `lib/widgets/tbc_assessment_banner.dart` (new)

**Features:**
- Separate "To Be Confirmed" section
- Batch edit: "Set all Week X assignments to..."
- Reminder to update TBC items
- Allow adding assessment without due date
- Quick copy from previous semester

---

### 3.3 Pagination for Archive
**Priority: LOW** - Only needed for power users

**Files to modify:**
- `lib/screens/semester/semester_archive_screen.dart`

**Implementation:**
- Load 10 semesters initially
- "Load more" button
- Infinite scroll variant
- Filter by year
- Search by semester name

---

## **PHASE 4: Advanced Features** (2-3 weeks)
*Complex but valuable*

### 4.1 Better Offline Support
**Priority: MEDIUM** - Requires careful design

**New files:**
- `lib/services/sync_queue_service.dart`
- `lib/models/sync_queue_item.dart`
- `lib/providers/connectivity_provider.dart`
- `lib/widgets/sync_status_indicator.dart`

**Architecture:**
1. **Write-through cache**
   - All writes go to local Hive first
   - Queue sync operation
   - Background sync when online

2. **Conflict Resolution**
   - Last-write-wins for most operations
   - User prompt for grade/weighting conflicts
   - Conflict log in settings

3. **UI Indicators**
   - Status bar: "Offline", "Syncing", "Synced"
   - Pending changes count
   - Force sync button
   - Visual feedback per item (synced checkmark)

**Firestore changes:**
- Add `lastModified` timestamp to all documents
- Add `version` field for optimistic locking

**Implementation steps:**
1. Add connectivity listener
2. Implement sync queue (Hive-based)
3. Wrap Firestore calls with queue logic
4. Build conflict detection
5. Create UI indicators
6. Test offline → online transitions

---

### 4.2 Customization
**Priority: LOW** - Nice-to-have

**Files to modify:**
- `lib/models/module.dart` - Add `color` field
- `lib/providers/theme_provider.dart` - Add preferences
- `lib/screens/settings/settings_screen.dart` - Customization section
- `lib/screens/module/module_form_screen.dart` - Color picker

**Features:**
- Per-module color picker (affects cards, calendar)
- Font size: Small, Medium, Large
- Week start day (Monday vs Sunday)
- Default task view (calendar vs list)
- Grade display format (percentage, letter, GPA)

---

### 4.3 Collaboration
**Priority: LOW** - Most complex, future consideration

**Requires:**
- Sharing model (read-only vs collaborative)
- User discovery (email invites)
- Permissions system
- Shared resource repository
- Activity feed
- Backend functions for invites

**Firestore structure changes:**
- `sharedModules` collection
- `modulePermissions` subcollection
- `sharedResources` collection

**This is a 2-3 week project on its own** - Consider v2.0

---

## **Recommended Implementation Order:**

### **Sprint 1** (Week 1-2): Foundation - ✅ **COMPLETED**
1. ✅ Component Extraction & Design System
2. ✅ Assessment Weighting Validation
3. ✅ Provider Optimization

### **Sprint 2** (Week 3-4): Core Value
1. Task Status Simplification
2. Grade Calculator (basic)
3. Module Detail Pages (v1)

### **Sprint 3** (Week 5-6): Enhanced UX
1. Smart Notifications
2. Grade Calculator (what-if tool)
3. Module Detail Pages (polish)

### **Sprint 4** (Week 7-8): Advanced
1. Better Offline Support
2. Assessment TBC Handling
3. Customization basics

### **Future (v2.0)**
1. Pagination optimizations
2. Advanced customization
3. Collaboration features

---

## **Quick Wins to Prioritize:**

Progress tracker:
1. ✅ **Week 1:** Component extraction + Assessment weighting validation - **COMPLETED**
2. **Week 2:** Task status simplification (feels much cleaner) - **NEXT**
3. **Week 3:** Basic grade calculator (current grade only)
4. **Week 4:** Module detail pages

This gives you a significantly better app in 4 weeks, then you can iterate on polish.

---

## Progress Tracker

### Completed Phases:
- ✅ **Phase 1: Foundation & Cleanup** (January 2025)
  - Design system and shared components
  - Assessment weighting validation
  - Provider optimization review

### Current Phase:
- 🔄 **Phase 2: Core Features** (In Progress)
  - Next up: Task Status Simplification

### Upcoming Phases:
- ⏳ Phase 3: Enhanced UX
- ⏳ Phase 4: Advanced Features

---

## Notes

- Each phase builds on previous phases
- Phases can be adjusted based on user feedback
- Testing should be done incrementally after each major feature
- Consider beta testing with real students after Sprint 2
- **Phase 1 completed successfully** - Foundation set for rapid feature development
