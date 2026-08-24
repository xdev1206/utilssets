#!/usr/bin/env bash

set -e

PROJECT_DIR="$HOME/workspace/projects"
PROJECT_NAME=${1:-gitgraph-demo}

echo "Creating project: $PROJECT_DIR/$PROJECT_NAME"

mkdir -p "$PROJECT_DIR/$PROJECT_NAME"
cd "$PROJECT_DIR/$PROJECT_NAME"

# 初始化项目
npm init -y

# 安装 GitGraph.js
npm install @gitgraph/js

# 创建示例页面
cat > index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>GitGraph Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
        }

        #gitgraph {
            border: 1px solid #ddd;
            padding: 20px;
        }
    </style>
</head>
<body>

<h2>GitGraph.js Demo</h2>
<div id="gitgraph"></div>

<script type="module">
import { createGitgraph } from "https://cdn.jsdelivr.net/npm/@gitgraph/js/+esm";

const graphContainer = document.getElementById("gitgraph");
const gitgraph = createGitgraph(graphContainer);

const master = gitgraph.branch("master");

master
  .commit("Initial commit")
  .commit("Add README");

const feature = gitgraph.branch("feature");

feature
  .commit("Implement feature")
  .commit("Fix bug");

master.commit("Hotfix");
master.merge(feature, "Merge feature");
</script>

</body>
</html>
EOF

echo
echo "Installation completed."
echo
echo "Open:"
echo "  $PROJECT_NAME/index.html"
