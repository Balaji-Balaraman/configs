#!/bin/bash

set -e

echo "🔄 Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing required packages..."
sudo apt install -y software-properties-common wget apt-transport-https gnupg2

echo "➕ Adding Grafana APT repository..."
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

echo "🔐 Adding Grafana GPG key..."
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

echo "📦 Installing Grafana..."
sudo apt update
sudo apt install -y grafana

echo "🔧 Enabling and starting Grafana service..."
sudo systemctl daemon-reexec
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "✅ Grafana installation complete!"
echo "📍 Service status:"
sudo systemctl status grafana-server --no-pager

echo -e "\n🌐 Access Grafana Web UI via:"
echo "  → Azure Bastion browser at http://localhost:3000"
echo "  → Or SSH tunnel from your local machine:"
echo "     ssh -L 3000:localhost:3000 <your-user>@<vm-private-ip>"
echo -e "\n🔐 Default login → Username: admin | Password: admin"
echo "⚠️ You will be prompted to change it on first login."
