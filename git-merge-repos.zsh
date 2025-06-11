#!/usr/bin/env zsh

# Git Repository Merger Script
# Merges one git repository into another while preserving all branches, tags, and commits
# Branches and tags from the incoming repo will be prefixed with the repo name

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    shift
    printf "${color}%s${NC}\n" "$*"
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <source-repo> <source-name>

Merge a source git repository into the current repository.

Arguments:
  source-repo    URL or path to the source repository to merge
  source-name    Name to prefix branches and tags with (e.g., 'project-a')

Options:
  -s, --subdirectory <dir>   Move all files from source repo into specified subdirectory
  -b, --branch <branch>      Only merge specified branch (default: merge all branches)
  -t, --skip-tags           Skip importing tags
  -f, --force               Force operations (may overwrite existing branches/tags)
  -n, --dry-run             Show what would be done without making changes
  -h, --help                Show this help message

Examples:
  # Merge all branches and tags from another repo
  $0 https://github.com/user/other-repo.git other-repo

  # Merge into a subdirectory
  $0 -s libs/other-project https://github.com/user/other-repo.git other-project

  # Merge only main branch
  $0 -b main ../other-local-repo other-local
EOF
}

# Parse command line arguments
SUBDIRECTORY=""
SPECIFIC_BRANCH=""
SKIP_TAGS=false
FORCE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subdirectory)
            SUBDIRECTORY="$2"
            shift 2
            ;;
        -b|--branch)
            SPECIFIC_BRANCH="$2"
            shift 2
            ;;
        -t|--skip-tags)
            SKIP_TAGS=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            print_color $RED "Error: Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check required arguments
if [[ $# -lt 2 ]]; then
    print_color $RED "Error: Missing required arguments"
    usage
    exit 1
fi

SOURCE_REPO="$1"
SOURCE_NAME="$2"

# Validate source name (should be a valid git ref component)
if ! [[ "$SOURCE_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    print_color $RED "Error: Invalid source name. Use only alphanumeric characters, dots, hyphens, and underscores."
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_color $RED "Error: Not in a git repository"
    exit 1
fi

# Function to execute or simulate commands
execute_cmd() {
    local cmd="$@"
    if [[ "$DRY_RUN" == true ]]; then
        print_color $YELLOW "[DRY RUN] $cmd"
    else
        print_color $BLUE "Executing: $cmd"
        if ! eval "$cmd"; then
            print_color $RED "Command failed: $cmd"
            exit 1
        fi
    fi
}

# AIDEV-NOTE: remote-naming - Using unique remote name to avoid conflicts
REMOTE_NAME="merge-source-${SOURCE_NAME}-$$"

print_color $GREEN "=== Git Repository Merger ==="
print_color $GREEN "Source repository: $SOURCE_REPO"
print_color $GREEN "Source name prefix: $SOURCE_NAME"
[[ -n "$SUBDIRECTORY" ]] && print_color $GREEN "Target subdirectory: $SUBDIRECTORY"
[[ "$DRY_RUN" == true ]] && print_color $YELLOW "Running in DRY RUN mode"
echo

# Add the source repository as a remote
print_color $BLUE "Adding source repository as remote..."
execute_cmd "git remote add '$REMOTE_NAME' '$SOURCE_REPO'"

# Fetch all branches from the source repository (tags will be processed separately)
print_color $BLUE "Fetching branches from source repository..."
execute_cmd "git fetch --no-tags '$REMOTE_NAME' '+refs/heads/*:refs/remotes/$REMOTE_NAME/*'"

# Get list of branches to process
if [[ -n "$SPECIFIC_BRANCH" ]]; then
    # Only process the specified branch - but first verify it exists
    if [[ "$DRY_RUN" == false ]]; then
        if ! git show-ref --verify --quiet "refs/remotes/$REMOTE_NAME/$SPECIFIC_BRANCH"; then
            print_color $RED "Error: Branch '$SPECIFIC_BRANCH' does not exist in source repository"
            git remote remove "$REMOTE_NAME" 2>/dev/null || true
            exit 1
        fi
    fi
    BRANCHES=("$SPECIFIC_BRANCH")
else
    if [[ "$DRY_RUN" == true ]]; then
        # In dry run mode, we can't list remote branches, so simulate what would happen
        print_color $YELLOW "[DRY RUN] Would process all branches from remote"
        # Continue to show the summary
        BRANCHES=()
    else
        # Get all branches from the remote
        BRANCHES=($(git branch -r | grep "^  $REMOTE_NAME/" | sed "s|^  $REMOTE_NAME/||" | grep -v "HEAD"))
    fi
fi

# Track created and skipped items
CREATED_BRANCHES=()
SKIPPED_BRANCHES=()
SKIPPED_TAGS=()

# Process branches
print_color $GREEN "\n=== Processing Branches ==="
for branch in "${BRANCHES[@]}"; do
    local_branch="${SOURCE_NAME}-${branch}"
    remote_branch="$REMOTE_NAME/$branch"
    
    print_color $BLUE "Processing branch: $branch -> $local_branch"
    
    # Check if local branch already exists
    if git show-ref --verify --quiet "refs/heads/$local_branch"; then
        if [[ "$FORCE" == true ]]; then
            print_color $YELLOW "Branch $local_branch exists, overwriting (--force)"
            git branch -D "$local_branch" 2>/dev/null || true
        else
            print_color $YELLOW "Branch $local_branch already exists, skipping (use --force to overwrite)"
            SKIPPED_BRANCHES+=("$local_branch")
            continue
        fi
    fi
    
    # Create local branch from remote (handling potential errors gracefully)
    if git branch "$local_branch" "$remote_branch" 2>/dev/null; then
        print_color $GREEN "Created branch: $local_branch"
        CREATED_BRANCHES+=("$local_branch")
    else
        print_color $RED "Failed to create branch: $local_branch"
        continue
    fi
    
    # If subdirectory is specified, we need to rewrite history
    if [[ -n "$SUBDIRECTORY" ]] && [[ "$DRY_RUN" == false ]]; then
        print_color $BLUE "Moving files to subdirectory: $SUBDIRECTORY"
        
        # Use filter-branch to move all files to subdirectory
        # AIDEV-NOTE: filter-branch-subdirectory - Rewrites history to move files
        FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --prune-empty --tree-filter "
            # Create a temporary directory to avoid conflicts
            if [[ ! -d '.git-rewrite-temp' ]]; then
                mkdir -p '.git-rewrite-temp/$SUBDIRECTORY'
                # Move all files except .git and our temp dir to the temp subdirectory
                find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.git-rewrite-temp' -exec mv {} '.git-rewrite-temp/$SUBDIRECTORY/' \; 2>/dev/null || true
                # Move the temp structure back
                if [[ -d '.git-rewrite-temp/$SUBDIRECTORY' ]] && [[ \"\$(ls -A '.git-rewrite-temp/$SUBDIRECTORY' 2>/dev/null)\" ]]; then
                    mkdir -p \"\$(dirname '$SUBDIRECTORY')\"
                    mv '.git-rewrite-temp/$SUBDIRECTORY' '$SUBDIRECTORY'
                fi
                rm -rf '.git-rewrite-temp'
            fi
        " -- "$local_branch"
    fi
done

# Process tags (unless skipped)
if [[ "$SKIP_TAGS" == false ]]; then
    print_color $GREEN "\n=== Processing Tags ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        # In dry run mode, we can't list remote tags
        print_color $YELLOW "[DRY RUN] Would process all tags from remote"
        TAGS=()
    else
        # Get all tags from the remote
        TAGS=($(git ls-remote --tags "$REMOTE_NAME" | awk '{print $2}' | sed 's|^refs/tags/||' | grep -v '\^{}$'))
    fi
    CREATED_TAGS=()
    
    for tag in "${TAGS[@]}"; do
        new_tag="${SOURCE_NAME}-${tag}"
        
        print_color $BLUE "Processing tag: $tag -> $new_tag"
        
        # Check if tag already exists
        if git show-ref --verify --quiet "refs/tags/$new_tag"; then
            if [[ "$FORCE" == true ]]; then
                print_color $YELLOW "Tag $new_tag exists, overwriting (--force)"
                git tag -d "$new_tag" 2>/dev/null || true
            else
                print_color $YELLOW "Tag $new_tag already exists, skipping (use --force to overwrite)"
                SKIPPED_TAGS+=("$new_tag")
                continue
            fi
        fi
        
        # Fetch the specific tag object first
        local temp_tag="${REMOTE_NAME}-temp-${tag}"
        if git fetch --no-tags "$REMOTE_NAME" "refs/tags/${tag}:refs/tags/${temp_tag}" 2>/dev/null; then
            # Create new tag with prefix pointing to the fetched tag
            if git tag "$new_tag" "$temp_tag" 2>/dev/null; then
                CREATED_TAGS+=("$new_tag")
                print_color $GREEN "Created tag: $new_tag"
                # Clean up temporary tag
                git tag -d "$temp_tag" 2>/dev/null || true
            else
                print_color $RED "Failed to create tag: $new_tag"
                SKIPPED_TAGS+=("$new_tag")
                # Clean up temporary tag
                git tag -d "$temp_tag" 2>/dev/null || true
            fi
        else
            print_color $RED "Failed to fetch tag: $tag"
            SKIPPED_TAGS+=("$new_tag")
        fi
    done
else
    print_color $YELLOW "\nSkipping tags (--skip-tags specified)"
fi

# Check if we created any branches (when not in dry-run and specific branch was requested)
if [[ "$DRY_RUN" == false ]] && [[ -n "$SPECIFIC_BRANCH" ]] && [[ ${#CREATED_BRANCHES[@]} -eq 0 ]]; then
    print_color $RED "Error: Failed to create any branches"
    git remote remove "$REMOTE_NAME" 2>/dev/null || true
    exit 1
fi

# Clean up - remove the temporary remote
print_color $BLUE "\nCleaning up..."
execute_cmd "git remote remove '$REMOTE_NAME'"

# Summary
print_color $GREEN "\n=== Merge Complete ==="
if [[ "$DRY_RUN" == false ]]; then
    print_color $GREEN "Successfully merged repository '$SOURCE_REPO' with prefix '$SOURCE_NAME'"
    
    # Show created branches
    if [[ ${#CREATED_BRANCHES[@]} -gt 0 ]]; then
        echo
        print_color $GREEN "Created branches:"
        for branch in "${CREATED_BRANCHES[@]}"; do
            echo "  - $branch"
        done
    fi
    
    if [[ "$SKIP_TAGS" == false ]] && [[ ${#CREATED_TAGS[@]} -gt 0 ]]; then
        echo
        print_color $GREEN "Created tags:"
        for tag in "${CREATED_TAGS[@]}"; do
            echo "  - $tag"
        done
    fi
    
    # Show skipped items if any
    if [[ ${#SKIPPED_BRANCHES[@]} -gt 0 ]] || [[ ${#SKIPPED_TAGS[@]} -gt 0 ]]; then
        echo
        print_color $YELLOW "Skipped (already exist):"
        for branch in "${SKIPPED_BRANCHES[@]}"; do
            echo "  - Branch: $branch"
        done
        for tag in "${SKIPPED_TAGS[@]}"; do
            echo "  - Tag: $tag"
        done
        print_color $YELLOW "Use --force to overwrite existing branches/tags"
    fi
    
    echo
    print_color $YELLOW "Next steps:"
    print_color $YELLOW "1. Review the imported branches and tags"
    print_color $YELLOW "2. Merge desired branches into your main branch:"
    print_color $YELLOW "   git checkout main"
    print_color $YELLOW "   git merge ${SOURCE_NAME}-main"
    if [[ -n "$SUBDIRECTORY" ]]; then
        print_color $YELLOW "3. All files from the source repo are now in: $SUBDIRECTORY/"
    fi
else
    print_color $YELLOW "Dry run completed. No changes were made."
fi 