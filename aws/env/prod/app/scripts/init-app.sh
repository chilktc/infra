#!/bin/bash
# t7-mindlog Production Application Initialization Script
# Version: 3.0 (Monitoring Enabled)

set -e

# Variable Injection from Terraform (using $ for template, needs escaping for shell if needed)
# Variable Injection from Terraform
TARGET_IPS="${target_ips}"

# Self-detecting Instance Role using IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
MY_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# First IP in the list is considered app-1 (Management Node)
MANAGEMENT_IP=$(echo $TARGET_IPS | cut -d',' -f1)

if [ "$MY_IP" == "$MANAGEMENT_IP" ]; then
    IS_MANAGEMENT=true
    echo "Self-detected as Management Node ($MY_IP)"
else
    IS_MANAGEMENT=false
    echo "Self-detected as Application Node ($MY_IP)"
fi

# Update and install dependencies
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker Compose installation
DOCKER_COMPOSE_VERSION="v2.21.0"
curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create configuration directory
mkdir -p /home/ubuntu/monitoring/prometheus
cd /home/ubuntu/monitoring

# Define Common Services (Node Exporter)
SERVICES="
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - \"9100:9100\"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
"

# Configure app-1 as Management Node
if [ "$IS_MANAGEMENT" = true ]; then
    echo "Configuring app-1 as Management Node..."
    
    # Generate prometheus.yml targets from TARGET_IPS (comma-separated list)
    IFS=',' read -ra ADDR <<< "$TARGET_IPS"
    PROMETHEUS_TARGETS=""
    for i in "$${ADDR[@]}"; do
        PROMETHEUS_TARGETS+=\"'$i:9100',\"
    done
    PROMETHEUS_TARGETS=$${PROMETHEUS_TARGETS%,}

cat <<EOF > prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: [$PROMETHEUS_TARGETS]
EOF

    SERVICES+="
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - \"9090:9090\"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - \"3001:3000\"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${gf_admin_password}
    networks:
      - monitoring

  opensearch:
    image: opensearchproject/opensearch:latest
    container_name: opensearch
    ports:
      - \"5601:5601\"
    environment:
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=${os_admin_password}
      - discovery.type=single-node
    networks:
      - monitoring
"
fi

# Write docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8'
services:
$SERVICES

networks:
  monitoring:
    driver: bridge
EOF

# Startup
docker-compose up -d

echo "Initialization Complete!"
