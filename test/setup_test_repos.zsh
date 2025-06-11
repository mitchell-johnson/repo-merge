#!/usr/bin/env zsh

# Setup test repositories for testing git-merge-repos scripts

source "$(dirname $0)/test_framework.zsh"

# Create simple test repository
create_simple_repo() {
    local repo_dir=$(create_test_repo "simple-repo")
    cd "$repo_dir"
    
    # Add files on main branch
    add_file_and_commit "README.md" "# Simple Test Repo" "Initial commit"
    add_file_and_commit "src/app.js" "console.log('Hello');" "Add app.js"
    
    # Create and add tag
    git tag -a v1.0 -m "Version 1.0" 2>/dev/null || true
    
    # Create develop branch
    git checkout -b develop > /dev/null 2>&1
    add_file_and_commit "src/feature.js" "function feature() {}" "Add feature"
    
    # Add another tag
    git tag v1.1 2>/dev/null || true
    
    # Return to main
    git checkout main > /dev/null 2>&1
    
    echo "$repo_dir"
}

# Create complex test repository
create_complex_repo() {
    local repo_dir=$(create_test_repo "complex-repo")
    cd "$repo_dir"
    
    # Add initial files
    add_file_and_commit "README.md" "# Complex Test Repo" "Initial commit"
    add_file_and_commit "src/main.js" "// Main file" "Add main.js"
    add_file_and_commit "docs/guide.md" "# User Guide" "Add documentation"
    
    # Tag initial release
    git tag -a v1.0 -m "Initial release" 2>/dev/null || true
    
    # Create develop branch
    git checkout -b develop > /dev/null 2>&1
    add_file_and_commit "src/utils.js" "// Utilities" "Add utils"
    
    # Create feature branch from develop
    git checkout -b feature/new-ui > /dev/null 2>&1
    add_file_and_commit "src/ui.js" "// New UI" "Add new UI"
    add_file_and_commit "styles/main.css" "body { margin: 0; }" "Add styles"
    
    # Back to develop
    git checkout develop > /dev/null 2>&1
    
    # Create bugfix branch
    git checkout -b bugfix/issue-123 > /dev/null 2>&1
    add_file_and_commit "src/fix.js" "// Bug fix" "Fix issue #123"
    
    # Create release branch
    git checkout main > /dev/null 2>&1
    git checkout -b release/2.0 > /dev/null 2>&1
    add_file_and_commit "CHANGELOG.md" "# v2.0 Changes" "Add changelog"
    
    # Add tags
    git tag v2.0-beta 2>/dev/null || true
    git tag -a v2.0 -m "Version 2.0" 2>/dev/null || true
    git tag latest main 2>/dev/null || true
    
    # Return to main
    git checkout main > /dev/null 2>&1
    
    echo "$repo_dir"
}

# Create edge case repository
create_edge_case_repo() {
    local repo_dir=$(create_test_repo "edge-case-repo")
    cd "$repo_dir"
    
    # Create initial commit
    add_file_and_commit "README.md" "# Edge Case Repo" "Initial commit"
    
    # Branch with special characters
    git checkout -b "feature/user@email.com" > /dev/null 2>&1
    add_file_and_commit "special.txt" "Special branch" "Add to special branch"
    
    # Branch with spaces (escaped)
    git checkout -b "feature/new-feature-2024" > /dev/null 2>&1
    add_file_and_commit "feature.txt" "Feature" "Add feature"
    
    # Very long branch name
    git checkout -b "feature/this-is-a-very-long-branch-name-that-exceeds-normal-length-expectations-and-might-cause-issues" > /dev/null 2>&1
    add_file_and_commit "long.txt" "Long branch" "Add to long branch"
    
    # Binary file
    git checkout main > /dev/null 2>&1
    printf '\x00\x01\x02\x03' > binary.dat
    git add binary.dat
    git commit -m "Add binary file" > /dev/null 2>&1
    
    # Tag with special characters  
    git tag "v1.0+build.123" 2>/dev/null || true
    
    echo "$repo_dir"
}

# Create empty repository
create_empty_repo() {
    local repo_dir=$(create_test_repo "empty-repo")
    # Just return the empty repo
    echo "$repo_dir"
}

# Create repository with subdirectories
create_subdir_repo() {
    local repo_dir=$(create_test_repo "subdir-repo")
    cd "$repo_dir"
    
    # Complex directory structure
    add_file_and_commit "src/main/java/App.java" "public class App {}" "Add Java app"
    add_file_and_commit "src/test/java/AppTest.java" "public class AppTest {}" "Add test"
    add_file_and_commit "docs/api/index.html" "<html>API</html>" "Add API docs"
    add_file_and_commit "config/app.yml" "name: app" "Add config"
    
    # Create branches
    git checkout -b feature/backend > /dev/null 2>&1
    add_file_and_commit "src/main/java/Service.java" "public class Service {}" "Add service"
    
    git checkout main > /dev/null 2>&1
    
    echo "$repo_dir"
}

# Main function to create all test repos
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Creating test repositories..."
    
    SIMPLE=$(create_simple_repo)
    echo "Created simple repo: $SIMPLE"
    
    COMPLEX=$(create_complex_repo)
    echo "Created complex repo: $COMPLEX"
    
    EDGE=$(create_edge_case_repo)
    echo "Created edge case repo: $EDGE"
    
    EMPTY=$(create_empty_repo)
    echo "Created empty repo: $EMPTY"
    
    SUBDIR=$(create_subdir_repo)
    echo "Created subdir repo: $SUBDIR"
fi

# AIDEV-NOTE: test-repo-setup - Creates various test repositories for comprehensive testing 