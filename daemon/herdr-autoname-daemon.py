#!/usr/bin/env python3
"""
herdr-autoname-daemon.py
Background event listener for Herdr multiplexer.
Automatically synchronizes tab numbering (1. folder, 2. folder, ...)
in real time whenever a tab is created, closed, or moved.
"""

import sys
import os
import socket
import json
import time
import re
import signal

SOCKET_PATH = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
RUNNING = True


def signal_handler(signum, frame):
    global RUNNING
    RUNNING = False
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def call_api(method, params, timeout=2.0):
    """
    Executes a short-lived request/response cycle against Herdr's socket API.
    """
    if not os.path.exists(SOCKET_PATH):
        return None
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.settimeout(timeout)
        s.connect(SOCKET_PATH)
        payload = {"id": f"req_{time.time_ns()}", "method": method, "params": params}
        s.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        buf = ""
        while "\n" not in buf:
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk.decode("utf-8")
        if buf.strip():
            return json.loads(buf.strip())
    except Exception as e:
        sys.stderr.write(f"[herdr-autoname] API call error ({method}): {e}\n")
    finally:
        try:
            s.close()
        except Exception:
            pass
    return None


def sync_workspace_tabs():
    """
    Queries session snapshot and ensures all tabs are sequentially
    numbered matching their 1-based index (1. folder, 2. folder...).
    """
    try:
        res = call_api("session.snapshot", {})
        if not res or "result" not in res or "snapshot" not in res["result"]:
            return

        snapshot = res["result"]["snapshot"]

        # Extract pane cwd by tab_id
        panes_cwd = {}
        for p in snapshot.get("panes", []):
            tid = p.get("tab_id")
            cwd = p.get("cwd") or p.get("foreground_cwd", "")
            if tid and cwd and tid not in panes_cwd:
                clean_cwd = cwd.rstrip("/") if cwd != "/" else "/"
                base = "~" if clean_cwd == os.path.expanduser("~") else os.path.basename(clean_cwd)
                panes_cwd[tid] = base or clean_cwd

        # Group tabs by workspace
        tabs_by_ws = {}
        for t in snapshot.get("tabs", []):
            ws = t.get("workspace_id")
            tabs_by_ws.setdefault(ws, []).append(t)

        # Renumber sequentially
        for ws, tabs in tabs_by_ws.items():
            for idx, t in enumerate(tabs, 1):
                tid = t.get("tab_id")
                cur_label = t.get("label", "")

                # Extract clean folder name (remove existing numeric prefix like '3. ')
                m = re.match(r"^\d+\.\s*(.*)$", cur_label)
                if m and m.group(1).strip():
                    folder = m.group(1).strip()
                elif cur_label.strip():
                    folder = cur_label.strip()
                else:
                    folder = panes_cwd.get(tid, str(idx))

                expected_label = f"{idx}. {folder}"
                if cur_label != expected_label:
                    call_api("tab.rename", {"tab_id": tid, "label": expected_label})
    except Exception as e:
        sys.stderr.write(f"[herdr-autoname] Error in sync_workspace_tabs: {e}\n")


def run_daemon():
    global RUNNING
    renumber_events = {
        "tab.closed", "tab_closed",
        "tab.created", "tab_created",
        "tab.moved", "tab_moved",
        "pane.closed", "pane_closed",
        "pane.exited", "pane_exited",
        "workspace.closed", "workspace_closed",
    }

    while RUNNING:
        if not os.path.exists(SOCKET_PATH):
            time.sleep(2)
            continue

        listener_sock = None
        try:
            listener_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            listener_sock.connect(SOCKET_PATH)
            listener_sock.settimeout(1.0)

            # Subscribe to tab & pane lifecycle events on dedicated streaming connection
            sub_req = {
                "id": "stream_sub",
                "method": "events.subscribe",
                "params": {
                    "subscriptions": [
                        {"type": "tab.closed"},
                        {"type": "tab.created"},
                        {"type": "tab.moved"},
                        {"type": "pane.closed"},
                        {"type": "pane.exited"},
                        {"type": "workspace.closed"},
                    ]
                },
            }
            listener_sock.sendall((json.dumps(sub_req) + "\n").encode("utf-8"))

            # Initial sync upon connection
            sync_workspace_tabs()

            buf = ""
            while RUNNING:
                try:
                    chunk = listener_sock.recv(4096)
                    if not chunk:
                        break
                    buf += chunk.decode("utf-8")
                    needs_sync = False
                    while "\n" in buf:
                        line, _, buf = buf.partition("\n")
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            data = json.loads(line)
                            evt = data.get("event") or data.get("data", {}).get("type")
                            if evt in renumber_events:
                                needs_sync = True
                        except json.JSONDecodeError:
                            continue

                    if needs_sync:
                        # Small delay for layout changes to settle in Herdr
                        time.sleep(0.08)
                        sync_workspace_tabs()
                except socket.timeout:
                    continue

        except Exception as e:
            time.sleep(2)
        finally:
            if listener_sock:
                try:
                    listener_sock.close()
                except Exception:
                    pass


def main():
    if "--sync-now" in sys.argv:
        if not os.path.exists(SOCKET_PATH):
            print(f"Herdr socket not found at {SOCKET_PATH}")
            sys.exit(1)
        sync_workspace_tabs()
        print("Herdr tabs renumbered successfully.")
        sys.exit(0)

    run_daemon()


if __name__ == "__main__":
    main()
