#!/usr/bin/env python3
import argparse
import os
import pwd
import re
import secrets
import shutil
import string
import subprocess
import sys
from pathlib import Path


DEFAULT_SHELL = "/bin/bash"
NOLOGIN_SHELLS = ["/usr/sbin/nologin", "/sbin/nologin", "/bin/false"]
PASSWORD_LENGTH = 16
USERNAME_PATTERN = re.compile(r"^[a-z_][a-z0-9._-]{0,31}$")


def info(message: str) -> None:
    print(f"[INFO] {message}")


def warn(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


def error(message: str, exit_code: int = 1) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    sys.exit(exit_code)


def require_root() -> None:
    if os.geteuid() != 0:
        error("Run as root or with sudo.")


def validate_username(username: str) -> None:
    if not USERNAME_PATTERN.fullmatch(username):
        error("Invalid username.")


def validate_workspace(workspace: str) -> None:
    if not workspace:
        error("Invalid workspace path.")
    if not os.path.isabs(workspace):
        error("Workspace path must be an absolute path.")


def user_exists(username: str) -> bool:
    try:
        pwd.getpwnam(username)
        return True
    except KeyError:
        return False


def run_command(cmd, input_text: str = None) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            cmd,
            input=input_text,
            text=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip() if exc.stderr else "command failed"
        error(stderr)


def run_command_allow_fail(cmd) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def detect_admin_group() -> str:
    for group in ("sudo", "wheel"):
        result = subprocess.run(
            ["getent", "group", group],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return group
    error("sudo/wheel group not found.")
    return ""


def detect_nologin_shell() -> str:
    for shell in NOLOGIN_SHELLS:
        if os.path.exists(shell) and os.access(shell, os.X_OK):
            return shell
    error("No nologin shell found.")
    return ""


def generate_password(length: int = PASSWORD_LENGTH) -> str:
    alphabet = string.ascii_letters + string.digits + "@#%+="
    return "".join(secrets.choice(alphabet) for _ in range(length))



def setup_shell_files(username: str) -> None:
    """确保用户目录下有 .bashrc 和 .profile"""
    home_dir = Path(f"/home/{username}")
    
    shell_files = {
        ".bashrc": home_dir / ".bashrc",
        ".profile": home_dir / ".profile",
    }
    
    skel_dir = Path("/etc/skel")
    
    for filename, filepath in shell_files.items():
        if filepath.exists():
            continue
            
        skel_file = skel_dir / filename
        if skel_file.exists():
            # 从 /etc/skel 复制
            shutil.copy2(skel_file, filepath)
            info(f"Copied {filename} from /etc/skel")
        else:
            # 创建最小化版本
            if filename == ".bashrc":
                content = r"""# ~/.bashrc: executed by bash for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# set a fancy prompt
PS1='\u@\h:\w\$ '

# enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# some useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
"""
            else:  # .profile
                content = """# ~/.profile: executed by the command interpreter for login shells.

# if running bash, source .bashrc
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi
"""
            filepath.write_text(content)
            info(f"Created minimal {filename}")
        
        # 设置正确的所有者
        run_command_allow_fail(["chown", f"{username}:{username}", str(filepath)])


def create_user(username: str) -> None:
    if user_exists(username):
        error("User already exists.")
    run_command(["useradd", "-m", "-s", DEFAULT_SHELL, username])
    info(f"User created: {username}")


def set_user_password(username: str, password: str) -> None:
    run_command(["chpasswd"], input_text=f"{username}:{password}\n")


def setup_workspace(username: str, workspace: str = None) -> None:
    if not workspace:
        return

    validate_workspace(workspace)
    base_path = Path(workspace)
    user_path = base_path / username

    base_path.mkdir(parents=True, exist_ok=True)
    user_path.mkdir(parents=True, exist_ok=True)

    chown_result = run_command_allow_fail(["chown", f"{username}:{username}", str(user_path)])
    if chown_result.returncode != 0:
        warn(f"chown failed for {user_path}: {chown_result.stderr.strip()}")

    chmod_result = run_command_allow_fail(["chmod", "755", str(user_path)])
    if chmod_result.returncode != 0:
        warn(f"chmod failed for {user_path}: {chmod_result.stderr.strip()}")

    info(f"Workspace ready: {user_path}")


def grant_sudo(username: str) -> None:
    admin_group = detect_admin_group()
    run_command(["usermod", "-aG", admin_group, username])
    info(f"Added to group: {admin_group}")


def lock_user(username: str) -> None:
    nologin_shell = detect_nologin_shell()
    run_command(["usermod", "-L", username])
    run_command(["usermod", "-s", nologin_shell, username])
    info(f"User locked: {username}")


def unlock_user(username: str) -> None:
    run_command(["usermod", "-U", username])
    run_command(["usermod", "-s", DEFAULT_SHELL, username])
    info(f"User unlocked: {username}")


def kill_user_processes(username: str) -> None:
    subprocess.run(
        ["pkill", "-u", username],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def delete_user_account(username: str) -> None:
    result = subprocess.run(
        ["userdel", "-r", username],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        run_command(["userdel", username])


def delete_workspace(username: str, workspace: str = None) -> None:
    if not workspace:
        return

    validate_workspace(workspace)
    user_path = Path(workspace) / username

    if user_path.exists():
        shutil.rmtree(user_path)
        info(f"Workspace deleted: {user_path}")


def add_user(username: str, workspace: str = None, password: str = None) -> None:
    create_user(username)
    setup_shell_files(username)
    update_user_bashrc(username)

    if not password:
        password = generate_password()
    set_user_password(username, password)
    setup_workspace(username, workspace)
    grant_sudo(username)

    print("Done\n")
    print(f"Username: {username}")
    print(f"Password: {password}")


def disable_user(username: str) -> None:
    if not user_exists(username):
        error("User not found.")
    lock_user(username)
    print(f"Disabled: {username}")


def enable_user(username: str) -> None:
    if not user_exists(username):
        error("User not found.")
    unlock_user(username)
    print(f"Enabled: {username}")


def delete_user(username: str, workspace: str = None) -> None:
    if not user_exists(username):
        error("User not found.")
    kill_user_processes(username)
    delete_user_account(username)
    delete_workspace(username, workspace)
    print(f"Deleted: {username}")


def reset_password(username: str) -> None:
    if not user_exists(username):
        error("User not found.")

    password = generate_password()
    set_user_password(username, password)

    print("Password reset\n")
    print(f"Username: {username}")
    print(f"Password: {password}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="User management tool for shared Linux servers."
    )

    subparsers = parser.add_subparsers(dest="action", required=True)

    add_parser = subparsers.add_parser("add", help="Create user")
    add_parser.add_argument("username", help="Username")
    add_parser.add_argument(
        "--workspace",
        dest="workspace",
        help="Absolute workspace path, e.g. /workspace",
    )
    add_parser.add_argument(
        "--password",
        dest="password",
        help="Specify password (auto-generated if omitted)",
    )
    disable_parser = subparsers.add_parser("disable", help="Disable user")
    disable_parser.add_argument("username", help="Username")

    enable_parser = subparsers.add_parser("enable", help="Enable user")
    enable_parser.add_argument("username", help="Username")

    delete_parser = subparsers.add_parser("delete", help="Delete user")
    delete_parser.add_argument("username", help="Username")
    delete_parser.add_argument(
        "--workspace",
        dest="workspace",
        help="Absolute workspace path, e.g. /workspace",
    )

    reset_password_parser = subparsers.add_parser(
        "reset-password", help="Reset user password"
    )
    reset_password_parser.add_argument("username", help="Username")

    return parser


def main() -> None:
    parser = build_parser()

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args = parser.parse_args()

    require_root()
    validate_username(args.username)

    if hasattr(args, "workspace") and args.workspace:
        validate_workspace(args.workspace)

    if args.action == "add":
        add_user(args.username, getattr(args, "workspace", None), getattr(args, "password", None))
    elif args.action == "disable":
        disable_user(args.username)
    elif args.action == "enable":
        enable_user(args.username)
    elif args.action == "delete":
        delete_user(args.username, getattr(args, "workspace", None))
    elif args.action == "reset-password":
        reset_password(args.username)
    else:
        error("Unknown action.")


if __name__ == "__main__":
    main()
