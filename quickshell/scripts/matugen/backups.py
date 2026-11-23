"""Preserve files and symlinks for the desktop installer and its app hooks."""

from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import tempfile


def backup_root():
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "dynamic-you/install-backups"


def exists(path):
    return path.exists() or path.is_symlink()


def copy(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        destination.symlink_to(source.readlink())
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True)
    else:
        shutil.copy2(source, destination)


def remove(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif exists(path):
        path.unlink()


def replace(path, source=None):
    """Prepare a replacement beside its destination before taking the old one away."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".dynamic-you-", dir=path.parent) as temp:
        temp = Path(temp)
        staged, old = temp / "new", temp / "old"
        if source is not None:
            copy(source, staged)
        if exists(path):
            path.rename(old)
        try:
            if source is not None:
                staged.rename(path)
        except BaseException:
            if exists(old):
                old.rename(path)
            raise


class Backup:
    def __init__(self, directory):
        self.directory = directory
        self.manifest = directory / "manifest.json"
        self.data = json.loads(self.manifest.read_text())

    @classmethod
    def create(cls, kind):
        root = backup_root()
        root.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        directory = Path(tempfile.mkdtemp(prefix=f"{kind}-{stamp}-", dir=root))
        (directory / "manifest.json").write_text(json.dumps({"kind": kind, "status": "pending", "paths": {}, "created_dirs": []}))
        return cls(directory)

    def save(self):
        with tempfile.NamedTemporaryFile("w", dir=self.directory, delete=False) as file:
            temporary = Path(file.name)
            json.dump(self.data, file, indent=2)
            file.write("\n")
        temporary.replace(self.manifest)

    def remember(self, path):
        path = Path(os.path.abspath(path))
        key = str(path)
        if key in self.data["paths"]:
            return
        if exists(path):
            target = Path("original") / path.relative_to(path.anchor)
            copy(path, self.directory / target)
            self.data["paths"][key] = str(target)
        else:
            self.data["paths"][key] = None
        created = self.data.setdefault("created_dirs", [])
        for parent in path.parents:
            if exists(parent):
                break
            if str(parent) not in created:
                created.append(str(parent))
        self.save()

    def status(self, status):
        self.data["status"] = status
        self.save()

    def restore(self):
        # Validate saved originals before touching any installed files.
        for original in filter(None, self.data["paths"].values()):
            if not exists(self.directory / original):
                raise OSError(f"Missing backup file: {self.directory / original}")
        for path, original in reversed(list(self.data["paths"].items())):
            path = Path(path)
            if original is not None:
                replace(path, self.directory / original)
            elif exists(path):
                replace(path)
        for name in sorted(self.data.get("created_dirs", []), key=lambda value: len(Path(value).parts), reverse=True):
            try:
                Path(name).rmdir()
            except OSError:
                # A user may have added files since installation.
                pass
