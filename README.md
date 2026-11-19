# nura-kiosk

Turn an old phone into an always-on wall display for a web dashboard (Grafana, Home Assistant,
an uptime page, anything with a URL).

The phone runs [Nura](https://nura.eco/) (formerly postmarketOS), a real Linux distribution for
phones. nura-kiosk adds a minimal full-screen browser on the phone's own screen, starts it at
boot, and lets you use the volume buttons to navigate.

- Full-screen browser, no desktop: [cage](https://github.com/cage-kiosk/cage) (a single-app Wayland compositor) + Firefox in kiosk mode
- Starts automatically at boot and restarts if the browser crashes
- Landscape or portrait, adjustable zoom and brightness
- **Volume Down = Back, Volume Up = Home**, plus automatic return to your dashboard after a few minutes without touch
- Everything is configured in one file, `/etc/conf.d/nura-kiosk`

> **Status: tested on one phone only.** It's been tested on a **Samsung Galaxy A6+ (2018)**, and
> that's the only device we currently know it works on. Nothing in it is specific to that phone,
> so it should work on other devices that Nura supports with a working display. If you try it on
> another phone, please open an issue with the result, whether it works or not.

## Tested devices

| Device | Nura codename | Result | Notes |
|---|---|---|---|
| Samsung Galaxy A6+ (2018) | `samsung-a6plte` | ✅ Works | Firefox GPU-accelerated. Chromium runs only in software mode (slow). |

## What you need

- A phone that Nura supports, with a **working display** (and ideally touch and Wi-Fi). Check the
  [Nura devices page](https://wiki.nura.eco/wiki/Devices) for your model and what works on it.
- A Linux computer to install Nura with (or a prebuilt image if your phone has one).
- A phone you're willing to wipe. Installing Nura erases Android, and flashing always carries some risk.
- A USB cable and a charger: the phone will stay plugged in.

## Step 1: Install Nura on the phone

Read these first. They're short and will save you time:

1. [State of Nura](https://nura.eco/state/): what to expect.
2. [Devices](https://wiki.nura.eco/wiki/Devices): find your phone and open its wiki page. It lists
   what works, the install method and known problems.
3. [Install Nura](https://nura.eco/install/): prebuilt images for well-supported phones.
4. [Installation guide](https://wiki.nura.eco/wiki/Installation_guide) and the
   [pmbootstrap docs](https://docs.nura.eco/pmbootstrap/): building and flashing your own image.

When you set up the image with `pmbootstrap init`, these choices work best for a kiosk:

| Setting | Choose | Why |
|---|---|---|
| User interface | `none` | console only; nura-kiosk provides the graphics |
| Service manager / init | `openrc` | nura-kiosk ships OpenRC services (systemd isn't supported yet) |
| SSH | enabled, with your public key added | you'll do the rest remotely |
| Extra packages | `networkmanager,networkmanager-wifi,networkmanager-cli,networkmanager-tui,wpa_supplicant` | Wi-Fi from the console |

If you use a prebuilt image with a desktop UI instead, that can work too, but it's untested.
Prebuilt images log in as `user` with password `147147`, so change it with `passwd`.

## Step 2: Get the phone online

Right after the first boot, the phone is usually reachable over the USB cable
(see the [SSH page](https://wiki.nura.eco/wiki/SSH#Start_the_SSH_Daemon)):

```sh
ssh user@172.16.42.1
```

Connect it to Wi-Fi (`sudo nmtui` gives you a menu), make NetworkManager start at boot, and
update the system:

```sh
sudo rc-update add networkmanager default
sudo nmtui
sudo apk update && sudo apk upgrade -a
```

From now on you can SSH in over Wi-Fi with `ssh user@<phone-ip>`.

## Step 3: Install nura-kiosk

Pick one.

**A) On the phone** (logged in over SSH):

```sh
sudo apk add git
git clone https://github.com/marinnedea/nura-kiosk.git
cd nura-kiosk
sudo ./install.sh
```

**B) From your computer** (copies the files over SSH and runs the same installer on the phone):

```sh
git clone https://github.com/marinnedea/nura-kiosk.git
cd nura-kiosk
./deploy.sh user@<phone-ip>
```

The installer adds the packages it needs (cage, Firefox, seatd, Python evdev…), installs two
services, frees the first console (tty1) for the display, and starts everything. The browser
runs as the user who ran `sudo`. After 30–60 seconds the demo dashboard
([Grafana Play](https://play.grafana.org)) appears on the screen.

To update later, pull the repo and run the same command again. Your settings file is kept.

## Step 4: Show your own page

Edit the settings and restart:

```sh
sudo nano /etc/conf.d/nura-kiosk
sudo rc-service nura-kiosk restart
```

| Setting | Default | What it does |
|---|---|---|
| `KIOSK_URL` | Grafana Play | The page to show. For Grafana, add `&kiosk&theme=dark` to the dashboard URL. |
| `KIOSK_TRANSFORM` | `normal` | Rotation: `normal` (or `0`), `90`, `180`, `270`. `normal` is the phone's native portrait and the smoothest; `90`/`270` = landscape (try the other one if it's upside down). See the rotation note below. |
| `KIOSK_ZOOM` | `1.5` | Page zoom. Raise it if text is too small. |
| `KIOSK_SCALE` | `1` | Screen scale. **Leave at 1** and use `KIOSK_ZOOM`. Fractional values make the browser much slower. |
| `KIOSK_BRIGHTNESS` | `35` | Backlight in percent. |
| `KIOSK_BROWSER` | `firefox` | `firefox` or `chromium`. Firefox is recommended. |
| `KIOSK_GPU` | `off` | Chromium only: `off`, `angle-gles`, `angle-gl`, `egl`. Try these if Chromium is slow on your phone. |
| `KIOSK_IDLE_HOME` | `300` | Seconds without touch before returning to `KIOSK_URL` (`0` = never). |
| `KIOSK_USER` | the installing user | User the browser runs as. |

**Portrait or landscape?** Portrait is much smoother. It's the screen's native orientation, so
the compositor passes the browser's frames straight to the display. In landscape it has to
rotate every frame on the GPU at full resolution, which makes scrolling and animations laggy
on phone hardware. Landscape is fine for dashboards that mostly sit still and refresh every
minute or so. Note that in portrait, Grafana switches to its mobile layout and stacks panels in
one column.

**Dashboard tips:** phones are slow at heavy web apps, so design the dashboard to fit on one
screen without scrolling, and use a dark theme. With `KIOSK_ZOOM=1.5` on a 1080×2220 phone the
page sees roughly 720×1480 pixels in portrait, or 1480×720 in landscape.

## Using it

| Action | How |
|---|---|
| Back | Volume Down |
| Home (back to `KIOSK_URL`) | Volume Up |
| Auto-home | happens `KIOSK_IDLE_HOME` seconds after the last touch |
| Text console | Ctrl+Alt+F2 with a USB/Bluetooth keyboard |

Remote control over SSH:

```sh
# Home / Back
sudo kill -USR1 $(pgrep -f '^/usr/bin/python3 /usr/local/bin/nura-kiosk-keys')
sudo kill -USR2 $(pgrep -f '^/usr/bin/python3 /usr/local/bin/nura-kiosk-keys')

# Restart the browser
sudo rc-service nura-kiosk restart

# Screenshot of what's on the screen (replace 1000 with: id -u <kiosk user>)
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 grim /tmp/screen.png
```

## Uninstall

```sh
sudo ./install.sh --uninstall          # on the phone
./deploy.sh user@<phone-ip> --uninstall  # or from your computer
```

This stops and removes the services and scripts and gives tty1 back to the login prompt.
Your settings file and the installed packages are kept.

## Troubleshooting

Logs: `/var/log/nura-kiosk.log` (compositor and browser) and `/var/log/nura-kiosk-keys.log` (buttons).

| Problem | Try |
|---|---|
| Screen stays black or white | Check `/var/log/nura-kiosk.log`. With Chromium, set `KIOSK_GPU="off"` or switch to Firefox. Make sure the phone's display works in Nura (see its wiki page). |
| "This site can't be reached" / DNS error | Test with `nslookup example.com` on the phone. If `/etc/resolv.conf` has no `nameserver` line, see the DNS note below. |
| Very slow | Keep `KIOSK_SCALE="1"`, use Firefox, simplify the page. Check `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq` to confirm CPU frequency scaling works on your port. |
| Upside down | Switch `KIOSK_TRANSFORM` between `90` and `270`. |
| Volume buttons do nothing | `/var/log/nura-kiosk-keys.log` lists the devices it found. `/dev/uinput` must exist. Restart both services: `sudo rc-service nura-kiosk-keys restart && sudo rc-service nura-kiosk restart`. |
| Touch is off-target | Your port may not map touch to the rotated screen; please report it in an issue. |

**DNS note:** if Tailscale (or anything else that pulls in `openresolv`) is installed,
NetworkManager can end up writing an empty `/etc/resolv.conf`. The installer adds
`/etc/NetworkManager/conf.d/10-nura-kiosk-dns.conf` (`rc-manager=file`) to prevent that.

## Running a phone 24/7

- **Burn-in:** OLED screens burn in with static content. Use dark themes and low brightness,
  and turn the screen off when nobody's looking (overnight screen-off is planned).
- **Battery:** the phone stays on the charger permanently. Some Nura ports can't report battery
  level or charging state yet (the tested phone can't), so check now and then that the back
  isn't bulging, and don't leave a swollen phone in service.
- **Power:** a USB port on a computer may not supply enough current for screen + browser. A
  proper wall charger is safer.

## Notes from the Galaxy A6+ (2018)

What we ran into on the tested phone. It may help on similar hardware (Snapdragon 450/625/632,
`msm8953`):

- Firefox renders with the GPU (Adreno 506, Mesa freedreno). Chromium's GPU process crashes
  with ANGLE, and `--use-gl=egl` silently falls back to software, so Chromium works only in software mode.
- A fractional screen scale (1.5) made the browser render at 2× and downscale, which was very slow. Scale 1 plus browser zoom fixed it.
- Landscape (rotated) scrolling was laggy even with the GPU working. In portrait (no rotation)
  scrolling is smooth.
- Firefox ignores the Wayland virtual-keyboard protocol (`wtype`), so the buttons inject keys
  through a kernel `uinput` device. cage only sees keyboards that exist when it starts, so the
  button service always starts first.
- No battery fuel gauge driver: only the charger's `online` value is reliable.
- One unexplained hang on the boot logo; booting through the bootloader menu worked, and later reboots were fine.

## How it works

```
OpenRC
├── nura-kiosk-keys   python-evdev daemon: watches volume keys + touchscreen,
│                     creates a uinput keyboard, sends Alt+Left / Alt+Home
└── nura-kiosk        cage (on seatd) as KIOSK_USER
    └── nura-kiosk-session   rotation/scale, waits for DNS, starts Firefox/Chromium in kiosk mode
```

| File | Purpose |
|---|---|
| `install.sh` | install / update / `--uninstall`, run on the phone |
| `deploy.sh` | runs `install.sh` on the phone from your computer |
| `etc/conf.d/nura-kiosk` | settings |
| `etc/init.d/nura-kiosk`, `etc/init.d/nura-kiosk-keys` | OpenRC services |
| `usr/local/bin/nura-kiosk-session` | runs inside cage, launches the browser |
| `usr/local/bin/nura-kiosk-keys` | button and idle navigation daemon |
| `etc/NetworkManager/conf.d/10-nura-kiosk-dns.conf` | DNS fix (see above) |

## Contributing

Tried it on another phone? Open an issue with the device, its Nura codename, and what worked
(display, rotation, touch, buttons, GPU, speed). It will be added to the table above.

## Disclaimer

This is an independent project. It is not affiliated with or endorsed by Nura/postmarketOS.
Flashing a phone erases it and can, in rare cases, make it unusable. You do this at your own risk.

## License

[MIT](LICENSE)
