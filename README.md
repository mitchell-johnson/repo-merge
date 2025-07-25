# Git Repository Merger Scripts

Powerful zsh scripts for merging one git repository into another while preserving all branches, tags, and commit history.

## Features

- ✅ Preserves all branches from both repositories
- ✅ Preserves all tags from both repositories  
- ✅ Maintains complete commit history
- ✅ Prefixes imported branches/tags to avoid naming conflicts
- ✅ Optional subdirectory placement to avoid file conflicts
- ✅ Dry-run mode for safety
- ✅ Advanced features like automatic merging and history rewriting

## Script List

| Script | Platform | Status |
|--------|----------|--------|
| `git-merge-repos-advanced.zsh` | macOS / Linux (zsh) | **Primary & tested** |
| `git-merge-repos.ps1` | Windows PowerShell | _Initial port – **experimental / untested**_ |

> The former `git-merge-repos.zsh` (basic version) has been removed – the advanced script supersedes it.

---

### `git-merge-repos-advanced.zsh` (main script)

The advanced script includes additional features for complex merging scenarios.

**Additional Options:**
- `-m, --merge-to <branch>` - Automatically merge after import
- `-p, --preserve-paths` - Keep original file paths
- `-r, --rewrite-history` - Use git-filter-repo for better performance
- `-g, --graft` - Use grafts to connect histories
- `--squash-merge` - Squash commits when merging
- `--no-commit` - Prepare merge without committing
- `--strategy <strategy>` - Specify merge strategy

## Quick Examples

### Automatic integration
```bash
./git-merge-repos-advanced.zsh -m main -s vendor/lib https://github.com/user/lib.git lib
```

## How It Works

1. **Remote Addition**: The source repository is added as a temporary remote
2. **Fetching**: All branches and tags are fetched from the source
3. **Branch Creation**: Local branches are created with the source name as prefix
4. **Tag Creation**: Tags are recreated with the source name as prefix
5. **Optional Subdirectory**: If specified, history is rewritten to move files
6. **Cleanup**: The temporary remote is removed

## Branch and Tag Naming

If you merge a repository with source name `other-repo` (new naming scheme):
- Branch `main` becomes `other-repo-main`
- Branch `feature/x` becomes `other-repo-feature/x`
- Tag `v1.0.0` becomes `other-repo/v1.0.0`

## Safety Features

- **Dry Run Mode**: Use `-n` to preview all changes
- **No Overwrites**: Existing branches/tags are skipped by default
- **Force Mode**: Use `-f` to explicitly overwrite
- **Unique Remote Names**: Prevents conflicts with existing remotes
- **Conflict Handling**: Gracefully handles repos with same branch/tag names
- **Clear Reporting**: Shows what was created and what was skipped

## Common Use Cases

### 1. Consolidating Microservices
```bash
# Merge multiple services into a monorepo
./git-merge-repos-advanced.zsh -s services/auth -m main https://github.com/company/auth-service.git auth
./git-merge-repos-advanced.zsh -s services/api -m main https://github.com/company/api-service.git api
```

### 2. Absorbing Dependencies
```bash
# Bring an external dependency in-house
./git-merge-repos-advanced.zsh -s vendor/cool-lib https://github.com/other/cool-lib.git cool-lib
```

### 3. Merging Forks
```bash
# Import a fork to cherry-pick changes
./git-merge-repos-advanced.zsh https://github.com/fork/project.git fork
git checkout main
git cherry-pick fork-feature-branch
```

## Requirements

- **zsh** shell
- **git** (2.20 or newer recommended)
- **git-filter-repo** (optional, for `-r` flag in advanced script)

## Installation

1. Clone or download the scripts
2. Make them executable:
   ```bash
   chmod +x git-merge-repos-advanced.zsh
   ```

## Best Practices

1. **Always backup first**: Create a backup branch or clone before merging
2. **Use dry run**: Test with `-n` flag first
3. **Use subdirectories**: Prevents file conflicts with `-s` option
4. **Review imported branches**: Check the imported content before merging
5. **Clean up afterwards**: Delete unnecessary imported branches after cherry-picking

## Troubleshooting

### "Not in a git repository" error
Make sure you're in a git repository before running the script.

### Existing branches/tags
Use `-f` to force overwrite, or manually delete conflicting branches/tags first.

### File conflicts
Use the `-s` subdirectory option to avoid conflicts, or the `-p` flag to preserve paths if you're sure there won't be conflicts.

### Large repositories
For very large repositories, the advanced script with `-r` flag uses git-filter-repo for better performance.

## Testing

Automated Zsh-based tests live in `test/` and can be run via:

```bash
zsh test/run_all_tests.zsh
```

PowerShell equivalents are being ported incrementally to `tests-windows/`.  A cross-platform
runner will be added once the suite is complete.

## Windows usage (experimental)

The PowerShell version mirrors the Zsh script but hasn't yet been exercised by an automated
suite or extensive real-world use.  Please file issues or PRs if you encounter problems.

## Recovery

If something goes wrong:
1. Use `git reflog` to find the previous state
2. Reset to previous commit: `git reset --hard <commit>`
3. Remove unwanted branches: `git branch -D <branch>`
4. Remove unwanted tags: `git tag -d <tag>`

## License

These scripts are provided as-is for use in your projects.

---

For more examples, run `bash examples.sh` or check the script help with `--help`. 