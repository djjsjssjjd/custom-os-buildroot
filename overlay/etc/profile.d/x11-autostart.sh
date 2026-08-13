# Auto-launch X + Openbox on console login, but only when a display device
# actually exists (virtio-gpu). Serial-only boots stay on the shell.
if [ -z "$DISPLAY" ] && [ -e /dev/fb0 ]; then
    case "$(tty)" in
        /dev/console|/dev/tty1|/dev/ttyAMA0) exec startx ;;
    esac
fi
