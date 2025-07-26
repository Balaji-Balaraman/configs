#!/bin/bash

set -e

# Directories
mkdir -p ~/monitoring
cd ~/monitoring

echo "🔧 Installing dependencies..."
sudo apt update && sudo apt install -y wget curl tar

# ------------------------------
# Install Prometheus
# ------------------------------
echo "📦 Installing Prometheus..."

PROM_VERSION="2.52.0"
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar -xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

# Move binaries
sudo mv prometheus /usr/local/bin/
sudo mv promtool /usr/local/bin/

# Create Prometheus user and directories
sudo useradd --no-create-home --shell /bin/false prometheus || true
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

# Copy config
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://www.thepanelstation.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9115
EOF

sudo chown -R prometheus:prometheus /etc/prometheus

# Create Prometheus systemd service
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/usr/share/prometheus/consoles \\
  --web.console.libraries=/usr/share/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable prometheus
sudo systemctl start prometheus

# ------------------------------
# Install Blackbox Exporter
# ------------------------------
echo "📦 Installing Blackbox Exporter..."

cd ~/monitoring
BLACKBOX_VERSION="0.25.0"
wget https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz
tar -xvf blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz
cd blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64

sudo mv blackbox_exporter /usr/local/bin/

# Create config for blackbox
cat <<EOF | sudo tee /etc/blackbox.yml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2"]
      valid_status_codes: [200, 302]
      method: GET
EOF

# Create systemd service
cat <<EOF | sudo tee /etc/systemd/system/blackbox_exporter.service
[Unit]
Description=Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/blackbox_exporter \\
  --config.file=/etc/blackbox.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable blackbox_exporter
sudo systemctl start blackbox_exporter

# ------------------------------
# Wrap up
# ------------------------------
echo "✅ Prometheus and Blackbox Exporter are installed and running."
echo "📍 Prometheus:     http://localhost:9090"
echo "📍 Blackbox probe: http://localhost:9115/probe?target=https://www.thepanelstation.com"
echo "🧩 In Grafana:"
echo "   → Add Prometheus data source: http://localhost:9090"
echo "   → Query: probe_success{instance=\"https://www.thepanelstation.com\"}"
