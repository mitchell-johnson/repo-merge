#!/usr/bin/env zsh

# Main test runner for git-merge-repos scripts

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Get test directory
TEST_DIR="$(dirname $0)"
cd "$TEST_DIR"

printf "${MAGENTA}=====================================${NC}\n"
printf "${MAGENTA}Git Repository Merger - Test Suite${NC}\n"
printf "${MAGENTA}=====================================${NC}\n"
echo

# Check if scripts exist
SCRIPT_DIR="$(dirname $(pwd))"
if [[ ! -f "$SCRIPT_DIR/git-merge-repos.zsh" ]]; then
    printf "${RED}Error: git-merge-repos.zsh not found${NC}\n"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/git-merge-repos-advanced.zsh" ]]; then
    printf "${RED}Error: git-merge-repos-advanced.zsh not found${NC}\n"
    exit 1
fi

# Run test suites
printf "${BLUE}Running Basic Functionality Tests...${NC}\n"
echo "======================================"
if ./test_basic_functionality.zsh; then
    BASIC_EXIT=0
else
    BASIC_EXIT=1
fi

echo
printf "${BLUE}Running Error Handling Tests...${NC}\n"
echo "================================="
if ./test_error_handling.zsh; then
    ERROR_EXIT=0
else
    ERROR_EXIT=1
fi

echo
printf "${BLUE}Running Additional Test Cases...${NC}\n"
echo "=================================="
if ./test_additional_cases.zsh; then
    ADDITIONAL_EXIT=0
else
    ADDITIONAL_EXIT=1
fi

echo
printf "${BLUE}Running Advanced Features Tests...${NC}\n"
echo "==================================="
if ./test_advanced_features.zsh; then
    ADVANCED_EXIT=0
else
    ADVANCED_EXIT=1
fi

# Summary
echo
printf "${MAGENTA}=====================================${NC}\n"
printf "${MAGENTA}Overall Test Summary${NC}\n"
printf "${MAGENTA}=====================================${NC}\n"

if [[ $BASIC_EXIT -eq 0 ]] && [[ $ERROR_EXIT -eq 0 ]] && [[ $ADDITIONAL_EXIT -eq 0 ]] && [[ $ADVANCED_EXIT -eq 0 ]]; then
    printf "${GREEN}All test suites passed!${NC}\n"
    exit 0
else
    printf "${RED}Some test suites failed!${NC}\n"
    [[ $BASIC_EXIT -ne 0 ]] && printf "${RED}- Basic functionality tests failed${NC}\n"
    [[ $ERROR_EXIT -ne 0 ]] && printf "${RED}- Error handling tests failed${NC}\n"
    [[ $ADDITIONAL_EXIT -ne 0 ]] && printf "${RED}- Additional test cases failed${NC}\n"
    [[ $ADVANCED_EXIT -ne 0 ]] && printf "${RED}- Advanced features tests failed${NC}\n"
    exit 1
fi

# AIDEV-NOTE: test-runner - Main test orchestrator for all test suites 