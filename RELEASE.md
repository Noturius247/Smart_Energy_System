# Release Guide for Smart Energy System

## Quick Release (Automated via GitHub Actions)

### Method 1: Create a Git Tag
```bash
# 1. Make sure all changes are committed
git add .
git commit -m "Release v1.0.0"

# 2. Create a version tag
git tag v1.0.0

# 3. Push the tag to GitHub
git push origin v1.0.0
```

Once you push the tag, GitHub Actions will automatically:
- Build Android APK
- Build Android App Bundle (AAB)
- Build Windows executable
- Build Web version
- Create a GitHub Release with all files attached

### Method 2: Manual Trigger from GitHub
1. Go to your repository on GitHub
2. Click on **Actions** tab
3. Select **Build and Release** workflow
4. Click **Run workflow** button
5. Choose the branch and click **Run workflow**

## Manual Local Build

If you want to build locally without GitHub Actions:

### Windows
```bash
# Run the build script
build-release.bat
```

### Manual Commands
```bash
# Get dependencies
flutter pub get

# Build Android APK
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --release

# Build Windows
flutter build windows --release

# Build Web
flutter build web --release
```

## Build Outputs

After building, you'll find the files at:

| Platform | Location |
|----------|----------|
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` |
| Android AAB | `build/app/outputs/bundle/release/app-release.aab` |
| Windows | `build/windows/x64/runner/Release/` |
| Web | `build/web/` |

## Version Numbering

Update version in [pubspec.yaml](pubspec.yaml):
```yaml
version: 1.0.0+1
#        │ │ │ │
#        │ │ │ └── Build number (increment for each build)
#        │ │ └──── Patch version (bug fixes)
#        │ └────── Minor version (new features, backwards compatible)
#        └──────── Major version (breaking changes)
```

## Pre-Release Checklist

Before creating a release:

- [ ] All tests pass: `flutter test`
- [ ] No analysis issues: `flutter analyze`
- [ ] Update version in `pubspec.yaml`
- [ ] Update CHANGELOG.md (if you have one)
- [ ] Test the app on Android/Windows
- [ ] Commit all changes
- [ ] Create and push git tag

## Publishing to Stores

### Google Play Store
1. Use the `app-release.aab` file from `build/app/outputs/bundle/release/`
2. Go to [Google Play Console](https://play.google.com/console)
3. Select your app
4. Go to **Production** > **Create new release**
5. Upload the AAB file
6. Fill in release notes and submit

### Direct Distribution
1. Share the `app-release.apk` file
2. Users need to enable "Install from Unknown Sources" on their devices
3. They can install directly by opening the APK

### Web Hosting
1. Upload contents of `build/web/` to your web server
2. Configure server for SPA routing (if needed)
3. Ensure Firebase hosting is configured (if using Firebase)

## Firebase Configuration

Make sure Firebase is properly configured before release:
- Android: `android/app/google-services.json`
- Web: Firebase config in web hosting
- iOS (if applicable): `ios/Runner/GoogleService-Info.plist`

## Troubleshooting

### Build Fails
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### GitHub Actions Fails
- Check the Actions tab for error logs
- Ensure all secrets are configured (if needed)
- Verify the Flutter version in workflow matches your local version

### APK Size Too Large
```bash
# Build split APKs per ABI
flutter build apk --split-per-abi --release
```

## GitHub Release Assets

When GitHub Actions completes, your release will include:
- `app-release.apk` - Android installation file
- `app-release.aab` - Google Play Store bundle
- `smart-energy-windows.zip` - Windows application
- `smart-energy-web.zip` - Web build for hosting

## Notes

- The GitHub Actions workflow requires GitHub repository write permissions
- First-time setup may require enabling GitHub Actions in repository settings
- Tags must follow semantic versioning: `v1.0.0`, `v1.2.3`, etc.
