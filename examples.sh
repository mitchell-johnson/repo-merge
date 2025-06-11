#!/usr/bin/env bash

# Examples of using the git-merge-repos scripts

echo "Git Repository Merger - Usage Examples"
echo "======================================"
echo

echo "Basic Script (git-merge-repos.zsh):"
echo "-----------------------------------"
echo
echo "1. Simple merge - all branches and tags:"
echo "   ./git-merge-repos.zsh https://github.com/user/other-repo.git other-repo"
echo
echo "2. Merge into a subdirectory:"
echo "   ./git-merge-repos.zsh -s libs/component https://github.com/user/component.git component"
echo
echo "3. Merge only the main branch:"
echo "   ./git-merge-repos.zsh -b main ../local-repo local"
echo
echo "4. Dry run to see what would happen:"
echo "   ./git-merge-repos.zsh -n https://github.com/user/repo.git repo"
echo
echo "5. Force overwrite existing branches/tags:"
echo "   ./git-merge-repos.zsh -f https://github.com/user/repo.git repo"
echo

echo "Advanced Script (git-merge-repos-advanced.zsh):"
echo "----------------------------------------------"
echo
echo "6. Automatic merge into current branch after import:"
echo "   ./git-merge-repos-advanced.zsh -m main https://github.com/user/lib.git lib"
echo
echo "7. Merge with subdirectory and modern history rewriting:"
echo "   ./git-merge-repos-advanced.zsh -s vendor/lib -r https://github.com/user/lib.git lib"
echo
echo "8. Squash merge into main branch:"
echo "   ./git-merge-repos-advanced.zsh -m main --squash-merge https://github.com/user/feature.git feature"
echo
echo "9. Preserve original paths (careful - may cause conflicts):"
echo "   ./git-merge-repos-advanced.zsh -p https://github.com/user/similar-project.git similar"
echo
echo "10. Use subtree merge strategy:"
echo "    ./git-merge-repos-advanced.zsh -m main --strategy subtree https://github.com/user/lib.git lib"
echo

echo "Real-world scenarios:"
echo "--------------------"
echo
echo "Scenario 1: Consolidating microservices into a monorepo"
echo "  # For each service:"
echo "  ./git-merge-repos-advanced.zsh -s services/auth -m main https://github.com/company/auth-service.git auth"
echo "  ./git-merge-repos-advanced.zsh -s services/api -m main https://github.com/company/api-service.git api"
echo "  ./git-merge-repos-advanced.zsh -s services/web -m main https://github.com/company/web-service.git web"
echo
echo "Scenario 2: Absorbing a dependency"
echo "  # First, do a dry run:"
echo "  ./git-merge-repos.zsh -n -s vendor/cool-lib https://github.com/other/cool-lib.git cool-lib"
echo "  # If looks good, do it for real:"
echo "  ./git-merge-repos.zsh -s vendor/cool-lib https://github.com/other/cool-lib.git cool-lib"
echo
echo "Scenario 3: Merging forks back together"
echo "  # Import the fork with prefixed branches"
echo "  ./git-merge-repos.zsh https://github.com/fork/project.git fork"
echo "  # Cherry-pick or merge specific branches"
echo "  git checkout main"
echo "  git merge fork-feature-x"
echo

echo "Tips:"
echo "-----"
echo "• Always do a dry run first with -n/--dry-run"
echo "• Use subdirectories (-s) to avoid file conflicts"
echo "• The source-name becomes the prefix for all branches/tags"
echo "• Back up your repository before merging"
echo "• Use 'git reflog' to recover if something goes wrong"
echo

# AIDEV-NOTE: example-validation - These examples assume scripts are executable 