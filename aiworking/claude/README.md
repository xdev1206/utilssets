一个完整的 Claude Code 项目配置结构：
project/
├── CLAUDE.md                    # 📋 项目级指令（团队共享，提交到 Git）
├── CLAUDE.local.md              # 👤 个人项目偏好（自动 gitignore）
├── .claude/
│   ├── settings.json            # ⚙️ 项目设置（团队共享）
│   ├── settings.local.json      # 👤 个人项目设置（gitignore）
│   ├── CLAUDE.md                # 📋 等效于根目录 CLAUDE.md
│   ├── rules/                   # 📏 模块化规则文件
│   │   ├── code-style.md        #    代码风格
│   │   ├── testing.md           #    测试规范
│   │   └── security.md          #    安全要求
│   ├── agents/                  # 🤖 自定义子代理
│   │   ├── code-reviewer.md
│   │   └── debugger.md
│   ├── skills/                  # ⚡ 自定义技能
│   │   └── fix-issue/
│   │       └── SKILL.md
│   └── worktrees/               # 🌳 Git Worktree 目录（加入 .gitignore）
├── .mcp.json                    # 🔌 项目级 MCP 服务器配置
└── .github/
    └── workflows/
        └── claude.yml           # 🔄 Claude Code GitHub Actions
