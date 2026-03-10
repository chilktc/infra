#!/bin/bash
# t7-mindlog Production Application Initialization Script
# Version: 2.0 (Shielded)

set -e

echo "Starting Application Initialization..."

# Update and install dependencies
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker Compose installation (pinned version)
DOCKER_COMPOSE_VERSION="v2.21.0"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create monitoring directory
mkdir -p /home/ubuntu/monitoring
cd /home/ubuntu/monitoring

# [SHIELDED] Create docker-compose.yml with injected secrets
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GF_ADMIN_PASSWORD}
    networks:
      - monitoring

  opensearch:
    image: opensearchproject/opensearch:latest
    ports:
      - "5601:5601"
    environment:
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=${OS_ADMIN_PASSWORD}
      - discovery.type=single-node
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
EOF

# Startup
docker-compose up -d

echo "Initialization Complete!"
