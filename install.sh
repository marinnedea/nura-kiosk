#!/bin/sh
# Install, update or remove nura-kiosk. Run ON THE PHONE from the repo folder:
#
#   sudo ./install.sh              install or update (keeps an existing /etc/conf.d/nura-kiosk)
#   sudo ./install.sh --uninstall  stop and remove everything this script installed
#
# The browser runs as the user who invoked sudo/doas (override with KIOSK_USER=name).
set -eu

say() { printf '\033[1m>> %s\033[0m\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo ./install.sh"
command -v apk >/dev/null || die "apk not found - this is meant for Nura (postmarketOS / Alpine)"
command -v openrc-run >/dev/null || [ -x /sbin/openrc-run ] || die "OpenRC not found - only OpenRC installs are supported (pick openrc in pmbootstrap init)"
cd "$(dirname "$0")"

FILES="/etc/init.d/nura-kiosk /etc/init.d/nura-kiosk-keys /usr/local/bin/nura-kiosk-session
/usr/local/bin/nura-kiosk-keys /etc/NetworkManager/conf.d/10-nura-kiosk-dns.conf"

if [ "${1:-}" = "--uninstall" ]; then
	say "stopping and removing nura-kiosk"
	for s in nura-kiosk nura-kiosk-keys; do
		rc-service "$s" stop >/dev/null 2>&1 || true
		rc-update del "$s" default >/dev/null 2>&1 || true
	done
	# shellcheck disable=SC2086
	rm -f $FILES
	sed -i 's|^#tty1::respawn|tty1::respawn|' /etc/inittab && kill -HUP 1 || true
	echo "kept /etc/conf.d/nura-kiosk and installed packages; remove them manually if you want"
	exit 0
fi

KUSER="${KIOSK_USER:-${SUDO_USER:-${DOAS_USER:-}}}"
[ -n "$KUSER" ] && [ "$KUSER" != root ] || die "can't tell which user should run the browser; use: sudo KIOSK_USER=<name> ./install.sh"
id "$KUSER" >/dev/null 2>&1 || die "user '$KUSER' does not exist"

BROWSER=firefox
[ -f /etc/conf.d/nura-kiosk ] && BROWSER=$(sed -n 's/^KIOSK_BROWSER="\{0,1\}\([a-z]*\).*/\1/p' /etc/conf.d/nura-kiosk)

say "installing packages"
apk add -q cage wlr-randr seatd seatd-openrc dbus mesa-dri-gallium mesa-egl \
	font-dejavu font-noto python3 py3-evdev grim "${BROWSER:-firefox}"

say "installing files"
install -m 755 etc/init.d/nura-kiosk etc/init.d/nura-kiosk-keys /etc/init.d/
install -m 755 usr/local/bin/nura-kiosk-session usr/local/bin/nura-kiosk-keys /usr/local/bin/
if [ -d /etc/NetworkManager ]; then
	install -D -m 644 etc/NetworkManager/conf.d/10-nura-kiosk-dns.conf /etc/NetworkManager/conf.d/10-nura-kiosk-dns.conf
fi
if [ -f /etc/conf.d/nura-kiosk ]; then
	echo "   keeping your existing /etc/conf.d/nura-kiosk"
else
	install -m 644 etc/conf.d/nura-kiosk /etc/conf.d/nura-kiosk
	sed -i "s/^KIOSK_USER=.*/KIOSK_USER=\"$KUSER\"/" /etc/conf.d/nura-kiosk
fi

say "system setup (user $KUSER)"
for g in video input seat; do
	getent group "$g" >/dev/null && addgroup "$KUSER" "$g" 2>/dev/null || true
done
# uinput is needed for the Back/Home buttons (built into most kernels; load it if it's a module)
[ -e /dev/uinput ] || modprobe uinput 2>/dev/null || true
[ -e /dev/uinput ] || echo "   warning: /dev/uinput missing - volume-key Back/Home won't work"
# Free tty1 for the kiosk; other VTs keep their login prompts
if grep -q '^tty1::respawn' /etc/inittab; then
	sed -i 's|^tty1::respawn|#tty1::respawn|' /etc/inittab
	kill -HUP 1
fi
for s in dbus seatd nura-kiosk-keys nura-kiosk; do
	rc-update add "$s" default >/dev/null 2>&1 || true
done

say "starting"
[ -d /etc/NetworkManager ] && rc-service networkmanager reload >/dev/null 2>&1 || true
rc-service dbus start >/dev/null 2>&1 || true
rc-service seatd start >/dev/null 2>&1 || true
rc-service nura-kiosk-keys restart >/dev/null 2>&1
rc-service nura-kiosk restart >/dev/null 2>&1
rc-status default | grep -E 'nura-kiosk|seatd'

cat <<EOF

Done. The page should appear on the phone's screen in about 30-60 seconds.
  Settings:  /etc/conf.d/nura-kiosk   (then: sudo rc-service nura-kiosk restart)
  Logs:      /var/log/nura-kiosk.log, /var/log/nura-kiosk-keys.log
EOF
