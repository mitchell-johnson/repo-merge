#!/usr/bin/env zsh

# Advanced Git Repository Merger Script
# Merges one git repository into another while preserving all branches, tags, and commits
# Uses modern Git features and handles edge cases

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
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

Advanced merge of a source git repository into the current repository.

Arguments:
  source-repo    URL or path to the source repository to merge
  source-name    Name to prefix branches and tags with (e.g., 'project-a')

Options:
  -s, --subdirectory <dir>   Move all files from source repo into specified subdirectory
  -b, --branch <branch>      Only merge specified branch (default: merge all branches)
  -t, --skip-tags           Skip importing tags
  -f, --force               Force operations (may overwrite existing branches/tags)
  -n, --dry-run             Show what would be done without making changes
  -m, --merge-to <branch>   After import, merge source's main/master into specified branch
  -p, --preserve-paths      Keep original file paths (may cause conflicts)
  -r, --rewrite-history     Use git-filter-repo for better history rewriting (requires git-filter-repo)
  -g, --graft               Use grafts to connect histories at merge point
  -h, --help                Show this help message

Advanced Options:
  --squash-merge            When using -m, perform a squash merge
  --no-commit              When using -m, prepare merge but don't commit
  --strategy <strategy>     Merge strategy to use (recursive, ours, subtree)

Examples:
  # Basic merge with automatic integration
  $0 -m main https://github.com/user/other-repo.git other-repo

  # Merge into subdirectory with history rewrite
  $0 -s libs/component -r https://github.com/user/component.git component

  # Merge preserving paths with custom strategy
  $0 -p --strategy subtree ../other-repo other
EOF
}

# Parse command line arguments
SUBDIRECTORY=""
SPECIFIC_BRANCH=""
SKIP_TAGS=false
FORCE=false
DRY_RUN=false
MERGE_TO=""
PRESERVE_PATHS=false
REWRITE_HISTORY=false
USE_GRAFT=false
SQUASH_MERGE=false
NO_COMMIT=false
MERGE_STRATEGY="recursive"
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subdirectory)
            SUBDIRECTORY="$2"; shift 2;;
        -b|--branch)
            SPECIFIC_BRANCH="$2"; shift 2;;
        -t|--skip-tags)
            SKIP_TAGS=true; shift;;
        -f|--force)
            FORCE=true; shift;;
        -n|--dry-run)
            DRY_RUN=true; shift;;
        -m|--merge-to)
            MERGE_TO="$2"; shift 2;;
        -p|--preserve-paths)
            PRESERVE_PATHS=true; shift;;
        -r|--rewrite-history)
            REWRITE_HISTORY=true; shift;;
        -g|--graft)
            USE_GRAFT=true; shift;;
        --squash-merge)
            SQUASH_MERGE=true; shift;;
        --no-commit)
            NO_COMMIT=true; shift;;
        --strategy)
            MERGE_STRATEGY="$2"; shift 2;;
        -h|--help)
            usage; exit 0;;
        --*)
            print_color $RED "Error: Unknown option: $1"; usage; exit 1;;
        *)
            POSITIONAL+=("$1"); shift;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL[@]}"

if [[ $# -lt 2 ]]; then
    print_color $RED "Error: Missing required arguments"
    usage
    exit 1
fi

SOURCE_REPO="$1"
SOURCE_NAME="$2"

# Validate source name
if ! [[ "$SOURCE_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    print_color $RED "Error: Invalid source name. Use only alphanumeric characters, dots, hyphens, and underscores."
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_color $RED "Error: Not in a git repository"
    exit 1
fi

# Check for required tools
if [[ "$REWRITE_HISTORY" == true ]] && ! command -v git-filter-repo &> /dev/null; then
    print_color $RED "Error: git-filter-repo is required for history rewriting"
    print_color $YELLOW "Install with: pip install git-filter-repo"
    exit 1
fi

# Validate options
if [[ "$PRESERVE_PATHS" == true ]] && [[ -n "$SUBDIRECTORY" ]]; then
    print_color $RED "Error: Cannot use --preserve-paths with --subdirectory"
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

# Function to check if branch exists locally
branch_exists() {
    git show-ref --verify --quiet "refs/heads/$1"
}

# Function to get default branch of remote
get_default_branch() {
    local remote=$1
    git symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s|refs/remotes/$remote/||" || echo "main"
}

# AIDEV-NOTE: unique-remote-name - Prevents conflicts with existing remotes
REMOTE_NAME="merge-source-${SOURCE_NAME}-$$"
ORIGINAL_DIR=$(pwd)

print_color $MAGENTA "=== Advanced Git Repository Merger ==="
print_color $GREEN "Source repository: $SOURCE_REPO"
print_color $GREEN "Source name prefix: $SOURCE_NAME"
[[ -n "$SUBDIRECTORY" ]] && print_color $GREEN "Target subdirectory: $SUBDIRECTORY"
[[ "$PRESERVE_PATHS" == true ]] && print_color $GREEN "Preserving original file paths"
[[ "$DRY_RUN" == true ]] && print_color $YELLOW "Running in DRY RUN mode"
echo

# Save current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Add the source repository as a remote
print_color $BLUE "Adding source repository as remote..."
execute_cmd "git remote add '$REMOTE_NAME' '$SOURCE_REPO'"

# Fetch all branches from the source repository (tags will be processed separately)
print_color $BLUE "Fetching branches from source repository..."
execute_cmd "git fetch --no-tags '$REMOTE_NAME' '+refs/heads/*:refs/remotes/$REMOTE_NAME/*'"

# Get default branch of source repo
DEFAULT_BRANCH=$(get_default_branch "$REMOTE_NAME")
print_color $CYAN "Detected default branch: $DEFAULT_BRANCH"

# Get list of branches to process
if [[ -n "$SPECIFIC_BRANCH" ]]; then
    BRANCHES=("$SPECIFIC_BRANCH")
else
    if [[ "$DRY_RUN" == true ]]; then
        # In dry run mode, we can't list remote branches, so simulate what would happen
        print_color $YELLOW "[DRY RUN] Would process all branches from remote"
        BRANCHES=()
    else
        # Get all branches from the remote
        BRANCHES=($(git branch -r | grep "^  $REMOTE_NAME/" | sed "s|^  $REMOTE_NAME/||" | grep -v "HEAD"))
    fi
fi

# If using subdirectory and modern rewriting, prepare filter-repo commands
if [[ -n "$SUBDIRECTORY" ]] && [[ "$REWRITE_HISTORY" == true ]]; then
    print_color $CYAN "Preparing for history rewrite with git-filter-repo..."
fi

# Process branches
print_color $GREEN "\n=== Processing Branches ==="
CREATED_BRANCHES=()

for branch in "${BRANCHES[@]}"; do
    local_branch="${SOURCE_NAME}-${branch}"
    remote_branch="$REMOTE_NAME/$branch"
    
    print_color $BLUE "Processing branch: $branch -> $local_branch"
    
    # Check if local branch already exists
    if branch_exists "$local_branch"; then
        if [[ "$FORCE" == true ]]; then
            print_color $YELLOW "Branch $local_branch exists, overwriting (--force)"
            git branch -D "$local_branch" 2>/dev/null || true
        else
            print_color $YELLOW "Branch $local_branch already exists, skipping (use --force to overwrite)"
            continue
        fi
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        # Create local branch from remote
        git branch "$local_branch" "$remote_branch"
        CREATED_BRANCHES+=("$local_branch")
        
        # If subdirectory is specified, we need to rewrite history
        if [[ -n "$SUBDIRECTORY" ]]; then
            print_color $BLUE "Moving files to subdirectory: $SUBDIRECTORY"
            
            if [[ "$REWRITE_HISTORY" == true ]]; then
                # AIDEV-NOTE: filter-repo-modern - Using git-filter-repo for better performance
                # Create a temporary clone for rewriting
                TEMP_DIR=$(mktemp -d)
                git clone --single-branch --branch "$local_branch" . "$TEMP_DIR" 2>/dev/null
                
                cd "$TEMP_DIR"
                git-filter-repo --to-subdirectory-filter "$SUBDIRECTORY" --force
                
                # Push the rewritten branch back
                cd "$ORIGINAL_DIR"
                git fetch "$TEMP_DIR" "$local_branch:$local_branch" --force
                rm -rf "$TEMP_DIR"
            else
                # Use traditional filter-branch
                git filter-branch -f --prune-empty --tree-filter "
                    mkdir -p '$SUBDIRECTORY'
                    find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '$SUBDIRECTORY' -exec mv {} '$SUBDIRECTORY/' \; 2>/dev/null || true
                " -- "$local_branch"
            fi
        fi
    else
        execute_cmd "git branch '$local_branch' '$remote_branch'"
        CREATED_BRANCHES+=("$local_branch")
    fi
done

# Process tags
if [[ "$SKIP_TAGS" == false ]]; then
    print_color $GREEN "\n=== Processing Tags ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        # In dry run mode, we can't list remote tags
        print_color $YELLOW "[DRY RUN] Would process all tags from remote"
        TAGS=()
    else
        # Get all tags from the remote
        TAGS=($(git ls-remote --tags "$REMOTE_NAME" \
            | awk '{print $2}' \
            | sed 's|^refs/tags/||' \
            | grep -v '\^{}$' || true))
    fi
    CREATED_TAGS=()
    
    for tag in "${TAGS[@]}"; do
        new_tag="${SOURCE_NAME}/${tag}"
        
        print_color $BLUE "Processing tag: $tag -> $new_tag"
        
        # Check if tag already exists
        if git show-ref --verify --quiet "refs/tags/$new_tag"; then
            if [[ "$FORCE" == true ]]; then
                print_color $YELLOW "Tag $new_tag exists, overwriting (--force)"
                git tag -d "$new_tag" 2>/dev/null || true
            else
                print_color $YELLOW "Tag $new_tag already exists, skipping (use --force to overwrite)"
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
                # Clean up temporary tag
                git tag -d "$temp_tag" 2>/dev/null || true
            fi
        else
            print_color $RED "Failed to fetch tag: $tag"
        fi
    done
else
    print_color $YELLOW "\nSkipping tags (--skip-tags specified)"
fi

# Automatic merge if requested
if [[ -n "$MERGE_TO" ]] && [[ "$DRY_RUN" == false ]]; then
    print_color $GREEN "\n=== Performing Automatic Merge ==="
    
    # Find the imported default branch
    MERGE_SOURCE="${SOURCE_NAME}-${DEFAULT_BRANCH}"
    
    if ! branch_exists "$MERGE_SOURCE"; then
        # Try common branch names
        for try_branch in "${SOURCE_NAME}-main" "${SOURCE_NAME}-master"; do
            if branch_exists "$try_branch"; then
                MERGE_SOURCE="$try_branch"
                break
            fi
        done
    fi
    
    if branch_exists "$MERGE_SOURCE"; then
        print_color $BLUE "Checking out target branch: $MERGE_TO"
        git checkout "$MERGE_TO"
        
        print_color $BLUE "Merging $MERGE_SOURCE into $MERGE_TO"
        
        # Build common strategy flag
        STRATEGY_FLAG="--strategy=$MERGE_STRATEGY"

        if [[ "$SQUASH_MERGE" == true ]]; then
            # Perform squash merge and create a single commit if --no-commit is not set
            if git merge --squash $STRATEGY_FLAG --allow-unrelated-histories "$MERGE_SOURCE"; then
                if [[ "$NO_COMMIT" == false ]]; then
                    git commit -m "Squash merge $MERGE_SOURCE"
                fi
                print_color $GREEN "Squash merge successful!"
            else
                print_color $RED "Squash merge failed"
            fi
        else
            # Standard or --no-commit merge (uses Git's default merge message)
            MERGE_CMD=(git merge $STRATEGY_FLAG --allow-unrelated-histories)
            if [[ "$NO_COMMIT" == true ]]; then
                MERGE_CMD+=(--no-commit)
            else
                MERGE_MSG="Merge branch '$MERGE_SOURCE'"
                MERGE_CMD+=(-m "$MERGE_MSG")
            fi
            MERGE_CMD+=("$MERGE_SOURCE")
            if "${MERGE_CMD[@]}"; then
                print_color $GREEN "Merge successful!"
            else
                print_color $RED "Merge failed - manual intervention required"
                print_color $YELLOW "Resolve conflicts and run: git merge --continue"
            fi
        fi
        
        # Record graft information when requested (and a commit was created)
        if [[ "$USE_GRAFT" == true ]] && [[ "$NO_COMMIT" == false ]]; then
            MERGE_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")
            if [[ -n "$MERGE_COMMIT" ]]; then
                echo "# Grafted merge from $SOURCE_NAME" >> .git/info/grafts
                echo "$MERGE_COMMIT $(git rev-parse $MERGE_SOURCE)" >> .git/info/grafts
            fi
        fi
    else
        print_color $YELLOW "Could not find source branch to merge"
    fi
fi

# If no automatic merge requested and preserve-paths is set, switch to imported branch
if [[ -z "$MERGE_TO" ]] && [[ "$PRESERVE_PATHS" == true ]] && [[ "$DRY_RUN" == false ]]; then
    IMPORT_BRANCH="${SOURCE_NAME}-${DEFAULT_BRANCH}"
    if branch_exists "$IMPORT_BRANCH"; then
        print_color $BLUE "Checking out imported branch: $IMPORT_BRANCH"
        git checkout "$IMPORT_BRANCH"
    fi
fi

# Restore to original branch only if we haven't intentionally switched (i.e., preserve-paths not used)
if [[ "$PRESERVE_PATHS" == false ]] && [[ "$CURRENT_BRANCH" != "$(git rev-parse --abbrev-ref HEAD)" ]] && [[ "$DRY_RUN" == false ]]; then
    git checkout "$CURRENT_BRANCH" 2>/dev/null || true
fi

# Clean up
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
    
    echo
    print_color $CYAN "Repository Statistics:"
    print_color $CYAN "  Total commits imported: $(git rev-list --count --all --since='1 minute ago')"
    print_color $CYAN "  Current branch: $(git rev-parse --abbrev-ref HEAD)"
    
    echo
    print_color $YELLOW "Next steps:"
    print_color $YELLOW "1. Review the imported branches and tags"
    if [[ -z "$MERGE_TO" ]]; then
        print_color $YELLOW "2. Merge desired branches into your main branch:"
        print_color $YELLOW "   git checkout main"
        print_color $YELLOW "   git merge ${SOURCE_NAME}-${DEFAULT_BRANCH}"
    fi
    if [[ -n "$SUBDIRECTORY" ]]; then
        print_color $YELLOW "3. All files from the source repo are now in: $SUBDIRECTORY/"
    fi
    
    # Check for potential conflicts
    if [[ "$PRESERVE_PATHS" == true ]]; then
        print_color $MAGENTA "\nWarning: Files were imported with original paths preserved."
        print_color $MAGENTA "Check for potential file conflicts before merging."
    fi
else
    print_color $YELLOW "Dry run completed. No changes were made."
    print_color $YELLOW "Remove --dry-run flag to perform actual merge."
fi 