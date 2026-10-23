#!/usr/bin/env python3
"""Super+Space menu.

The idle list is the parent entries and normal applications. Submenu items
such as Grok and Gazebo stay in their menus. Typing a name adds the matching
submenu item, and choosing it installs or launches that item.

COREBRUM_LAUNCHER_LIST=1 prints the visible names and does not open a window.
The query is COREBRUM_LAUNCHER_QUERY. Exit 2 when GTK is unavailable so the
shell can fall back to Fuzzel.
"""

import os
import subprocess
import sys

SEARCH_PREFIXES = (
    "corebrum-agent-",
    "corebrum-ros-tool-",
    "corebrum-realsense-tool-",
    "corebrum-agenticros-action-",
)
FIELD_CODES = {
    "%f", "%F", "%u", "%U", "%i", "%c", "%k", "%d", "%D", "%n", "%N", "%v", "%m",
}


class Entry:
    def __init__(self, app_id, name, generic, keywords, comment, icon, argv, terminal, search_only):
        self.app_id = app_id
        self.name = name
        self.generic = generic
        self.keywords = keywords
        self.comment = comment
        self.icon = icon
        self.argv = argv
        self.terminal = terminal
        self.search_only = search_only


def data_dirs():
    dirs = []
    home = os.environ.get("XDG_DATA_HOME", "")
    if not home:
        home_dir = os.environ.get("HOME", "")
        if home_dir:
            home = os.path.join(home_dir, ".local", "share")
    if home and os.path.isdir(home):
        dirs.append(home)
    raw = os.environ.get("XDG_DATA_DIRS")
    if raw:
        dirs.extend(part for part in raw.split(":") if part)
    else:
        dirs.extend(["/usr/local/share", "/usr/share"])
    return dirs


def unescape(value):
    out = []
    i = 0
    while i < len(value):
        if value[i] == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            out.append({"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}.get(nxt, nxt))
            i += 2
            continue
        out.append(value[i])
        i += 1
    return "".join(out)


def split_exec(line):
    args = []
    cur = []
    quote = ""
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == quote:
                quote = ""
            elif ch == "\\" and quote == '"' and i + 1 < len(line):
                i += 1
                cur.append(line[i])
            else:
                cur.append(ch)
        elif ch in "\"'":
            quote = ch
        elif ch.isspace():
            if cur:
                args.append("".join(cur))
                cur = []
        elif ch == "\\" and i + 1 < len(line):
            i += 1
            cur.append(line[i])
        else:
            cur.append(ch)
        i += 1
    if cur:
        args.append("".join(cur))
    cleaned = []
    for arg in args:
        if arg in FIELD_CODES:
            continue
        cleaned.append(arg.replace("%%", "%"))
    return cleaned


def parse_desktop(path):
    group = ""
    fields = {}
    try:
        text = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return None
    for raw in text:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            if group == "Desktop Entry":
                break
            group = line[1:-1]
            continue
        if group != "Desktop Entry" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if "[" in key:
            continue
        fields.setdefault(key, unescape(value.strip()))
    if fields.get("Type", "Application") != "Application":
        return None
    if fields.get("Hidden", "").lower() == "true":
        return None
    name = fields.get("Name", "")
    if not name:
        return None
    return fields


def desktop_allowed(fields):
    current = [part for part in os.environ.get("XDG_CURRENT_DESKTOP", "").replace(":", ";").split(";") if part]
    only = [part for part in fields.get("OnlyShowIn", "").split(";") if part]
    if only and not any(item in only for item in current):
        return False
    hidden = [part for part in fields.get("NotShowIn", "").split(";") if part]
    if hidden and any(item in hidden for item in current):
        return False
    return True


def is_search_only(filename):
    base = os.path.basename(filename)
    return any(base.startswith(prefix) for prefix in SEARCH_PREFIXES)


def load_entries():
    found = {}
    for root in data_dirs():
        app_dir = os.path.join(root, "applications")
        if not os.path.isdir(app_dir):
            continue
        for dirpath, dirnames, filenames in os.walk(app_dir):
            dirnames.sort()
            rel = os.path.relpath(dirpath, app_dir)
            prefix = "" if rel == "." else rel.replace(os.sep, "-") + "-"
            for filename in sorted(filenames):
                if not filename.endswith(".desktop"):
                    continue
                path = os.path.join(dirpath, filename)
                app_id = prefix + filename[: -len(".desktop")]
                if app_id in found:
                    continue
                fields = parse_desktop(path)
                if fields is None:
                    continue
                search_only = is_search_only(filename)
                if not search_only:
                    if fields.get("NoDisplay", "").lower() == "true":
                        continue
                    if not desktop_allowed(fields):
                        continue
                found[app_id] = Entry(
                    app_id=app_id,
                    name=fields.get("Name", app_id),
                    generic=fields.get("GenericName", ""),
                    keywords=fields.get("Keywords", ""),
                    comment=fields.get("Comment", ""),
                    icon=fields.get("Icon", ""),
                    argv=split_exec(fields.get("Exec", "")),
                    terminal=fields.get("Terminal", "").lower() == "true",
                    search_only=search_only,
                )
    return list(found.values())


def normalize(text):
    return "".join(ch.lower() if ch.isalnum() else " " for ch in text)


def haystack(entry):
    return normalize(" ".join([entry.name, entry.generic, entry.keywords, entry.comment, entry.app_id.replace("-", " ")]))


def visible_entries(entries, query):
    compact = " ".join(normalize(query).split())
    shown = []
    for entry in entries:
        if not compact:
            if not entry.search_only:
                shown.append(entry)
            continue
        text = haystack(entry)
        if compact in text or compact.replace(" ", "") in text.replace(" ", ""):
            shown.append(entry)

    def sort_key(entry):
        text = haystack(entry)
        starts = 0 if compact and (text.startswith(compact) or normalize(entry.name).startswith(compact)) else 1
        return (starts, entry.name.casefold())

    shown.sort(key=sort_key)
    return shown


def launch(entry):
    if not entry.argv:
        return
    if entry.terminal:
        cmd = ["/usr/local/bin/corebrum-terminal", "--", *entry.argv]
    else:
        cmd = entry.argv
    subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def list_names():
    query = os.environ.get("COREBRUM_LAUNCHER_QUERY", "")
    for entry in visible_entries(load_entries(), query):
        print(entry.name)


def widget_pointer(widget):
    import ctypes

    get_pointer = ctypes.pythonapi.PyCapsule_GetPointer
    get_pointer.restype = ctypes.c_void_p
    get_pointer.argtypes = [ctypes.py_object, ctypes.c_char_p]
    return get_pointer(widget.__gpointer__, None)


def use_layer_shell(window):
    import ctypes

    try:
        lib = ctypes.CDLL("libgtk-layer-shell.so.0")
    except OSError:
        return False
    lib.gtk_layer_is_supported.restype = ctypes.c_bool
    if not lib.gtk_layer_is_supported():
        return False
    lib.gtk_layer_init_for_window.argtypes = [ctypes.c_void_p]
    lib.gtk_layer_set_layer.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.gtk_layer_set_keyboard_mode.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.gtk_layer_set_exclusive_zone.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.gtk_layer_set_namespace.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    ptr = widget_pointer(window)
    if not ptr:
        return False
    lib.gtk_layer_init_for_window(ptr)
    lib.gtk_layer_set_layer(ptr, 2)
    lib.gtk_layer_set_keyboard_mode(ptr, 1)
    lib.gtk_layer_set_exclusive_zone(ptr, 0)
    lib.gtk_layer_set_namespace(ptr, b"corebrum-launcher")
    return True


def run_window():
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        from gi.repository import Gdk, GLib, Gtk
    except Exception:
        sys.exit(2)

    GLib.set_prgname("corebrum-launcher")
    if hasattr(Gdk, "set_program_class"):
        Gdk.set_program_class("corebrum-launcher")
    entries = load_entries()
    Gtk.init([])
    window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    window.set_title("corebrum-launcher")
    window.set_name("corebrum-launcher")
    window.set_decorated(False)
    window.set_resizable(False)
    window.set_default_size(680, 460)
    window.set_keep_above(True)
    layered = use_layer_shell(window)
    window.get_style_context().add_class("corebrum-menu")

    # Same colors as config/fuzzel/fuzzel.ini. The desktop GTK theme is light,
    # and it paints the entry, list, and viewport unless these nodes are set too.
    css = Gtk.CssProvider()
    loaded = css.load_from_data(b"""
.corebrum-menu {
  background-color: #1c1c1c;
  color: #e8e6e3;
  border: 2px solid #3d9a8b;
  border-radius: 8px;
}
.corebrum-menu box,
.corebrum-menu scrolledwindow,
.corebrum-menu viewport,
.corebrum-menu list,
.corebrum-menu row,
.corebrum-menu entry {
  background-color: #1c1c1c;
  background-image: none;
  color: #e8e6e3;
  border-color: #1c1c1c;
  box-shadow: none;
}
.corebrum-menu entry {
  caret-color: #3d9a8b;
  font-family: "Noto Sans Mono";
  font-size: 12pt;
  padding: 10px 14px;
}
.corebrum-menu entry selection {
  background-color: #3d9a8b;
  color: #1c1c1c;
}
.corebrum-menu row {
  padding: 4px 10px;
}
.corebrum-menu label {
  background-color: transparent;
  color: #e8e6e3;
  font-family: "Noto Sans Mono";
  font-size: 12pt;
}
.corebrum-menu row:selected,
.corebrum-menu row:selected label {
  background-color: #3d9a8b;
  color: #1c1c1c;
}
""")
    if loaded is False:
        print("corebrum-launcher: dark theme stylesheet was rejected", file=sys.stderr)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER
    )
    try:
        settings = Gtk.Settings.get_default()
        settings.set_property("gtk-application-prefer-dark-theme", True)
        settings.set_property("gtk-icon-theme-name", "Papirus")
    except Exception:
        pass

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    search = Gtk.Entry()
    search.set_has_frame(False)
    results = Gtk.ListBox()
    results.set_selection_mode(Gtk.SelectionMode.SINGLE)
    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scroll.set_min_content_height(40)
    scroll.set_max_content_height(12 * 36)
    scroll.set_propagate_natural_height(True)
    scroll.add(results)
    box.pack_start(search, False, False, 0)
    box.pack_start(scroll, True, True, 0)
    window.add(box)
    theme = Gtk.IconTheme.get_default()
    armed = {"ok": False}

    def refill(*_args):
        for child in results.get_children():
            results.remove(child)
        shown = visible_entries(entries, search.get_text())
        for entry in shown:
            row = Gtk.ListBoxRow()
            line = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            if entry.icon:
                try:
                    pix = theme.load_icon(entry.icon, 24, 0)
                    image = Gtk.Image.new_from_pixbuf(pix)
                    line.pack_start(image, False, False, 0)
                except Exception:
                    pass
            label = Gtk.Label(label=entry.name, xalign=0)
            line.pack_start(label, True, True, 0)
            row.add(line)
            row.entry = entry
            results.add(row)
        results.show_all()
        first = results.get_row_at_index(0)
        if first is not None:
            results.select_row(first)

    def activate(*_args):
        row = results.get_selected_row()
        if row is None:
            return
        try:
            launch(row.entry)
        finally:
            Gtk.main_quit()

    def on_key(_widget, event):
        key = event.keyval
        if key == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        if key in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            activate()
            return True
        if key in (Gdk.KEY_Down, Gdk.KEY_KP_Down):
            move(1)
            return True
        if key in (Gdk.KEY_Up, Gdk.KEY_KP_Up):
            move(-1)
            return True
        return False

    def move(delta):
        selected = results.get_selected_row()
        if selected is None:
            return
        nxt = results.get_row_at_index(selected.get_index() + delta)
        if nxt is not None:
            results.select_row(nxt)
            nxt.grab_focus()
            search.grab_focus()

    def on_focus_in(*_args):
        armed["ok"] = True

    def on_focus_out(*_args):
        if armed["ok"] and not layered:
            Gtk.main_quit()

    search.connect("changed", refill)
    search.connect("key-press-event", on_key)
    results.connect("row-activated", activate)
    window.connect("focus-in-event", on_focus_in)
    window.connect("focus-out-event", on_focus_out)
    window.connect("destroy", Gtk.main_quit)
    refill()
    window.show_all()
    search.grab_focus()
    Gtk.main()


def main():
    if os.environ.get("COREBRUM_LAUNCHER_LIST") == "1":
        list_names()
        return
    run_window()


if __name__ == "__main__":
    main()
