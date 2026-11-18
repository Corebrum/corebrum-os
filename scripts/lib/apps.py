"""Install and launch reviewed Corebrum Apps catalog releases."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from urllib.parse import urlsplit
from urllib.request import urlopen

CATALOG = "https://skills.corebrum.com/apps/v1/catalog.json"
APP_ID = r"[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*"
VERSION = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
DIGEST = r"[0-9a-f]{64}"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def relative_path(value):
    path = PurePosixPath(value)
    require(path.parts and not path.is_absolute() and ".." not in path.parts,
            f"Invalid app-relative path: {value}")
    return Path(*path.parts)


def https(url):
    parts = urlsplit(url)
    require(parts.scheme == "https" and parts.hostname and not parts.username,
            "Catalog and artifact URLs must use HTTPS")
    return url


def strings(values):
    return isinstance(values, list) and all(isinstance(value, str) and value for value in values)


def validate_catalog(data):
    require(data["schemaVersion"] == 1, "Unsupported Apps catalog schema")
    require(isinstance(data["apps"], list), "Catalog apps must be a list")
    seen = set()
    for app in data["apps"]:
        app_id = app["id"]
        require(re.fullmatch(APP_ID, app_id) and app_id not in seen,
                f"Invalid or duplicate app ID: {app_id}")
        seen.add(app_id)
        https(app["source"])
        for key in ("title", "description", "license"):
            require(isinstance(app[key], str) and app[key].strip(), f"{app_id} needs {key}")
        require(app["interface"] in {"terminal", "graphical"}, f"Invalid interface: {app_id}")
        require(strings(app["tags"]), f"Invalid tags: {app_id}")
        require(isinstance(app["releases"], list) and app["releases"], f"No releases: {app_id}")
        versions = set()
        for release in app["releases"]:
            version = release["version"]
            require(re.fullmatch(VERSION, version) and version not in versions,
                    f"Invalid or duplicate release version: {version}")
            versions.add(version)
            relative_path(release["entry"])
            if "requirementsFile" in release:
                relative_path(release["requirementsFile"])
            require(isinstance(release["targets"], list) and release["targets"],
                    f"No targets: {app_id}@{version}")
            targets = set()
            for target in release["targets"]:
                key = (target["ubuntu"], target["arch"])
                require(key[0] in {"24.04", "26.04"} and
                        key[1] in {"amd64", "arm64"} and key not in targets,
                        f"Invalid or duplicate release target: {key}")
                targets.add(key)
                https(target["url"])
                require(re.fullmatch(DIGEST, target["sha256"]), "Invalid SHA-256")
                require(strings(target["hardware"]) and target["hardware"],
                        f"Missing tested hardware: {app_id}@{version}")
                require(strings(target["requirements"]) and strings(target.get("commands", [])),
                        f"Invalid requirements: {app_id}@{version}")
    return data["apps"]


def open_https(url):
    response = urlopen(https(url), timeout=30)
    try:
        https(response.geturl())
    except ValueError:
        response.close()
        raise
    return response


def catalog():
    override = os.getenv("COREBRUM_APPS_CATALOG")
    if override and Path(override).is_absolute():
        with Path(override).open() as stream:
            return validate_catalog(json.load(stream))
    with open_https(override or CATALOG) as stream:
        return validate_catalog(json.load(stream))


def choose_release(app, requested_version):
    host = platform.freedesktop_os_release()
    arch = {"x86_64": "amd64", "aarch64": "arm64"}.get(platform.machine())
    ubuntu = host.get("VERSION_ID")
    releases = sorted(app["releases"],
                      key=lambda release: tuple(map(int, release["version"].split("."))),
                      reverse=True)
    for release in releases:
        if requested_version and release["version"] != requested_version:
            continue
        for target in release["targets"]:
            if host["ID"] == "ubuntu" and (target["ubuntu"], target["arch"]) == (ubuntu, arch):
                return release, target
    raise ValueError(f"No compatible release for {app['id']} on {host['ID']} {ubuntu} {arch or platform.machine()}")


def extract_archive(archive, destination):
    with tarfile.open(archive, "r:gz") as bundle:
        for member in bundle:
            require(member.isfile() or member.isdir(),
                    f"Unsupported archive member: {member.name}")
            if member.isdir() and member.name in (".", "./"):
                continue
            path = relative_path(member.name)
            require(path.parts[0] not in {".venv", ".corebrum.json"},
                    f"Reserved archive path: {path}")
            bundle.extract(member, destination, filter="data")


def install(app, release, target, directory):
    missing = [command for command in target.get("commands", []) if not shutil.which(command)]
    require(not missing, "Missing host commands: " + ", ".join(missing))
    directory.mkdir(parents=True, exist_ok=True)
    metadata = {"id": app["id"], "version": release["version"], "entry": release["entry"],
                "sha256": target["sha256"], "requirementsFile": release.get("requirementsFile")}
    active = directory / "active"
    current = active / ".corebrum.json"
    if current.is_file() and json.loads(current.read_text(encoding="utf-8")) == metadata:
        entry = active / relative_path(release["entry"])
        if entry.is_file() and os.access(entry, os.X_OK):
            print(f"Already installed {app['id']}@{release['version']}")
            return
    with tempfile.TemporaryDirectory(prefix=".download-", dir=directory) as download:
        archive = Path(download) / "release.tar.gz"
        digest = hashlib.sha256()
        with open_https(target["url"]) as response, archive.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        require(digest.hexdigest() == target["sha256"], "Release SHA-256 mismatch")
        # Keep the final path fixed so venv scripts retain valid shebangs.
        installed = Path(tempfile.mkdtemp(prefix=f"{release['version']}-", dir=directory))
        try:
            extract_archive(archive, installed)
            entry = installed / relative_path(release["entry"])
            require(entry.is_file() and os.access(entry, os.X_OK),
                    f"Missing executable entry point: {release['entry']}")
            if "requirementsFile" in release:
                python = installed / ".venv/bin/python"
                subprocess.run([sys.executable, "-m", "venv", installed / ".venv"], check=True)
                subprocess.run([python, "-m", "pip", "--isolated", "install", "--no-index",
                                "--only-binary=:all:", "--require-hashes", "--find-links",
                                installed / "wheelhouse", "-r",
                                installed / relative_path(release["requirementsFile"])],
                               check=True, cwd=installed)
            (installed / ".corebrum.json").write_text(json.dumps(metadata), encoding="utf-8")
            pending = Path(download) / "active"
            pending.symlink_to(installed.name)
            pending.replace(active)
        finally:
            if not active.is_symlink() or active.readlink() != Path(installed.name):
                shutil.rmtree(installed)
    print(f"Installed {app['id']}@{release['version']}")


def main():
    parser = argparse.ArgumentParser(prog="corebrum apps")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("search").add_argument("query", nargs="?", default="")
    commands.add_parser("list")
    for name in ("info", "install", "run", "remove"):
        command = commands.add_parser(name)
        command.add_argument("app")
        if name == "run":
            command.add_argument("args", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command == "search":
        for app in catalog():
            fields = [app["id"], app["title"], app["description"], *app["tags"]]
            for release in app["releases"]:
                for target in release["targets"]:
                    fields.extend([target["arch"], *target["hardware"]])
            if args.query.casefold() in " ".join(fields).casefold():
                print(f"{app['id']}\t{app['title']}\t{app['description']}")
        return

    app_id, separator, version = getattr(args, "app", "").partition("@")
    if args.command != "list":
        require(re.fullmatch(APP_ID, app_id), "Expected an owner/app ID")
    if separator:
        require(args.command == "install" and re.fullmatch(VERSION, version),
                "A version is allowed only for install and must use MAJOR.MINOR.PATCH")
    if args.command in {"info", "install"}:
        app = next((item for item in catalog() if item["id"] == app_id), None)
        require(app is not None, f"App not found: {app_id}")
        if args.command == "info":
            print(json.dumps(app, indent=2))
            return
        release, target = choose_release(app, version)

    require(os.geteuid() != 0, "Run app commands as your regular user")
    data_home = Path(os.getenv("XDG_DATA_HOME") or Path.home() / ".local/share")
    root = (data_home / "corebrum/apps").resolve()
    root.mkdir(parents=True, exist_ok=True)
    directory = root / app_id
    with (root / ".lock").open("ab") as lock:
        write = args.command in {"install", "remove"}
        fcntl.flock(lock, fcntl.LOCK_EX if write else fcntl.LOCK_SH)
        if args.command == "install":
            install(app, release, target, directory)
        elif args.command == "list":
            for manifest in sorted(root.glob("*/*/active/.corebrum.json")):
                metadata = json.loads(manifest.read_text(encoding="utf-8"))
                print(f"{metadata['id']}\t{metadata['version']}")
        else:
            active = directory / "active"
            require(active.is_dir(), f"App is not installed: {app_id}")
            if args.command == "remove":
                shutil.rmtree(directory)
                print(f"Removed {app_id}")
                return
            installed = active.resolve(strict=True)
            metadata = json.loads((installed / ".corebrum.json").read_text(encoding="utf-8"))
            entry = installed / relative_path(metadata["entry"])
            venv = installed / ".venv"
            if venv.is_dir():
                os.environ["VIRTUAL_ENV"] = str(venv)
                os.environ["PATH"] = str(venv / "bin") + os.pathsep + os.environ["PATH"]
            os.chdir(installed)
            # Keep the app available until the launched process exits.
            os.set_inheritable(lock.fileno(), True)
            launch_args = args.args[1:] if args.args[:1] == ["--"] else args.args
            os.execv(entry, [str(entry), *launch_args])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, tarfile.TarError,
            subprocess.CalledProcessError) as error:
        sys.exit(f"corebrum apps: {error}")
