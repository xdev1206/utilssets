`aiworking/claude/` 是本仓库里 Claude 公共模板目录。`install/common/setup_claude_cli.sh` 会把这里的共享配置同步到 `~/.claude/`。

公共模板目录结构：

```text
aiworking/claude/
├── README.md                    # 这个目录的说明文档
├── CLAUDE.md                    # 同步到 ~/.claude/CLAUDE.md 的公共指令
├── settings.json.example        # 不含真实密钥的共享设置模板
├── local/
│   ├── .gitkeep                 # 占位文件
│   └── settings.json            # 本机私有 Claude 设置（gitignore）
├── .claude/
│   ├── agents/                  # 同步到 ~/.claude/agents/ 的共享子代理
│   └── skills/                  # 同步到 ~/.claude/skills/ 的共享技能
└── skills/
    └── */SKILL.md               # 仓库内维护的 Claude 技能源码
```

说明：
- `README.md` 只负责解释模板结构和安装方式，不作为 Claude 自动读取的指令文件。
- `CLAUDE.md` 才是 Claude 会消费的公共规则文件。
- 真实 `ANTHROPIC_AUTH_TOKEN` 等敏感配置只放 `local/settings.json`，不要写进共享模板。

基于这套模板生成具体项目时，项目根目录应增加如下文档目录：

```text
project/
└── docs/
    └── README.md                # docs/ 文档索引，列出 docs/ 下各文档及用途
```

`docs/README.md` 是具体项目里 `docs/` 目录的总索引。每当项目新增一个 `docs/*.md` 文档，都要同步更新 `docs/README.md`，说明该文档的主题和用途。

基于该模板的 Claude 项目结构示例：
```text
project/
├── CLAUDE.md                    # 📋 项目级指令（团队共享，提交到 Git）
├── CLAUDE.local.md              # 👤 个人项目偏好（自动 gitignore）
├── docs/
│   └── README.md                # 项目 docs/ 文档索引
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
```
