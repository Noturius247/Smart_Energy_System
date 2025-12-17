#!/bin/bash
# Smart Energy System - Test Runner Script for Linux/Mac
# This script runs all unit tests with detailed output

echo "========================================"
echo "Smart Energy System - Unit Test Runner"
echo "========================================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "ERROR: Flutter is not installed or not in PATH"
    echo "Please install Flutter from https://flutter.dev"
    exit 1
fi

echo "Running all unit tests..."
echo ""

# Run tests with expanded reporter for detailed output
flutter test --reporter expanded

# Capture exit code
TEST_EXIT_CODE=$?

echo ""
echo "========================================"
echo "Test execution completed!"
echo "========================================"
echo ""

# Check exit code
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✓ All tests PASSED!"
    exit 0
else
    echo "✗ Some tests FAILED!"
    exit 1
fi
