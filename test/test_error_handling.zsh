#!/usr/bin/env zsh

# Test error handling in git-merge-repos scripts

source "$(dirname $0)/test_framework.zsh"
source "$(dirname $0)/setup_test_repos.zsh"

# Path to scripts
SCRIPT_DIR="$(cd "$(dirname $0)/.." && pwd)"
BASIC_SCRIPT="$SCRIPT_DIR/git-merge-repos-advanced.zsh"
ADVANCED_SCRIPT="$BASIC_SCRIPT"

# Test T070: Invalid repository URL
test_invalid_repo() {
    start_test "T070: Invalid repository URL"
    
    # Create target repo
    local target_repo=$(create_test_repo "target-invalid")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Try to merge non-existent repo
    assert_failure "$BASIC_SCRIPT '/tmp/non-existent-repo' invalid 2>&1" \
        "Should fail with invalid repo"
    
    # Try with invalid URL
    assert_failure "$BASIC_SCRIPT 'https://invalid-url-that-does-not-exist.com/repo.git' invalid 2>&1" \
        "Should fail with invalid URL"
    
    end_test
}

# Test T071: Invalid source name
test_invalid_source_name() {
    start_test "T071: Invalid source name"
    
    # Create repos
    local source_repo=$(create_simple_repo)
    local target_repo=$(create_test_repo "target-badname")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Try various invalid names
    assert_failure "$BASIC_SCRIPT '$source_repo' 'bad name with spaces' 2>&1" \
        "Should fail with spaces in name"
    
    assert_failure "$BASIC_SCRIPT '$source_repo' '@invalid' 2>&1" \
        "Should fail with @ at start"
    
    assert_failure "$BASIC_SCRIPT '$source_repo' 'bad/name' 2>&1" \
        "Should fail with slash in name"
    
    end_test
}

# Test T072: Not in a git repository
test_not_in_git_repo() {
    start_test "T072: Not in a git repository"
    
    # Create a non-git directory
    local non_git_dir="$TEMP_DIR/not-a-repo"
    mkdir -p "$non_git_dir"
    cd "$non_git_dir"
    
    # Try to run merge
    $BASIC_SCRIPT "/tmp/some-repo" test > /tmp/test_output 2>&1
    local exit_code=$?
    local output=$(cat /tmp/test_output)
    
    assert_failure "test $exit_code -eq 0" "Should fail when not in git repo"
    assert_contains "$output" "Not in a git repository" \
        "Should show appropriate error message"
    
    end_test
}

# Test T073: Missing required arguments
test_missing_arguments() {
    start_test "T073: Missing required arguments"
    
    # Create target repo
    local target_repo=$(create_test_repo "target-args")
    cd "$target_repo"
    
    # No arguments
    assert_failure "$BASIC_SCRIPT 2>&1" \
        "Should fail with no arguments"
    
    # Only one argument
    assert_failure "$BASIC_SCRIPT 'repo-url' 2>&1" \
        "Should fail with only one argument"
    
    # Check error message
    local output=$($BASIC_SCRIPT 2>&1)
    assert_contains "$output" "Missing required arguments" \
        "Should show missing arguments error"
    
    end_test
}

# Test T074: Conflicting options
test_conflicting_options() {
    start_test "T074: Conflicting options"
    
    # Create repos
    local source_repo=$(create_simple_repo)
    local target_repo=$(create_test_repo "target-conflict")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Test conflicting options in advanced script
    assert_failure "$ADVANCED_SCRIPT -p -s subdir '$source_repo' conflict 2>&1" \
        "Should fail with -p and -s together"
    
    end_test
}

# Test T080: Empty repository merge
test_empty_repo() {
    start_test "T080: Empty repository merge"
    
    # Create empty source repo
    local source_repo=$(create_empty_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-empty")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # This should succeed but not create any branches
    local output=$($BASIC_SCRIPT "$source_repo" empty 2>&1)
    assert_success "echo \$?" "Empty repo merge should succeed"
    
    # No branches should be created (empty repo has no branches)
    assert_branch_not_exists "empty-main" \
        "No branches should be created from empty repo"
    
    end_test
}

# Test T083: Very long branch names
test_long_branch_names() {
    start_test "T083: Very long branch names"
    
    # Create edge case repo
    local source_repo=$(create_edge_case_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-long")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Run merge
    assert_success "$BASIC_SCRIPT '$source_repo' edge" \
        "Should handle long branch names"
    
    # Check that long branch was created
    local branches=$(git branch | grep "edge-feature/this-is-a-very-long")
    assert_success "test -n '$branches'" \
        "Long branch name should be created"
    
    end_test
}

# Test special characters in branch/tag names
test_special_characters() {
    start_test "T084: Special characters handling"
    
    # Create edge case repo
    local source_repo=$(create_edge_case_repo)
    
    # Create target repo
    local target_repo=$(create_test_repo "target-special")
    cd "$target_repo"
    add_file_and_commit "target.txt" "Target" "Initial commit"
    
    # Run merge
    assert_success "$BASIC_SCRIPT '$source_repo' special" \
        "Should handle special characters"
    
    # Check branches with special chars
    assert_branch_exists "special-feature/user@email.com" \
        "Branch with @ should be created"
    
    assert_branch_exists "special-feature/new-feature-2024" \
        "Branch with numbers should be created"
    
    # Check tag with special chars
    assert_tag_exists "special-v1.0+build.123" \
        "Tag with + should be created"
    
    end_test
}

# Test help option
test_help_option() {
    start_test "Help option functionality"
    
    # Test basic script help
    local output=$($BASIC_SCRIPT --help 2>&1)
    assert_success "echo \$?" "Help should exit successfully"
    assert_contains "$output" "Usage:" "Help should show usage"
    assert_contains "$output" "Options:" "Help should show options"
    
    # Test advanced script help
    output=$($ADVANCED_SCRIPT --help 2>&1)
    assert_success "echo \$?" "Advanced help should exit successfully"
    assert_contains "$output" "Advanced Options:" \
        "Advanced script should show additional options"
    
    end_test
}

# Run all tests
init_test_env

test_invalid_repo
test_invalid_source_name
test_not_in_git_repo
test_missing_arguments
test_conflicting_options
test_empty_repo
test_long_branch_names
test_special_characters
test_help_option

print_summary
cleanup_test_env

# AIDEV-NOTE: error-tests - Error handling and edge case tests 