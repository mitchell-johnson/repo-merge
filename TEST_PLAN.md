# Git Repository Merger - Test Plan

## Test Overview

This test plan covers both `git-merge-repos.zsh` and `git-merge-repos-advanced.zsh` scripts.

## Test Categories

### 1. Basic Functionality Tests
- [ ] T001: Merge simple repo with single branch
- [ ] T002: Merge repo with multiple branches
- [ ] T003: Merge repo with tags
- [ ] T004: Merge repo with both branches and tags
- [ ] T005: Verify commit history preservation
- [ ] T006: Verify author/timestamp preservation

### 2. Subdirectory Tests
- [ ] T010: Merge into subdirectory with single branch
- [ ] T011: Merge into nested subdirectory
- [ ] T012: Merge into subdirectory with multiple branches
- [ ] T013: Verify file paths are correctly moved

### 3. Branch Selection Tests
- [ ] T020: Merge only specific branch with -b flag
- [ ] T021: Merge specific branch that doesn't exist (error handling)
- [ ] T022: Merge specific branch with subdirectory

### 4. Tag Handling Tests
- [ ] T030: Skip tags with --skip-tags flag
- [ ] T031: Handle annotated tags
- [ ] T032: Handle lightweight tags
- [ ] T033: Handle tags pointing to non-commit objects

### 5. Conflict Resolution Tests
- [ ] T040: Handle existing branch names (should skip)
- [ ] T041: Force overwrite with -f flag
- [ ] T042: Handle existing tag names
- [ ] T043: Handle special characters in branch/tag names

### 6. Dry Run Tests
- [ ] T050: Dry run shows correct operations
- [ ] T051: Dry run makes no changes
- [ ] T052: Dry run with subdirectory option

### 7. Advanced Features Tests
- [ ] T060: Auto-merge with -m flag
- [ ] T061: Squash merge with --squash-merge
- [ ] T062: No-commit merge with --no-commit
- [ ] T063: Different merge strategies
- [ ] T064: Preserve paths option

### 8. Error Handling Tests
- [ ] T070: Invalid repository URL
- [ ] T071: Invalid source name (special chars)
- [ ] T072: Not in a git repository
- [ ] T073: Missing required arguments
- [ ] T074: Conflicting options (e.g., -p with -s)

### 9. Edge Cases
- [ ] T080: Empty repository merge
- [ ] T081: Repository with binary files
- [ ] T082: Repository with submodules
- [ ] T083: Repository with very long branch names
- [ ] T084: Repository with non-ASCII branch/tag names

### 10. Performance Tests
- [ ] T090: Large repository handling
- [ ] T091: Repository with many branches (50+)
- [ ] T092: Repository with deep history (1000+ commits)

## Test Repository Structure

### Test Repo A (Simple)
- Branches: main, develop
- Tags: v1.0, v1.1
- Files: README.md, src/app.js
- Commits: 10-15

### Test Repo B (Complex)
- Branches: main, develop, feature/x, bugfix/y, release/1.0
- Tags: v1.0, v1.1, v2.0-beta, latest
- Files: Multiple directories and files
- Commits: 50+

### Test Repo C (Edge Cases)
- Empty repo
- Binary files
- Submodules
- Special characters in names

## Success Criteria

Each test must verify:
1. Exit code (0 for success, non-zero for expected failures)
2. Expected branches/tags created
3. File locations (especially for subdirectory tests)
4. Commit history integrity
5. No unintended side effects

## Test Execution Plan

1. Setup test environment
2. Create test repositories
3. Run each test category
4. Verify results
5. Cleanup test environment
6. Generate test report

## AIDEV-NOTE: test-coverage - Ensure all script options are tested 