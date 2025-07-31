# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a CustomPiOS-based kiosk system that creates Raspberry Pi images for running Chromium in kiosk mode. The project includes a Hono-based web application for IP configuration.

## Architecture

- **CustomPiOS Module**: Located in `src/modules/fullpageos/` - contains the main OS customization
- **IP Configurator App**: Located in `apps/ip_configurator/` - Deno/Hono web app for network configuration
- **Build System**: Uses CustomPiOS framework with Docker support

### Key Components

- `src/modules/fullpageos/filesystem/` - Contains files that get copied to the target system
- `src/modules/fullpageos/start_chroot_script` - Main installation script run during image build
- `apps/ip_configurator/main.ts` - Hono web server for IP configuration interface

## Development Commands

### IP Configurator App (Deno/Hono)
```bash
cd apps/ip_configurator
deno task start                    # Run development server
deno task compile                  # Compile for ARM64 target
```

### OS Image Building
```bash
# Using Docker (recommended)
docker-compose up

# Direct build (requires CustomPiOS setup)
cd src
sudo bash -x ./build_dist
```

### Testing the IP Configurator
The IP configurator runs on port 8000 and provides a web interface for configuring:
- Touchscreen IP address
- Gateway IP address
- JACE IP address

Configuration is saved to `~/apps/ip_configurator/ip_config.json` and updates `/etc/systemd/network/10-eth0.network`.

## File Structure Context

- `src/modules/fullpageos/filesystem/boot/` - Boot configuration files (urls.txt, etc.)
- `src/modules/fullpageos/filesystem/home/pi/` - Pi user home directory content
- `src/modules/fullpageos/filesystem/root/custom_scripts/` - System setup scripts
- `apps/ip_configurator/` - Self-contained Deno application

## Build Process

The CustomPiOS build process:
1. Downloads base Raspbian image
2. Mounts and modifies the image using chroot
3. Runs `start_chroot_script` to install packages and configure system
4. Copies filesystem overlay from `src/modules/fullpageos/filesystem/`
5. Creates final .img file

All this is done in GitHub Actions (see .github/workflows/main.yml).

## Configuration

Kiosk behavior is controlled by files in `/boot/`:
- `urls.txt` - URLs to display and automation commands
- `autosecure` - Enables random password generation
- `ssh` - Enables SSH access
- `mutesound.txt` - Audio control settings
