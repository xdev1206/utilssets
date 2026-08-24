# Directory Restructure Plan

## Current Structure Issues
1. `env/` mixes configs, tools, and binaries
2. `scripts/` and `setup/` have overlapping purposes
3. `source/` contains mixed languages without clear organization
4. Platform-specific files scattered across directories

## New Structure

```
utilssets/
├── bin/                    # All executable scripts (from env/bin)
├── lib/                    # Shared libraries and modules
│   ├── shell/             # Shell function libraries (common.sh, etc.)
│   └── python/            # Python modules (from source/pyutils)
├── config/                 # All configuration files
│   ├── shell/             # Shell configs (from env/config)
│   ├── vim/               # Vim configs (from env/vim)
│   └── templates/         # Config templates
├── tools/                  # Third-party tools
│   ├── pyenv/             # From env/tool/pyenv
│   ├── fzf/               # From env/tool/fzf
│   └── android-sdk/       # From env/android
├── src/                    # Source code by language
│   ├── c/                 # C projects
│   ├── cpp/               # C++ projects (from source/c++)
│   ├── python/            # Python projects
│   │   ├── audio/         # Audio processing (from source/audio)
│   │   └── android/       # Android utilities (from source/android)
│   └── java/              # Java projects
├── scripts/                # User utility scripts by category
│   ├── android/           # Android development
│   ├── docker/            # Docker utilities
│   ├── git/               # Git utilities
│   └── system/            # System utilities (from shell/debian/darwin)
├── install/                # Installation scripts (from setup/)
│   ├── common/            # Common installers
│   ├── darwin/            # macOS-specific
│   └── linux/             # Linux-specific
├── docs/                   # Documentation
│   ├── issues.md          # Known issues
│   └── guides/            # Usage guides
└── tests/                  # Test files
    ├── shell/
    └── python/

## Migration Commands

### Phase 1: Create new structure
mkdir -p bin lib/{shell,python} config/{shell,vim,templates} tools src/{c,cpp,python,java} scripts/system install/{common,darwin,linux} docs/guides tests/{shell,python}

### Phase 2: Move files
# Binaries
mv env/bin/* bin/

# Libraries
mv setup/env/common.sh lib/shell/
mv source/pyutils lib/python/

# Configs
mv env/config/*.conf config/shell/
mv env/config.env config/shell/
mv env/vim config/vim/
mv env/latex config/

# Tools
mv env/tool/pyenv tools/
mv env/tool/fzf tools/
mv env/android tools/android-sdk

# Source code
mv source/c src/
mv source/c++ src/cpp/
mv source/audio src/python/
mv source/android src/python/
mv source/cmake src/
mv source/gnu src/

# Scripts - consolidate system scripts
mv scripts/shell scripts/system/
mv scripts/debian scripts/system/
mv scripts/darwin scripts/system/

# Installation
mv setup/* install/common/
mv install/common/Darwin install/darwin/
mv install/common/Linux install/linux/
mv install/common/env install/common/

# Docs
mv setup/issues.md docs/
mv OPTIMIZATION.md docs/

### Phase 3: Update references
# Update config/shell/path.conf
# Update config/shell/config.env
# Update install scripts
# Update README.md

### Phase 4: Cleanup
rmdir env source setup
```

## Benefits
1. Clear separation of concerns
2. Easier to find files
3. Better for version control
4. Standard project layout
5. Easier to add tests
6. Clearer installation process
