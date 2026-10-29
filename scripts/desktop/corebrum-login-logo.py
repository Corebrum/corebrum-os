#!/usr/bin/env python3
# Logo above the wlgreet card. wlgreet draws a 1024x128 card and has no image widget.
import sys

LOGO = "/usr/share/corebrum/logo.png"
# config/brand/logo.png is 1104x320. 759x220 keeps that aspect, as on the old login screen.
LOGO_WIDTH = 759
LOGO_HEIGHT = 220
# wlgreet 0.5 sizes the login card at 128px and centers it.
CARD_HEIGHT = 128
GAP = 24


def margin_top(screen_height):
    top = (screen_height // 2) - (CARD_HEIGHT // 2) - GAP - LOGO_HEIGHT
    if top < 16:
        return 16
    return top


def gobject_pointer(obj):
    import ctypes

    get_pointer = ctypes.pythonapi.PyCapsule_GetPointer
    get_pointer.restype = ctypes.c_void_p
    get_pointer.argtypes = [ctypes.py_object, ctypes.c_char_p]
    return get_pointer(obj.__gpointer__, None)


def place_logo(window, monitor):
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
    lib.gtk_layer_set_margin.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
    lib.gtk_layer_set_monitor.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    window_ptr = gobject_pointer(window)
    monitor_ptr = gobject_pointer(monitor)
    if not window_ptr or not monitor_ptr:
        return False
    # Layer top sits under wlgreet, which uses the overlay layer.
    # Edge top is 2. Keyboard mode none is 0.
    lib.gtk_layer_init_for_window(window_ptr)
    lib.gtk_layer_set_layer(window_ptr, 2)
    lib.gtk_layer_set_keyboard_mode(window_ptr, 0)
    lib.gtk_layer_set_exclusive_zone(window_ptr, 0)
    lib.gtk_layer_set_namespace(window_ptr, b"corebrum-login-logo")
    lib.gtk_layer_set_anchor(window_ptr, 2, True)
    lib.gtk_layer_set_margin(window_ptr, 2, margin_top(monitor.get_geometry().height))
    lib.gtk_layer_set_monitor(window_ptr, monitor_ptr)
    return True


def show():
    import gi

    gi.require_version("Gdk", "3.0")
    gi.require_version("GdkPixbuf", "2.0")
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gdk, GdkPixbuf, Gtk

    if not Gtk.init_check([]):
        return 0
    display = Gdk.Display.get_default()
    if display is None or display.get_n_monitors() < 1:
        return 0
    pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
        LOGO, LOGO_WIDTH, LOGO_HEIGHT, False
    )
    shown = False
    for index in range(display.get_n_monitors()):
        monitor = display.get_monitor(index)
        window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        window.set_decorated(False)
        window.set_resizable(False)
        window.set_app_paintable(True)
        window.set_accept_focus(False)
        visual = window.get_screen().get_rgba_visual()
        if visual is not None:
            window.set_visual(visual)
        image = Gtk.Image.new_from_pixbuf(pixbuf)
        window.add(image)
        if not place_logo(window, monitor):
            continue
        window.show_all()
        shown = True
    if not shown:
        return 0
    Gtk.main()
    return 0


def main(argv):
    if len(argv) >= 3 and argv[1] == "margin":
        print(margin_top(int(argv[2])))
        return 0
    try:
        return show()
    except Exception as exc:
        print(f"corebrum-login-logo: {exc}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
