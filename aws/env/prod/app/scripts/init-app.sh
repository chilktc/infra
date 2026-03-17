#!/bin/bash
# t7-mindlog Production System Initialization Script
# Version: 3.5 (Fixed AWS CLI, Docker, and All Services)

set -e

# Variable Injection from Terraform
TARGET_IPS="${target_ips}"
REGION="ap-northeast-2"
ACCOUNT_ID="274130523831"

# Self-detecting Instance Role using IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
MY_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Define Node IPs
NODE_1="10.7.0.10"
NODE_2="10.7.11.10"
NODE_3="10.7.10.20"
NODE_4="10.7.11.20"
NODE_5="10.7.10.30"
NODE_6="10.7.11.30"

# SSH Key Injection
if [ "$MY_IP" == "$NODE_1" ]; then
    echo "${bastion_pub_key}" >> /home/ubuntu/.ssh/authorized_keys
fi
if [ "$MY_IP" == "$NODE_3" ]; then
    echo "${gateway_pub_key}" >> /home/ubuntu/.ssh/authorized_keys
fi

# Fix SSH Directory Permissions strictly required by Ubuntu
chown -R ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys

# 1. Basic Dependencies & AWS CLI
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release unzip awscli net-tools

# 2. Install Docker & Dependencies (Official Repository)
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

# 3. AWS ECR Login
# Note: Instance must have IAM role with ECR access (SSM Core is already attached, usually enough if supplemented)
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# 4. Setup Project Directory
mkdir -p /home/ubuntu/app/fluent-bit
cd /home/ubuntu/app

# --- Fluent-bit Configuration ---
cat <<EOF > fluent-bit/fluent-bit.conf
[SERVICE]
    Flush        5
    Daemon       Off
    Log_Level    info
    Parsers_File parsers.conf

[INPUT]
    Name             tail
    Path             /var/lib/docker/containers/*/*.log
    Parser           docker
    Tag              docker.*
    Refresh_Interval 5
    Mem_Buf_Limit    5MB
    Skip_Long_Lines  On

[OUTPUT]
    Name            opensearch
    Match           *
    Host            $NODE_1
    Port            9200
    Index           mindlog-logs
    Type            _doc
    Suppress_Type_Name On
EOF

cat <<EOF > fluent-bit/parsers.conf
[PARSER]
    Name         docker
    Format       json
    Time_Key     time
    Time_Format  %Y-%m-%dT%H:%M:%S.%L
    Time_Keep    On
EOF

# 5. Global Services (Node Exporter)
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

# 6. Role-based Service Definition
# --- APP-1 (Management: Prometheus, Grafana, OpenSearch) ---
if [ "$MY_IP" == "$NODE_1" ]; then
    echo "Configuring Node-1 (Management)..."
    mkdir -p prometheus
    cat <<EOF > prometheus/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['$NODE_1:9100', '$NODE_2:9100', '$NODE_3:9100', '$NODE_4:9100', '$NODE_5:9100', '$NODE_6:9100']
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

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - \"3001:3000\"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${gf_admin_password}
    volumes:
      - grafana-data:/var/lib/grafana

  opensearch:
    image: opensearchproject/opensearch:2.11.1
    container_name: opensearch
    ports:
      - \"9200:9200\"
    environment:
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=${os_admin_password}
      - discovery.type=single-node
      - \"OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m\"
      - DISABLE_SECURITY_PLUGIN=true

  opensearch-dashboards:
    image: opensearchproject/opensearch-dashboards:2.11.1
    container_name: opensearch-dashboards
    ports:
      - \"5601:5601\"
    environment:
      - OPENSEARCH_HOSTS=http://opensearch:9200
      - DISABLE_SECURITY_DASHBOARDS_PLUGIN=true
"
fi

# --- APP-2, APP-3, APP-4, APP-5, APP-6 (Backend + Frontend) ---
if [ "$MY_IP" == "$NODE_2" ] || [ "$MY_IP" == "$NODE_3" ] || [ "$MY_IP" == "$NODE_4" ] || [ "$MY_IP" == "$NODE_5" ] || [ "$MY_IP" == "$NODE_6" ]; then
    echo "Configuring App Instance (Backend + Frontend)..."
    SERVICES+="
  backend:
    image: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/t7-mindlog-backend:latest
    container_name: backend
    restart: always
    ports:
      - \"8080:8080\"
    environment:
      - SPRING_PROFILES_ACTIVE=prod

  frontend:
    image: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/t7-mindlog-frontend:latest
    container_name: frontend
    restart: always
    ports:
      - \"3000:3000\"
"
fi

# --- Removed APP-4 only block ---

# 7. Add Fluent-bit to Global Services
SERVICES+="
  fluent-bit:
    image: fluent/fluent-bit:latest
    container_name: fluent-bit
    restart: always
    volumes:
      - ./fluent-bit/fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf
      - ./fluent-bit/parsers.conf:/fluent-bit/etc/parsers.conf
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    user: root
"

# Write docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  $SERVICES
volumes:
  grafana-data:
EOF

# Startup
docker-compose up -d

echo "Initialization Complete!"
