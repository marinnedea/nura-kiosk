#!/bin/sh
# Install nura-kiosk from your computer: copies this folder to the phone over SSH and runs
# install.sh there (you'll be asked for your sudo password on the phone).
#
#   ./deploy.sh user@device                 install or update
#   ./deploy.sh user@device --uninstall     remove
set -eu
[ $# -ge 1 ] || { echo "usage: $0 user@device [--uninstall]"; exit 1; }
TARGET="$1"; shift
cd "$(dirname "$0")"

echo ">> copying to $TARGET:/tmp/nura-kiosk"
tar czf - install.sh etc usr | ssh "$TARGET" 'rm -rf /tmp/nura-kiosk && mkdir -p /tmp/nura-kiosk && tar xzf - -C /tmp/nura-kiosk'

echo ">> running install.sh on $TARGET"
ssh -t "$TARGET" "sudo sh /tmp/nura-kiosk/install.sh $*; rm -rf /tmp/nura-kiosk"
