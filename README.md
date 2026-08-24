# Utilssets

A collection of development utilities and scripts for multi-platform environments.

## Structure

```
utilssets/
├── bin/                    # Executable scripts and tools
├── lib/                    # Shared libraries
│   ├── shell/             # Shell function libraries
│   └── python/            # Python modules
├── config/                 # Configuration files
│   ├── shell/             # Shell configurations
│   ├── vim/               # Vim configurations
│   └── latex/             # LaTeX templates
├── tools/                  # Third-party tools
│   ├── pyenv/             # Python version manager
│   ├── fzf/               # Fuzzy finder
│   └── bin/               # Helper binaries generated or managed by installers
├── src/                    # Source code and standalone examples
│   ├── android/           # Android / NDK utilities and experiments
│   ├── audio/             # Audio processing utilities and components
│   ├── c/                 # C projects
│   ├── cmake/             # CMake examples
│   ├── cpp/               # C++ projects
│   ├── gnu/               # GNU tools
│   └── ml/                # Standalone ML scripts
├── scripts/                # Utility scripts by category
│   ├── android/           # Android development
│   ├── docker/            # Docker utilities
│   ├── git/               # Git utilities
│   ├── python/            # Python scripts
│   ├── tensorflow/        # TensorFlow utilities
│   └── system/            # System utilities
├── install/                # Installation scripts
│   ├── common/            # Common installers
│   ├── darwin/            # macOS-specific
│   └── linux/             # Linux-specific
└── docs/                   # Documentation
```

## Quick Start

### 1. Initial Setup

```bash
# macOS
bash install/darwin/wizard_Darwin.sh

# Linux
bash install/linux/wizard_Linux.sh
```

### 2. Optional Setup

```bash
# Configure locale (default: C.UTF-8)
bash install/common/setup_locale.sh [LOCALE]

# Setup pyenv
bash install/common/setup_pyenv.sh
```

### 2. Load Environment

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export UTILSSETS_ROOT="/path/to/utilssets"
source ${UTILSSETS_ROOT}/config/shell/config.env
```

### 3. Platform-Specific Setup

**macOS:**
```bash
bash install/darwin/wizard_Darwin.sh
```

**Linux:**
```bash
bash install/linux/wizard_Linux.sh
```

## Components

### Executables (bin/)
- System utilities and helper scripts
- Document conversion tools (md2pdf, tex2pdf)
- Android development tools
- Code formatting utilities

### Libraries (lib/)
- **Python**: Machine learning utilities (PyTorch, ONNX), audio processing
- **Shell**: Common functions for error handling, logging, and utilities

### Tools (tools/)
- **pyenv**: Python version management
- **fzf**: Fuzzy finder for command-line
- **android-sdk**: Android development tools

### Scripts (scripts/)
- Android development automation
- Docker container management
- Git/Gerrit utilities
- System administration tools

## Requirements

- Bash 4.0+ or Zsh 5.0+
- Git
- curl/wget
- Platform-specific: see `install/common/prerequisite.sh`

## Configuration

Configuration files are located in `config/`:
- `config/shell/env.conf`: Environment variables
- `config/shell/path.conf`: PATH configurations
- `config/shell/config.env`: Loads all shell `*.conf` files
- `config/vim/`: Vim configuration and plugins

## Python Development

Install Python dependencies:
```bash
pip install -r lib/python/requirements.txt
```

Import utilities:
```python
from pyutils.ml import torch_model_utils, onnx_model_utils
```

## Known Issues

See [install/common/issues.md](install/common/issues.md) for known issues and solutions.

## Documentation

- [Optimization History](docs/OPTIMIZATION.md)
- [Restructure Plan](docs/RESTRUCTURE_PLAN.md)

## License

Internal use only.
