#!/usr/bin/env python3
"""Small camera window for a screen recording."""

import argparse
import re
import signal
import sys

import gi

gi.require_version("GdkPixbuf", "2.0")
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, GdkPixbuf, Gtk

GLib.set_prgname("corebrum-camera")


def parse_args():
    parser = argparse.ArgumentParser(description="Show a camera in the recording corner.")
    parser.add_argument("--v4l2", default="", help="Webcam device, such as /dev/video6")
    return parser.parse_args()


class Window:
    def __init__(self):
        self.stopped = False
        self.window = Gtk.Window(title="Camera")
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_default_size(320, 180)
        self.image = Gtk.Image()
        self.window.add(self.image)
        self.window.connect("destroy", self.close)
        self.window.show_all()
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.on_signal)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self.on_signal)

    def on_signal(self):
        self.close()
        return GLib.SOURCE_REMOVE

    def close(self, *_args):
        if self.stopped:
            return
        self.stopped = True
        self.release()
        Gtk.main_quit()

    def release(self):
        return

    def show_rgb(self, raw, width, height):
        pix = GdkPixbuf.Pixbuf.new_from_bytes(
            GLib.Bytes.new(raw),
            GdkPixbuf.Colorspace.RGB,
            False,
            8,
            width,
            height,
            width * 3,
        )
        scaled = pix.scale_simple(320, 180, GdkPixbuf.InterpType.BILINEAR)
        self.image.set_from_pixbuf(scaled)


class RealSensePreview(Window):
    def __init__(self):
        try:
            import pyrealsense2 as rs
        except ImportError:
            print("pyrealsense2 is not installed", file=sys.stderr)
            raise SystemExit(1)
        self.rs = rs
        self.pipeline = rs.pipeline()
        config = rs.config()
        config.enable_stream(rs.stream.color, 640, 480, rs.format.rgb8, 30)
        try:
            self.pipeline.start(config)
        except Exception as exc:
            print(exc, file=sys.stderr)
            raise SystemExit(1)
        super().__init__()
        GLib.timeout_add(66, self.frame)

    def release(self):
        try:
            self.pipeline.stop()
        except Exception:
            pass

    def frame(self):
        if self.stopped:
            return False
        frames = self.pipeline.poll_for_frames()
        color = frames.get_color_frame()
        if not color:
            return True
        self.show_rgb(bytes(color.get_data()), color.get_width(), color.get_height())
        return True


class WebcamPreview(Window):
    def __init__(self, device):
        if re.fullmatch(r"/dev/video[0-9]+", device) is None:
            print("webcam device is not a video node", file=sys.stderr)
            raise SystemExit(1)
        try:
            gi.require_version("Gst", "1.0")
            from gi.repository import Gst
        except ValueError:
            print("GStreamer typelibs are not installed", file=sys.stderr)
            raise SystemExit(1)
        self.gst = Gst
        Gst.init(None)
        source = Gst.ElementFactory.make("v4l2src", "source")
        convert = Gst.ElementFactory.make("videoconvert", "convert")
        scale = Gst.ElementFactory.make("videoscale", "scale")
        capsfilter = Gst.ElementFactory.make("capsfilter", "caps")
        sink = Gst.ElementFactory.make("appsink", "sink")
        if not all((source, convert, scale, capsfilter, sink)):
            print("webcam preview elements are missing", file=sys.stderr)
            raise SystemExit(1)
        source.set_property("device", device)
        capsfilter.set_property("caps", Gst.Caps.from_string("video/x-raw,format=RGB,width=640,height=480"))
        sink.set_property("max-buffers", 1)
        sink.set_property("drop", True)
        sink.set_property("sync", False)
        self.pipeline = Gst.Pipeline.new("webcam")
        self.sink = sink
        for element in (source, convert, scale, capsfilter, sink):
            self.pipeline.add(element)
        if not source.link(convert) or not convert.link(scale) or not scale.link(capsfilter) or not capsfilter.link(sink):
            print("webcam preview could not link", file=sys.stderr)
            raise SystemExit(1)
        self.pipeline.set_state(Gst.State.PLAYING)
        change = self.pipeline.get_state(2 * Gst.SECOND)
        if change[0] == Gst.StateChangeReturn.FAILURE:
            print("webcam did not open", file=sys.stderr)
            self.pipeline.set_state(Gst.State.NULL)
            raise SystemExit(1)
        super().__init__()
        GLib.timeout_add(66, self.frame)

    def release(self):
        try:
            self.pipeline.set_state(self.gst.State.NULL)
        except Exception:
            pass

    def frame(self):
        if self.stopped:
            return False
        sample = self.sink.emit("try-pull-sample", 0)
        if sample is None:
            return True
        buf = sample.get_buffer()
        structure = sample.get_caps().get_structure(0)
        width = structure.get_value("width")
        height = structure.get_value("height")
        ok, info = buf.map(self.gst.MapFlags.READ)
        if not ok:
            return True
        raw = bytes(info.data[: width * height * 3])
        buf.unmap(info)
        self.show_rgb(raw, width, height)
        return True


def main():
    args = parse_args()
    if args.v4l2:
        WebcamPreview(args.v4l2)
    else:
        RealSensePreview()
    Gtk.main()


if __name__ == "__main__":
    main()
