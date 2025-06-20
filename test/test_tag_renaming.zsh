#!/usr/bin/env zsh

# Test tag renaming correctness (old tag names should be absent)

source "$(dirname $0)/test_framework.zsh"
source "$(dirname $0)/setup_test_repos.zsh"

SCRIPT_DIR="$(cd "$(dirname $0)/.." && pwd)"
MERGE_SCRIPT="$SCRIPT_DIR/git-merge-repos-advanced.zsh"

init_test_env

start_test "T095: Tag renaming validation"

SOURCE_REPO=$(create_test_repo "tag-rename-source")
cd "$SOURCE_REPO"
# create annotated and lightweight tags
add_file_and_commit "file.txt" "First" "Initial commit"
git tag -a v1.0 -m "v1.0"
git tag v1.1

DEST_REPO=$(create_test_repo "tag-rename-dest")
cd "$DEST_REPO"
add_file_and_commit "base.txt" "Base" "Base commit"

assert_success "$MERGE_SCRIPT '$SOURCE_REPO' renamed" "Merge should succeed"

# New tags should exist
assert_tag_exists "renamed/v1.0"
assert_tag_exists "renamed/v1.1"

# Old tags should NOT exist in destination
assert_tag_not_exists "v1.0"
assert_tag_not_exists "v1.1"

end_test

print_summary
SUMMARY_EXIT=$?
cleanup_test_env
exit $SUMMARY_EXIT 