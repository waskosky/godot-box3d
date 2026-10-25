#!/usr/bin/env python3
"""Export the unchanged physics fixture using an explicit Web template."""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from package_addon import sha256, source_provenance


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--profile", choices=("static", "extension"), required=True)
    parser.add_argument("--target", choices=("debug", "release"), default="release")
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, help="Override the copied fixture's Box3D worker request for a comparison run.")
    args = parser.parse_args()
    if args.workers is not None and args.workers < 1:
        parser.error("--workers must be positive")
    root = Path(__file__).resolve().parents[1]
    template = args.template.resolve(strict=True)
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error("--output must be an empty or new export directory; existing artifacts are preserved")
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="box3d-web-smoke-") as temporary:
        project = Path(temporary) / "project"
        shutil.copytree(root / "web_smoke_project", project, ignore=shutil.ignore_patterns(".godot", "*.uid", "bin"))
        preset = project / "export_presets.cfg"
        text = preset.read_text()
        for target in ("debug", "release"):
            text = re.sub(rf'^custom_template/{target}=.*$', f'custom_template/{target}="{template.as_posix()}"', text, flags=re.MULTILINE)
        text = text.replace('variant/extensions_support=true', f'variant/extensions_support={str(args.profile == "extension").lower()}')
        text = text.replace('variant/thread_support=false', f'variant/thread_support={str(args.profile == "static").lower()}')
        if args.profile == "static":
            text = text.replace('exclude_filter=""', 'exclude_filter="addons/godot-box3d/*"')
        else:
            library = root / f"bin/web/libgodot-box3d.web.template_{args.target}.wasm32.nothreads.wasm"
            destination = project / "addons/godot-box3d/bin/web" / library.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(library, destination)
        preset.write_text(text)
        settings = project / "project.godot"
        if args.workers is not None:
            settings.write_text(re.sub(r'^box3d/worker_count=.*$', f'box3d/worker_count={args.workers}', settings.read_text(), flags=re.MULTILINE))
        subprocess.run([args.godot, "--headless", "--recovery-mode", "--path", str(project), f"--export-{args.target}", "Web Box3D Smoke", str(output / "index.html")], check=True)
    if not (output / "index.wasm").is_file():
        raise RuntimeError("Export did not produce index.wasm")
    if args.profile == "static" and list(output.glob("*.side.wasm")):
        raise RuntimeError("Static export unexpectedly contains a side module")
    manifest = {
        "source": source_provenance(), "profile": args.profile, "target": args.target,
        "requested_box3d_workers": args.workers if args.workers is not None else 8,
        "template": {"name": template.name, "sha256": sha256(template)},
        "fixture": {name: sha256(root / "web_smoke_project" / name) for name in ("smoke_test.gd", "stress_test.gd")},
        "artifacts": {path.name: sha256(path) for path in output.iterdir() if path.suffix in (".wasm", ".pck")},
    }
    (output / "EXPORT_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Exported {args.profile} {args.target} physics fixture: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
