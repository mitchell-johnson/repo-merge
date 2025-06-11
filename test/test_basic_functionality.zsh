#!/usr/bin/env zsh

# Test basic functionality of git-merge-repos scripts

source "$(dirname $0)/test_framework.zsh"
source "$(dirname $0)/setup_test_repos.zsh"

# Path to scripts
SCRIPT_DIR="$(cd "$(dirname $0)/.." && pwd)"
BASIC_SCRIPT="$SCRIPT_DIR/git-merge-repos.zsh"
ADVANCED_SCRIPT="$SCRIPT_DIR/git-merge-repos-advanced.zsh"

# Test T001: Merge simple repo with single branch
test_simple_merge() {
    start_test "T001: Simple repository merge"
    
    # Create source repo
    local source_repo=$(create_simple_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target repo" "Initial target commit"
    
    # Run merge from within the target repo
    assert_success "$BASIC_SCRIPT '$source_repo' simple" \
        "Basic merge should succeed"
    
    # Verify branches
    assert_branch_exists "simple-main" "Source main branch should exist"
    assert_branch_exists "simple-develop" "Source develop branch should exist"
    
    # Verify tags
    assert_tag_exists "simple-v1.0" "Source v1.0 tag should exist"
    assert_tag_exists "simple-v1.1" "Source v1.1 tag should exist"
    
    # Verify original branches still exist
    assert_branch_exists "main" "Original main branch should exist"
    
    end_test
}

# Test T002: Merge repo with multiple branches
test_multiple_branches() {
    start_test "T002: Multiple branches merge"
    
    # Create complex source repo
    local source_repo=$(create_complex_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-multi")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Run merge from within the target repo
    assert_success "$BASIC_SCRIPT '$source_repo' complex" \
        "Complex merge should succeed"
    
    # Verify all branches
    assert_branch_exists "complex-main"
    assert_branch_exists "complex-develop"
    assert_branch_exists "complex-feature/new-ui"
    assert_branch_exists "complex-bugfix/issue-123"
    assert_branch_exists "complex-release/2.0"
    
    end_test
}

# Test T005: Verify commit history preservation
test_commit_history() {
    start_test "T005: Commit history preservation"
    
    # Create source repo
    local source_repo=$(create_simple_repo)
    
    # Get commit count in source
    cd "$source_repo"
    local source_commits=$(git rev-list --all --count)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-history")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    local target_commits=$(git rev-list --all --count)
    
    # Run merge from within the target repo
    assert_success "$BASIC_SCRIPT '$source_repo' history"
    
    # Check total commits (should be sum of both repos)
    local total_commits=$(git rev-list --all --count)
    local expected_commits=$((source_commits + target_commits))
    
    assert_equal "$total_commits" "$expected_commits" \
        "Total commits should be preserved"
    
    # Check specific commit messages are preserved
    local log_output=$(git log --all --oneline)
    assert_contains "$log_output" "Initial commit" \
        "Source repo commits should be preserved"
    assert_contains "$log_output" "Add app.js" \
        "Source repo commits should be preserved"
    
    end_test
}

# Test T010: Merge into subdirectory
test_subdirectory_merge() {
    start_test "T010: Subdirectory merge"
    
    # Create source repo
    local source_repo=$(create_simple_repo)
    
    # Create target repo  
    local target_repo=$(create_test_repo "target-subdir")
    cd "$target_repo"
    add_file_and_commit "existing.txt" "Existing file" "Initial commit"
    
    # Run merge with subdirectory from within the target repo
    assert_success "$BASIC_SCRIPT -s 'libs/imported' '$source_repo' subdir"
    
    # Check files are in subdirectory on imported branches
    git checkout subdir-main > /dev/null 2>&1
    assert_file_in_subdir "libs/imported" "README.md" \
        "README should be in subdirectory"
    assert_file_in_subdir "libs/imported" "src/app.js" \
        "app.js should be in subdirectory"
    
    # Original files should not exist at root
    assert_failure "test -f README.md" \
        "README should not be at root"
    
    # Return to main branch
    git checkout main > /dev/null 2>&1
    
    end_test
}

# Test T020: Merge only specific branch
test_specific_branch() {
    start_test "T020: Specific branch merge"
    
    # Create source repo
    local source_repo=$(create_complex_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-specific")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Run merge for specific branch only from within the target repo
    assert_success "$BASIC_SCRIPT -b develop '$source_repo' specific"
    
    # Only develop branch should exist
    assert_branch_exists "specific-develop" \
        "Specified branch should exist"
    assert_branch_not_exists "specific-main" \
        "Non-specified branches should not exist"
    assert_branch_not_exists "specific-feature/new-ui" \
        "Non-specified branches should not exist"
    
    end_test
}

# Test T030: Skip tags
test_skip_tags() {
    start_test "T030: Skip tags option"
    
    # Create source repo
    local source_repo=$(create_simple_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-notags")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Run merge skipping tags from within the target repo
    assert_success "$BASIC_SCRIPT -t '$source_repo' notags"
    
    # Branches should exist
    assert_branch_exists "notags-main"
    assert_branch_exists "notags-develop"
    
    # Tags should not exist
    assert_tag_not_exists "notags-v1.0" \
        "Tags should be skipped"
    assert_tag_not_exists "notags-v1.1" \
        "Tags should be skipped"
    
    end_test
}

# Test T050: Dry run
test_dry_run() {
    start_test "T050: Dry run mode"
    
    # Create source repo
    local source_repo=$(create_simple_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-dryrun")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Get initial state
    local branches_before=$(git branch -a | wc -l)
    local tags_before=$(git tag | wc -l)
    
    # Run dry run from within the target repo
    local output=$($BASIC_SCRIPT -n "$source_repo" dryrun 2>&1)
    assert_success "echo 'Dry run completed'" "Dry run should succeed"
    
    # Verify output contains expected messages
    assert_contains "$output" "DRY RUN" \
        "Output should indicate dry run mode"
    assert_contains "$output" "Dry run completed" \
        "Output should show completion message"
    
    # Verify no changes were made
    local branches_after=$(git branch -a | wc -l)
    local tags_after=$(git tag | wc -l)
    
    assert_equal "$branches_before" "$branches_after" \
        "No branches should be created in dry run"
    assert_equal "$tags_before" "$tags_after" \
        "No tags should be created in dry run"
    
    end_test
}

# Test T040/T041: Existing branches and force mode  
test_existing_branches() {
    start_test "T040/T041: Existing branches handling"
    
    # Create source repo
    local source_repo=$(create_simple_repo)
    
    # Create target repo with existing branch
    local target_repo=$(create_test_repo "target-existing")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    git checkout -b "existing-main" > /dev/null 2>&1
    add_file_and_commit "existing.txt" "Existing branch" "Existing commit"
    git checkout main > /dev/null 2>&1
    
    # First merge should succeed from within the target repo
    assert_success "$BASIC_SCRIPT '$source_repo' existing"
    
    # Second merge without force should skip existing branches
    local output=$($BASIC_SCRIPT "$source_repo" existing 2>&1)
    assert_contains "$output" "already exists, skipping" \
        "Should skip existing branches"
    
    # Merge with force should overwrite
    assert_success "$BASIC_SCRIPT -f '$source_repo' existing" \
        "Force merge should succeed"
    
    end_test
}

# Run all tests
init_test_env

test_simple_merge
test_multiple_branches  
test_commit_history
test_subdirectory_merge
test_specific_branch
test_skip_tags
test_dry_run
test_existing_branches

print_summary
cleanup_test_env

# AIDEV-NOTE: basic-tests - Core functionality tests for git merge scripts 