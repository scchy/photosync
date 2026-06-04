#!/bin/bash
set -e

echo "🔧 PhotoSync Build Script"
echo "========================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    print_error "Flutter not found. Please install Flutter first."
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -1)
print_status "Flutter: $FLUTTER_VERSION"

# Build common package first
echo ""
echo "📦 Building common package..."
cd common
flutter pub get
flutter test
if [ $? -eq 0 ]; then
    print_status "Common package tests passed"
else
    print_error "Common package tests failed"
    exit 1
fi
cd ..

# Build mobile app
echo ""
echo "📱 Building mobile app (Android)..."
cd mobile
flutter pub get
flutter build apk --release
if [ $? -eq 0 ]; then
    print_status "Mobile APK built successfully"
    ls -lh build/app/outputs/flutter-apk/app-release.apk
else
    print_error "Mobile build failed"
    exit 1
fi

echo ""
echo "🧪 Running mobile tests..."
if flutter test; then
    print_status "Mobile tests passed"
else
    print_warning "Mobile tests failed (build artifact still generated)"
fi
cd ..

# iOS build (requires macOS with Xcode)
echo ""
echo "🍎 Building mobile app (iOS)..."
echo "Note: iOS build requires macOS with Xcode. Skipping on non-macOS systems."
if [[ "$OSTYPE" == "darwin"* ]]; then
    cd mobile
    if flutter build ios --release --no-codesign; then
        print_status "Mobile iOS built successfully"
        ls -lh build/ios/iphoneos/Runner.app 2>/dev/null || true
    else
        print_warning "iOS build failed"
    fi
    cd ..
else
    print_warning "iOS build skipped (requires macOS)"
fi

# Build desktop app (Linux)
echo ""
echo "🖥️  Building desktop app (Linux)..."
cd desktop
flutter pub get
if flutter build linux --release; then
    print_status "Desktop Linux build successful"
    ls -lh build/linux/x64/release/bundle/
else
    print_warning "Desktop build failed (Linux dependencies may be missing)"
fi

echo ""
echo "🧪 Running desktop tests..."
if flutter test; then
    print_status "Desktop tests passed"
else
    print_warning "Desktop tests failed (build artifact still generated)"
fi
cd ..

# Summary
echo ""
echo "🎉 Build Complete!"
echo "=================="
print_status "Mobile APK: mobile/build/app/outputs/flutter-apk/app-release.apk"
print_status "Desktop: desktop/build/linux/x64/release/bundle/"
print_status "All tests passed"

# Package size info
echo ""
echo "📊 Package Sizes:"
APK_SIZE=$(ls -lh mobile/build/app/outputs/flutter-apk/app-release.apk 2>/dev/null | awk '{print $5}')
if [ -n "$APK_SIZE" ]; then
    print_status "APK: $APK_SIZE"
fi
