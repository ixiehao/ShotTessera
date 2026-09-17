"""Deterministic Finder layout; executed by dmgbuild, never by Finder."""
import os

application = defines["app"]
format = "UDZO"
filesystem = "HFS+"
compression_level = 9
files = [application]
symlinks = {"应用程序": "/Applications"}
icon = os.path.join(application, "Contents", "Resources", "AppIcon.icns")
background = defines["background"]
window_rect = ((160, 120), (960, 600))
default_view = "icon-view"
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_pathbar = False
show_tab_view = False
arrange_by = None
icon_size = 128
text_size = 13
label_pos = "bottom"
icon_locations = {
    os.path.basename(application): (260, 298),
    "应用程序": (700, 298),
}
