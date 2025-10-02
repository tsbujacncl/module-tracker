# Development Guidelines

## Code Style

### Flutter/Dart Conventions
- Use `const` constructors wherever possible
- Prefer `final` over `var` for immutable values
- Always check `mounted` before async operations that modify UI
- Use descriptive variable names (no single letters except for loops)

### State Management Rules
1. Don't use `autoDispose` on providers that are watched during navigation
2. Always reset `_isLoading` states before navigation
3. Add small delays (100ms) before navigation to ensure UI updates
4. Cache data locally when dealing with Firestore race conditions

### Error Handling
- Wrap async operations in try-catch blocks
- Show user-friendly error messages via SnackBars
- Add debug logging for troubleshooting: `print('DEBUG: ...')`
- Log both error and stack trace: `catch (e, stackTrace)`

### Navigation
- Always use `if (mounted)` before `Navigator` operations
- Reset loading states before navigation
- Clear cached data after successful operations
- Use small delays to ensure state updates complete

## Firebase Best Practices

### Firestore
- Enable persistence and unlimited cache size
- Use streams for real-time updates
- Verify writes with read-back in debug mode
- Structure data by user to ensure proper security

### Authentication
- Always check for null user before operations
- Log auth state changes for debugging
- Handle all FirebaseAuthException cases

## UI/UX Guidelines

### Forms
- Validate all inputs before submission
- Show clear error messages
- Disable buttons during loading with CircularProgressIndicator
- Auto-close dialogs/screens after successful submission

### Loading States
- Use `CircularProgressIndicator` for async operations
- Always provide loading, data, and error states
- Show cached data immediately, update from network

### Design System
- Use gradient backgrounds consistently
- Constrain form widths (400-700px depending on content)
- Use Google Fonts for typography
- Follow Material 3 guidelines

## Testing Checklist

Before marking a feature complete:
- [ ] Works on first run (no existing data)
- [ ] Works after app restart (data persists)
- [ ] Works offline (cache enabled)
- [ ] No stuck loading states
- [ ] Auto-closes after successful operations
- [ ] Shows appropriate error messages
- [ ] Logs debug information
