#!/bin/bash
set -e

: "${DEPLOY_HOST:192.168.100.9}"
: "${DEPLOY_STAGE:=production}"
: "${DEPLOY_USER:=deploy}"

echo "🔧 Starting deploy to $DEPLOY_HOST as $DEPLOY_USER..."

# Set up SSH directories
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Server key setup
echo "🔐 Copying deploy key..."
cp /app/server_key /root/.ssh/deploy_key
chmod 600 /root/.ssh/deploy_key

# GitHub key (already mounted)
echo "🔑 GitHub key already mounted at /app/github_key"
chmod 600 /app/github_key

# Add GitHub to known_hosts
echo "🌍 Adding GitHub to known_hosts..."
ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts
ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts

# Create SSH config
cat > /root/.ssh/config <<EOF
Host deploy_target
  HostName $DEPLOY_HOST
  User $DEPLOY_USER
  IdentityFile /root/.ssh/deploy_key
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
EOF

# Test SSH
echo "🧪 Testing SSH connection..."
ssh deploy_target echo "✅ SSH connection successful"

# Run deploy
echo "🚀 Deploying to $DEPLOY_STAGE..."
bundle exec cap "$DEPLOY_STAGE" deploy
