#!/usr/bin/env bash
# Bisection script to find which test creates unwanted files/state
# Usage: ./find-polluter.sh <file_or_dir_to_check> <test_pattern>
# Example: ./find-polluter.sh '.jj' 'src/**/*.test.ts'

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <file_to_check> <test_pattern>"
  echo "Example: $0 '.jj' 'src/**/*.test.ts'"
  exit 1
fi

POLLUTION_CHECK="$1"
TEST_PATTERN="$2"

pollution_paths() {
  if [[ "$POLLUTION_CHECK" == */* ]]; then
    [ ! -e "$POLLUTION_CHECK" ] || printf '%s\n' "$POLLUTION_CHECK"
  else
    find . -name "$POLLUTION_CHECK" -print | sort
  fi
}

echo "🔍 Searching for test that creates: $POLLUTION_CHECK"
echo "Test pattern: $TEST_PATTERN"
echo ""

# Preserve metadata that belongs to the existing workspace, such as its root
# .jj directory. Only paths created while a test runs are pollution.
EXISTING_POLLUTION=$(pollution_paths)

# Get list of test files (find . emits ./-prefixed paths, so accept the
# pattern written with or without a leading ./)
TEST_PATTERN="${TEST_PATTERN#./}"
# find -path can't match '**/' against zero directory levels, so a pattern
# like src/**/*.test.ts would skip src/top.test.ts; also try the pattern
# with '**/' collapsed to cover files directly under the base directory.
TEST_FILES=$(find . \( -path "./$TEST_PATTERN" -o -path "./${TEST_PATTERN//\*\*\//}" \) | sort -u)
if [ -z "$TEST_FILES" ]; then
  TOTAL=0
else
  TOTAL=$(printf '%s\n' "$TEST_FILES" | wc -l | tr -d ' ')
fi

echo "Found $TOTAL test files"
echo ""

COUNT=0
for TEST_FILE in $TEST_FILES; do
  COUNT=$((COUNT + 1))

  echo "[$COUNT/$TOTAL] Testing: $TEST_FILE"

  # Run the test
  npm test "$TEST_FILE" > /dev/null 2>&1 || true

  # Check for paths that were not present before the search began.
  CURRENT_POLLUTION=$(pollution_paths)
  NEW_POLLUTION=$(comm -13 \
    <(printf '%s\n' "$EXISTING_POLLUTION" | sed '/^$/d') \
    <(printf '%s\n' "$CURRENT_POLLUTION" | sed '/^$/d'))
  if [ -n "$NEW_POLLUTION" ]; then
    echo ""
    echo "🎯 FOUND POLLUTER!"
    echo "   Test: $TEST_FILE"
    echo "   Created:"
    while IFS= read -r POLLUTION_PATH; do
      printf '   %s\n' "$POLLUTION_PATH"
    done <<< "$NEW_POLLUTION"
    echo ""
    echo "Pollution details:"
    while IFS= read -r POLLUTION_PATH; do
      ls -la "$POLLUTION_PATH"
    done <<< "$NEW_POLLUTION"
    echo ""
    echo "To investigate:"
    echo "  npm test $TEST_FILE    # Run just this test"
    echo "  cat $TEST_FILE         # Review test code"
    exit 1
  fi
done

echo ""
echo "✅ No polluter found - all tests clean!"
exit 0
