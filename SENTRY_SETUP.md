# Sentry Integration Setup

## Step 1: Add Sentry SDK to Xcode Project

1. Open `focusmate.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the `focusmate` target
4. Go to **Package Dependencies** tab
5. Click the **+** button
6. Enter the Sentry repository URL: `https://github.com/getsentry/sentry-cocoa.git`
7. Select **Up to Next Major Version** with `8.0.0` as the minimum
8. Click **Add Package**
9. Select **Sentry** and **SentrySwiftUI** frameworks
10. Click **Add Package**

## Step 2: Get Sentry DSN

1. Go to [https://sentry.io](https://sentry.io) and sign in (or create account)
2. Create a new project or select existing project
3. Choose **iOS** as the platform
4. Copy the **DSN** (looks like: `https://xxxxx@sentry.io/xxxxx`)

## Step 3: Add DSN to Info.plist

1. Open `focusmate/Info.plist`
2. Add a new key `SENTRY_DSN` with your DSN as the value

Alternatively, for security, you can store it in a separate config file or environment variable.

## Step 4: Build the Project

After adding the Sentry SDK, the SentryService.swift file will automatically work with the SDK.

```bash
xcodebuild -project focusmate.xcodeproj -scheme focusmate -sdk iphonesimulator build
```

## Features Included

✅ Error and crash reporting
✅ Performance monitoring
✅ Network request tracking
✅ Breadcrumb tracking for debugging
✅ User context management
✅ Custom tags and context
✅ Session tracking
✅ Automatic performance tracing

## Testing

Once integrated, you can test Sentry by:
1. Triggering an intentional error
2. Checking the Sentry dashboard for the error
3. Verifying breadcrumbs and context appear correctly

## Environment Configuration

The service automatically detects the environment:
- **DEBUG builds**: environment = "development", debug mode enabled
- **RELEASE builds**: environment = "production", debug mode disabled

## Privacy & Performance

- Network tracking is enabled but can be disabled if needed
- Sample rate for transactions: 100% (adjust in SentryService.swift if needed)
- Session replay: disabled by default, only on errors
- Stack traces: attached automatically

## Documentation

- Sentry iOS SDK: https://docs.sentry.io/platforms/apple/guides/ios/
- Performance Monitoring: https://docs.sentry.io/platforms/apple/guides/ios/performance/
