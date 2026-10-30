#!/usr/bin/env python3
# Centered greetd login card. wlgreet 0.5 draws a 1024x128 bar with a 72px
# Login word on the left and the prompt at a fixed x, and its config cannot
# move either one. This client fills the screen with one transparent layer.
# The logo and the two fields stay centered. Scan lines and bars cover the
# wallpaper and pass clicks through to the fields.
import json
import os
import struct
import sys
import time
from pathlib import Path

SESSION = os.environ.get("COREBRUM_SESSION", "/usr/local/bin/corebrum-session")
LOGO_WIDTH = 759
LOGO_HEIGHT = 220
LAYER_OVERLAY = 3
KEYBOARD_EXCLUSIVE = 1
KEYBOARD_ON_DEMAND = 2
# Keep these four numbers aligned with corebrum-glitch-module.c.
GLITCH_PERIOD_MS = 60_000
GLITCH_BURST_MS = 1200
GLITCH_GRACE_MS = 200
GLITCH_CLEAR_MS = 1500


def frame(payload):
    body = json.dumps(payload, separators=(",", ":")).encode()
    return struct.pack("<I", len(body)) + body


def parse_frame(header, body):
    (length,) = struct.unpack("<I", header)
    if length != len(body):
        raise ValueError(f"greetd frame length {length} does not match {len(body)}")
    return json.loads(body.decode())


def interpret(message):
    kind = message.get("type")
    if kind == "success":
        return "success"
    if kind == "error":
        if message.get("error_type") == "auth_error":
            return "auth_error"
        return "fatal"
    if kind == "auth_message":
        mode = message.get("auth_message_type")
        if mode in ("info", "error"):
            return "acknowledge"
        if mode == "secret":
            return "need_secret"
        if mode == "visible":
            return "need_visible"
    return "fatal"


def glitch_wait_ms(second, nanosecond):
    into = (second % 60) * 1000 + nanosecond // 1_000_000
    if into <= GLITCH_GRACE_MS:
        return 0
    return GLITCH_PERIOD_MS - into


def glitch_wait_from_clock(now_ns=None):
    if now_ns is None:
        now_ns = time.time_ns()
    seconds, nanos = divmod(now_ns, 1_000_000_000)
    return glitch_wait_ms(time.localtime(seconds).tm_sec, nanos)


def schedule_glitch(GLib, windows):
    def clear_glitch():
        for window in windows:
            window.get_style_context().remove_class("glitch")
        arm()
        return False

    def start_glitch():
        for window in windows:
            window.get_style_context().add_class("glitch")
        GLib.timeout_add(GLITCH_CLEAR_MS, clear_glitch)
        return False

    def arm():
        GLib.timeout_add(glitch_wait_from_clock(), start_glitch)
        return False

    arm()


def css_path():
    installed = Path("/etc/corebrum/greetd/login.css")
    if installed.is_file():
        return installed
    return source_css_path()


def source_css_path():
    bundled = Path(__file__).resolve().parents[2] / "config" / "greetd" / "login.css"
    if bundled.is_file():
        return bundled
    return Path("/etc/corebrum/greetd/login.css")


class Greetd:
    def __init__(self, sock):
        self.sock = sock
        self.phase = "username"

    def send(self, payload):
        self.sock.sendall(frame(payload))

    def recv(self):
        header = self._read(4)
        (length,) = struct.unpack("<I", header)
        if length > 1_000_000:
            raise ValueError("greetd frame is too large")
        return parse_frame(header, self._read(length))

    def _read(self, count):
        chunks = []
        remaining = count
        while remaining:
            part = self.sock.recv(remaining)
            if not part:
                raise EOFError("greetd closed the socket")
            chunks.append(part)
            remaining -= len(part)
        return b"".join(chunks)

    def cancel(self):
        try:
            self.send({"type": "cancel_session"})
            self.recv()
        except (OSError, EOFError, ValueError, json.JSONDecodeError):
            pass
        self.phase = "username"

    def pump(self, password):
        sent_password = False
        for _ in range(8):
            step = interpret(self.recv())
            if step == "success":
                self.send({"type": "start_session", "cmd": [SESSION], "env": []})
                if interpret(self.recv()) != "success":
                    return "fatal"
                return "started"
            if step == "acknowledge":
                self.send({"type": "post_auth_message_response", "response": None})
                continue
            if step == "need_secret":
                self.phase = "password"
                if password and not sent_password:
                    self.send({"type": "post_auth_message_response", "response": password})
                    sent_password = True
                    continue
                return "need_secret"
            if step == "need_visible":
                self.phase = "visible"
                return "need_visible"
            if step == "auth_error":
                self.cancel()
                return "auth_error"
            return "fatal"
        return "fatal"

    def submit(self, username, password):
        if self.phase == "username":
            if not username:
                return "need_username"
            self.send({"type": "create_session", "username": username})
            return self.pump(password)
        self.send({"type": "post_auth_message_response", "response": password})
        return self.pump("")


def self_check():
    payload = {"type": "create_session", "username": "corebrum"}
    raw = frame(payload)
    header, body = raw[:4], raw[4:]
    if parse_frame(header, body) != payload:
        return "frame did not round-trip"
    if interpret({"type": "auth_message", "auth_message_type": "secret", "auth_message": "Password:"}) != "need_secret":
        return "secret prompt was not recognized"
    if interpret({"type": "error", "error_type": "auth_error", "description": "no"}) != "auth_error":
        return "auth error was not recognized"
    if interpret({"type": "success"}) != "success":
        return "success was not recognized"
    if not source_css_path().is_file():
        return f"missing {source_css_path()}"
    css = source_css_path().read_text()
    if "min-width: 380px" not in css or "#login-card" not in css:
        return "login card style is missing"
    if "box#login-logo" not in css:
        return "login logo is not its own box"
    if "window.glitch box#login-logo" not in css:
        return "login logo does not glitch"
    if "animation: login-glitch-logo 1200ms linear 1" not in css:
        return "login glitch is not the clock burst"
    if "40s" in css or "infinite" in css:
        return "login glitch still loops on its own"
    if GLITCH_CLEAR_MS <= GLITCH_BURST_MS + 140:
        return "login glitch clear cuts off the bars"
    if glitch_wait_ms(0, 0) != 0 or glitch_wait_ms(30, 0) != 30000:
        return "glitch does not start on the minute"
    if glitch_wait_ms(0, 200_000_000) != 0:
        return "glitch grace missed the boundary"
    if glitch_wait_ms(0, 201_000_000) != 59799:
        return "glitch grace was too wide"
    if glitch_wait_ms(15, 0) != 45000 or glitch_wait_ms(45, 500_000_000) != 14500:
        return "glitch wait inside the minute was wrong"
    if glitch_wait_ms(59, 999_000_000) != 1:
        return "glitch wait at the end of a minute was wrong"
    previous_tz = os.environ.get("TZ")
    os.environ["TZ"] = "UTC"
    time.tzset()
    try:
        if glitch_wait_from_clock(0) != 0 or glitch_wait_from_clock(60 * 1_000_000_000) != 0:
            return "glitch clock missed UTC minute boundaries"
        if glitch_wait_from_clock(30 * 1_000_000_000) != 30000:
            return "glitch clock fired on the half-minute"
        if glitch_wait_from_clock(15 * 1_000_000_000) != 45000:
            return "glitch clock midpoint was wrong"
    finally:
        if previous_tz is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = previous_tz
        time.tzset()
    if "transform:" in css:
        return "login style uses transform"
    if "Login" in css:
        return "login style still names a Login title"
    return ""


def gobject_pointer(obj):
    import ctypes

    get_pointer = ctypes.pythonapi.PyCapsule_GetPointer
    get_pointer.restype = ctypes.c_void_p
    get_pointer.argtypes = [ctypes.py_object, ctypes.c_char_p]
    return get_pointer(obj.__gpointer__, None)


def place_window(window, monitor, exclusive):
    import ctypes

    lib = ctypes.CDLL("libgtk-layer-shell.so.0")
    lib.gtk_layer_is_supported.restype = ctypes.c_bool
    if not lib.gtk_layer_is_supported():
        return False
    lib.gtk_layer_init_for_window.argtypes = [ctypes.c_void_p]
    lib.gtk_layer_set_layer.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.gtk_layer_set_keyboard_mode.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.gtk_layer_set_exclusive_zone.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lib.gtk_layer_set_namespace.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lib.gtk_layer_set_anchor.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_bool]
    lib.gtk_layer_set_monitor.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    window_ptr = gobject_pointer(window)
    if not window_ptr:
        return False
    lib.gtk_layer_init_for_window(window_ptr)
    lib.gtk_layer_set_layer(window_ptr, LAYER_OVERLAY)
    lib.gtk_layer_set_keyboard_mode(
        window_ptr, KEYBOARD_EXCLUSIVE if exclusive else KEYBOARD_ON_DEMAND
    )
    lib.gtk_layer_set_exclusive_zone(window_ptr, 0)
    lib.gtk_layer_set_namespace(window_ptr, b"corebrum-login")
    # Left, right, top, and bottom. The surface covers the wallpaper so the
    # glitch bars can cross it. The card stays centered inside the surface.
    for edge in range(4):
        lib.gtk_layer_set_anchor(window_ptr, edge, True)
    if monitor is not None:
        monitor_ptr = gobject_pointer(monitor)
        if not monitor_ptr:
            return False
        lib.gtk_layer_set_monitor(window_ptr, monitor_ptr)
    return True


def apply_css(Gtk, Gdk):
    provider = Gtk.CssProvider()
    provider.load_from_path(str(css_path()))
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )


def pass_overlay(overlay, widget):
    widget.set_can_focus(False)
    overlay.add_overlay(widget)
    overlay.set_overlay_pass_through(widget, True)


def build_form(Gtk, on_activate):
    overlay = Gtk.Overlay()
    overlay.set_hexpand(True)
    overlay.set_vexpand(True)
    # The overlay gives its main child the whole screen. This holder keeps
    # the column at its natural size and centers it. fill stays off so the
    # extra space becomes padding instead of stretching the fields.
    holder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    holder.set_hexpand(True)
    holder.set_vexpand(True)
    column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
    column.set_halign(Gtk.Align.CENTER)
    column.set_valign(Gtk.Align.CENTER)
    logo = Gtk.Box()
    logo.set_name("login-logo")
    logo.set_halign(Gtk.Align.CENTER)
    logo.set_size_request(LOGO_WIDTH, LOGO_HEIGHT)
    logo.set_can_focus(False)
    column.pack_start(logo, False, False, 0)
    card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    card.set_name("login-card")
    card.set_halign(Gtk.Align.CENTER)
    username = Gtk.Entry()
    username.set_name("login-username")
    username.set_placeholder_text("Username")
    username.set_halign(Gtk.Align.CENTER)
    username.set_width_chars(24)
    password = Gtk.Entry()
    password.set_name("login-password")
    password.set_placeholder_text("Password")
    password.set_visibility(False)
    password.set_input_purpose(Gtk.InputPurpose.PASSWORD)
    password.set_halign(Gtk.Align.CENTER)
    password.set_width_chars(24)
    error = Gtk.Label(label="")
    error.set_name("login-error")
    error.set_halign(Gtk.Align.CENTER)
    error.set_no_show_all(True)
    card.pack_start(username, False, False, 0)
    card.pack_start(password, False, False, 0)
    card.pack_start(error, False, False, 0)
    column.pack_start(card, False, False, 0)
    holder.pack_start(column, True, False, 0)
    overlay.add(holder)
    scan = Gtk.Box()
    scan.set_name("glitch-scan")
    scan.set_hexpand(True)
    scan.set_vexpand(True)
    pass_overlay(overlay, scan)
    flash = Gtk.Box()
    flash.set_name("glitch-flash")
    flash.set_hexpand(True)
    flash.set_vexpand(True)
    pass_overlay(overlay, flash)
    layer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    layer.set_name("glitch-layer")
    layer.set_hexpand(True)
    layer.set_vexpand(True)
    for name, width, height in (
        ("glitch-bar-a", 520, 8),
        ("glitch-bar-b", 240, 3),
        ("glitch-bar-c", 680, 14),
        ("glitch-bar-d", 160, 4),
    ):
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        spacer.set_can_focus(False)
        layer.pack_start(spacer, True, True, 0)
        bar = Gtk.Box()
        bar.set_name(name)
        bar.set_halign(Gtk.Align.START)
        bar.set_size_request(width, height)
        bar.set_can_focus(False)
        layer.pack_start(bar, False, False, 0)
    tail = Gtk.Box()
    tail.set_vexpand(True)
    tail.set_can_focus(False)
    layer.pack_start(tail, True, True, 0)
    pass_overlay(overlay, layer)

    def activate(entry):
        if entry is username and not password.get_text():
            if username.get_text().strip():
                password.grab_focus()
            return
        on_activate(username, password, error)

    username.connect("activate", activate)
    password.connect("activate", activate)
    return overlay, username


def show():
    import socket

    import gi

    gi.require_version("Gdk", "3.0")
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gdk, GLib, Gtk

    os.environ.setdefault("GDK_BACKEND", "wayland")
    if not Gtk.init_check([]):
        print("corebrum-login: GTK failed to start", file=sys.stderr)
        return 1
    display = Gdk.Display.get_default()
    if display is None or display.get_n_monitors() < 1:
        print("corebrum-login: no monitor", file=sys.stderr)
        return 1
    sock_path = os.environ.get("GREETD_SOCK", "")
    if not sock_path:
        print("corebrum-login: GREETD_SOCK is not set", file=sys.stderr)
        return 1
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(sock_path)
    except OSError as exc:
        print(f"corebrum-login: {exc}", file=sys.stderr)
        return 1
    greetd = Greetd(sock)
    apply_css(Gtk, Gdk)
    first_username = None

    def fail(error, text):
        greetd.cancel()
        error.set_text(text)
        error.show()

    def on_activate(username, password, error):
        error.hide()
        try:
            step = greetd.submit(username.get_text().strip(), password.get_text())
        except (OSError, EOFError, ValueError, json.JSONDecodeError) as exc:
            fail(error, "Login failed")
            print(f"corebrum-login: {exc}", file=sys.stderr)
            return
        if step == "started":
            os._exit(0)
        if step == "need_secret":
            password.grab_focus()
            return
        if step == "need_username":
            username.grab_focus()
            return
        if step in ("auth_error", "need_visible", "fatal"):
            username.set_text("")
            password.set_text("")
            fail(error, "Login failed")
            username.grab_focus()

    shown = False
    windows = []
    for index in range(display.get_n_monitors()):
        monitor = display.get_monitor(index)
        window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        window.set_decorated(False)
        window.set_resizable(False)
        window.set_app_paintable(True)
        visual = window.get_screen().get_rgba_visual()
        if visual is not None:
            window.set_visual(visual)
        form, username = build_form(Gtk, on_activate)
        window.add(form)
        if not place_window(window, monitor, exclusive=(index == 0)):
            continue
        window.show_all()
        windows.append(window)
        if first_username is None:
            first_username = username
        shown = True
    if not shown:
        print("corebrum-login: layer shell is not available", file=sys.stderr)
        return 1
    if first_username is not None:
        GLib.idle_add(first_username.grab_focus)
    schedule_glitch(GLib, windows)
    Gtk.main()
    return 1


def preview(path):
    os.environ.setdefault("GDK_BACKEND", "wayland")
    import gi

    gi.require_version("Gdk", "3.0")
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gdk, Gtk

    if not Gtk.init_check([]):
        print("corebrum-login: GTK failed to start", file=sys.stderr)
        return 1
    apply_css(Gtk, Gdk)
    window = Gtk.OffscreenWindow()
    form, _username = build_form(Gtk, lambda *_args: None)
    form.set_margin_top(24)
    form.set_margin_bottom(24)
    window.add(form)
    window.show_all()
    while Gtk.events_pending():
        Gtk.main_iteration()
    pixbuf = window.get_pixbuf()
    if pixbuf is None:
        print("corebrum-login: preview produced no image", file=sys.stderr)
        return 1
    pixbuf.savev(path, "png", [], [])
    return 0


def main(argv):
    if len(argv) >= 2 and argv[1] == "self-check":
        problem = self_check()
        if problem:
            print(problem, file=sys.stderr)
            return 1
        print("ok")
        return 0
    if len(argv) >= 3 and argv[1] == "preview":
        try:
            return preview(argv[2])
        except Exception as exc:
            print(f"corebrum-login: {exc}", file=sys.stderr)
            return 1
    try:
        return show()
    except Exception as exc:
        print(f"corebrum-login: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
