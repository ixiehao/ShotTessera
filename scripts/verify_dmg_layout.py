"""Validate persisted Finder metadata on the final, read-only mounted image."""
import os
import sys
from ds_store import DSStore
from mac_alias import Alias

def text(value):
    return value.decode("utf-8") if isinstance(value, bytes) else value

mount, app_name = sys.argv[1:]
mount = os.path.realpath(mount)
with DSStore.open(os.path.join(mount, ".DS_Store"), "r") as store:
    assert store["."]["icvl"] == (b"type", b"icnv"), "Default view is not icon view"
    window = store["."]["bwsp"]
    assert window["WindowBounds"] == "{{160, 120}, {960, 600}}", window
    assert not window["ShowToolbar"] and not window["ShowSidebar"], window
    view = store["."]["icvp"]
    assert view["backgroundType"] == 2, "Background is not an image"
    assert view["iconSize"] == 128 and view["arrangeBy"] == "none", view
    assert store[app_name]["Iloc"] == (260, 298), "App position changed"
    assert store["应用程序"]["Iloc"] == (700, 298), "Applications position changed"
    assert not list(store.find(".", b"pBBk")), "Obsolete background bookmark causes a white Finder background"
    saved_alias = Alias.from_bytes(view["backgroundImageAlias"])
    background = os.path.join(mount, ".background.png")
    actual_alias = Alias.for_file(background)
    # Volume identity and filesystem node identity survive compression and a
    # different mount path. A stale absolute path alone is not sufficient.
    assert saved_alias.volume.creation_date == actual_alias.volume.creation_date
    assert text(saved_alias.volume.name) == text(actual_alias.volume.name)
    assert saved_alias.target.cnid == actual_alias.target.cnid
    assert saved_alias.target.creation_date == actual_alias.target.creation_date
    assert text(saved_alias.target.posix_path) == text(actual_alias.target.posix_path)

assert os.readlink(os.path.join(mount, "应用程序")) == "/Applications"
print("Finder layout verified: icon view, window, image alias identity, icon positions, Applications link")
