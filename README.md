# DocScan Clone — Flutter MVP

A clean mobile document scanner inspired by the workflow of Adobe Scan, with original branding/UI.

## Included
- Camera capture
- Multi-page scans
- Manual crop / perspective adjustment UI
- Auto, grayscale and B&W enhancement filters
- Reorder and delete pages
- PDF generation
- Native share sheet export
- Simple recent-scans UI for the current app session

## Run
1. Install Flutter 3.24+ and platform tooling.
2. From this folder run:
   ```bash
   flutter create .
   flutter pub get
   flutter run
   ```
   `flutter create .` adds the Android/iOS host projects while keeping the supplied `lib/` source.

## Required platform permissions

### iOS — ios/Runner/Info.plist
Add inside `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>DocScan uses the camera to scan documents.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>DocScan can import document images from your photo library.</string>
```

### Android
`image_picker` handles standard camera intents. Verify your generated Android project targets a current SDK and follow package documentation if your build environment requires extra configuration.

## Architecture
- `models/` scan data
- `services/image_service.dart` image crop/filter pipeline
- `services/pdf_service.dart` PDF creation
- `screens/home_screen.dart` scan library / capture entry
- `screens/editor_screen.dart` multi-page editor and export

## Production upgrades
The MVP uses the system camera followed by crop. For a production-grade Adobe Scan-like experience, add live quadrilateral edge detection, auto-capture when the document is stable, OCR/searchable PDF, persistent metadata/database, cloud sync, authentication, encryption, and automated tests.

## Notes
This project does not copy Adobe trademarks, icons, assets, or proprietary UI. It implements a similar document-scanning workflow with original branding.
