#!/bin/bash

# Build script for SignatureManager
# Usage: ./build.sh [options]
#
# Options:
#   --run, -r         Run the application after building
#   --release, -R     Build Release configuration (default: Debug)
#   --clean, -c       Clean build (remove all artifacts first)
#   --test, -t        Run tests
#   --help, -h        Show this help message
#
# Examples:
#   ./build.sh              # Build Debug
#   ./build.sh --run        # Build and run Debug
#   ./build.sh --release    # Build Release
#   ./build.sh -R -r        # Build and run Release
#   ./build.sh --clean      # Clean build
#   ./build.sh --test       # Run tests

set -e

PROJECT="SignatureManager.xcodeproj"
SCHEME="SignatureManager"
BUILD_DIR="./build"
CONFIGURATION="Debug"
RUN_AFTER_BUILD=false
CLEAN_BUILD=false
RUN_TESTS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--run)
            RUN_AFTER_BUILD=true
            shift
            ;;
        -R|--release)
            CONFIGURATION="Release"
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -t|--test)
            RUN_TESTS=true
            shift
            ;;
        -h|--help)
            echo "Build script for SignatureManager"
            echo ""
            echo "Usage: ./build.sh [options]"
            echo ""
            echo "Options:"
            echo "  --run, -r         Run the application after building"
            echo "  --release, -R     Build Release configuration (default: Debug)"
            echo "  --clean, -c       Clean build (remove all artifacts first)"
            echo "  --test, -t        Run tests"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./build.sh              # Build Debug (incremental)"
            echo "  ./build.sh --run        # Build and run Debug"
            echo "  ./build.sh --release    # Build Release"
            echo "  ./build.sh -R -r        # Build and run Release"
            echo "  ./build.sh --clean      # Force clean build"
            echo "  ./build.sh --test       # Run tests"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use --help to see available options"
            exit 1
            ;;
    esac
done

APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/SignatureManager.app"

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Cleaning build artifacts..."
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean &>/dev/null || true
    echo ""
fi

# Build
echo "🔨 Building SignatureManager ($CONFIGURATION)..."
echo ""

# Detect native architecture
ARCH=$(uname -m)

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS,arch=$ARCH" \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | \
    grep -E "^\*\*|error:|warning:|note:" | \
    grep -v "Using the first of multiple matching destinations" | \
    grep -v "{ platform:macOS" | \
    grep -v "iOSSimulator:" | \
    grep -v "CoreSimulator" | \
    grep -v "appintentsmetadataprocessor.*warning: Metadata extraction skipped" || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "✅ Build complete!"
echo "📦 Application: $APP_PATH"

# Run if requested
if [ "$RUN_AFTER_BUILD" = true ]; then
    echo ""
    echo "🚀 Launching SignatureManager..."
    open "$APP_PATH"
fi

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    echo ""
    echo "🧪 Running tests..."
    echo ""
    
    # Save output to temp file
    TEMP_TEST_LOG=$(mktemp)
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=macOS,arch=$ARCH" \
        -derivedDataPath "$BUILD_DIR" > "$TEMP_TEST_LOG" 2>&1
    
    TEST_EXIT_CODE=$?
    
    # Check if tests aren't configured yet
    if grep -q "not currently configured for the test action" "$TEMP_TEST_LOG"; then
        echo "⚠️  Test target not configured in Xcode yet"
        echo ""
        echo "To enable tests (one-time setup):"
        echo "  1. Open SignatureManager.xcodeproj in Xcode"
        echo "  2. Follow instructions in SignatureManagerTests/README.md"
        echo "  3. Run: ./build.sh --test"
        echo ""
        rm "$TEMP_TEST_LOG"
        exit 1
    fi
    
    # Show filtered test output
    grep -E "Test Suite|Test Case|passed|failed|^\*\*" "$TEMP_TEST_LOG" | \
        grep -v "iOSSimulator:" | \
        grep -v "CoreSimulator" || true
    
    if [ $TEST_EXIT_CODE -eq 0 ]; then
        # Verify tests actually ran
        if grep -q "Test Suite.*passed" "$TEMP_TEST_LOG"; then
            echo ""
            echo "✅ All tests passed!"
        else
            echo ""
            echo "⚠️  No tests found or tests didn't run"
            rm "$TEMP_TEST_LOG"
            exit 1
        fi
    else
        echo ""
        echo "❌ Some tests failed!"
        echo ""
        echo "Run without grep to see full output:"
        echo "  xcodebuild test -project $PROJECT -scheme $SCHEME -destination 'platform=macOS,arch=$ARCH'"
        rm "$TEMP_TEST_LOG"
        exit 1
    fi
    
    rm "$TEMP_TEST_LOG"
fi
