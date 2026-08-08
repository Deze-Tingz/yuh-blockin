# iOS Build & App Store Submission Guide

This document covers common iOS build issues and their solutions for the Yuh Blockin app.

---

## Pre-Build Checklist

Before submitting to App Store Connect:

- [ ] `lib/main.dart` exists and is committed (entry point)
- [ ] All changes pushed to the correct branch (check Codemagic workflow settings)
- [ ] Version and build number updated in `pubspec.yaml`
- [ ] App created in App Store Connect with matching Bundle ID

---

## Common Build Errors

### 1. "Target file lib/main.dart not found"

**Cause:** The entry point file isn't in the repository or Codemagic is using wrong branch.

**Fix:**
```bash
# Ensure main.dart exists and is committed
git add lib/main.dart
git commit -m "Add main.dart entry point"
git push
```

Also verify Codemagic workflow is set to the correct branch (`main` vs `master`).

---

### 2. "Cannot determine Apple ID from Bundle ID"

**Cause:** App doesn't exist in App Store Connect.

**Fix:**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. My Apps → + → New App
3. Fill in:
   - Platform: iOS
   - Name: Yuh Blockin
   - Bundle ID: `com.dezetingz.yuhBlockin`
   - SKU: `yuh-blockin-app` (any unique identifier)
4. Create the app, then re-run build

---

### 3. iPad Orientation Validation Error

**Error:** `Invalid bundle. The "UIInterfaceOrientationPortrait" orientations were provided...`

**Cause:** Apple requires all orientations declared for iPad multitasking support.

**Fix:** Add all orientations to `ios/Runner/Info.plist`:
```xml
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

Note: Your app will still lock to portrait in code; this just satisfies App Store requirements.

---

### 4. Export Compliance / Encryption Prompt

**Question:** "What type of encryption algorithms does your app implement?"

**Answer:** Select "None of the algorithms mentioned above" if you only use:
- HTTPS (handled by Apple's OS)
- Standard APIs (Supabase, RevenueCat, etc.)

**Permanent Fix:** Add to `ios/Runner/Info.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

### 5. iOS Text Spacing Issues (Extra Line Height)

**Symptom:** Text appears with excessive vertical spacing on iOS but looks normal on Android.

**Cause:** The `height` property in `TextStyle` is interpreted differently on iOS vs Android. iOS adds extra padding above/below text when `height` is specified.

**Fix:** Remove all `height` properties from TextStyle declarations:

```dart
// BAD - causes spacing issues on iOS
TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.4,  // REMOVE THIS
)

// GOOD - uses platform default line height
TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
)
```

**Files to check:**
- `lib/core/theme/premium_theme.dart` (theme text styles)
- Any file with inline TextStyle declarations

**Command to find all instances:**
```bash
grep -r "height: 1\." lib/ --include="*.dart"
```

---

## Info.plist Reference

Key entries for `ios/Runner/Info.plist`:

```xml
<!-- App Display Name -->
<key>CFBundleDisplayName</key>
<string>Yuh Blockin</string>

<!-- iPad Orientations (required for App Store) -->
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>

<!-- Export Compliance -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## Codemagic Configuration

The app uses Codemagic for CI/CD. Key settings:

- **Branch:** Ensure workflow uses `main` (not `master`)
- **Build command:** `flutter build ipa --release`
- **Export options:** Auto-generated via `xcode-project use-profiles`

---

## Version Bumping

Before each release, update version in `pubspec.yaml`:

```yaml
version: 1.0.1+2  # format: version+buildNumber
```

- Increment build number for every upload
- Version string for user-visible changes

---

## Troubleshooting

### Build succeeds but upload fails
- Check App Store Connect for existing app with same Bundle ID
- Verify provisioning profiles are valid and not expired
- Ensure version/build number is higher than previous uploads

### App rejected for missing functionality
- Test all features on physical iOS device
- Ensure push notifications work (not just simulator)
- Verify in-app purchases are configured in App Store Connect

### Slow build times
- Check for unnecessary dependencies
- Consider using build cache in Codemagic

---

## Useful Commands

```bash
# Check for iOS-specific issues
flutter analyze

# Build locally for testing
flutter build ios --release

# Check provisioning profiles
security find-identity -v -p codesigning

# List simulators
xcrun simctl list devices
```

---

## Resources

- [App Store Connect](https://appstoreconnect.apple.com)
- [Apple Developer Portal](https://developer.apple.com)
- [Codemagic Documentation](https://docs.codemagic.io)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
