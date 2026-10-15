# DocScan — Flutter document scanner

Scan with automatic document edge detection, perspective correction and native auto-capture, then use the existing multi-page editor to crop, enhance, reorder, delete, add pages and share a PDF.

- **Scan / Add** open the native scanner: ML Kit on Android with Google Play services, VisionKit on supported iOS devices. Use Auto mode in the native UI for automatic capture; manual shutter and review remain available. Auto-capture timing and corner detection are controlled by the platform, not a Dart timer.
- Android without Google Play services uses the scanner plugin's manual camera/corner adjustment fallback; automatic detection is unavailable there. First use of the Google scanner may need network access to download its module. iOS scanning needs a supported physical device.
- **Text** recognizes the selected page locally and shows selectable/copyable text. This version recognizes **Latin script** only, including English and accented Latin languages.
- **Searchable PDF** is on by default. Export recognizes every current page and places invisible, selectable word text over the image using OCR coordinates. Noto Sans is bundled (OFL license) so export needs no font download. Empty OCR results produce image-only pages. OCR errors stop export and show a message; retry or explicitly turn off Searchable PDF to export images only.
- Cropping/filtering invalidates cached OCR. Reordering/deleting preserves the remaining pages' OCR. OCR runs on demand, not during capture.
- Recent scans remain in memory for the current app session. Back returns edited pages to the recent list. This is not a persistent document library or a library-wide search feature.

## Setup

Install current stable Flutter with Dart 3.13 or newer (Flutter 3.47+), Android tooling, and Xcode/CocoaPods for iOS. The repository contains app source; generate host projects first:

```sh
flutter create --platforms=android,ios --project-name docscan_clone .
flutter pub get
```

Keep the supplied `lib/`, assets and `pubspec.yaml`. Apply the following host settings **after generation**, before building.

### Android

In `android/app/build.gradle.kts`, use `minSdk = 24`, and `compileSdk` / `targetSdk` at least 36 (or the higher SDK required by your installed Flutter). Install that SDK. Use Java 17, Kotlin 2.2.0 or newer, Android Gradle Plugin 8.12.1 or newer, and Gradle 8.13 or newer, as required by share_plus. Current Flutter host templates supply compatible tooling.

Add to `android/app/src/main/AndroidManifest.xml`, directly inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Inside `<application>`, register the manual crop editor activity required by image_cropper:

```xml
<activity
    android:name="com.yalantis.ucrop.UCropActivity"
    android:screenOrientation="portrait"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar" />
```

The scanner plugin supplies backup exclusions for its own scan directory. If your generated `<application>` already declares `android:dataExtractionRules` or `android:fullBackupContent`, follow the [scanner manifest merge instructions](https://pub.dev/packages/cunning_document_scanner) and keep appropriate exclusions in your own rules. App-owned session images and exported PDFs follow your application's backup policy.

### iOS

Set Runner's minimum deployment target to **15.5** in Xcode and `platform :ios, '15.5'` in `ios/Podfile`. Use Xcode 15.3 or newer / Swift 5 or newer. In the existing Podfile `post_install`, retain `flutter_additional_ios_build_settings(target)` and raise pod deployment targets below 15.5; exclude `armv7` as described in the [OCR plugin setup](https://pub.dev/packages/google_mlkit_text_recognition). Do not replace Flutter's existing post-install hook with a second hook.

For a CocoaPods host, merge this into the existing hook:

```ruby
platform :ios, '15.5'
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=*]'] = 'armv7'
      deployment = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] || '0'
      if Gem::Version.new(deployment) < Gem::Version.new('15.5')
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'
      end
    end
  end
end
```

Add inside `ios/Runner/Info.plist`'s `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>DocScan uses the camera to scan documents.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>DocScan can access document images.</string>
```

Run `cd ios && pod install`, then open `ios/Runner.xcworkspace` to configure signing. The iPad share sheet receives a popover anchor.

```sh
flutter analyze
flutter test
flutter run
```

## Verification and device checklist

Automated tests cover OCR invalidation and searchable/image-only PDF generation. CI also runs `tool/verify_pdf.py` with PyMuPDF to check actual text extraction (including accents), selection geometry, portrait/landscape page sizes, blank pages and identical visible pixels with/without OCR. Native detection and recognition require physical-device testing:

1. Scan a well-lit page using Auto mode; confirm detected corners and automatic shutter. Cancel once and start again.
2. Scan multiple pages; Add more, crop, apply each filter, reorder and delete. Back out and reopen the recent scan.
3. Read Text, edit that page, read Text again and confirm it reflects the edited image.
4. Share a searchable PDF with portrait and landscape pages. In a PDF viewer, search for a distinctive word, copy accented text and check selection alignment.
5. Try blank paper, denied camera permission, first-use module download failure and Android without Play services. Confirm errors are visible and cancellation preserves the editor.
6. Turn searchable export off and confirm an image-only PDF still shares. Test iPad sharing on a device.

Automated checks were run with Flutter 3.47.7 / Dart 3.13.5. Android/iOS host builds and physical-device camera/OCR checks have not been run in this workspace.

## API references and design

Verified against [cunning_document_scanner 3.0.3](https://pub.dev/packages/cunning_document_scanner) (`getPictures`, nullable cancellation, `ScannerSource.camera`), [google_mlkit_text_recognition 0.17.1](https://pub.dev/packages/google_mlkit_text_recognition) (`InputImage.fromFilePath`, Latin `TextRecognizer`, word bounds, `close`) and [pdf TextStyle](https://pub.dev/documentation/pdf/latest/widgets/TextStyle-class.html) (`PdfTextRenderingMode.invisible`). Sharing uses [share_plus 13.3.1](https://pub.dev/packages/share_plus) `SharePlus.instance.share(ShareParams(...))`; manual cropping uses [image_cropper 13.0.0](https://pub.dev/packages/image_cropper). Dependency resolution is recorded in `pubspec.lock`.

`ScannerService` copies plugin-owned scan output to application support storage before returning it to the editor. Image edits use temporary files. `OcrService` releases its recognizer after each page, and `PdfService` embeds the current image and its matching OCR coordinates on pages preserving image aspect ratio. PDFs use unique filenames to avoid overwriting previous exports. Text follows the recognizer's reading order; skewed/curved pages and low-quality scans can reduce accuracy and selection alignment. Other scripts require additional ML Kit models, script selection and matching embedded fonts.

App-owned images and PDFs are not automatically deleted; storage management and a persistent library remain future work. This app uses original branding and assets, without Adobe trademarks or proprietary UI.
