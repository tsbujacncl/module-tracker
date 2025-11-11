# Environment Configuration Setup

This app uses environment variables to store sensitive configuration like OAuth client IDs.

## Initial Setup

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in your actual values** in the `.env` file:
   - `GOOGLE_WEB_CLIENT_ID`: Get this from Firebase Console > Authentication > Sign-in method > Google > Web SDK configuration

## Important Security Notes

⚠️ **NEVER commit the `.env` file to version control!**

- The `.env` file is already in `.gitignore`
- Only commit `.env.example` with placeholder values
- Each developer/environment should have their own `.env` file

## Accessing Environment Variables

Use the `EnvConfig` helper class for type-safe access:

```dart
import 'package:module_tracker/utils/env_config.dart';

// Get required variable (throws if missing)
final clientId = EnvConfig.googleWebClientId;

// Get with fallback
final appName = EnvConfig.get('APP_NAME', fallback: 'Module Tracker');

// Get or null
final optionalValue = EnvConfig.getOrNull('OPTIONAL_KEY');

// Check if exists
if (EnvConfig.has('SOME_KEY')) {
  // ...
}
```

## Adding New Environment Variables

1. Add to `.env` file with actual value
2. Add to `.env.example` with placeholder
3. (Optional) Add type-safe getter to `EnvConfig` class:
   ```dart
   static String get myNewVariable => get('MY_NEW_VARIABLE');
   ```

## Deployment

### Web (Netlify)
- Add environment variables in Netlify dashboard: Site Settings > Environment Variables
- Netlify will inject these during build time

### iOS/Android
- For App Store/Play Store: Add to CI/CD environment secrets
- For local builds: Keep `.env` file locally (not committed)

## Troubleshooting

**Error: "Environment variable X not found"**
- Make sure you copied `.env.example` to `.env`
- Check that the variable exists in your `.env` file
- Restart the app after changing `.env` file

**Google Sign-In not working on web**
- Verify `GOOGLE_WEB_CLIENT_ID` matches your Firebase Console configuration
- Clear browser cache and try again
