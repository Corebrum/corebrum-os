#!/usr/bin/env python3
"""Super+Space menu.

The idle list is the root groups (Apps, Learn, Robot, Appearance, Setup,
Updates, System). Rows that open another level end with >. Enter or Right
drills into a group. Backspace or Left with an empty search box goes up one
level. Typing finds matching descendants of the active menu; nested hits show
a parent path.

COREBRUM_LAUNCHER_LIST=1 prints the visible names and does not open a window.
COREBRUM_LAUNCHER_QUERY is the filter. COREBRUM_LAUNCHER_ACTIVE is the menu id
(default root). COREBRUM_MENU_TREE overrides the menu tree path. Exit 2 when
GTK is unavailable so the shell can fall back to Fuzzel.
"""

import json
import os
import subprocess
import sys

SEARCH_PREFIXES = (
    "corebrum-agent-",
    "corebrum-ros-tool-",
    "corebrum-realsense-tool-",
    "corebrum-synapse-action-",
    "corebrum-arc-action-",
    "corebrum-update-",
    "corebrum-power-action-",
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


class Row:
    def __init__(self, name, icon, keywords, comment, kind, menu_id=None, entry=None, path="", depth=0):
        self.name = name
        self.icon = icon
        self.keywords = keywords
        self.comment = comment
        self.kind = kind  # menu | leaf | provider
        self.menu_id = menu_id
        self.entry = entry
        self.path = path
        self.depth = depth
        self.app_id = entry.app_id if entry is not None else (menu_id or name)


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
                # The first desktop file for an id wins. A hidden copy in the
                # runtime directory has to claim that id, or a later snap file
                # with the same id is listed again.
                if not search_only and (
                    fields.get("NoDisplay", "").lower() == "true" or not desktop_allowed(fields)
                ):
                    found[app_id] = None
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
    return {app_id: entry for app_id, entry in found.items() if entry is not None}


def menu_tree_path():
    override = os.environ.get("COREBRUM_MENU_TREE", "")
    if override:
        return override
    installed = "/etc/corebrum/menu/corebrum-menu.json"
    if os.path.isfile(installed):
        return installed
    here = os.path.dirname(os.path.abspath(__file__))
    checkout = os.path.normpath(os.path.join(here, "..", "..", "config", "menu", "corebrum-menu.json"))
    return checkout


def load_menu_tree():
    path = menu_tree_path()
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {"root": [], "navigate": {}, "dynamic": []}


def load_icon_pixbuf(theme, icon, size):
    if not icon:
        return None
    path = os.path.expanduser(icon)
    if icon.startswith("/") or icon.startswith("~/"):
        if not os.path.isfile(path):
            return None
        import gi
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
        return GdkPixbuf.Pixbuf.new_from_file_at_size(path, size, size)
    return theme.load_icon(icon, size, 0)


def normalize(text):
    return "".join(ch.lower() if ch.isalnum() else " " for ch in text)


def haystack_parts(*parts):
    return normalize(" ".join(part for part in parts if part))


def entry_haystack(entry):
    return haystack_parts(
        entry.name,
        entry.generic,
        entry.keywords,
        entry.comment,
        entry.app_id.replace("-", " "),
    )


def row_haystack(row):
    if row.entry is not None:
        return entry_haystack(row.entry)
    return haystack_parts(row.name, row.keywords, row.comment, row.menu_id or "")


def matches(hay, compact):
    if not compact:
        return True
    return compact in hay or compact.replace(" ", "") in hay.replace(" ", "")


class MenuModel:
    def __init__(self, tree, entries):
        self.tree = tree or {}
        self.entries = entries
        self.root_nodes = list(self.tree.get("root") or [])
        self.navigate = dict(self.tree.get("navigate") or {})
        self.dynamic = set(self.tree.get("dynamic") or [])
        self.nodes = {node["id"]: node for node in self.root_nodes if "id" in node}
        self.claimed = self._claimed_ids()

    def _claimed_ids(self):
        claimed = set()
        for node in self.root_nodes:
            desktop = node.get("desktop")
            if desktop:
                claimed.add(desktop)
            for child in node.get("children") or []:
                claimed.add(child)
        claimed.update(self.navigate)
        claimed.update(self.dynamic)
        return claimed

    def label_for(self, menu_id):
        node = self.nodes.get(menu_id)
        if node:
            return node.get("label", menu_id)
        entry = self.entries.get(menu_id)
        if entry:
            return entry.name
        return menu_id

    def path_labels(self, parts):
        return " / ".join(self.label_for(part) for part in parts if part and part != "root")

    def group_row(self, node, path="", depth=0):
        icon = node.get("icon", "")
        desktop = node.get("desktop")
        if desktop and desktop in self.entries and not icon:
            icon = self.entries[desktop].icon
        kind = "provider" if node.get("provider") else "menu"
        return Row(
            name=node.get("label", node["id"]),
            icon=icon,
            keywords=node.get("keywords", ""),
            comment=node.get("comment", ""),
            kind=kind,
            menu_id=node["id"],
            path=path,
            depth=depth,
        )

    def entry_row(self, entry, path="", depth=0, kind="leaf"):
        return Row(
            name=entry.name,
            icon=entry.icon,
            keywords=entry.keywords,
            comment=entry.comment,
            kind=kind,
            menu_id=entry.app_id if kind == "menu" else None,
            entry=entry,
            path=path,
            depth=depth,
        )

    def apps_entries(self):
        shown = []
        for entry in self.entries.values():
            if entry.search_only:
                continue
            if entry.app_id in self.claimed:
                continue
            shown.append(entry)
        shown.sort(key=lambda item: item.name.casefold())
        return shown

    def children_of(self, menu_id):
        if menu_id in ("", "root", None):
            return [self.group_row(node) for node in self.root_nodes]

        if menu_id == "apps" or (menu_id in self.nodes and self.nodes[menu_id].get("provider") == "apps"):
            return [self.entry_row(entry) for entry in self.apps_entries()]

        if menu_id in self.nodes:
            node = self.nodes[menu_id]
            rows = []
            for child_id in node.get("children") or []:
                if child_id in self.navigate:
                    entry = self.entries.get(child_id)
                    if entry is None:
                        continue
                    rows.append(self.entry_row(entry, kind="menu"))
                    continue
                if child_id in self.dynamic:
                    entry = self.entries.get(child_id)
                    if entry is not None:
                        rows.append(self.entry_row(entry, kind="leaf"))
                    continue
                entry = self.entries.get(child_id)
                if entry is not None:
                    rows.append(self.entry_row(entry, kind="leaf"))
            return rows

        if menu_id in self.navigate:
            prefix = self.navigate[menu_id].get("prefix", "")
            rows = []
            for entry in self.entries.values():
                if entry.app_id.startswith(prefix):
                    rows.append(self.entry_row(entry))
            rows.sort(key=lambda row: row.name.casefold())
            return rows

        return []

    def navigate_children(self, menu_id):
        if menu_id not in self.navigate:
            return []
        prefix = self.navigate[menu_id].get("prefix", "")
        return [
            entry
            for entry in self.entries.values()
            if entry.app_id.startswith(prefix)
        ]

    def can_navigate(self, menu_id):
        if menu_id in self.nodes:
            return True
        if menu_id == "apps":
            return True
        if menu_id in self.navigate:
            return bool(self.navigate_children(menu_id))
        return False

    def row_navigable(self, row):
        if row.kind in ("menu", "provider") and row.menu_id and self.can_navigate(row.menu_id):
            return True
        if row.kind == "menu" and row.entry is not None:
            return self.can_navigate(row.entry.app_id)
        return False

    def display_name(self, row):
        if self.row_navigable(row):
            return f"{row.name} >"
        return row.name

    def collect_descendants(self, menu_id, path_parts=None, depth=0):
        if path_parts is None:
            path_parts = []
        rows = []
        children = self.children_of(menu_id)
        path = self.path_labels(path_parts)
        for child in children:
            child.path = path
            child.depth = depth
            rows.append(child)
            next_id = None
            if child.kind in ("menu", "provider") and child.menu_id:
                next_id = child.menu_id
            elif child.kind == "menu" and child.entry is not None:
                next_id = child.entry.app_id
            if next_id and self.can_navigate(next_id):
                nested_parts = path_parts + [next_id]
                for nested in self.collect_descendants(next_id, nested_parts, depth + 1):
                    rows.append(nested)
        return rows

    def visible(self, menu_id, query):
        compact = " ".join(normalize(query).split())
        if not compact:
            return self.children_of(menu_id or "root")

        active = menu_id or "root"
        candidates = self.collect_descendants(active, [], 0)
        shown = [row for row in candidates if matches(row_haystack(row), compact)]

        def sort_key(row):
            text = row_haystack(row)
            starts = 0 if text.startswith(compact) or normalize(row.name).startswith(compact) else 1
            return (row.depth, starts, row.name.casefold())

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
    active = os.environ.get("COREBRUM_LAUNCHER_ACTIVE", "root")
    model = MenuModel(load_menu_tree(), load_entries())
    for row in model.visible(active, query):
        name = model.display_name(row)
        if row.path:
            print(f"{name}\t{row.path}")
        else:
            print(name)


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
    # GTK_LAYER_SHELL_LAYER_OVERLAY (3): above fullscreen windows on Sway.
    lib.gtk_layer_set_layer(ptr, 3)
    lib.gtk_layer_set_keyboard_mode(ptr, 1)
    lib.gtk_layer_set_exclusive_zone(ptr, 0)
    lib.gtk_layer_set_namespace(ptr, b"corebrum-launcher")
    return True


def run_window():
    try:
        import gi
        # The Jetson image ships Gdk 4 beside Gdk 3. An unversioned import
        # loads Gdk 4, Gtk 3 then fails, and Super+Space falls back to Fuzzel.
        # Fuzzel skips the hidden submenu files, so search cannot find them.
        gi.require_version("Gdk", "3.0")
        gi.require_version("Gtk", "3.0")
        from gi.repository import Gdk, GLib, Gtk
    except Exception:
        sys.exit(2)

    GLib.set_prgname("corebrum-launcher")
    if hasattr(Gdk, "set_program_class"):
        Gdk.set_program_class("corebrum-launcher")
    model = MenuModel(load_menu_tree(), load_entries())
    state = {"active": "root", "stack": []}
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
.corebrum-menu label.path {
  color: #9a9895;
  font-size: 10pt;
}
.corebrum-menu row:selected,
.corebrum-menu row:selected label {
  background-color: #3d9a8b;
  color: #1c1c1c;
}
.corebrum-menu row:selected label.path {
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
    refill_guard = {"skip": False}

    def clear_filter():
        if search.get_text():
            refill_guard["skip"] = True
            search.set_text("")
            refill_guard["skip"] = False

    def refill(*_args):
        if refill_guard["skip"]:
            return
        for child in results.get_children():
            results.remove(child)
        shown = model.visible(state["active"], search.get_text())
        for row_data in shown:
            row = Gtk.ListBoxRow()
            line = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            if row_data.icon:
                try:
                    pix = load_icon_pixbuf(theme, row_data.icon, 24)
                    if pix is not None:
                        image = Gtk.Image.new_from_pixbuf(pix)
                        line.pack_start(image, False, False, 0)
                except Exception:
                    pass
            text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
            label = Gtk.Label(label=model.display_name(row_data), xalign=0)
            text_box.pack_start(label, True, True, 0)
            if row_data.path:
                path_label = Gtk.Label(label=row_data.path, xalign=0)
                path_label.get_style_context().add_class("path")
                text_box.pack_start(path_label, True, True, 0)
            line.pack_start(text_box, True, True, 0)
            row.add(line)
            row.row_data = row_data
            results.add(row)
        results.show_all()
        first = results.get_row_at_index(0)
        if first is not None:
            results.select_row(first)

    def go_back():
        if not state["stack"]:
            return False
        state["active"] = state["stack"].pop()
        clear_filter()
        refill()
        return True

    def enter_menu(menu_id):
        state["stack"].append(state["active"])
        state["active"] = menu_id
        clear_filter()
        refill()

    def selected_menu_id():
        row = results.get_selected_row()
        if row is None:
            return None
        data = row.row_data
        if not model.row_navigable(data):
            return None
        if data.menu_id:
            return data.menu_id
        if data.entry is not None:
            return data.entry.app_id
        return None

    def activate(*_args):
        row = results.get_selected_row()
        if row is None:
            return
        menu_id = selected_menu_id()
        if menu_id is not None:
            enter_menu(menu_id)
            return
        data = row.row_data
        if data.kind == "menu" and data.entry is not None:
            try:
                launch(data.entry)
            finally:
                Gtk.main_quit()
            return
        if data.entry is not None:
            try:
                launch(data.entry)
            finally:
                Gtk.main_quit()

    def on_key(_widget, event):
        key = event.keyval
        empty = search.get_text() == ""
        if key == Gdk.KEY_Escape:
            if not empty:
                clear_filter()
                refill()
                return True
            Gtk.main_quit()
            return True
        if empty and key in (Gdk.KEY_BackSpace, Gdk.KEY_Left, Gdk.KEY_KP_Left):
            if go_back():
                return True
            return False
        # Right only opens a submenu. It does not launch a leaf the way Enter does.
        if empty and key in (Gdk.KEY_Right, Gdk.KEY_KP_Right):
            menu_id = selected_menu_id()
            if menu_id is not None:
                enter_menu(menu_id)
                return True
            return False
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
