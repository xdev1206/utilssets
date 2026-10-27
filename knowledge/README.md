# Workspace Knowledge Base

This directory stores reusable cross-project knowledge and project-specific knowledge indexed by project. It is part of the repository for versioning and Codex access, but its content should not describe `utilssets` implementation details.

## Start Here

- [Knowledge documentation index](docs/README.md)
- [Knowledge note template](templates/note.md)

## Structure

```text
knowledge/
├── AGENTS.md
├── README.md
├── docs/
│   ├── README.md
│   ├── projects/
│   │   ├── gemma-pytorch/
│   │   │   └── README.md
│   │   ├── litert/
│   │   │   ├── README.md
│   │   │   ├── litert-feishu-knowledge-publishing.md
│   │   │   └── architecture/
│   │   └── mtk-llm/
│   │       ├── README.md
│   │       ├── gemma4/
│   │       ├── mediatek-npu/
│   │       └── runtime/
│   ├── howto/
│   └── references/
└── templates/
    └── note.md
```

Project-specific material belongs under its project index. Cross-project
procedures and references stay in the shared categories; create a category
directory only when it has content.
