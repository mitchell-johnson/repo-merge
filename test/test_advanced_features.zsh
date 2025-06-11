#!/usr/bin/env zsh

# Test suite for advanced features of git-merge-repos-advanced.zsh

# Source test framework
source "$(dirname $0)/test_framework.zsh"
source "$(dirname $0)/setup_test_repos.zsh"

# Get script path
SCRIPT_DIR="$(cd "$(dirname $0)/.." && pwd)"
ADVANCED_SCRIPT="$SCRIPT_DIR/git-merge-repos-advanced.zsh"

# Initialize test environment
init_test_env

# T060: Auto-merge with -m flag
start_test "T060: Auto-merge with -m flag"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "auto-merge-dest"
cd "$TEMP_DIR/auto-merge-dest"
add_file_and_commit "main.txt" "Main repo content"

# Create branches that should be merged
cd "$SOURCE_REPO"
git checkout -b develop > /dev/null 2>&1
add_file_and_commit "develop.txt" "Develop content"

cd "$TEMP_DIR/auto-merge-dest"
assert_success "$ADVANCED_SCRIPT -m main '$SOURCE_REPO' source" \
    "Auto-merge should succeed"

# Check that branches were merged  
assert_contains "$(git log --oneline | head -1)" "Merge branch 'source-main'" \
    "Should have merge commit"

end_test

# T061: Squash merge with --squash-merge
start_test "T061: Squash merge with --squash-merge"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "squash-dest"
cd "$TEMP_DIR/squash-dest"
add_file_and_commit "main.txt" "Main repo content"

# Create multiple commits to squash
cd "$SOURCE_REPO"
add_file_and_commit "file1.txt" "First commit"
add_file_and_commit "file2.txt" "Second commit"
add_file_and_commit "file3.txt" "Third commit"

cd "$TEMP_DIR/squash-dest"
assert_success "$ADVANCED_SCRIPT '$SOURCE_REPO' squash -b main -m main --squash-merge" \
    "Squash merge should succeed"

# Verify squash behavior - we should have a single commit for the merge
COMMIT_COUNT=$(git log --oneline | grep -c "squash")
assert_equal "$COMMIT_COUNT" "1" "Should have single squash merge commit"

end_test

# T062: No-commit merge with --no-commit
start_test "T062: No-commit merge with --no-commit"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "no-commit-dest"
cd "$TEMP_DIR/no-commit-dest"
add_file_and_commit "main.txt" "Main repo content"

cd "$SOURCE_REPO"
add_file_and_commit "new-file.txt" "New content"

cd "$TEMP_DIR/no-commit-dest"
assert_success "$ADVANCED_SCRIPT '$SOURCE_REPO' nocommit -b main -m main --no-commit" \
    "No-commit merge should succeed"

# Check for staged changes (merge without commit)
STATUS=$(git status --porcelain)
assert_contains "$STATUS" "M" "Should have staged changes"

end_test

# T063: Different merge strategies
start_test "T063: Different merge strategies"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "strategy-dest"
cd "$TEMP_DIR/strategy-dest"
add_file_and_commit "shared.txt" "Original content"

cd "$SOURCE_REPO"
add_file_and_commit "shared.txt" "Modified content"

cd "$TEMP_DIR/strategy-dest"
# Test with ours strategy
assert_success "$ADVANCED_SCRIPT '$SOURCE_REPO' strat -b main -m main --strategy ours" \
    "Merge with 'ours' strategy should succeed"

CONTENT=$(cat shared.txt 2>/dev/null || echo "")
assert_equal "$CONTENT" "Original content" "Ours strategy should keep original content"

end_test

# T064: Preserve paths option
start_test "T064: Preserve paths option"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "preserve-dest"
cd "$TEMP_DIR/preserve-dest"
add_file_and_commit "main.txt" "Main repo content"

cd "$SOURCE_REPO"
mkdir -p deep/nested/path
add_file_and_commit "deep/nested/path/file.txt" "Deep file content"

cd "$TEMP_DIR/preserve-dest"
assert_success "$ADVANCED_SCRIPT '$SOURCE_REPO' preserve -p" \
    "Preserve paths merge should succeed"

# Files should be at original paths, not in subdirectory
assert_file_exists "deep/nested/path/file.txt" \
    "Files should be preserved at original paths"

end_test

# Print summary
print_summary
SUMMARY_EXIT=$?

# Cleanup
cleanup_test_env

# AIDEV-NOTE: test-advanced - Tests for git-merge-repos-advanced.zsh specific features
exit $SUMMARY_EXIT 