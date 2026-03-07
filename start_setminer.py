from __future__ import annotations

import argparse
import mimetypes
import os
import shutil
import subprocess
import sys
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse


ROOT = Path(__file__).resolve().parent
BACKEND_DIR = ROOT / "backend"
FRONTEND_DIR = ROOT / "frontend"
FRONTEND_DIST_DIR = FRONTEND_DIR / "dist"
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

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api.routes import router
from app.core.config import settings


def _resolve_npm() -> str:
    candidates = ["npm.cmd", "npm"] if os.name == "nt" else ["npm"]
    for candidate in candidates:
        if shutil.which(candidate):
            return candidate
    raise FileNotFoundError("未找到 npm，请先安装 Node.js 并确认 npm 已加入 PATH。")


def _build_backend_command(host: str, port: int) -> list[str]:
    return [
        sys.executable,
        "-m",
        "uvicorn",
        "app.main:app",
        "--host",
        host,
        "--port",
        str(port),
        "--reload",
    ]


def _build_frontend_command(npm_executable: str, host: str, port: int) -> list[str]:
    return [npm_executable, "run", "dev", "--", "--host", host, "--port", str(port)]


def _validate_common_environment() -> list[str]:
    problems: list[str] = []
    if not BACKEND_DIR.exists():
        problems.append("缺少 backend 目录。")
    if not FRONTEND_DIR.exists():
        problems.append("缺少 frontend 目录。")
    if not (BACKEND_DIR / "requirements.txt").exists():
        problems.append("缺少 backend/requirements.txt。")
    if shutil.which(sys.executable) is None:
        problems.append("当前 Python 不可用。")
    return problems


def _validate_serve_environment() -> list[str]:
    problems = _validate_common_environment()
    if not FRONTEND_DIST_DIR.exists():
        problems.append("缺少 frontend/dist，无法托管前端静态文件，请先在 frontend 目录执行 npm run build。")
    if not (FRONTEND_DIST_DIR / "index.html").exists():
        problems.append("缺少 frontend/dist/index.html，无法托管前端首页。")
    return problems


def _validate_dev_environment() -> list[str]:
    problems = _validate_common_environment()
    if not (FRONTEND_DIR / "package.json").exists():
        problems.append("缺少 frontend/package.json。")
    try:
        _resolve_npm()
    except FileNotFoundError as exc:
        problems.append(str(exc))
    return problems


def _spawn(command: list[str], cwd: Path, new_console: bool) -> subprocess.Popen[str]:
    kwargs: dict[str, object] = {
        "cwd": str(cwd),
    }
    if os.name == "nt" and new_console:
        kwargs["creationflags"] = subprocess.CREATE_NEW_CONSOLE
    return subprocess.Popen(command, **kwargs)


def create_app() -> FastAPI:
    web_app = FastAPI(title=f"{settings.app_name} Web")
    web_app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    web_app.include_router(router, prefix=settings.api_prefix)

    @web_app.get("/healthz", include_in_schema=False)
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @web_app.get("/", include_in_schema=False)
    async def root_index():
        return _serve_frontend_path("")

    @web_app.get("/{full_path:path}", include_in_schema=False)
    async def frontend_files(full_path: str):
        if full_path.startswith("api"):
            raise HTTPException(status_code=404, detail="API route not found")
        return _serve_frontend_path(full_path)

    return web_app


def _serve_frontend_path(full_path: str):
    if not FRONTEND_DIST_DIR.exists():
        return JSONResponse(
            status_code=503,
            content={
                "detail": "frontend/dist 不存在，请先在 frontend 目录执行 npm run build，或改用 --mode dev 启动开发模式。"
            },
        )

    normalized = full_path.strip("/")
    target = (FRONTEND_DIST_DIR / normalized).resolve() if normalized else FRONTEND_DIST_DIR / "index.html"
    dist_root = FRONTEND_DIST_DIR.resolve()

    if dist_root not in target.parents and target != dist_root:
        raise HTTPException(status_code=404, detail="File not found")

    if normalized and target.is_file():
        media_type = STATIC_MEDIA_TYPES.get(target.suffix.lower())
        if media_type is None:
            media_type, _ = mimetypes.guess_type(str(target))
        return FileResponse(target, media_type=media_type)

    index_file = FRONTEND_DIST_DIR / "index.html"
    if index_file.exists():
        return FileResponse(index_file, media_type="text/html")

    return JSONResponse(status_code=503, content={"detail": "前端构建文件缺失，无法返回首页。"})


def _print_problems(problems: list[str]) -> int:
    if problems:
        print("启动前检查失败：")
        for problem in problems:
            print(f"- {problem}")
        return 1
    return 0


def _run_dev_mode(args: argparse.Namespace) -> int:
    problems = _validate_dev_environment()
    if _print_problems(problems):
        return 1

    npm_executable = _resolve_npm()
    backend_command = _build_backend_command(args.host, args.backend_port)
    frontend_command = _build_frontend_command(npm_executable, args.host, args.frontend_port)

    print("开发模式环境检查通过。")
    print(f"后端地址: http://{args.host}:{args.backend_port}")
    print(f"前端地址: http://{args.host}:{args.frontend_port}")

    if args.check_only:
        print("已完成检查，未启动服务。")
        return 0

    print("正在启动后端开发服务...")
    backend_process = _spawn(backend_command, BACKEND_DIR, new_console=not args.same_window)
    print(f"后端进程已启动，PID={backend_process.pid}")

    print("正在启动前端开发服务...")
    frontend_process = _spawn(frontend_command, FRONTEND_DIR, new_console=not args.same_window)
    print(f"前端进程已启动，PID={frontend_process.pid}")

    print("启动完成。关闭对应终端窗口即可停止服务。")
    return 0


def _run_serve_mode(args: argparse.Namespace) -> int:
    problems = _validate_serve_environment()
    if _print_problems(problems):
        return 1

    print("托管模式环境检查通过。")
    print(f"统一访问地址: http://{args.host}:{args.port}")
    print(f"API 路径前缀: {settings.api_prefix}")
    print(f"前端静态目录: {FRONTEND_DIST_DIR}")

    if args.check_only:
        print("已完成检查，未启动服务。")
        return 0

    uvicorn.run("start_setminer:app", host=args.host, port=args.port, reload=args.reload)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="启动 SetMiner。支持开发模式和静态托管模式。")
    parser.add_argument("--mode", choices=["serve", "dev"], default="serve", help="serve=单端口托管前后端，dev=前后端分别启动开发服务")
    parser.add_argument("--host", default="127.0.0.1", help="监听地址")
    parser.add_argument("--port", type=int, default=5000, help="serve 模式端口，支持 python -m start_setminer --port 5000")
    parser.add_argument("--backend-port", type=int, default=8000, help="dev 模式后端端口")
    parser.add_argument("--frontend-port", type=int, default=5173, help="dev 模式前端端口")
    parser.add_argument("--reload", action="store_true", help="serve 模式启用 uvicorn reload")
    parser.add_argument("--check-only", action="store_true", help="仅检查环境，不实际启动服务。")
    parser.add_argument(
        "--same-window",
        action="store_true",
        help="dev 模式下不新开终端窗口，直接在当前会话中启动子进程。",
    )
    args = parser.parse_args()

    if args.mode == "dev":
        return _run_dev_mode(args)
    return _run_serve_mode(args)


app = create_app()


if __name__ == "__main__":
    raise SystemExit(main())
