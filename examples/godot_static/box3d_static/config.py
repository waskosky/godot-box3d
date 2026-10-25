from pathlib import Path


def can_build(env, platform):
	return platform == "web"


def get_opts(platform):
	archive_dir = Path(__file__).resolve().parents[3] / "bin" / "web" / "static"
	return [("box3d_archive_dir", "Directory containing matching Box3D and godot-cpp archives", str(archive_dir))]


def configure(env):
	pass
