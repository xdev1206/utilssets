# Codex app-server socket 权限故障

## 症状

Codex daemon 报 `app server did not become ready`，stderr 同时提示 `app-server socket directory must be a user-owned directory with mode 0700`。

## 排查与修复

检查 `/tmp` 的真实目标：

```bash
readlink -f /tmp
```

如果 `/tmp` 指向共享目录，检查对应的用户临时目录（例如 `/workspace/tmp/codex-daemon-1000`）：

```bash
stat -c '%A %a %U:%G %n' /workspace/tmp/codex-daemon-1000
chmod 700 /workspace/tmp/codex-daemon-1000
chown "$(id -un):$(id -gn)" /workspace/tmp/codex-daemon-1000
```

随后重启并验证：

```bash
codex app-server daemon stop
codex app-server daemon start
codex app-server daemon version
test -S "$CODEX_HOME/app-server-control/app-server-control.sock"
```

目录必须由运行 Codex 的用户拥有且权限严格为 `0700`；`.codex/app-server-control` 本身也应满足同样条件。不要把 API key 写入日志或诊断输出。
