#!/usr/bin/env python

import os
import sys

# python -c "import torch; print(torch.__version__)"
# python -c "import torch; print(torch.version.cuda)"

env_path = os.environ.get("ENV_PATH")
print("ENV_PATH repr:", repr(env_path))

env_path = os.path.expanduser(env_path.strip())
print("ENV_PATH normalized:", env_path)
print("ENV_PATH exists:", os.path.exists(env_path))

for base_path in env_path.split(os.pathsep):
    ml_path = os.path.join(env_path, "..", "source", "ml")
    ml_path = os.path.abspath(os.path.normpath(ml_path))

    print("ml_path:", ml_path)
    print("exists:", os.path.exists(ml_path))
    print("isdir:", os.path.isdir(ml_path))

    if os.path.exists(ml_path):
        print("listdir:", os.listdir(ml_path)[:5])

    if os.path.isdir(ml_path):
        if ml_path not in sys.path:
            print("add path", ml_path)
            sys.path.insert(0, ml_path)
