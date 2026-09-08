<p align="center">
  <img src="https://img.shields.io/badge/Platform-OpenWrt-blue?style=for-the-badge&logo=openwrt" />
  <img src="https://img.shields.io/badge/Hardware-GL--AR300M-green?style=for-the-badge" />
  <img src="https://img.shields.io/badge/License-GPL--3.0-yellow?style=for-the-badge" />
  <img src="https://img.shields.io/badge/UI-CGI%20Dashboard-cyan?style=for-the-badge" />
</p>

<h1 align="center">🦈 JabberJaw</h1>
<p align="center"><b>Pocket-Sized Network Auditing &amp; Diagnostics Toolkit</b></p>
<p align="center"><i>Inspired by the Hak5 Shark Jack — built on commodity hardware and open-source software.</i></p>

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture & Components](#architecture--components)
- [Integrated Payload Modules](#integrated-payload-modules)
- [Prerequisites](#prerequisites)
- [Installation & Deployment](#installation--deployment)
- [Getting Started](#getting-started)
- [Directory Structure](#directory-structure)
- [Screenshots](#screenshots)
- [Legal Disclaimer](#legal-disclaimer)
- [License](#license)

---

## Project Overview

**JabberJaw** turns a low-cost GL-AR300M travel router (or any compatible GL.iNet device running OpenWrt) into a portable, self-contained network auditing appliance — functionally similar to the [Hak5 Shark Jack](https://shop.hak5.org/products/shark-jack), but built entirely from off-the-shelf hardware and open-source components.

### Key Features

- **Plug-and-Scan**: Automatically executes a configurable payload when a cable is plugged into the WAN port — no interaction required.
- **Web Dashboard**: A lightweight, dark-mode CGI dashboard accessible over Wi-Fi or LAN at `http://172.16.24.1:8080`, featuring tabbed views for loot inspection, a live web console, real-time traffic monitoring, and a one-click payload launcher.
- **Physical Toggle**: The hardware slide switch on the GL-AR300M doubles as a mode selector (Active / Cleanup) via a hotplug handler.
- **Modular Payloads**: Drop new `.sh` scripts into `/root/payload/`, register them in the whitelist, and they appear in the web UI — no recompilation, no framework overhead.
- **Zero Dependencies on External Frameworks**: The entire frontend is vanilla HTML, CSS, and JavaScript. The backend is pure POSIX shell, compatible with BusyBox `ash`.

> **Why "JabberJaw"?**  
> Named after the classic cartoon shark — because every good network tool deserves a memorable codename.

---

## Architecture & Components

```
┌─────────────────────────────────────────────────────┐
│                   GL-AR300M (OpenWrt)                │
│                                                     │
│  ┌─────────────┐   ┌──────────────────────────────┐ │
│  │  uhttpd :8080│   │  /root/payload/              │ │
│  │  ┌─────────┐ │   │  ├── payload.sh (default)    │ │
│  │  │ Web UI  │ │──▶│  ├── payload_recon.sh        │ │
│  │  │ (HTML/  │ │   │  ├── payload_tcpdump.sh      │ │
│  │  │  JS/CSS)│ │   │  └── payload_stealth.sh      │ │
│  │  └─────────┘ │   └──────────────────────────────┘ │
│  │  ┌─────────┐ │   ┌──────────────────────────────┐ │
│  │  │CGI Back-│ │   │  /root/loot/nmap/            │ │
│  │  │end      │ │──▶│  ├── nmap-scan_*.txt         │ │
│  │  │loot.sh  │ │   │  ├── recon_*.txt             │ │
│  │  │shell.sh │ │   │  ├── capture_*.pcap          │ │
│  │  │traffic. │ │   │  └── capture_*.tar.gz        │ │
│  │  │sh       │ │   └──────────────────────────────┘ │
│  │  └─────────┘ │                                    │
│  └─────────────┘   ┌──────────────────────────────┐  │
│                    │  Hotplug Triggers             │  │
│                    │  ├── 99-sharkjack (WAN link)  │  │
│                    │  └── 99-sharkjack-switch      │  │
│                    └──────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Backend

| Component | Path | Role |
|---|---|---|
| **Loot Manager** | `/www/loot/cgi-bin/loot.sh` | Lists, views, downloads loot files; executes whitelisted payloads via `?action=execute&script=<id>` |
| **Web Console** | `/www/loot/cgi-bin/shell.sh` | Accepts POST commands, executes them on the device, returns stdout |
| **Traffic Stats** | `/www/loot/cgi-bin/traffic.sh` | Reads `/proc/net/dev` and `nf_conntrack`, returns JSON with RX/TX counters and connection count |
| **Hotplug (WAN)** | `/etc/hotplug.d/iface/99-sharkjack` | Triggers the default payload when the WAN interface comes up |
| **Hotplug (Switch)** | `/etc/hotplug.d/button/99-sharkjack-switch` | Maps the physical toggle to Active mode (BTN_0) and Cleanup mode (BTN_1) |
| **LED Helper** | `/usr/bin/LED` | Abstracts LED control: `LED SUCCESS`, `LED FAIL`, `LED ATTACK`, `LED SETUP`, `LED OFF` |

### Frontend

The dashboard is a single `index.html` file served by `uhttpd`. No build step, no bundler, no npm.

| Tab | Description |
|---|---|
| **Loot** | Lists all scan results with inline syntax-highlighted viewing and direct download |
| **Console** | Full interactive web terminal (command history, arrow-key navigation) |
| **Live Traffic** | Real-time RX/TX throughput for LAN and WAN interfaces, plus active connection count |
| **Payloads** | Card-based launcher for registered payload modules with async execution and toast notifications |

---

## Integrated Payload Modules

> **⚠️ Disclaimer**: These modules are designed exclusively for **authorized network auditing, diagnostics, and educational purposes**. Always obtain explicit written permission before scanning or analyzing any network you do not own.

| Module | Script | Description |
|---|---|---|
| **Default Scan** | `payload.sh` | Fast Nmap host discovery and port scan of the detected subnet. Auto-detects gateway via DHCP with ARP fallback. |
| **Network Recon** | `payload_recon.sh` | Comprehensive reconnaissance: `ifconfig`, ARP table, routing table, DNS configuration, and active host enumeration. |
| **TCPDump Capture** | `payload_tcpdump.sh` | Raw packet capture on the WAN interface for a configurable duration. Outputs `.pcap` files viewable in Wireshark. |
| **Ultra-Stealth Recon** | `payload_stealth.sh` | Passive listening in promiscuous mode. Extracts ARP, DHCP hostnames, and domain names without transmitting any packets. |
| **Rogue DHCP & DNS Logger** | `payload_rogue.sh` | Deploys a secondary `dnsmasq` instance to log DNS queries from clients that connect to the rogue DHCP server. |

All payload output is saved to `/root/loot/nmap/` and immediately visible in the Loot tab of the dashboard.

---

## Prerequisites

### Hardware

| Item | Notes |
|---|---|
| **GL-AR300M** (or compatible GL.iNet router) | NAND version recommended for extra storage. Other models (GL-AR150, GL-MT300N-V2) may work with minor adjustments. |
| **USB flash drive** | Required for `extroot` overlay — the internal flash (~16 MB) is not enough to install all packages (nmap, tcpdump, etc.). A 2–8 GB USB drive formatted as ext4 and mounted as overlay provides the extra space. |
| **Ethernet cable** | For connecting to target networks via WAN port. |
| **USB power source** | The device draws ~2W. Any USB power bank or adapter works. |

### Firmware: Installing OpenWrt

JabberJaw requires **OpenWrt** to be flashed on your GL-AR300M. The stock GL.iNet firmware will **not** work.

> **Tested version**: OpenWrt **25.12.5** — newer releases should be compatible but are untested.

#### Step-by-step:

1. Download the OpenWrt firmware for GL-AR300M from the [official downloads page](https://firmware-selector.openwrt.org/).

2. Flash OpenWrt via the U-Boot recovery  panel at `http://192.168.1.1`.

3. After flashing, the router will reboot. Connect to it via Ethernet and access LuCI at:
    ```
    http://192.168.1.1
    ```

4. Set a root password via SSH or LuCI:
    ```bash
    ssh root@192.168.1.1
    passwd
    ```

5. **Reconfigure the network** — JabberJaw uses `172.16.24.1` as the management IP for both Wi-Fi and LAN, keeping the WAN port free for target networks:
    ```bash
    # Set LAN IP to 172.16.24.1
    uci set network.lan.ipaddr='172.16.24.1'
    uci commit network

    # Set Wi-Fi SSID and enable
    uci set wireless.default_radio0.ssid='JabberJaw'
    uci set wireless.default_radio0.encryption='psk2'
    uci set wireless.default_radio0.key='jabberjaw'
    uci set wireless.radio0.disabled='0'
    uci commit wireless

    # Apply changes
    /etc/init.d/network restart
    wifi
    ```

6. After restarting, the router is reachable at:
    - **Wi-Fi**: Connect to SSID `JabberJaw` (password: `jabberjaw`) → `http://172.16.24.1`
    - **LAN cable**: Plug into the LAN port → `http://172.16.24.1`
    - **WAN port**: Reserved for target networks (payload trigger)

> **⚠️ Important**: After changing the IP to `172.16.24.1`, you will lose the connection at `192.168.1.1`. Reconnect via the new IP or Wi-Fi.

### Software (OpenWrt Packages)

Install via `opkg update && opkg install <package>`:

```bash
# Core (likely already installed)
opkg install uhttpd

# Scanning & capture tools
opkg install nmap tcpdump

# Networking utilities
opkg install ip-full dnsmasq curl

# Optional but recommended
opkg install nano htop
```

> **Note**: Ensure your OpenWrt installation has enough flash space. Run `df -h /` to check. If you're using `extroot` with a USB drive, space won't be an issue.

---

## Installation & Deployment

### 1. Clone the Repository

```bash
git clone https://github.com/skelegamerYT11/jabberjaw.git
cd jabberjaw
```

### 2. Transfer Files to the Router

Use `scp` or the Web Console to copy files to the device:

```bash
# From your local machine
scp -r www/loot/* root@172.16.24.1:/www/loot/
scp -r payload/*   root@172.16.24.1:/root/payload/
scp hotplug/99-sharkjack        root@172.16.24.1:/etc/hotplug.d/iface/
scp hotplug/99-sharkjack-switch root@172.16.24.1:/etc/hotplug.d/button/
scp bin/LED                     root@172.16.24.1:/usr/bin/
```

### 3. Set Executable Permissions

SSH into the router and run:

```bash
ssh root@172.16.24.1

# CGI scripts
chmod +x /www/loot/cgi-bin/loot.sh
chmod +x /www/loot/cgi-bin/shell.sh
chmod +x /www/loot/cgi-bin/traffic.sh

# Payload scripts
chmod +x /root/payload/payload.sh
chmod +x /root/payload/payload_recon.sh
chmod +x /root/payload/payload_tcpdump.sh
chmod +x /root/payload/payload_stealth.sh
chmod +x /root/payload/payload_rogue.sh

# Hotplug handlers
chmod +x /etc/hotplug.d/iface/99-sharkjack
chmod +x /etc/hotplug.d/button/99-sharkjack-switch

# LED utility
chmod +x /usr/bin/LED

# Create loot directory
mkdir -p /root/loot/nmap
```

### 4. Configure uhttpd

Edit `/etc/config/uhttpd` to add the dashboard listener:

```
config uhttpd 'loot'
    list listen_http '0.0.0.0:8080'
    option home '/www/loot'
    option cgi_prefix '/cgi-bin'
    option index_page 'index.html'
```

Then restart the service:

```bash
/etc/init.d/uhttpd restart
```

---

## Getting Started

### Quick Start (From Zero to First Scan)

```bash
# 1. Connect to the JabberJaw Wi-Fi network (SSID: "JabberJaw")
#    Default IP: 172.16.24.1 | Password: jabberjaw

# 2. Open the dashboard in your browser
open http://172.16.24.1:8080

# 3. Option A: Plug an Ethernet cable into the WAN port
#    → The default payload runs automatically
#    → LED blinks green during scan, solid green on success

# 4. Option B: Use the Payloads tab in the dashboard
#    → Click "▶ Execute" on any module card
#    → A toast notification confirms the script has started

# 5. Switch to the Loot tab to view results
#    → Click any report for syntax-highlighted inline viewing
#    → Use the ⬇ Download button to save locally
```

### Adding a Custom Payload

1. Create your script:
    ```bash
    nano /root/payload/payload_custom.sh
    chmod +x /root/payload/payload_custom.sh
    ```

2. Register it in the backend whitelist (`/www/loot/cgi-bin/loot.sh`):
    ```bash
    # Add inside the payload_file() case block:
    custom)   echo "payload_custom.sh" ;;
    ```

3. Add a card in the frontend (`/www/loot/index.html`):
    ```javascript
    // Add to the PAYLOAD_MODULES array:
    {
      id: 'custom',
      name: 'My Custom Module',
      desc: 'Description of what this module does.',
      script: 'payload_custom.sh'
    }
    ```

4. Reload the dashboard — your new module appears instantly.

---

## Directory Structure

```
jabberjaw/
├── www/
│   └── loot/
│       ├── index.html              # Dashboard (single-file frontend)
│       └── cgi-bin/
│           ├── loot.sh             # Loot manager + payload executor
│           ├── shell.sh            # Web console backend
│           └── traffic.sh          # Live traffic stats API
├── payload/
│   ├── payload.sh                  # Default auto-trigger payload
│   ├── payload_recon.sh            # Network reconnaissance
│   ├── payload_tcpdump.sh          # Packet capture
│   ├── payload_stealth.sh          # Passive stealth recon
│   └── payload_rogue.sh            # Rogue DHCP & DNS logger
├── hotplug/
│   ├── 99-sharkjack               # WAN link-up trigger
│   └── 99-sharkjack-switch        # Physical toggle handler
├── bin/
│   └── LED                         # LED abstraction utility
├── README.md
└── LICENSE
```

---

## Screenshots

### Loot Viewer
![Loot tab showing scan reports](https://imgur.com/y1UHfAu.png)

### Web Console
![Console tab with interactive terminal](https://imgur.com/DAVX1Xx.png)

### Live Traffic Monitor
![Live Traffic tab with real-time RX/TX stats](https://imgur.com/PsQbY47.png)

### Payload Launcher
![Payloads tab with module cards](https://imgur.com/p4oHwVL.png)

---

## Legal Disclaimer

> **This tool is provided for authorized security auditing, network diagnostics, and educational purposes only.**
>
> Unauthorized access to computer networks is illegal. You are solely responsible for ensuring you have explicit, written permission from the network owner before using JabberJaw on any network.
>
> The authors of this project accept no liability for misuse, damage, or any legal consequences arising from the use of this software. By using JabberJaw, you agree to comply with all applicable local, state, and federal laws.

---

## Acknowledgements

This project was inspired by the excellent guide by **Samy** on converting a travel router into a portable network auditing device:

> 🔗 [JabberJaw — Convert Your Router into a Portable Network Attack Dev](https://samy.link/blog/jabberjaw-convert-your-router-in-portable-network-attack-dev)

The original concept, name, and core architecture come from that write-up. This repository expands on it with a full web dashboard, modular payload system, and plug-and-play automation.

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

---

<p align="center">
  <b>Built with 🦈 by the JabberJaw community</b><br>
  <i>Turning a $25 travel router into a professional network auditing toolkit.</i>
</p>
