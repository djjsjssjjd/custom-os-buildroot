#!/bin/sh
# Start Openbox session; fall back to bare openbox, then twm+xterm.
openbox-session 2>/dev/null || openbox 2>/dev/null || { xterm & exec twm; }
