# Module Tracker - Roadmap to v1.0 (9/10 Rating)

**Current Rating:** 8.0/10
**Target Rating:** 9.0/10
**Timeline:** 2-3 weeks
**Last Updated:** January 11, 2025

---

## ✅ Week 1: Production Readiness (COMPLETED)

All tasks complete! App is now production-grade:

- [x] Professional logging system with AppLogger
- [x] Replace all 150+ print() statements
- [x] Firebase Crashlytics integration
- [x] Custom exception classes (10+ types)
- [x] Environment configuration (.env)
- [x] OAuth secrets moved to environment variables
- [x] Privacy Policy & Terms of Service (GDPR compliant)

**Production Readiness Score:** 6.5/10 → **9/10** ✨

---

## 🎯 Week 2: Core Features (Target: 8.5/10)

**Goal:** Add missing user-requested features
**Time Estimate:** 5-7 days
**Priority:** HIGH

### 2.1 Degree-Level Grade Tracking (HIGH PRIORITY)
**Status:** Not Started
**Time:** 2-3 days

- [ ] Create `DegreeSettings` model with year weightings
  - Year 1: 0% (configurable)
  - Year 2: 33% (configurable)
  - Year 3: 67% (configurable)
  - Final year: 100% (configurable)

- [ ] Create `DegreeGrade` model
  - Track year-by-year GPA
  - Calculate weighted cumulative average
  - Project final degree classification (First, 2:1, 2:2, Third, Pass)

- [ ] New screen: "Overall Degree" or add to existing grades
  - Year breakdown view (Year 1, Year 2, Year 3, etc.)
  - Weighted cumulative GPA display
  - Projected final classification with visual indicator
  - Progress bar for each year
  - "What I need" calculator (for target classification)

- [ ] Settings: Configure year weightings
  - Default UK weighting (0%, 33%, 67%)
  - Allow custom weightings per university
  - Save to user preferences

- [ ] Provider: `degree_grade_provider.dart`
  - Calculate year averages
  - Apply weighting formula
  - Project final grade
  - Calculate required grades for target classification

**Acceptance Criteria:**
- User can see year-by-year grade breakdown
- Cumulative weighted average displays correctly
- Can configure custom year weightings
- Projects final classification accurately

---

### 2.2 Redesign Assessments Page (MEDIUM PRIORITY)
**Status:** Not Started
**Time:** 2 days

**Current Problems:**
- Poor layout/UX - hard to scan
- No overall grade display
- Limited filtering/sorting
- No prioritization visual

**Improvements:**

- [ ] Add overall grade widget at top
  - Current semester GPA
  - Overall degree GPA (once 2.1 is done)
  - Quick stats (pending, submitted, graded)

- [ ] Improve card layout
  - Larger touch targets
  - Better visual hierarchy
  - Priority indicators (overdue in red, due soon in orange)
  - Module color coding

- [ ] Add filtering options
  - Filter by: All, Pending, Submitted, Graded
  - Filter by module
  - Filter by priority level
  - Show/hide completed

- [ ] Add sorting options
  - Sort by: Due date, Module, Weighting, Priority
  - Toggle ascending/descending

- [ ] Add search functionality
  - Search by assessment name
  - Quick filter chips

- [ ] Better empty states
  - "No assessments yet" with helpful message
  - "All caught up!" for completed state

**Acceptance Criteria:**
- User can quickly find what's due soon
- Overall grade visible at top
- Can filter and sort assessments easily
- Better visual hierarchy

---

### 2.3 Timetable Export (.ics Calendar) (MEDIUM PRIORITY)
**Status:** Not Started
**Time:** 1-2 days

**Goal:** Export schedule to any calendar app

- [ ] Install `icalendar` or similar package

- [ ] Create `CalendarExportService`
  - Generate .ics file from recurring tasks
  - Include assessments as events
  - Add location data for lectures/labs
  - Set reminders based on user preferences

- [ ] Export options:
  - Export current semester
  - Export specific module
  - Export all active modules
  - Date range selection

- [ ] Sharing mechanism:
  - Generate .ics file
  - Share via native share sheet
  - Save to files/downloads
  - Generate QR code for quick import

- [ ] Test compatibility:
  - Google Calendar
  - Apple Calendar
  - Outlook
  - Other calendar apps

**Acceptance Criteria:**
- User can export schedule as .ics file
- File imports correctly into major calendar apps
- Includes all recurring tasks and assessments
- Can share via multiple methods

---

## 🧪 Week 3: Testing & Code Quality (Target: 9.0/10)

**Goal:** Reduce risk and improve maintainability
**Time Estimate:** 5-7 days
**Priority:** HIGH (for production apps)

### 3.1 Unit Tests (CRITICAL)
**Status:** Not Started
**Time:** 3-4 days
**Target Coverage:** 60-70% of business logic

**Priority Tests:**

- [ ] **Grade Calculations (HIGHEST PRIORITY)**
  ```
  test/models/grade_calculation_test.dart (20+ tests)
  ```
  - Test weighted average calculation
  - Test UK classification boundaries (70%, 60%, 50%, 40%)
  - Test edge cases (no grades, all zeros, 100% scores)
  - Test required average calculation
  - Test projection accuracy
  - Test degree-level weighting (once 2.1 done)

- [ ] **Date & Week Utilities (HIGH PRIORITY)**
  ```
  test/utils/date_utils_test.dart (15+ tests)
  ```
  - Test week number calculation
  - Test semester date ranges
  - Test current week detection
  - Test semester breaks handling
  - Test reading week logic
  - Test exam period dates

- [ ] **Semester Logic (MEDIUM PRIORITY)**
  ```
  test/models/semester_test.dart (10+ tests)
  ```
  - Test semester creation
  - Test week count calculation
  - Test auto-archiving logic
  - Test date validation

- [ ] **Module & Assessment Logic (MEDIUM PRIORITY)**
  ```
  test/models/module_test.dart (10+ tests)
  test/models/assessment_test.dart (10+ tests)
  ```
  - Test module GPA calculation
  - Test assessment weighting validation
  - Test status transitions
  - Test completion tracking

- [ ] **Providers (MEDIUM PRIORITY)**
  ```
  test/providers/grade_provider_test.dart
  test/providers/semester_provider_test.dart
  ```
  - Test state updates
  - Test computed values
  - Test error handling

**Total Target:** 60-80 unit tests

**Setup:**
- [ ] Configure test environment
- [ ] Add `mocktail` for mocking
- [ ] Set up test fixtures/mock data
- [ ] Configure CI for test running

---

### 3.2 Widget Tests (MEDIUM PRIORITY)
**Status:** Not Started
**Time:** 2 days
**Target:** 20-30 widget tests

**Priority Widgets:**

- [ ] **Grade Display Widgets**
  ```
  test/widgets/overall_grade_widget_test.dart (5 tests)
  test/widgets/module_card_test.dart (5 tests)
  ```
  - Test grade rendering
  - Test color coding
  - Test tap interactions

- [ ] **Calendar Widget**
  ```
  test/widgets/weekly_calendar_test.dart (8 tests)
  ```
  - Test event rendering
  - Test time calculations
  - Test gesture handling
  - Test empty states

- [ ] **Assessment Card**
  ```
  test/widgets/assessment_card_test.dart (5 tests)
  ```
  - Test status display
  - Test priority indicators
  - Test overdue highlighting

- [ ] **Navigation**
  ```
  test/widgets/week_navigation_bar_test.dart (5 tests)
  ```
  - Test week switching
  - Test boundary conditions

**Total Target:** 25-30 widget tests

---

### 3.3 Code Cleanup & Refactoring (LOW-MEDIUM PRIORITY)
**Status:** Not Started
**Time:** 1-2 days

- [ ] **Split Large Files**
  - `settings_screen.dart` (1,985 lines) → 3-4 files
    - Split into: AccountSettings, CustomizationSettings, LegalSettings
  - Extract dialog methods to separate files
  - Extract large widget builders to components

- [ ] **Extract Utilities**
  - `ResponsiveUtils` class for repeated scaling logic
  - `ValidationUtils` for form validation
  - `DateFormatUtils` for date formatting

- [ ] **Add Documentation**
  - Add dartdoc comments to public APIs
  - Document complex algorithms (grade calc, week calc)
  - Add README to each major directory
  - Create ARCHITECTURE.md

- [ ] **Performance Optimization**
  - Add pagination to Firestore queries (limit: 50 items)
  - Add `const` constructors where possible
  - Profile with Flutter DevTools
  - Optimize rebuild performance

- [ ] **Remove Dead Code**
  - Remove unused imports (analyzer warnings)
  - Remove commented-out code
  - Remove unused variables/methods

**Acceptance Criteria:**
- No files >500 lines
- Zero analyzer warnings
- Public APIs documented
- Performance profiling shows <2s load time

---

## 🚀 Week 4: App Store Preparation (Target: Ready for Launch)

**Goal:** Final polish and submission readiness
**Time Estimate:** 3-5 days
**Priority:** MEDIUM-HIGH (for public release)

### 4.1 App Store Requirements (CRITICAL)
**Status:** Privacy Policy ✅ | Rest Not Started
**Time:** 2-3 days

- [x] Privacy Policy (✅ DONE - upload to tyrbujac.com)
- [x] Terms of Service (✅ DONE - upload to tyrbujac.com)

- [ ] **App Icons**
  - iOS: All required sizes (1024x1024, 180x180, 120x120, etc.)
  - Android: Adaptive icon + legacy icons
  - Web: favicon + manifest icons
  - macOS: If supporting desktop

- [ ] **Screenshots**
  - iOS: 6.7" (iPhone 14 Pro Max), 6.5", 5.5"
  - Android: 5.5", 7", 10" tablet
  - Minimum 4 screenshots per device size
  - Show key features: calendar, grades, assessments, settings

- [ ] **App Description**
  - App Store: 170 chars for subtitle, 4000 for description
  - Play Store: 80 chars for short, 4000 for long
  - Keywords for ASO (App Store Optimization)
  - What's New section

- [ ] **App Store Connect Setup**
  - Create app listing
  - Configure pricing (free)
  - Set up TestFlight for beta testing
  - Add app categories (Education, Productivity)
  - Age rating (4+)

- [ ] **Play Console Setup**
  - Create app listing
  - Configure internal/alpha/beta tracks
  - Content rating questionnaire
  - Target audience (University students)

---

### 4.2 Platform Testing (HIGH PRIORITY)
**Status:** Not Started
**Time:** 1-2 days

- [ ] **iOS Testing**
  - Test on physical iPhone (iOS 15+)
  - Test on physical iPad (landscape/portrait)
  - Test Sign in with Apple
  - Test push notifications
  - Test accessibility (VoiceOver)

- [ ] **Android Testing**
  - Test on physical Android device (API 23+)
  - Test on tablet
  - Test Google Sign-In
  - Test back button behavior
  - Test TalkBack accessibility

- [ ] **Web Testing**
  - Test on Chrome, Safari, Firefox, Edge
  - Test responsive design (mobile, tablet, desktop)
  - Test Google Sign-In on web
  - Test deep linking

- [ ] **Edge Cases**
  - No internet connection behavior
  - Empty states (no modules, no assessments)
  - Offline sync testing
  - Data migration (upgrade scenarios)

---

### 4.3 Performance & Optimization (MEDIUM PRIORITY)
**Status:** Not Started
**Time:** 1 day

- [ ] **Performance Profiling**
  - Profile with Flutter DevTools
  - Check for rebuild issues
  - Optimize large lists (use ListView.builder)
  - Add pagination to long lists

- [ ] **App Size Optimization**
  - Analyze app bundle size
  - Remove unused assets
  - Enable code shrinking (ProGuard/R8)
  - Target: <30MB download size

- [ ] **Loading Time Optimization**
  - Optimize initial load (<2 seconds)
  - Add splash screen with proper branding
  - Preload critical data
  - Lazy load non-essential features

- [ ] **Battery & Memory**
  - Profile memory usage
  - Check for memory leaks
  - Optimize background tasks
  - Test battery drain

---

### 4.4 Final Polish (LOW-MEDIUM PRIORITY)
**Status:** Not Started
**Time:** 1 day

- [ ] **User Onboarding**
  - Improve first-time setup flow
  - Add feature tooltips/tours (optional)
  - Sample data option for demo/testing

- [ ] **Accessibility**
  - Run accessibility scanner
  - Test with VoiceOver (iOS) / TalkBack (Android)
  - Ensure proper semantic labels
  - Test keyboard navigation (web)
  - Color contrast compliance (WCAG AA)

- [ ] **Analytics (Optional)**
  - Firebase Analytics for usage tracking
  - Track feature adoption rates
  - Monitor crash-free rate
  - Set up custom events
  - **Note:** Update Privacy Policy if adding analytics

- [ ] **Error Messages**
  - Review all user-facing error messages
  - Ensure they're helpful and actionable
  - Add recovery suggestions
  - Test error scenarios

---

## 📦 Bonus Features (v1.1+)

**Priority:** LOW - Nice to have, but not required for 9/10

### Future Enhancements

- [ ] **Dark Mode**
  - Complete theme system (removed earlier, but could re-implement properly)
  - Test all screens in dark mode
  - Follow system theme setting

- [ ] **Data Export**
  - Export grades to CSV
  - Export schedule to PDF
  - Backup/restore functionality
  - Share progress report

- [ ] **Smart Notifications**
  - "You have 3 deadlines this week" summary
  - Weekly progress notifications
  - Motivational messages
  - Customizable notification timing

- [ ] **University System Import**
  - Parse timetable from university portal
  - Auto-import modules and assessments
  - Requires per-university implementation
  - **Very complex** - recommend v2.0+

- [ ] **Widgets**
  - iOS home screen widgets (upcoming deadlines)
  - Android app widgets
  - macOS menu bar widget

- [ ] **Collaboration Features**
  - Study groups
  - Share notes with classmates
  - Module recommendations
  - Social features

- [ ] **AI Features**
  - Grade predictions based on historical data
  - Study time recommendations
  - Deadline reminders based on workload
  - Requires ML model training

---

## 🎯 Priority Matrix

### Must-Have for 9/10 (Week 2-3)
1. ⚠️ **Unit tests for grade calculations** (CRITICAL - prevents calculation errors)
2. ⭐ **Degree-level grade tracking** (HIGH - user requested, key feature)
3. ⚠️ **Unit tests for date/week utilities** (CRITICAL - prevents scheduling bugs)
4. ⭐ **Redesigned assessments page** (HIGH - improves UX significantly)

### Should-Have for 9/10 (Week 3-4)
5. 🧪 **Widget tests** (MEDIUM - improves stability)
6. 📅 **Calendar export (.ics)** (MEDIUM - nice convenience feature)
7. 🛠️ **Code cleanup** (MEDIUM - improves maintainability)
8. 📱 **Platform testing** (HIGH - ensures it works everywhere)

### Nice-to-Have for Polish (Week 4)
9. 📸 **App Store assets** (HIGH for public release, but can be added later)
10. ⚡ **Performance optimization** (MEDIUM - only if issues found)
11. 📊 **Analytics** (LOW - optional for v1.0)
12. 🎨 **Accessibility improvements** (MEDIUM - important for inclusivity)

---

## 📊 Expected Rating Progression

| Milestone | Rating | Effort | Time |
|-----------|--------|--------|------|
| **Current State** | 8.0/10 | ✅ Done | - |
| **Week 2: Features** | 8.5/10 | Medium | 5-7 days |
| **Week 3: Testing** | 9.0/10 | High | 5-7 days |
| **Week 4: Polish** | 9.0/10 | Medium | 3-5 days |

---

## ⏱️ Time Estimates Summary

**To 9/10 Rating:**
- **Minimum (Fast Track):** 10-12 days
  - Week 2 essentials: Degree tracking + assessment redesign (4 days)
  - Week 3 essentials: Critical unit tests only (4 days)
  - Week 4 essentials: Basic platform testing (2 days)

- **Recommended (Balanced):** 15-18 days
  - Week 2: All features (6 days)
  - Week 3: Full testing + cleanup (7 days)
  - Week 4: Basic polish (2 days)

- **Comprehensive (Best Quality):** 20-25 days
  - Week 2: All features (7 days)
  - Week 3: Full testing + cleanup (8 days)
  - Week 4: Full polish + App Store prep (5 days)

---

## 🚦 Decision Points

### Option A: Submit Now (8/10)
**Pros:**
- Get user feedback early
- Start building audience
- Iterate based on real usage

**Cons:**
- No tests = higher bug risk
- Missing key features users want
- May get poor reviews if buggy

**Recommended if:** You want to validate market fit quickly

---

### Option B: Add Features First (8.5/10)
**Pros:**
- More complete feature set
- Better first impression
- Users less likely to complain about missing features

**Cons:**
- Still no tests
- Delays launch by 1 week

**Recommended if:** User feedback indicated these features are critical

---

### Option C: Add Tests First (8.5/10)
**Pros:**
- Much lower bug risk
- Confidence in calculations
- Easier to refactor later

**Cons:**
- No new features for users
- Testing isn't visible to users

**Recommended if:** You expect 1,000+ users and can't afford bugs

---

### Option D: Full 9/10 (Recommended)
**Pros:**
- Complete feature set
- Tested and stable
- Professional quality
- Strong foundation for growth

**Cons:**
- Delays launch by 2-3 weeks

**Recommended if:** You want a solid foundation before public launch

---

## 📝 Notes

- This roadmap assumes ~4-6 hours/day of focused work
- Adjust timelines based on your availability
- Feel free to skip "Bonus Features" section entirely
- Testing is optional but strongly recommended for production apps
- Week 4 (App Store prep) can be done in parallel with Week 2-3

---

## 🎓 Learning Project Considerations

Since you mentioned this is a "learning project" before your main apps:

**What you should prioritize:**
1. ✅ **Testing** - Critical skill for professional development
2. ✅ **Code quality** - Learn to write maintainable code
3. ✅ **Error handling** - Already done well! ✨
4. ⚠️ **Performance** - Important but can wait

**What you can skip:**
- ❌ Dark mode (nice-to-have)
- ❌ Advanced analytics (overkill for learning)
- ❌ AI features (way too complex)
- ❌ Collaboration (different project entirely)

**Key Takeaway:**
Focus on **testing + core features** to learn professional development practices. These skills will transfer to your main apps!

---

## 📞 Questions or Changes?

This roadmap is a living document. Update it as priorities change or new requirements emerge.

**Current Focus:** Week 2 (Features) vs Week 3 (Testing) - which comes first is up to you!

---

**Last Updated:** January 11, 2025
**Version:** 1.0
**Created by:** Claude Code
