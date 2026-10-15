# DocScan — Flutter document scanner

Scan with automatic document edge detection, perspective correction and native auto-capture, then use the existing multi-page editor to crop, enhance, reorder, delete, add pages and share a PDF.

- **Scan / Add** open the native scanner: ML Kit on Android with Google Play services, VisionKit on supported iOS devices. Use Auto mode in the native UI for automatic capture; manual shutter and review remain available. Auto-capture timing and corner detection are controlled by the platform, not a Dart timer.
- Android without Google Play services uses the scanner plugin's manual camera/corner adjustment fallback; automatic detection is unavailable there. First use of the Google scanner may need network access to download its module. iOS scanning needs a supported physical device.
- **OCR** recognizes the selected page locally, then lets you correct or clear individual words while retaining their position on the page. Corrections change searchable PDF text; the scanned image itself stays visible. This version recognizes **Latin script** only, including English and accented Latin languages.
- **Searchable PDF** is on by default. Export recognizes every current page and places invisible, selectable word text over the image using OCR coordinates. Noto Sans is bundled (OFL license) so export needs no font download. Empty OCR results produce image-only pages. OCR errors stop export and show a message; retry or explicitly turn off Searchable PDF to export images only.
- Cropping/filtering/rotation invalidates cached OCR and its corrections. Reordering/deleting preserves the remaining pages' OCR. OCR runs on demand, not during capture.
- **Save and close** (save icon or Back) stores the document and all current edits on device. Saved scans reopen from the home screen after restarting the app. If saving fails, the editor stays open for retry. Save before closing the app; edits in an open editor are not continuously autosaved.
- **Import PDF** opens a PDF from the device's file picker and renders its pages into editable images at 144 DPI. The original file is untouched; save the edited copy in the library and export a new PDF. Import accepts up to 50 MB / 100 pages and rejects failed/partial imports. Existing PDF vectors, forms, links and text objects are flattened; searchable text is rebuilt by OCR.
- **Annotate** adds visible text, translucent highlights and a hand-drawn signature. Tap to add/edit text, drag text to move, and use the size sliders to resize it. Draw highlights or signature strokes directly on the page. Long-press any mark to remove it; Undo restores the last edit in the annotation session. Apply returns the marks to the editor; Back discards unapplied annotation changes.
- **Rotate** turns a page clockwise. Crop/rotate first flatten existing annotations into the image so marks follow the page geometry; those marks then become image pixels. Filters preserve editable overlays, while all image edits invalidate cached OCR/corrections for that page.
- The home search filters saved document names, recognized/corrected text and text annotations. It uses OCR already saved in the library; it does not run recognition in the background.

## Setup

Install current stable Flutter with Dart 3.13 or newer (Flutter 3.47+), Android tooling, and Xcode/CocoaPods for iOS. The Android host is included. To add an iOS host, run:

```sh
flutter create --platforms=ios --project-name docscan_clone .
flutter pub get
```

Keep the supplied `lib/`, assets and `pubspec.yaml`. The Android settings below are included in the repository; apply the iOS settings after generating its host. The Gradle wrapper is pinned to 8.13.

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

Automated tests cover OCR invalidation/corrections, persistent image and metadata storage (including moved iOS containers), save failure recovery, PDF import ordering/failure/limits, annotation removal/undo and editor retry behavior. CI also runs `tool/verify_pdf.py` with PyMuPDF to check actual text extraction (including accents), selection geometry, portrait/landscape page sizes, blank pages, identical visible pixels with/without OCR, visible text, highlights and signature geometry. Native detection and recognition require physical-device testing:

1. Scan a well-lit page using Auto mode; confirm detected corners and automatic shutter. Cancel once and start again.
2. Scan multiple pages; Add more, crop, rotate, apply each filter, reorder and delete. Save and close, restart the app, and reopen the saved scan.
3. Open OCR, correct a word, save and reopen; verify the correction in a searchable export. Crop or filter the page, then verify OCR is refreshed.
4. Share a searchable PDF with portrait and landscape pages. In a PDF viewer, search for a distinctive word, copy accented text and check selection alignment.
5. Try blank paper, denied camera permission, first-use module download failure and Android without Play services. Confirm errors are visible and cancellation preserves the editor.
6. Annotate a page with visible text, a highlight and a drawn signature. Move/resize text, delete a mark, undo, apply and save. Reopen and export; check all marks visually in the PDF. Crop/rotate an annotated page and check the marks move with the image.
7. Import a multi-page PDF from local storage and a cloud file provider; save, reopen and edit it. Test cancellation, an invalid/encrypted PDF, over-limit files and a failed import. Confirm the original file stays unchanged.
8. Turn searchable export off and confirm the page images and visible annotations still share. Test iPad sharing on a device.

Automated checks were run with Flutter 3.47.7 / Dart 3.13.5. Android/iOS host builds and physical-device camera/OCR/file-picker/PDF-renderer checks have not been run in this workspace.

## API references and design

Verified against [cunning_document_scanner 3.0.3](https://pub.dev/packages/cunning_document_scanner) (`getPictures`, nullable cancellation, `ScannerSource.camera`), [google_mlkit_text_recognition 0.17.1](https://pub.dev/packages/google_mlkit_text_recognition) (`InputImage.fromFilePath`, Latin `TextRecognizer`, word bounds, `close`) and [pdf TextStyle](https://pub.dev/documentation/pdf/latest/widgets/TextStyle-class.html) (`PdfTextRenderingMode.invisible`). Sharing uses [share_plus 13.3.1](https://pub.dev/packages/share_plus) `SharePlus.instance.share(ShareParams(...))`; manual cropping uses [image_cropper 13.0.0](https://pub.dev/packages/image_cropper). Dependency resolution is recorded in `pubspec.lock`.

`ScannerService` copies plugin-owned scan output to application support storage before returning it to the editor. Image edits use temporary files. `OcrService` releases its recognizer after each page, and `PdfService` embeds the current image and its matching OCR coordinates on pages preserving image aspect ratio. PDFs use unique filenames to avoid overwriting previous exports. Text follows the recognizer's reading order; skewed/curved pages and low-quality scans can reduce accuracy and selection alignment. Other scripts require additional ML Kit models, script selection and matching embedded fonts.

`DocumentStore` writes versioned image copies and atomically replaces per-document metadata, preserving the previous saved version if a save fails. Saved image filenames are relative to the library directory, so moving an iOS application container does not break paths. Obsolete copies are removed after a successful save. Temporary scanner/import/edit files and exported PDFs still need periodic storage cleanup; document deletion and cloud sync are future work.

PDF imports and flattening use [printing 5.15.1](https://pub.dev/packages/printing) `Printing.raster` / `PdfRaster.toPng`. File selection uses the current [file_picker 13.1.0](https://pub.dev/packages/file_picker) `FilePicker.pickFile` API, which returns a nullable `PlatformFile`. Neither PDF import nor annotation editing requires network access to download app fonts. On Android/iOS these packages need no additional host settings beyond the setup above. This app uses original branding and assets, without Adobe trademarks or proprietary UI.
