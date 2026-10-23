#!/usr/bin/env python3
"""Classic VNC password login for macOS Screen Sharing.

Ubuntu wayvnc 0.9 offers Apple and VeNCrypt logins. Screen Sharing refuses
those and reports a firewall error before it asks for a password. This process
listens on the network, checks the 8-character VNC password, and then connects
the Mac to wayvnc on localhost. Screen Sharing asks for depth 32. wayvnc then
writes 4 bytes per pixel, while the Mac reads 3, so the window flashes with
no desktop. This process reports depth 24, asks for a ZRLE or raw picture,
and turns the Mac Command key into Super. The local connection is not left
on the connect timer, or Screen Sharing closes and redraws after a few quiet
seconds.
"""
import argparse
import hmac
import os
import socket
import subprocess
import sys
import threading


def recvn(sock, count):
    buf = bytearray()
    while len(buf) < count:
        chunk = sock.recv(count - len(buf))
        if not chunk:
            raise ConnectionError("connection closed")
        buf += chunk
    return bytes(buf)


def vnc_des_key(password):
    raw = password.encode("latin1", "replace")[:8]
    raw = raw.ljust(8, b"\x00")
    return bytes(int(f"{byte:08b}"[::-1], 2) for byte in raw)


def des_encrypt(key, block):
    proc = subprocess.run(
        [
            "openssl",
            "enc",
            "-des-ecb",
            "-nopad",
            "-K",
            key.hex(),
            "-provider",
            "legacy",
        ],
        input=block,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0 or len(proc.stdout) != len(block):
        raise RuntimeError("openssl DES failed")
    return proc.stdout


def vnc_response(password, challenge):
    return des_encrypt(vnc_des_key(password), challenge)


def client_version(banner):
    text = banner.decode("ascii", "replace").strip()
    numbers = text.split(" ", 1)[-1]
    major, minor = numbers.split(".", 1)
    return int(major), int(minor)


def handshake_upstream(upstream, shared):
    banner = recvn(upstream, 12)
    if not banner.startswith(b"RFB "):
        raise RuntimeError("wayvnc banner was not RFB")
    upstream.sendall(b"RFB 003.008\n")
    count = recvn(upstream, 1)[0]
    types = recvn(upstream, count)
    if 1 not in types:
        raise RuntimeError("wayvnc did not offer an open local login")
    upstream.sendall(bytes([1]))
    result = recvn(upstream, 4)
    if result != b"\x00\x00\x00\x00":
        raise RuntimeError("wayvnc rejected the local connection")
    upstream.sendall(bytes([shared]))


def screen_pixel_format(msg):
    """Make a 32-bit format use the 3-byte pixels Screen Sharing reads."""
    if len(msg) != 20 or msg[0] != 0:
        return msg
    bpp = msg[4]
    depth = msg[5]
    true_color = msg[7]
    red = int.from_bytes(msg[8:10], "big")
    green = int.from_bytes(msg[10:12], "big")
    blue = int.from_bytes(msg[12:14], "big")
    if bpp == 32 and depth > 24 and true_color == 1 and (red, green, blue) == (255, 255, 255):
        adjusted = bytearray(msg)
        adjusted[5] = 24
        return bytes(adjusted)
    return msg


def mac_command_key(msg):
    """Screen Sharing sends Command as Alt and Option as Meta.

    That is what another Mac expects. This desktop uses Super and Alt.
    """
    if len(msg) != 8 or msg[0] != 4:
        return msg
    keysym = int.from_bytes(msg[4:8], "big")
    mapped = {
        0xFFE9: 0xFFEB,  # Alt_L, Command -> Super_L
        0xFFEA: 0xFFEC,  # Alt_R, Command -> Super_R
        0xFFE7: 0xFFE9,  # Meta_L, Option -> Alt_L
        0xFFE8: 0xFFEA,  # Meta_R, Option -> Alt_R
    }.get(keysym)
    if mapped is None:
        return msg
    return msg[:4] + mapped.to_bytes(4, "big")


def rewrite_encodings(requested):
    """Keep the picture formats Screen Sharing can draw.

    wayvnc uses the first of ZRLE, Tight, or raw. Tight and the cursor image
    are what make the Mac window flash. ZRLE is a complete desktop image.
    """
    chosen = [code for code in (16, 0) if code in requested]
    if -223 in requested:
        chosen.append(-223)
    if 16 not in chosen and 0 not in chosen:
        chosen.insert(0, 0)
    return chosen


class ClientMessages:
    """Forward client messages, with the picture request adjusted."""

    def __init__(self):
        self.buf = bytearray()
        self.passthrough = False
        self.full_frame_sent = False

    def feed(self, data):
        if self.passthrough:
            return data
        self.buf += data
        out = bytearray()
        while True:
            msg = self.pop()
            if msg is None:
                break
            out += msg
        return bytes(out)

    def take(self, size):
        if len(self.buf) < size:
            return None
        msg = bytes(self.buf[:size])
        del self.buf[:size]
        return msg

    def pop(self):
        if not self.buf:
            return None
        kind = self.buf[0]
        if kind == 0:
            msg = self.take(20)
            if msg is None:
                return None
            return screen_pixel_format(msg)
        if kind == 2:
            if len(self.buf) < 4:
                return None
            count = int.from_bytes(self.buf[2:4], "big")
            if count > 64:
                return self.pass_rest()
            raw = self.take(4 + 4 * count)
            if raw is None:
                return None
            requested = [
                int.from_bytes(raw[4 + 4 * i : 8 + 4 * i], "big", signed=True)
                for i in range(count)
            ]
            chosen = rewrite_encodings(requested)
            body = b"".join(
                code.to_bytes(4, "big", signed=True) for code in chosen
            )
            return bytes([2, 0]) + len(chosen).to_bytes(2, "big") + body
        if kind == 3:
            msg = self.take(10)
            if msg is None:
                return None
            if not self.full_frame_sent:
                msg = bytes([msg[0], 0]) + msg[2:]
                self.full_frame_sent = True
            return msg
        if kind == 4:
            msg = self.take(8)
            if msg is None:
                return None
            return mac_command_key(msg)
        if kind == 5:
            return self.take(6)
        if kind == 6:
            if len(self.buf) < 8:
                return None
            length = int.from_bytes(self.buf[4:8], "big", signed=True)
            if length < 0 or length > 1_000_000:
                return self.pass_rest()
            return self.take(8 + length)
        if kind == 150:
            return self.take(10)
        return self.pass_rest()

    def pass_rest(self):
        self.passthrough = True
        rest = bytes(self.buf)
        self.buf.clear()
        return rest


def splice(left, right):
    def pump(src, dst, client_side):
        messages = ClientMessages() if client_side else None
        try:
            while True:
                data = src.recv(65536)
                if not data:
                    break
                if messages is not None:
                    data = messages.feed(data)
                    if not data:
                        continue
                dst.sendall(data)
        except (ConnectionError, OSError):
            pass
        finally:
            for sock, how in ((src, socket.SHUT_RD), (dst, socket.SHUT_WR)):
                try:
                    sock.shutdown(how)
                except OSError:
                    pass

    threads = [
        threading.Thread(target=pump, args=(left, right, True), daemon=True),
        threading.Thread(target=pump, args=(right, left, False), daemon=True),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()


def serve_client(client, password, upstream_host, upstream_port):
    try:
        # Screen Sharing answers "RFB 003.008" by falling back to protocol 3.3.
        # 3.3 is one 4-byte security type and then the challenge, not a list.
        client.sendall(b"RFB 003.008\n")
        banner = recvn(client, 12)
        if not banner.startswith(b"RFB "):
            return
        _major, minor = client_version(banner)
        legacy = minor < 7
        if legacy:
            client.sendall((2).to_bytes(4, "big"))
        else:
            client.sendall(bytes([1, 2]))
            chosen = recvn(client, 1)[0]
            if chosen != 2:
                client.sendall(b"\x00\x00\x00\x01")
                return
        challenge = os.urandom(16)
        client.sendall(challenge)
        response = recvn(client, 16)
        if not hmac.compare_digest(response, vnc_response(password, challenge)):
            if not legacy:
                client.sendall(b"\x00\x00\x00\x01")
            return
        # Screen Sharing waits for this result on both protocol 3.3 and 3.8
        # before it sends ClientInit. Without it, the window stays on Connecting.
        client.sendall(b"\x00\x00\x00\x00")
        shared = recvn(client, 1)[0]
        upstream = socket.create_connection((upstream_host, upstream_port), 5)
        # create_connection leaves this timeout on the socket. A quiet desktop
        # then closes after 5 seconds and Screen Sharing opens a new picture.
        upstream.settimeout(None)
        try:
            handshake_upstream(upstream, shared)
        except (ConnectionError, OSError, RuntimeError):
            upstream.close()
            return
        splice(client, upstream)
        upstream.close()
    except (ConnectionError, OSError, RuntimeError):
        return
    finally:
        client.close()


def listen(host, port, password, upstream_host, upstream_port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((host, port))
    server.listen(4)
    while True:
        client, _addr = server.accept()
        threading.Thread(
            target=serve_client,
            args=(client, password, upstream_host, upstream_port),
            daemon=True,
        ).start()


def encoding_message(codes):
    body = b"".join(code.to_bytes(4, "big", signed=True) for code in codes)
    return bytes([2, 0]) + len(codes).to_bytes(2, "big") + body


def self_test():
    password = "testpass"
    challenge = bytes(range(16))
    expected = vnc_response(password, challenge)
    if vnc_response(password, challenge) != expected or len(expected) != 16:
        raise SystemExit("DES response was not stable")
    if rewrite_encodings([7, -239, -308, -313, 16, 0, -223]) != [16, 0, -223]:
        raise SystemExit("picture formats were not limited to ZRLE and raw")
    if rewrite_encodings([7, -239]) != [0]:
        raise SystemExit("Tight-only clients were not given a raw picture")
    depth32 = bytes([0, 0, 0, 0, 32, 32, 0, 1, 0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0])
    if screen_pixel_format(depth32)[5] != 24:
        raise SystemExit("depth 32 was not reported as 24")
    command = bytes([4, 1, 0, 0]) + (0xFFE9).to_bytes(4, "big")
    if int.from_bytes(mac_command_key(command)[4:8], "big") != 0xFFEB:
        raise SystemExit("Command was not mapped to Super")
    option = bytes([4, 1, 0, 0]) + (0xFFE7).to_bytes(4, "big")
    if int.from_bytes(mac_command_key(option)[4:8], "big") != 0xFFE9:
        raise SystemExit("Option was not mapped to Alt")

    upstream = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    upstream.bind(("127.0.0.1", 0))
    upstream.listen(2)
    upstream_port = upstream.getsockname()[1]

    def read_encodings(conn):
        head = recvn(conn, 4)
        if head[0] != 2:
            raise SystemExit("picture request was not forwarded")
        count = int.from_bytes(head[2:4], "big")
        body = recvn(conn, 4 * count)
        return [
            int.from_bytes(body[4 * i : 4 * i + 4], "big", signed=True)
            for i in range(count)
        ]

    def fake_wayvnc():
        for index in range(2):
            conn, _addr = upstream.accept()
            conn.sendall(b"RFB 003.008\n")
            if recvn(conn, 12) != b"RFB 003.008\n":
                raise SystemExit("proxy sent the wrong banner upstream")
            conn.sendall(bytes([1, 1]))
            if recvn(conn, 1) != b"\x01":
                raise SystemExit("proxy did not choose the open local login")
            conn.sendall(b"\x00\x00\x00\x00")
            if recvn(conn, 1) != b"\x01":
                raise SystemExit("proxy did not send ClientInit")
            conn.sendall(b"SERVERINIT")
            if index == 0:
                pixel_format = recvn(conn, 20)
                if pixel_format[5] != 24:
                    raise SystemExit("wayvnc was still told to use 4-byte pixels")
                if read_encodings(conn) != [16, 0, -223]:
                    raise SystemExit("wayvnc was still offered the flashing formats")
                request = recvn(conn, 10)
                if request[1] != 0:
                    raise SystemExit("the first picture request was not a full frame")
            else:
                try:
                    recvn(conn, 4)
                except ConnectionError:
                    pass
            conn.close()

    threading.Thread(target=fake_wayvnc, daemon=True).start()
    proxy = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    proxy.bind(("127.0.0.1", 0))
    proxy.listen(2)
    proxy_port = proxy.getsockname()[1]

    def accept_both():
        for _ in range(2):
            client, _addr = proxy.accept()
            threading.Thread(
                target=serve_client,
                args=(client, password, "127.0.0.1", upstream_port),
                daemon=True,
            ).start()

    threading.Thread(target=accept_both, daemon=True).start()

    client = socket.create_connection(("127.0.0.1", proxy_port), 2)
    if recvn(client, 12) != b"RFB 003.008\n":
        raise SystemExit("proxy banner was not RFB 003.008")
    client.sendall(b"RFB 003.008\n")
    offered = recvn(client, 2)
    if offered != bytes([1, 2]):
        raise SystemExit(f"proxy offered {list(offered)}, not VNC password only")
    client.sendall(bytes([2]))
    server_challenge = recvn(client, 16)
    client.sendall(vnc_response(password, server_challenge))
    if recvn(client, 4) != b"\x00\x00\x00\x00":
        raise SystemExit("correct password was rejected")
    client.sendall(bytes([1]))
    if recvn(client, len(b"SERVERINIT")) != b"SERVERINIT":
        raise SystemExit("desktop data did not pass through")
    client.sendall(bytes([0, 0, 0, 0, 32, 32, 0, 1, 0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0]))
    client.sendall(encoding_message([7, -239, -308, -313, 16, 0, -223]))
    client.sendall(bytes([3, 1, 0, 0, 0, 0, 7, 128, 4, 56]))
    client.close()
    legacy = socket.create_connection(("127.0.0.1", proxy_port), 2)
    if recvn(legacy, 12) != b"RFB 003.008\n":
        raise SystemExit("legacy banner was not RFB 003.008")
    legacy.sendall(b"RFB 003.003\n")
    if recvn(legacy, 4) != (2).to_bytes(4, "big"):
        raise SystemExit("protocol 3.3 was not offered the VNC password type")
    legacy_challenge = recvn(legacy, 16)
    legacy.sendall(vnc_response(password, legacy_challenge))
    if recvn(legacy, 4) != b"\x00\x00\x00\x00":
        raise SystemExit("protocol 3.3 did not accept the password")
    legacy.sendall(bytes([1]))
    if recvn(legacy, len(b"SERVERINIT")) != b"SERVERINIT":
        raise SystemExit("protocol 3.3 desktop data did not pass through")
    legacy.close()
    print("vnc proxy self-test passed")


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        self_test()
        return
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen", default="0.0.0.0:5900")
    parser.add_argument("--upstream", default="127.0.0.1:5901")
    parser.add_argument("--password-file", required=True)
    args = parser.parse_args()
    listen_host, listen_port = args.listen.rsplit(":", 1)
    upstream_host, upstream_port = args.upstream.rsplit(":", 1)
    with open(args.password_file, encoding="utf-8") as handle:
        password = handle.read().strip()
    if not password:
        raise SystemExit("password file is empty")
    listen(listen_host, int(listen_port), password, upstream_host, int(upstream_port))


if __name__ == "__main__":
    main()
