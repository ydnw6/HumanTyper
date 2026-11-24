# dmgbuild settings for HumanTyper.dmg — used by build-app.sh:
#   dmgbuild -s dmg/dmg-settings.py -D app=out/HumanTyper.app HumanTyper out/HumanTyper.dmg
# Window layout matches dmg/background.png (660 × 420, icon centres at (170, 200) and (490, 200)).
import os.path

app = defines["app"]  # noqa: F821 — injected by dmgbuild
# Paths are relative to mac/ (build-app.sh runs from there; dmgbuild gives settings files no __file__).

format = "UDZO"
compression_level = 9
filesystem = "HFS+"

files = [app]
symlinks = {"Applications": "/Applications"}
icon = "AppIcon.icns"         # volume icon
background = "dmg/background.png"

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
window_rect = ((200, 200), (660, 448))   # 420 of content + the 28 pt title bar
default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True
arrange_by = None
icon_size = 112
text_size = 13
label_pos = "bottom"
icon_locations = {
    os.path.basename(app): (170, 200),
    "Applications": (490, 200),
}
