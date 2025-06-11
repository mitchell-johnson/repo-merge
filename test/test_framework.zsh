#!/usr/bin/env zsh

# Test framework for git-merge-repos scripts

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""
CURRENT_TEST_FAILED=false

# Test directories
TEST_ROOT="$(dirname $0)"
TEMP_DIR=""

# Initialize test environment
init_test_env() {
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    echo "Test environment: $TEMP_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        cd /
        rm -rf "$TEMP_DIR"
    fi
}

# Start a test
start_test() {
    CURRENT_TEST="$1"
    CURRENT_TEST_FAILED=false
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "\n${BLUE}Running test: $CURRENT_TEST${NC}\n"
}

# Assert command success
assert_success() {
    local cmd="$1"
    local desc="${2:-Command should succeed}"
    
    eval "$cmd" > /dev/null 2>&1
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc (exit code: $exit_code)\n"
        printf "    Command: $cmd\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert command failure
assert_failure() {
    local cmd="$1"
    local desc="${2:-Command should fail}"
    
    eval "$cmd" > /dev/null 2>&1
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc (expected failure but got success)\n"
        printf "    Command: $cmd\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert branch exists
assert_branch_exists() {
    local branch="$1"
    local desc="${2:-Branch $branch should exist}"
    
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert branch does not exist
assert_branch_not_exists() {
    local branch="$1"
    local desc="${2:-Branch $branch should not exist}"
    
    if ! git show-ref --verify --quiet "refs/heads/$branch"; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert tag exists
assert_tag_exists() {
    local tag="$1"
    local desc="${2:-Tag $tag should exist}"
    
    if git show-ref --verify --quiet "refs/tags/$tag"; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert tag does not exist
assert_tag_not_exists() {
    local tag="$1"
    local desc="${2:-Tag $tag should not exist}"
    
    if ! git show-ref --verify --quiet "refs/tags/$tag"; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    local desc="${2:-File $file should exist}"
    
    if [[ -f "$file" ]]; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert file in subdirectory
assert_file_in_subdir() {
    local subdir="$1"
    local file="$2"
    local desc="${3:-File should be in $subdir}"
    
    if [[ -f "$subdir/$file" ]]; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert string contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local desc="${3:-Output should contain '$needle'}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# Assert equal
assert_equal() {
    local actual="$1"
    local expected="$2"
    local desc="${3:-Values should be equal}"
    
    if [[ "$actual" == "$expected" ]]; then
        printf "  ${GREEN}✓${NC} $desc\n"
        return 0
    else
        printf "  ${RED}✗${NC} $desc\n"
        printf "    Expected: $expected\n"
        printf "    Actual: $actual\n"
        CURRENT_TEST_FAILED=true
        return 1
    fi
}

# End test and update counters
end_test() {
    if [[ "$CURRENT_TEST_FAILED" == false ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf "${GREEN}Test passed: $CURRENT_TEST${NC}\n"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf "${RED}Test failed: $CURRENT_TEST${NC}\n"
    fi
}

# Print test summary
print_summary() {
    printf "\n${BLUE}===== Test Summary =====${NC}\n"
    echo "Total tests run: $TESTS_RUN"
    printf "Passed: ${GREEN}$TESTS_PASSED${NC}\n"
    printf "Failed: ${RED}$TESTS_FAILED${NC}\n"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf "\n${GREEN}All tests passed!${NC}\n"
        return 0
    else
        printf "\n${RED}Some tests failed!${NC}\n"
        return 1
    fi
}

# Create a test repository
create_test_repo() {
    local repo_name="$1"
    local repo_dir="$TEMP_DIR/$repo_name"
    
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init --initial-branch=main > /dev/null 2>&1
    
    # Configure git for testing
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    echo "$repo_dir"
}

# Add a file and commit
add_file_and_commit() {
    local filename="$1"
    local content="$2"
    local message="${3:-Add $filename}"
    
    mkdir -p "$(dirname "$filename")"
    echo "$content" > "$filename"
    git add "$filename"
    git commit -m "$message" > /dev/null 2>&1
}

# AIDEV-NOTE: test-framework-core - Essential test utilities for git merge testing 