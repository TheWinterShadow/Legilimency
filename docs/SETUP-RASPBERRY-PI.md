# Raspberry Pi Setup Guide

This guide covers setting up your Raspberry Pi for the multi-cloud monitoring stack.

## Hardware Requirements

### Recommended Setup

| Component | Specification | Notes |
|-----------|---------------|-------|
| Raspberry Pi | Pi 4, 4GB RAM | 8GB preferred for future expansion |
| Storage | 32GB+ microSD | A2 rated for better I/O |
| Power Supply | Official USB-C 5V/3A | Avoid cheap adapters (causes instability) |
| Cooling | Heatsink + fan case | Required for 24/7 operation |
| Network | Ethernet recommended | WiFi works but less reliable |

### Minimum Requirements

- Raspberry Pi 4, 2GB RAM (will be memory-constrained)
- 16GB microSD card
- Stable power supply (2.5A minimum)
- Network connectivity

## Operating System Installation

### 1. Download Ubuntu Server

Download Ubuntu Server 22.04 LTS (ARM64):

- https://ubuntu.com/download/raspberry-pi

Or use Raspberry Pi Imager:

- https://www.raspberrypi.com/software/

### 2. Flash the SD Card

Using Raspberry Pi Imager:

1. Download and install Raspberry Pi Imager
2. Click "Choose OS" → "Other general-purpose OS" → "Ubuntu" → "Ubuntu Server 22.04 LTS (64-bit)"
3. Click "Choose Storage" → Select your microSD card
4. Click the gear icon (⚙️) for advanced options:
   - Set hostname: `monitoring-pi`
   - Enable SSH with password authentication
   - Set username and password
   - Configure WiFi (if needed)
   - Set locale settings
5. Click "Write"

### 3. First Boot

1. Insert the SD card into your Raspberry Pi
2. Connect Ethernet cable (recommended)
3. Connect power supply
4. Wait 2-3 minutes for first boot to complete

### 4. Find Your Pi's IP Address

Option A - Check your router's admin interface for connected devices

Option B - Use nmap to scan your network:

```bash
nmap -sn 192.168.1.0/24 | grep -B2 "Raspberry"
```

Option C - If you have a monitor connected:

```bash
ip addr show eth0 | grep inet
```

### 5. SSH into the Pi

```bash
ssh ubuntu@<pi-ip-address>
# Default password: ubuntu (you'll be prompted to change it)
```

## System Configuration

### 1. Update the System

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Set Static IP Address (Recommended)

Edit netplan configuration:

```bash
sudo nano /etc/netplan/50-cloud-init.yaml
```

Replace contents with:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24  # Change to your desired IP
      gateway4: 192.168.1.1  # Your router's IP
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

Apply changes:

```bash
sudo netplan apply
```

### 3. Set Timezone

```bash
sudo timedatectl set-timezone America/Los_Angeles  # Change to your timezone
```

List available timezones:

```bash
timedatectl list-timezones
```

### 4. Configure Swap (Optional but Recommended)

The 4GB model benefits from swap for memory-intensive operations:

```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

## Docker Installation

### 1. Install Docker

```bash
# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### 2. Post-Installation Steps

```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# Start Docker on boot
sudo systemctl enable docker

# Apply group changes (or log out and back in)
newgrp docker
```

### 3. Verify Installation

```bash
docker --version
docker compose version
docker run hello-world
```

## Security Hardening

### 1. Configure Firewall

```bash
# Install ufw
sudo apt install -y ufw

# Default deny incoming, allow outgoing
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (change port if using non-standard)
sudo ufw allow ssh

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### 2. Disable Password Authentication (Optional)

After setting up SSH keys:

```bash
# Generate SSH key on your local machine (if not already done)
# ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key to Pi
# ssh-copy-id ubuntu@<pi-ip-address>

# Disable password authentication
sudo nano /etc/ssh/sshd_config
```

Set these options:

```
PasswordAuthentication no
PubkeyAuthentication yes
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

### 3. Enable Automatic Security Updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 4. Install Fail2ban (Optional)

```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Performance Optimization

### 1. Reduce GPU Memory (Headless Server)

```bash
sudo nano /boot/firmware/config.txt
```

Add:

```
gpu_mem=16
```

### 2. Disable Unnecessary Services

```bash
# Disable Bluetooth (if not needed)
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth

# Disable WiFi (if using Ethernet)
sudo systemctl disable wpa_supplicant
```

### 3. Enable cgroups for Docker

Edit boot config:

```bash
sudo nano /boot/firmware/cmdline.txt
```

Add to the end of the line (same line, space-separated):

```
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```

Reboot:

```bash
sudo reboot
```

## Monitoring Setup

### 1. Clone the Repository

```bash
cd ~
git clone https://github.com/yourusername/raspberry-pi-monitoring.git
cd raspberry-pi-monitoring
```

### 2. Create Configuration

```bash
cp .env.example .env
nano .env  # Fill in your credentials
```

### 3. Run Setup Script

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

## Maintenance

### Automatic Reboots (Optional)

Schedule weekly reboots for memory cleanup:

```bash
sudo crontab -e
```

Add:

```
0 4 * * 0 /sbin/reboot
```

### Log Rotation

Docker logs are automatically rotated. For system logs:

```bash
sudo nano /etc/logrotate.d/rsyslog
```

Ensure reasonable rotation settings:

```
/var/log/syslog
{
    rotate 7
    daily
    missingok
    notifempty
    compress
    delaycompress
}
```

### Backup Important Files

Create a backup script:

```bash
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/monitoring-config-$(date +%Y%m%d).tar.gz \
    ~/raspberry-pi-monitoring/.env \
    ~/raspberry-pi-monitoring/configs/
```

## Troubleshooting

### High CPU Usage

Check which container is using resources:

```bash
docker stats
```

### Memory Issues

Check memory usage:

```bash
free -h
```

If running low, try:

```bash
# Clear caches
sudo sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
```

### Network Issues

Check connectivity:

```bash
# Test DNS
nslookup google.com

# Test HTTPS
curl -I https://grafana.com

# Check Docker networks
docker network ls
docker network inspect monitoring-network
```

### Docker Issues

View container logs:

```bash
docker-compose logs -f [service-name]
```

Restart all containers:

```bash
docker-compose down && docker-compose up -d
```

### SD Card Health

Check for filesystem errors:

```bash
sudo dmesg | grep -i "error\|fail\|mmc"
```

Check SD card wear (requires smartmontools):

```bash
sudo apt install -y smartmontools
sudo smartctl -a /dev/mmcblk0
```

## Next Steps

1. [Set up Grafana Cloud](SETUP-GRAFANA-CLOUD.md)
2. [Configure AWS connector](SETUP-AWS-CONNECTOR.md)
3. [Configure GCP connector](SETUP-GCP-CONNECTOR.md)
