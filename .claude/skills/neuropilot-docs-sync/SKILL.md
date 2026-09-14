---
name: neuropilot-docs-sync
description: 从 NeuroPilot 文档站拉取最新 HTML 文档并更新到本地 docs/neuropilot/${version} 目录
arguments:
  - name: version
    description: 文档版本标识，对应 URL 中的路径段（如 neuropilot-8-premium-gai-full）
    required: false
    default: neuropilot-8-premium-gai-full
allowed-tools: Bash Read Write
---

你是 NeuroPilot 文档同步助手。目标：从 `https://neuropilot.mediatek.com/sphinx/${version}/html/` 抓取最新文档，保存到本地 `docs/neuropilot/${version}/` 目录。

**version 参数**：若用户未指定，默认使用 `neuropilot-8-premium-gai-full`。

---

## 第一步：确认参数

输出一行确认信息：
```
同步目标：https://neuropilot.mediatek.com/sphinx/${version}/html/
本地目录：docs/neuropilot/${version}/
```

---

## 第二步：获取认证 Cookie

该网站需要 SSO 登录。请指导用户获取 Cookie：

1. 在浏览器中访问 `https://neuropilot.mediatek.com/sphinx/${version}/html/`，完成登录
2. 打开浏览器开发者工具（F12）→ Network 标签页
3. 刷新页面，点击任意文档请求
4. 在 Headers 中找到 `Cookie:` 请求头，复制完整 Cookie 字符串
5. 将 Cookie 字符串粘贴到此对话中

等待用户提供 Cookie 后继续。

---

## 第三步：验证 Cookie 有效性

用用户提供的 Cookie 测试连通性：

```bash
curl -s -o /dev/null -w "%{http_code}" \
  --max-time 10 \
  -H "Cookie: ${USER_COOKIE}" \
  "https://neuropilot.mediatek.com/sphinx/${version}/html/"
```

- 返回 `200`：Cookie 有效，继续
- 返回 `302` 或 `401`：Cookie 无效，提示用户重新获取
- 超时或其他错误：检查网络连通性

---

## 第四步：创建本地目录

```bash
mkdir -p docs/neuropilot/${version}
```

---

## 第五步：使用 wget 镜像文档站

```bash
wget \
  --mirror \
  --convert-links \
  --adjust-extension \
  --no-parent \
  --no-host-directories \
  --cut-dirs=2 \
  --timeout=30 \
  --tries=3 \
  --wait=1 \
  --random-wait \
  --header "Cookie: ${USER_COOKIE}" \
  --header "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  --reject "*.zip,*.tar.gz,*.whl,*.egg" \
  --directory-prefix=docs/neuropilot/${version} \
  "https://neuropilot.mediatek.com/sphinx/${version}/html/"
```

若 `wget` 不可用，改用以下 Python 脚本：

```bash
python3 - <<'PYEOF'
import os, re, time, urllib.request, urllib.parse
from html.parser import HTMLParser

COOKIE = os.environ.get("NEUROPILOT_COOKIE", "")
BASE_URL = f"https://neuropilot.mediatek.com/sphinx/${version}/html/"
OUT_DIR = f"docs/neuropilot/${version}"
VISITED = set()

class LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])

def fetch(url):
    req = urllib.request.Request(url, headers={
        "Cookie": COOKIE,
        "User-Agent": "Mozilla/5.0"
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read(), resp.headers.get("Content-Type", "")
    except Exception as e:
        print(f"  ERROR {url}: {e}")
        return None, ""

def url_to_path(url):
    path = urllib.parse.urlparse(url).path
    # 去掉 /sphinx/${version}/html/ 前缀
    prefix = f"/sphinx/${version}/html/"
    if path.startswith(prefix):
        path = path[len(prefix):]
    return os.path.join(OUT_DIR, path or "index.html")

def crawl(url):
    if url in VISITED or not url.startswith(BASE_URL):
        return
    VISITED.add(url)
    print(f"Fetching: {url}")
    content, ctype = fetch(url)
    if content is None:
        return
    local_path = url_to_path(url)
    if local_path.endswith("/") or not os.path.basename(local_path):
        local_path = os.path.join(local_path, "index.html")
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    with open(local_path, "wb") as f:
        f.write(content)
    if "html" in ctype:
        parser = LinkParser()
        parser.feed(content.decode("utf-8", errors="ignore"))
        for href in parser.links:
            abs_url = urllib.parse.urljoin(url, href).split("#")[0]
            if abs_url.startswith(BASE_URL):
                crawl(abs_url)
    time.sleep(0.5)

os.makedirs(OUT_DIR, exist_ok=True)
crawl(BASE_URL)
print(f"\n完成！共下载 {len(VISITED)} 个页面到 {OUT_DIR}/")
PYEOF
```

执行时将 Cookie 传入环境变量：
```bash
NEUROPILOT_COOKIE="${USER_COOKIE}" python3 上述脚本
```

---

## 第六步：验证结果

```bash
# 统计下载文件数
find docs/neuropilot/${version} -name "*.html" | wc -l

# 显示目录结构（前20条）
find docs/neuropilot/${version} -name "*.html" | head -20
```

输出摘要：
- 下载的 HTML 页面总数
- 本地目录路径
- 是否存在 `index.html` 入口文件

---

## 错误处理

| 情况 | 处理方式 |
|------|---------|
| Cookie 过期（中途 302 重定向） | 提示用户重新获取 Cookie 后继续 |
| 部分页面 404 | 正常跳过，最终报告跳过数量 |
| 网络超时 | wget 会自动 retry 3 次；Python 脚本跳过并继续 |
| 磁盘空间不足 | 报错并停止，提示检查剩余空间 |
