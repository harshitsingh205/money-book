#!/bin/bash
set -e

echo "========================================="
echo " Building Money Book for iOS (IPA)..."
echo "========================================="

# 1. Fetch dependencies
flutter pub get

# 2. Run verification tests
flutter test

# 3. Build iOS release without code signing
flutter build ios --release --no-codesign

# 4. Package as .ipa archive
echo "Packaging into Money_Book.ipa..."
rm -rf Payload Money_Book.ipa
mkdir -p Payload
cp -r build/ios/iphoneos/Runner.app Payload/Money_Book.app
zip -r -q Money_Book.ipa Payload
rm -rf Payload

echo "========================================="
echo " SUCCESS! Generated: Money_Book.ipa"
echo "========================================="
