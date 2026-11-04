#!/usr/bin/env python3
"""Exercise the single editable-game workflow against disposable binary fixtures.

The low-level capture builder is used ONLY to construct test input. These files
are not native Studio exports, and these checks establish no engine/play result.
Every command runs in a temporary project; real assets and builds stay untouched.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "tools"))
import build

CANONICAL_NAME = "Drone Blower revolution - editable workspace.rbxl"
LEGACY_NAME = "Drone Blower revolution.rbxl"
PACKAGE_NAME = "drone-blower-revolution-review.zip"


def inventory(data: bytes) -> dict[str, dict]:
    return {item["path"]: item for item in build.script_inventory(list(build.chunks(data)))}


def source_free_chunks(data: bytes) -> list[bytes]:
    result = [data[:32]]
    for kind, decoded, raw in build.chunks(data):
        if kind != b"PROP" or build.string(decoded, 4)[0] != "Source":
            result.append(raw)
    return result


def replace_source(data: bytes, path: str, source: bytes) -> bytes:
    rows = build.script_inventory(list(build.chunks(data)))
    matches = [row for row in rows if row["path"] == path]
    assert len(matches) == 1, "Fixture must target a uniquely identified Source"
    item = matches[0]
    count = sum(row["cid"] == item["cid"] for row in rows)
    result = [data[:32]]
    changed = False
    for kind, decoded, raw in build.chunks(data):
        if kind == b"PROP" and build.u32(decoded) == item["cid"]:
            prop, offset = build.string(decoded, 4)
            if prop == "Source":
                values = build.string_values(decoded, offset + 1, count)
                values[item["index"]] = source
                result.append(build.chunk(kind, decoded[:offset + 1] + b"".join(
                    struct.pack("<I", len(value)) + value for value in values
                )))
                changed = True
                continue
        result.append(raw)
    assert changed, "Fixture did not replace a real Source property"
    return b"".join(result)


def native_name_fixture(data: bytes, marker: str) -> bytes:
    """Change an actual Part Name property without changing script identities.

    A leaf part name is enough to prove native non-Source bytes survive refresh;
    inventing an extra opaque chunk would not exercise an actual place property.
    """
    decoded_chunks = list(build.chunks(data))
    classes = {}
    for kind, decoded, _ in decoded_chunks:
        if kind == b"INST":
            class_name, offset = build.string(decoded, 4)
            classes[build.u32(decoded)] = (class_name, build.u32(decoded, offset + 1))
    def scripts(value):
        return sorted((row["ref"], row["path"], row["class"], row["source"])
                      for row in build.script_inventory(list(build.chunks(value))))
    original_scripts = scripts(data)
    for index, (kind, decoded, _) in enumerate(decoded_chunks):
        if kind != b"PROP":
            continue
        class_name, count = classes[build.u32(decoded)]
        prop, offset = build.string(decoded, 4)
        if class_name != "Part" or prop != "Name" or decoded[offset] != 1:
            continue
        values = build.string_values(decoded, offset + 1, count)
        for value_index in range(count):
            replaced = list(values)
            replaced[value_index] = marker.encode()
            replacement = build.chunk(kind, decoded[:offset + 1] + b"".join(
                struct.pack("<I", len(value)) + value for value in replaced
            ))
            candidate = data[:32] + b"".join(
                replacement if n == index else raw
                for n, (_, _, raw) in enumerate(decoded_chunks)
            )
            if scripts(candidate) == original_scripts:
                assert source_free_chunks(candidate) != source_free_chunks(data)
                return candidate
    raise AssertionError("No script-free Part Name was available for native fixture")


class SingleGameWorkflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture_directory = tempfile.TemporaryDirectory(prefix="single-game-fixture-")
        fixture = Path(cls.fixture_directory.name) / "capture-derived-fixture.rbxl"
        # Explicitly outside every project build directory: never a release path.
        build.build_live(build.ACTIVE_BASE, fixture)
        cls.current_fixture = fixture.read_bytes()
        cls.native_fixture = native_name_fixture(cls.current_fixture, "NativeEditedFixturePart")

    @classmethod
    def tearDownClass(cls):
        cls.fixture_directory.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="single-game-project-")
        self.root = Path(self.temporary.name) / "project"
        self.root.mkdir()
        for directory in ("src", "tools"):
            shutil.copytree(PROJECT / directory, self.root / directory, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        (self.root / "assets").mkdir()
        shutil.copy2(build.ACTIVE_BASE, self.root / "assets" / build.ACTIVE_BASE.name)
        (self.root / ".gitignore").write_text("build/\n__pycache__/\n*.pyc\n")
        (self.root / "build").mkdir()
        self.canonical = self.root / "build" / CANONICAL_NAME
        self.legacy = self.root / "build" / LEGACY_NAME
        self.package = self.root / "build" / PACKAGE_NAME
        self.asset = self.root / "assets" / build.ACTIVE_BASE.name
        self.asset_bytes = self.asset.read_bytes()
        self.command(["git", "init", "--quiet"])
        self.command(["git", "add", "src", "tools", "assets", ".gitignore"])
        self.command(["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "Single-game binary test fixture"])
        self.previous_commit = self.command(["git", "rev-parse", "HEAD"]).stdout.strip()

    def tearDown(self):
        self.assertEqual(self.asset.read_bytes(), self.asset_bytes, "Workflow modified the immutable capture")
        self.temporary.cleanup()

    def command(self, args: list[str], success: bool = True):
        result = subprocess.run(args, cwd=self.root, capture_output=True, text=True)
        message = f"Command: {args}\nstdout: {result.stdout}\nstderr: {result.stderr}"
        if success:
            self.assertEqual(result.returncode, 0, message)
        else:
            self.assertNotEqual(result.returncode, 0, message)
        return result

    def tool(self, name: str, *args: str, success: bool = True):
        return self.command([sys.executable, str(self.root / "tools" / name), *args], success)

    def install_native(self):
        self.canonical.write_bytes(self.native_fixture)

    def stage_source_update(self) -> Path:
        payload = self.root / "previous-installed-payload.json"
        self.tool("build.py", "--source-payload", str(payload))
        server = self.root / "src" / "Server.lua"
        server.write_text(server.read_text() + "\n-- Disposable single-game refresh test.\n")
        return payload

    def assert_native_preserved(self, before: bytes, after: bytes):
        self.assertEqual(source_free_chunks(after), source_free_chunks(before))
        original = {item["ref"]: item for item in build.script_inventory(list(build.chunks(before)))}
        updated = {item["ref"]: item for item in build.script_inventory(list(build.chunks(after)))}
        self.assertEqual(set(original), set(updated))
        for ref, item in original.items():
            self.assertEqual(tuple(updated[ref][key] for key in ("path", "class", "cid", "index")),
                             tuple(item[key] for key in ("path", "class", "cid", "index")))
            if item["path"] not in build.LIVE_SOURCES:
                self.assertEqual(updated[ref]["source"], item["source"], item["path"])

    def test_missing_native_never_falls_back_to_capture(self):
        self.legacy.write_bytes(self.current_fixture)
        for tool, args in (("build.py", ()), ("release.py", ("--allow-dirty",)), ("consolidate_game.py", ())):
            self.tool(tool, *args, success=False)
            self.assertFalse(self.canonical.exists(), "Missing editable game was silently reconstructed")
            self.assertEqual(self.legacy.read_bytes(), self.current_fixture)
        self.assertFalse(self.package.exists())

    def test_default_build_preserves_native_properties_and_creates_no_plain_place(self):
        self.install_native()
        self.tool("build.py")
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)
        self.assertFalse(self.legacy.exists())

    def test_capture_builder_and_alternate_cli_cannot_create_competing_game(self):
        self.install_native()
        self.tool("build.py", "--output", str(self.legacy), success=False)
        self.command([sys.executable, "-c", "import sys;sys.path.insert(0,'tools');from build import build_live,ACTIVE_BASE,LEGACY_OUTPUT;build_live(ACTIVE_BASE,LEGACY_OUTPUT)"], success=False)
        self.assertFalse(self.legacy.exists())
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)

    def test_stale_native_requires_explicit_previous_payload(self):
        self.install_native()
        previous = self.stage_source_update()
        self.tool("refresh_editable.py", success=False)
        self.tool("build.py", success=False)
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)
        self.tool("refresh_editable.py", "--previous-payload", str(previous))
        updated = self.canonical.read_bytes()
        self.assertNotEqual(updated, self.native_fixture)
        self.assert_native_preserved(self.native_fixture, updated)
        self.tool("refresh_editable.py")
        self.assertEqual(self.canonical.read_bytes(), updated)

    def test_previous_commit_refresh_preserves_native_geometry(self):
        self.install_native()
        self.stage_source_update()
        self.tool("refresh_editable.py", "--previous-commit", self.previous_commit)
        updated = self.canonical.read_bytes()
        self.assertNotEqual(updated, self.native_fixture)
        self.assert_native_preserved(self.native_fixture, updated)

    def test_unknown_live_source_is_never_overwritten(self):
        self.install_native()
        previous = self.stage_source_update()
        path = "ServerScriptService.GlobalDroneControl"
        unknown = replace_source(self.native_fixture, path, inventory(self.native_fixture)[path]["source"] + b"\n-- Unknown editor change\n")
        self.canonical.write_bytes(unknown)
        self.tool("refresh_editable.py", "--previous-payload", str(previous), success=False)
        self.tool("release.py", "--allow-dirty", "--previous-payload", str(previous), success=False)
        self.assertEqual(self.canonical.read_bytes(), unknown)
        self.assertFalse(self.package.exists())

    def test_refresh_preserves_native_backups_and_release_refuses_unverified_backups(self):
        self.install_native()
        path = next(path for path in inventory(self.native_fixture) if path not in build.LIVE_SOURCES)
        unknown = replace_source(self.native_fixture, path, b"-- Unreviewed backup modification\n")
        self.canonical.write_bytes(unknown)
        self.tool("refresh_editable.py")
        previous = self.stage_source_update()
        self.tool("refresh_editable.py", "--previous-payload", str(previous))
        updated = self.canonical.read_bytes()
        self.assert_native_preserved(unknown, updated)
        self.tool("build.py")
        self.tool("release.py", "--allow-dirty", success=False)
        self.assertEqual(self.canonical.read_bytes(), updated)
        self.assertFalse(self.package.exists())

    def test_release_contains_exactly_one_native_game_and_no_source_places(self):
        self.install_native()
        self.legacy.write_bytes(self.current_fixture)
        self.tool("release.py", "--allow-dirty")
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)
        with zipfile.ZipFile(self.package) as archive:
            names = archive.namelist()
            places = [name for name in names if Path(name).suffix.lower() in (".rbxl", ".rbxlx")]
            self.assertEqual(places, [CANONICAL_NAME])
            self.assertEqual(archive.read(CANONICAL_NAME), self.native_fixture)
            self.assertIn("source/src/Server.lua", names, "Source exclusion test was vacuous")
            metadata = json.loads(archive.read("revision.json"))
            self.assertEqual(metadata["place"], CANONICAL_NAME)
            self.assertEqual(metadata["place_sha256"], hashlib.sha256(self.native_fixture).hexdigest())

    def test_release_can_refresh_from_exact_previous_payload(self):
        self.install_native()
        previous = self.stage_source_update()
        self.tool("release.py", "--allow-dirty", success=False)
        self.tool("release.py", "--allow-dirty", "--previous-payload", str(previous))
        self.assert_native_preserved(self.native_fixture, self.canonical.read_bytes())
        with zipfile.ZipFile(self.package) as archive:
            self.assertEqual(archive.read(CANONICAL_NAME), self.canonical.read_bytes())

    def test_known_capture_derived_duplicate_is_removed_after_native_validation(self):
        self.install_native()
        self.legacy.write_bytes(self.current_fixture)
        self.tool("consolidate_game.py")
        self.assertFalse(self.legacy.exists())
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)

    def test_stale_verified_multi_game_package_is_removed_with_duplicate(self):
        self.install_native()
        self.legacy.write_bytes(self.current_fixture)
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr(LEGACY_NAME, self.current_fixture)
            archive.writestr(CANONICAL_NAME, self.native_fixture)
        self.tool("consolidate_game.py")
        self.assertFalse(self.legacy.exists())
        self.assertFalse(self.package.exists())
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)

    def test_consolidation_refreshes_native_and_removes_exact_prior_native_package(self):
        self.install_native()
        self.legacy.write_bytes(self.current_fixture)
        previous = self.stage_source_update()
        # This is the exact native file the owner had before its allowlisted
        # Sources are refreshed. Its authored Part property differs from capture.
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr(LEGACY_NAME, self.current_fixture)
            archive.writestr(CANONICAL_NAME, self.native_fixture)
        self.tool("consolidate_game.py", "--previous-payload", str(previous))
        updated = self.canonical.read_bytes()
        self.assertNotEqual(updated, self.native_fixture)
        self.assert_native_preserved(self.native_fixture, updated)
        self.assertFalse(self.legacy.exists())
        self.assertFalse(self.package.exists())
        self.tool("refresh_editable.py")
        self.assertEqual(self.canonical.read_bytes(), updated)

    def test_unknown_archived_geometry_blocks_every_pending_deletion(self):
        self.install_native()
        self.legacy.write_bytes(self.current_fixture)
        distinct = native_name_fixture(self.current_fixture, "UnreviewedArchivedGeometry")
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr(LEGACY_NAME, self.current_fixture)
            archive.writestr("Unreviewed native edit.rbxl", distinct)
        package_bytes = self.package.read_bytes()
        self.tool("consolidate_game.py", success=False)
        self.assertEqual(self.legacy.read_bytes(), self.current_fixture)
        self.assertEqual(self.package.read_bytes(), package_bytes)
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)

    def test_unique_archived_source_blocks_every_pending_deletion(self):
        self.install_native()
        self.legacy.write_bytes(self.current_fixture)
        with zipfile.ZipFile(self.package, "w") as archive:
            archive.writestr(LEGACY_NAME, self.current_fixture)
            archive.writestr("source/src/Server.lua", "-- A newer source exists only in this archive.\n")
        package_bytes = self.package.read_bytes()
        self.tool("consolidate_game.py", success=False)
        self.assertEqual(self.legacy.read_bytes(), self.current_fixture)
        self.assertEqual(self.package.read_bytes(), package_bytes)
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)

    def test_distinct_duplicate_geometry_refuses_deletion(self):
        self.install_native()
        distinct = native_name_fixture(self.current_fixture, "DistinctDuplicateGeometry")
        self.legacy.write_bytes(distinct)
        self.tool("consolidate_game.py", success=False)
        self.assertEqual(self.legacy.read_bytes(), distinct)
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)

    def test_unknown_duplicate_source_refuses_deletion(self):
        self.install_native()
        path = "StarterPlayer.StarterPlayerScripts.ClientDroneControl"
        unknown = replace_source(self.current_fixture, path, inventory(self.current_fixture)[path]["source"] + b"\n-- Unreviewed duplicate Source\n")
        self.legacy.write_bytes(unknown)
        self.tool("consolidate_game.py", success=False)
        self.assertEqual(self.legacy.read_bytes(), unknown)
        self.assertEqual(self.canonical.read_bytes(), self.native_fixture)


if __name__ == "__main__":
    unittest.main(verbosity=2)
