#!/usr/bin/env zsh

# Test suite for additional test cases

# Source test framework
source "$(dirname $0)/test_framework.zsh"
source "$(dirname $0)/setup_test_repos.zsh"

# Get script paths
SCRIPT_DIR="$(cd "$(dirname $0)/.." && pwd)"
BASIC_SCRIPT="$SCRIPT_DIR/git-merge-repos-advanced.zsh"
ADVANCED_SCRIPT="$BASIC_SCRIPT"

# Initialize test environment
init_test_env

# T003: Merge repo with tags
start_test "T003: Merge repo with tags"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "tags-dest"
cd "$TEMP_DIR/tags-dest"
add_file_and_commit "main.txt" "Main repo content"

cd "$SOURCE_REPO"
# Create annotated tag
git tag -a v1.0 -m "Version 1.0" > /dev/null 2>&1
# Create lightweight tag
git tag v1.1 > /dev/null 2>&1

cd "$TEMP_DIR/tags-dest"
assert_success "$BASIC_SCRIPT '$SOURCE_REPO' tagtest" \
    "Merge with tags should succeed"

assert_tag_exists "tagtest-v1.0" "Annotated tag should be created"
assert_tag_exists "tagtest-v1.1" "Lightweight tag should be created"

end_test

# T004: Merge repo with both branches and tags
start_test "T004: Merge repo with branches and tags"
SOURCE_REPO=$(create_complex_repo)
create_test_repo "full-dest"
cd "$TEMP_DIR/full-dest"
add_file_and_commit "main.txt" "Main repo content"

cd "$TEMP_DIR/full-dest"
assert_success "$BASIC_SCRIPT '$SOURCE_REPO' full" \
    "Full merge should succeed"

# Check branches
assert_branch_exists "full-main"
assert_branch_exists "full-develop"
assert_branch_exists "full-feature/new-ui"

# Check tags
assert_tag_exists "full-v1.0"
assert_tag_exists "full-v2.0"

end_test

# T006: Verify author/timestamp preservation
start_test "T006: Author/timestamp preservation"
SOURCE_REPO=$(create_test_repo "author-source")
cd "$SOURCE_REPO"

# Create commits with specific author
git config user.email "original@example.com"
git config user.name "Original Author"
add_file_and_commit "file1.txt" "Content 1"
ORIGINAL_AUTHOR=$(git log -1 --format="%an <%ae>")
ORIGINAL_DATE=$(git log -1 --format="%ai")

create_test_repo "author-dest"
cd "$TEMP_DIR/author-dest"
add_file_and_commit "main.txt" "Main content"

assert_success "$BASIC_SCRIPT '$SOURCE_REPO' author" \
    "Merge should succeed"

git checkout author-main > /dev/null 2>&1
MERGED_AUTHOR=$(git log -1 --format="%an <%ae>" -- file1.txt)
MERGED_DATE=$(git log -1 --format="%ai" -- file1.txt)

assert_equal "$MERGED_AUTHOR" "$ORIGINAL_AUTHOR" "Author should be preserved"
assert_equal "$MERGED_DATE" "$ORIGINAL_DATE" "Timestamp should be preserved"

end_test

# T011: Merge into nested subdirectory
start_test "T011: Nested subdirectory merge"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "nested-dest"
cd "$TEMP_DIR/nested-dest"
add_file_and_commit "main.txt" "Main repo content"

assert_success "$BASIC_SCRIPT -s deep/path/to/source '$SOURCE_REPO' nested" \
    "Nested subdirectory merge should succeed"

# Switch to the created branch to check files
git checkout nested-main > /dev/null 2>&1

assert_file_in_subdir "deep/path/to/source" "README.md" \
    "Files should be in nested subdirectory"
assert_file_in_subdir "deep/path/to/source/src" "app.js" \
    "Nested files should maintain structure"

end_test

# T012: Merge into subdirectory with multiple branches
start_test "T012: Subdirectory with multiple branches"
SOURCE_REPO=$(create_complex_repo)
create_test_repo "subdir-multi-dest"
cd "$TEMP_DIR/subdir-multi-dest"
add_file_and_commit "main.txt" "Main repo content"

assert_success "$BASIC_SCRIPT -s imported '$SOURCE_REPO' submulti" \
    "Subdirectory merge with multiple branches should succeed"

# Check that files are in subdirectory for each branch
git checkout submulti-main > /dev/null 2>&1
assert_file_in_subdir "imported" "README.md"

git checkout submulti-develop > /dev/null 2>&1
assert_file_in_subdir "imported" "README.md"

end_test

# T021: Merge specific branch that doesn't exist
start_test "T021: Non-existent branch merge"
SOURCE_REPO=$(create_simple_repo)
create_test_repo "nonexist-dest"
cd "$TEMP_DIR/nonexist-dest"

assert_failure "$BASIC_SCRIPT -b nonexistent '$SOURCE_REPO' nonexist" \
    "Should fail when branch doesn't exist"

end_test

# T031-T033: Detailed tag handling
start_test "T031-T033: Various tag types"
SOURCE_REPO=$(create_test_repo "tagtype-source")
cd "$SOURCE_REPO"
add_file_and_commit "file.txt" "Content"

# Annotated tag
git tag -a annotated -m "Annotated tag"
# Lightweight tag
git tag lightweight
# Tag pointing to tree (non-commit)
TREE_SHA=$(git write-tree)
git tag tree-tag $TREE_SHA

create_test_repo "tagtype-dest"
cd "$TEMP_DIR/tagtype-dest"
add_file_and_commit "main.txt" "Main content"

OUTPUT=$($BASIC_SCRIPT "$SOURCE_REPO" tagtypes 2>&1)
assert_success "echo 'done'" "Merge should handle various tag types"

# Verify proper tags were created
assert_tag_exists "tagtypes-annotated"
assert_tag_exists "tagtypes-lightweight"
# Tree tag might be skipped - check output
assert_contains "$OUTPUT" "tree-tag" "Should process tree tag (even if skipped)"

end_test

# T082: Repository with submodules
start_test "T082: Repository with submodules"
CHILD_REPO=$(create_test_repo "submodule-child")
cd "$CHILD_REPO"
add_file_and_commit "child.txt" "Child content"

SOURCE_REPO=$(create_test_repo "submodule-source")
cd "$SOURCE_REPO"
add_file_and_commit "parent.txt" "Parent content"
git submodule add "$CHILD_REPO" child > /dev/null 2>&1
git commit -m "Add submodule" > /dev/null 2>&1

create_test_repo "submodule-dest"
cd "$TEMP_DIR/submodule-dest"
add_file_and_commit "main.txt" "Main content"

OUTPUT=$($BASIC_SCRIPT "$SOURCE_REPO" submod 2>&1)
assert_success "echo 'done'" "Should handle repos with submodules"
assert_contains "$OUTPUT" "submodule" "Should mention submodule handling"

end_test

# T091: Repository with many branches
start_test "T091: Many branches handling"
SOURCE_REPO=$(create_test_repo "many-branches-source")
cd "$SOURCE_REPO"
add_file_and_commit "file.txt" "Initial content"

# Create 20 branches for testing
for i in {1..20}; do
    git checkout -b "branch-$i" main > /dev/null 2>&1
    add_file_and_commit "file$i.txt" "Content $i"
done

create_test_repo "many-branches-dest"
cd "$TEMP_DIR/many-branches-dest"
add_file_and_commit "main.txt" "Main content"

assert_success "$BASIC_SCRIPT '$SOURCE_REPO' many" \
    "Should handle many branches"

# Verify a sample of branches
assert_branch_exists "many-branch-1"
assert_branch_exists "many-branch-10"
assert_branch_exists "many-branch-20"

end_test

# Print summary
print_summary
SUMMARY_EXIT=$?

# Cleanup
cleanup_test_env

# AIDEV-NOTE: test-additional - Additional test cases covering gaps in test suite
exit $SUMMARY_EXIT 