# 全栈项目统一启动器模式

一个 Python 入口脚本，同时承担 **生产托管** 和 **开发调试** 两种职责，适用于 FastAPI + Vite（React / Vue）前后端项目。

---

## 命令中的 `start_app` 是什么

`python -m start_app` 意思是"把 `start_app` 当作模块运行"，Python 会在当前目录找 `start_app.py` 并执行。所以 **`start_app` 就是你的启动脚本文件名（不含 `.py`）**，按项目自行命名即可：

| 文件名 | 启动命令 |
|--------|----------|
| `start_setminer.py` | `python -m start_setminer --dev --same-window` |
| `start_crm.py` | `python -m start_crm --dev --same-window` |
| `start_app.py` | `python -m start_app --dev --same-window` |

下文统一用 `start_app` 作为占位名。

---

## 命令速查
```powershell
# ── 开发（推荐）──
python -m start_app --dev --same-window              # 单窗口合并日志
python -m start_app --dev                             # Windows 各开新窗口
python -m start_app --dev --same-window --backend-port 9000 --frontend-port 3000

# ── 生产/演示 ──
python -m start_app                                   # 默认 :5000
python -m start_app --port 8080                       # 自定义端口
python -m start_app --reload                          # 开启后端热重载
uvicorn start_app:app --host 0.0.0.0 --port 5000     # 直接用 uvicorn

# ── 环境检查 ──
python -m start_app --check-only                      # 检查 serve 环境
python -m start_app --dev --check-only                # 检查 dev 环境
```


## 核心思路

```
项目根目录/
├── backend/          ← FastAPI 后端
├── frontend/         ← Vite 前端
├── start_app.py      ← 统一入口（本文主角）
├── start_app.bat     ← Windows 双击启动（serve 模式）
└── start_app_dev.bat ← Windows 双击启动（dev 模式）
```

一个 `start_app.py` 同时是：

| 身份 | 用法 | 说明 |
|------|------|------|
| CLI 入口 | `python -m start_app --dev` | 通过 `__main__` 进入 argparse |
| ASGI 应用 | `uvicorn start_app:app` | 模块级 `app = create_app()` |

这样不管是开发还是部署，团队只需记住一个文件名。

---

## 两种运行模式对比

| | serve 模式（默认） | dev 模式 |
|---|---|---|
| 适用场景 | 演示 / 内网部署 / CI 预览 | 日常开发 |
| 进程数量 | 1 个 uvicorn | 2 个（uvicorn + vite） |
| 前端来源 | `frontend/dist` 静态文件 | vite dev server（HMR 热更新） |
| 后端热重载 | 可选 `--reload` | 默认开启 `--reload` |
| 端口 | 单端口（默认 5000） | 双端口（后端 18000 + 前端 5173） |
| 启动命令 | `python -m start_app` | `python -m start_app --dev --same-window` |

---

## 完整演示代码

以下是可直接复用的 `start_app.py`，只需替换 `from app.api.routes import router` 等项目特定导入即可。

```python
"""
start_app.py — 全栈统一启动器

用法:
    python -m start_app                         # serve 模式（单端口托管）
    python -m start_app --dev --same-window     # dev 模式（推荐，单窗口合并输出）
    python -m start_app --dev                   # dev 模式（Windows 各开新窗口）
    uvicorn start_app:app --port 5000           # 直接用 uvicorn 启动
"""

from __future__ import annotations

import argparse
import mimetypes
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

# ──────────────────────────── 路径常量 ────────────────────────────

ROOT = Path(__file__).resolve().parent
BACKEND_DIR = ROOT / "backend"
FRONTEND_DIR = ROOT / "frontend"
FRONTEND_DIST_DIR = FRONTEND_DIR / "dist"

# 把 backend 加入 sys.path，使 from app.xxx import ... 生效
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# ★ 替换为你自己项目的后端路由和配置
from app.api.routes import router
from app.core.config import settings

# ──────────────────────────── 静态文件 MIME ────────────────────────────

STATIC_MEDIA_TYPES = {
    ".css": "text/css",
    ".gif": "image/gif",
    ".html": "text/html",
    ".ico": "image/x-icon",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".js": "application/javascript",
    ".json": "application/json",
    ".map": "application/json",
    ".mjs": "application/javascript",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".txt": "text/plain; charset=utf-8",
    ".webp": "image/webp",
}

# ──────────────────────────── 工具函数 ────────────────────────────


def _resolve_npm() -> str:
    """查找 npm 可执行文件，Windows 下优先找 npm.cmd。"""
    candidates = ["npm.cmd", "npm"] if os.name == "nt" else ["npm"]
    for c in candidates:
        if shutil.which(c):
            return c
    raise FileNotFoundError("未找到 npm，请先安装 Node.js。")


def _build_backend_command(host: str, port: int) -> list[str]:
    """构造后端 uvicorn 启动命令。"""
    return [
        sys.executable, "-m", "uvicorn",
        "app.main:app",          # ★ 替换为你的 ASGI 入口
        "--host", host,
        "--port", str(port),
        "--reload",
    ]


def _build_frontend_command(npm: str, host: str, port: int) -> list[str]:
    """构造前端 vite dev 启动命令。"""
    return [npm, "run", "dev", "--", "--host", host, "--port", str(port)]


# ──────────────────────────── 环境校验 ────────────────────────────


def _validate_common() -> list[str]:
    """基础环境检查，两种模式共用。"""
    problems: list[str] = []
    if not BACKEND_DIR.exists():
        problems.append("缺少 backend 目录。")
    if not FRONTEND_DIR.exists():
        problems.append("缺少 frontend 目录。")
    if not (BACKEND_DIR / "requirements.txt").exists():
        problems.append("缺少 backend/requirements.txt。")
    return problems


def _validate_serve() -> list[str]:
    """serve 模式额外检查：需要已构建的 frontend/dist。"""
    problems = _validate_common()
    if not FRONTEND_DIST_DIR.exists():
        problems.append("缺少 frontend/dist，请先执行 npm run build。")
    elif not (FRONTEND_DIST_DIR / "index.html").exists():
        problems.append("缺少 frontend/dist/index.html。")
    return problems


def _validate_dev() -> list[str]:
    """dev 模式额外检查：需要 npm 和 package.json。"""
    problems = _validate_common()
    if not (FRONTEND_DIR / "package.json").exists():
        problems.append("缺少 frontend/package.json。")
    try:
        _resolve_npm()
    except FileNotFoundError as exc:
        problems.append(str(exc))
    return problems


# ──────────────────────────── 进程管理 ────────────────────────────


def _spawn(
    command: list[str],
    cwd: Path,
    new_console: bool,
    *,
    env: dict[str, str] | None = None,
    capture_output: bool = False,
) -> subprocess.Popen[str]:
    """
    启动子进程的统一入口。

    - new_console=True  → Windows 下打开新终端窗口（CREATE_NEW_CONSOLE）
    - capture_output=True → 捕获 stdout+stderr，供日志线程读取
    """
    kwargs: dict[str, object] = {
        "cwd": str(cwd),
        "env": env or os.environ.copy(),
    }
    if os.name == "nt" and new_console:
        kwargs["creationflags"] = subprocess.CREATE_NEW_CONSOLE
    if capture_output:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.STDOUT
        kwargs["text"] = True
        kwargs["encoding"] = "utf-8"
        kwargs["errors"] = "replace"
        kwargs["bufsize"] = 1          # 行缓冲，日志实时输出
    return subprocess.Popen(command, **kwargs)


def _stream_output(process: subprocess.Popen[str], prefix: str) -> None:
    """在后台线程中逐行读取子进程输出，加 [prefix] 前缀打印。"""
    if process.stdout is None:
        return
    try:
        for raw_line in process.stdout:
            line = raw_line.rstrip()
            if line:
                print(f"[{prefix}] {line}")
    except Exception as exc:
        print(f"[{prefix}] 日志线程异常: {exc}")
    finally:
        try:
            process.stdout.close()
        except Exception:
            pass


def _terminate_process_tree(process: subprocess.Popen[str]) -> None:
    """
    安全终止子进程树。

    Windows: taskkill /T /F 杀整棵进程树（否则 npm 子进程会残留）
    Unix:    先 SIGTERM，超时后 SIGKILL
    """
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()


# ──────────────────────────── dev 模式：单窗口 ────────────────────────────


def _run_dev_same_window(
    backend_cmd: list[str],
    frontend_cmd: list[str],
    frontend_env: dict[str, str],
) -> int:
    """
    --same-window 模式的核心逻辑：
    1. 启动后端、前端两个子进程（capture_output=True）
    2. 各分配一个 daemon 线程读取输出并加 [backend]/[frontend] 前缀
    3. 主线程轮询进程状态，Ctrl+C 时统一清理
    """
    print("正在启动后端...")
    backend = _spawn(backend_cmd, BACKEND_DIR, new_console=False, capture_output=True)
    print(f"后端 PID={backend.pid}")

    print("正在启动前端...")
    frontend = _spawn(
        frontend_cmd, FRONTEND_DIR,
        new_console=False, env=frontend_env, capture_output=True,
    )
    print(f"前端 PID={frontend.pid}")
    print("按 Ctrl+C 可同时停止前后端。")

    bt = threading.Thread(target=_stream_output, args=(backend, "backend"), daemon=True)
    ft = threading.Thread(target=_stream_output, args=(frontend, "frontend"), daemon=True)
    bt.start()
    ft.start()

    exit_code = 0
    try:
        while True:
            bc, fc = backend.poll(), frontend.poll()
            if bc is not None or fc is not None:
                if bc not in (None, 0):
                    exit_code = bc
                if fc not in (None, 0):
                    exit_code = fc or exit_code
                break
            time.sleep(0.3)
    except KeyboardInterrupt:
        print("\n正在停止服务...")
    finally:
        _terminate_process_tree(frontend)
        _terminate_process_tree(backend)
        bt.join(timeout=2)
        ft.join(timeout=2)
        print("服务已停止。")

    return exit_code


# ──────────────────────────── FastAPI 应用（serve 模式） ────────────────────────────


def create_app() -> FastAPI:
    """
    创建 FastAPI 实例，同时挂载：
    - /api/*       → 后端路由
    - /healthz     → 健康检查
    - /*           → frontend/dist 静态文件（SPA fallback 到 index.html）
    """
    web_app = FastAPI(title="MyApp")
    web_app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],         # ★ 按需收紧
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    web_app.include_router(router, prefix="/api")   # ★ 替换为你的前缀

    @web_app.get("/healthz", include_in_schema=False)
    def healthz():
        return {"status": "ok"}

    @web_app.get("/", include_in_schema=False)
    async def root():
        return _serve_frontend("")

    @web_app.get("/{full_path:path}", include_in_schema=False)
    async def spa_fallback(full_path: str):
        if full_path.startswith("api"):
            raise HTTPException(404, "API route not found")
        return _serve_frontend(full_path)

    return web_app


def _serve_frontend(full_path: str):
    """
    serve 模式下的前端静态文件服务：
    - 精确匹配文件 → 直接返回
    - 其余路径 → fallback 到 index.html（SPA 路由）
    """
    if not FRONTEND_DIST_DIR.exists():
        return JSONResponse(503, {"detail": "frontend/dist 不存在，请先 npm run build。"})

    normalized = full_path.strip("/")
    target = (FRONTEND_DIST_DIR / normalized).resolve() if normalized else FRONTEND_DIST_DIR / "index.html"
    dist_root = FRONTEND_DIST_DIR.resolve()

    if dist_root not in target.parents and target != dist_root:
        raise HTTPException(404, "Not found")

    if normalized and target.is_file():
        mt = STATIC_MEDIA_TYPES.get(target.suffix.lower())
        if mt is None:
            mt, _ = mimetypes.guess_type(str(target))
        return FileResponse(target, media_type=mt)

    index = FRONTEND_DIST_DIR / "index.html"
    if index.exists():
        return FileResponse(index, media_type="text/html")

    return JSONResponse(503, {"detail": "index.html 缺失。"})


# ──────────────────────────── CLI 主入口 ────────────────────────────


def _print_problems(problems: list[str]) -> int:
    if problems:
        print("启动前检查失败：")
        for p in problems:
            print(f"  - {p}")
        return 1
    return 0


def _run_dev(args: argparse.Namespace) -> int:
    problems = _validate_dev()
    if _print_problems(problems):
        return 1

    npm = _resolve_npm()
    backend_cmd = _build_backend_command(args.host, args.backend_port)
    frontend_cmd = _build_frontend_command(npm, args.host, args.frontend_port)
    frontend_env = os.environ.copy()
    frontend_env["VITE_API_PROXY_TARGET"] = f"http://{args.host}:{args.backend_port}"

    print(f"后端: http://{args.host}:{args.backend_port}")
    print(f"前端: http://{args.host}:{args.frontend_port}")

    if args.check_only:
        print("环境检查通过，未启动服务。")
        return 0

    if args.same_window:
        return _run_dev_same_window(backend_cmd, frontend_cmd, frontend_env)

    # 非 same-window：Windows 下各开新终端
    _spawn(backend_cmd, BACKEND_DIR, new_console=True)
    _spawn(frontend_cmd, FRONTEND_DIR, new_console=True, env=frontend_env)
    print("前后端已在新窗口中启动，关闭对应窗口即可停止。")
    return 0


def _run_serve(args: argparse.Namespace) -> int:
    problems = _validate_serve()
    if _print_problems(problems):
        return 1

    print(f"统一地址: http://{args.host}:{args.port}")

    if args.check_only:
        print("环境检查通过，未启动服务。")
        return 0

    uvicorn.run("start_app:app", host=args.host, port=args.port, reload=args.reload)
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="全栈统一启动器")
    p.add_argument("--mode", choices=["serve", "dev"], default="serve",
                   help="serve=单端口托管, dev=前后端分离开发")
    p.add_argument("--dev", action="store_true",
                   help="等价于 --mode dev")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=5000,
                   help="serve 模式端口")
    p.add_argument("--backend-port", type=int, default=18000,
                   help="dev 模式后端端口")
    p.add_argument("--frontend-port", type=int, default=5173,
                   help="dev 模式前端端口")
    p.add_argument("--reload", action="store_true",
                   help="serve 模式开启热重载")
    p.add_argument("--check-only", action="store_true",
                   help="仅检查环境，不启动")
    p.add_argument("--same-window", action="store_true",
                   help="dev 模式下在当前终端合并输出")
    args = p.parse_args()

    if args.dev:
        args.mode = "dev"

    return _run_dev(args) if args.mode == "dev" else _run_serve(args)


# 模块级 app，供 uvicorn start_app:app 使用
app = create_app()

if __name__ == "__main__":
    raise SystemExit(main())
```

---

## 设计详解

### 1. 双重身份：CLI + ASGI

文件末尾两段代码让同一个 `.py` 文件同时扮演两个角色：

```python
# 角色 1：ASGI 应用（被 uvicorn 导入时执行）
app = create_app()

# 角色 2：CLI 入口（python -m start_app 时执行）
if __name__ == "__main__":
    raise SystemExit(main())
```

- `python -m start_app` → Python 把模块当脚本执行，`__name__ == "__main__"` 为真，进入 `main()`
- `uvicorn start_app:app` → uvicorn 导入模块拿 `app` 变量，不触发 `main()`

好处：不需要分两个文件，团队只需记住一个入口。

### 2. serve 模式：单端口 SPA 托管

```
浏览器 → :5000/api/*    → FastAPI 路由
       → :5000/assets/* → frontend/dist 静态文件
       → :5000/其他路径  → index.html（SPA fallback）
```

关键实现是 `/{full_path:path}` 通配路由 + SPA fallback 逻辑：

- 请求路径精确匹配到 `dist/` 下某个文件 → 直接返回该文件
- 匹配不到 → 返回 `index.html`，让前端路由接管

这样不需要 nginx，一个 uvicorn 进程就能完成前后端托管。

### 3. dev 模式：双进程管理

dev 模式同时启动两个独立进程：

| 进程 | 命令 | 热重载 |
|------|------|--------|
| 后端 | `uvicorn app.main:app --reload` | 文件变更自动重载 |
| 前端 | `npm run dev`（vite） | HMR 即时热更新 |

#### 3.1 --same-window 模式（推荐）

```
主进程
├── 后端子进程（capture_output=True）
│   └── daemon 线程：逐行读 stdout → print("[backend] ...")
├── 前端子进程（capture_output=True）
│   └── daemon 线程：逐行读 stdout → print("[frontend] ...")
└── 主线程：轮询 poll() + 响应 Ctrl+C → 统一清理
```

核心要点：
- `capture_output=True` 让子进程 stdout/stderr 通过管道回到主进程
- 两个 **daemon 线程** 分别读取并加前缀打印，日志不会交错丢失
- `bufsize=1` 行缓冲，确保日志实时输出
- `Ctrl+C` 触发 `KeyboardInterrupt`，`finally` 块调用 `_terminate_process_tree` 清理

#### 3.2 非 same-window 模式

Windows 下使用 `CREATE_NEW_CONSOLE` 为每个子进程打开独立终端窗口。关闭窗口即停止对应进程。

### 4. 进程树清理（Windows 重点）

```python
def _terminate_process_tree(process):
    if os.name == "nt":
        # taskkill /T 杀整棵进程树
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], ...)
    else:
        process.terminate()
        process.wait(timeout=5)  # 超时则 kill
```

为什么不能只用 `process.terminate()`？因为 `npm run dev` 实际上是 `npm.cmd → node → vite`，直接 terminate 只杀 npm.cmd，node/vite 子进程会残留。`taskkill /T` 能杀掉整棵进程树。

### 5. 环境校验

启动前先检查目录/文件/工具是否齐全，提前报错而非运行中崩溃：

```
serve 模式检查：backend/ + frontend/dist/index.html
dev   模式检查：backend/ + frontend/package.json + npm 可用
```

`--check-only` 可以只做检查不启动，适合 CI 或环境验收。

### 6. 前端 API 代理

dev 模式下前后端端口不同，需要配置代理。启动器通过环境变量传递后端地址：

```python
frontend_env["VITE_API_PROXY_TARGET"] = f"http://{args.host}:{args.backend_port}"
```

前端 `vite.config.ts` 中读取：

```typescript
export default defineConfig({
  server: {
    proxy: {
      "/api": {
        target: process.env.VITE_API_PROXY_TARGET || "http://127.0.0.1:18000",
        changeOrigin: true,
      },
    },
  },
});
```

---

## BAT 文件（Windows 双击启动）

### start_app.bat — serve 模式

```bat
@echo off
cd /d "%~dp0"
python -m start_app %*
if errorlevel 1 pause
```

### start_app_dev.bat — dev 模式

```bat
@echo off
cd /d "%~dp0"
python -m start_app --dev --same-window %*
if errorlevel 1 pause
```

说明：
- `cd /d "%~dp0"` 确保工作目录是 bat 文件所在目录，避免路径问题
- `%*` 透传用户额外参数（如 `start_app_dev.bat --backend-port 9000`）
- `if errorlevel 1 pause` 出错时暂停窗口，便于查看错误信息

---

## 命令速查

```powershell
# ── 开发（推荐）──
python -m start_app --dev --same-window              # 单窗口合并日志
python -m start_app --dev                             # Windows 各开新窗口
python -m start_app --dev --same-window --backend-port 9000 --frontend-port 3000

# ── 生产/演示 ──
python -m start_app                                   # 默认 :5000
python -m start_app --port 8080                       # 自定义端口
python -m start_app --reload                          # 开启后端热重载
uvicorn start_app:app --host 0.0.0.0 --port 5000     # 直接用 uvicorn

# ── 环境检查 ──
python -m start_app --check-only                      # 检查 serve 环境
python -m start_app --dev --check-only                # 检查 dev 环境
```

---

## 复用到新项目的步骤

1. 复制 `start_app.py` 到新项目根目录，重命名为 `start_<项目名>.py`
2. 修改文件顶部的 **项目特定导入**（`router`、`settings` 等）
3. 修改 `_build_backend_command` 中的 ASGI 入口路径（`app.main:app`）
4. 修改 `create_app()` 中的路由前缀和 CORS 配置
5. 修改 `uvicorn.run()` 中的模块引用字符串（`"start_app:app"` → `"start_<项目名>:app"`）
6. 复制并修改两个 `.bat` 文件
7. 确保项目目录结构满足 `backend/` + `frontend/` 的约定

需要调整的代码位置都已用 `★` 标记。

---

## 依赖

启动器本身只依赖后端已有的包，无需额外安装：

- `fastapi`
- `uvicorn`

前端需要：

- `node` + `npm`
- `vite`（通过 `package.json` 管理）
