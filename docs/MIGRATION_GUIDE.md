# Migration Guide for Existing Users

If you have been using the old directory structure, follow these steps to migrate:

## 1. Update Environment Variables

**Old:**
```bash
export ENV_PATH="/path/to/utilssets/env"
source ${ENV_PATH}/config.env
```

**New:**
```bash
export UTILSSETS_ROOT="/path/to/utilssets"
source ${UTILSSETS_ROOT}/config/shell/config.env
```

## 2. Update Shell RC Files

Edit your `~/.bashrc` or `~/.zshrc`:

```bash
# Remove old lines
sed -i.bak '/ENV_PATH=/d' ~/.bashrc
sed -i.bak '/ENV_PATH\/config.env/d' ~/.bashrc

# Add new lines
echo 'export UTILSSETS_ROOT="/path/to/utilssets"' >> ~/.bashrc
echo 'source ${UTILSSETS_ROOT}/config/shell/config.env' >> ~/.bashrc
```

## 3. Path Changes Reference

| Old Path | New Path |
|----------|----------|
| `env/bin/` | `bin/` |
| `env/config/` | `config/shell/` |
| `env/vim/` | `config/vim/` |
| `env/tool/pyenv/` | `tools/pyenv/` |
| `env/tool/fzf/` | `tools/fzf/` |
| `source/pyutils/` | `lib/python/pyutils/` |
| `source/audio/` | `src/python/audio/` |
| `setup/` | `install/` |

## 4. Python Import Changes

**Old:**
```python
from pyutils.ml import torch_model_utils
```

**New:**
```python
from pyutils.ml import torch_model_utils
# (No change needed - PYTHONPATH updated automatically)
```

## 5. Script References

If you have custom scripts referencing old paths, update them:

```bash
# Old
source ${ENV_PATH}/config/func.conf

# New
source ${UTILSSETS_ROOT}/config/shell/func.conf
```

## 6. Reload Environment

After making changes:

```bash
source ~/.bashrc  # or ~/.zshrc
```

## Verification

Check that paths are correctly set:

```bash
echo $UTILSSETS_ROOT
echo $PATH | grep utilssets
which md2pdf  # Should point to utilssets/bin/md2pdf.sh
```
