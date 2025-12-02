# WireGuard Easy - Docker Compose Setup

A simple Docker Compose configuration for [wg-easy](https://github.com/wg-easy/wg-easy), the easiest way to run WireGuard VPN with a Web-based Admin UI.

## Credits

This repository uses [wg-easy](https://github.com/wg-easy/wg-easy) by [@wg-easy](https://github.com/wg-easy), licensed under the [GNU Affero General Public License v3.0](https://www.gnu.org/licenses/agpl-3.0.en.html).

All credit for the WireGuard Easy application goes to the original creators. This repo only provides a pre-configured Docker Compose setup with environment variable management.

## Features

- 🔧 Environment variable configuration via `.env` file
- 🚫 IPv6 disabled by default (easily configurable)
- 🔒 Secure credential management with `.gitignore`
- 📝 Well-documented configuration examples
- 🎯 Split-tunnel VPN setup for LAN access

## Quick Start

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd wg-easy
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and configure at minimum:

- `INIT_USERNAME`: Your admin username
- `INIT_PASSWORD`: A strong password
- `INIT_HOST`: Your server's public IP or domain name

### 3. Prepare the host system

Run the preparation script to configure iptables rules and IP forwarding:

```bash
chmod +x prepare-host.sh
sudo ./prepare-host.sh
```

This script will:
- Enable IP forwarding
- Configure iptables rules to allow traffic between VPN and your LANs
- Read network configuration from your `.env` file

**Note**: iptables rules are not persistent across reboots by default. To make them persistent:

```bash
sudo apt-get install iptables-persistent
sudo netfilter-persistent save
```

### 4. Start the service

```bash
docker compose up -d
```

### 5. Access the Web UI

Open your browser and navigate to:
- `http://your-server-ip:80` (or the port you configured in `PORT`)

### 6. Remove initialization variables

After the first successful startup, edit `.env` and remove or comment out all `INIT_*` variables to avoid exposing credentials.

## Configuration

### Network Setup

- **VPN Network**: `10.32.33.0/24` (configurable via `INIT_IPV4_CIDR`)
- **VPN Port**: `51820/UDP` (configurable via `WG_PORT` and `INIT_PORT`)
- **Web UI Port**: `80/TCP` (configurable via `PORT`)

### Firewall

Make sure to forward the WireGuard port in your firewall:
- **Port**: `51820/UDP` (or your custom `WG_PORT`)

### Split-Tunnel Configuration

By default, this setup routes only LAN traffic through the VPN (`INIT_ALLOWED_IPS=192.168.124.0/23`).

To route all traffic through VPN:
```env
INIT_ALLOWED_IPS=0.0.0.0/0
```

## File Structure

```
.
├── docker-compose.yml    # Docker Compose configuration
├── prepare-host.sh       # Host preparation script (iptables, IP forwarding)
├── .env                  # Your environment variables (git-ignored)
├── .env.example          # Environment variables template
├── .gitignore            # Protects sensitive files
└── README.md             # This file
```

## Environment Variables

See [.env.example](.env.example) for detailed documentation of all available configuration options.

### Key Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `INIT_USERNAME` | Admin username for Web UI | Yes (first start) |
| `INIT_PASSWORD` | Admin password | Yes (first start) |
| `INIT_HOST` | Public IP or domain | Yes (first start) |
| `INIT_PORT` | WireGuard port | Yes (first start) |
| `PORT` | Web UI port | No (default: 51821) |
| `WG_PORT` | Host WireGuard port | No (default: 51820) |
| `DISABLE_IPV6` | Disable IPv6 support | No (default: false) |

## Updating

To update to the latest version of wg-easy:

```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

### Container won't start
- Check logs: `docker compose logs -f`
- Verify `.env` file has correct values
- Ensure WireGuard kernel module is loaded: `lsmod | grep wireguard`

### Can't access Web UI
- Check firewall allows the configured `PORT`
- Verify container is running: `docker compose ps`

### VPN clients can't connect
- Ensure `WG_PORT` is forwarded in your firewall
- Verify `INIT_HOST` matches your public IP/domain
- Check `INIT_PORT` matches `WG_PORT`

## License

This repository is licensed under the [GNU Affero General Public License v3.0](LICENSE), the same license as the original [wg-easy](https://github.com/wg-easy/wg-easy) project.

This means you are free to use, modify, and distribute this configuration, but any modifications must also be released under the same AGPL v3.0 license. If you run a modified version on a network server, you must make the source code available to users.

## Links

- **wg-easy Repository**: https://github.com/wg-easy/wg-easy
- **wg-easy Documentation**: https://wg-easy.github.io/wg-easy/latest/
- **WireGuard Official**: https://www.wireguard.com/
