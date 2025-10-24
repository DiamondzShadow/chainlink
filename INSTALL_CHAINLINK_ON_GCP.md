# Installing Chainlink on Your GCP Server

This guide shows you how to get Chainlink onto your GCP server from scratch.

## Step 1: SSH into Your GCP Server

```bash
# Using gcloud CLI (if installed locally)
gcloud compute ssh YOUR_INSTANCE_NAME --zone=YOUR_ZONE

# OR using standard SSH
ssh YOUR_USERNAME@YOUR_GCP_EXTERNAL_IP

# OR use the SSH button in GCP Console (opens browser terminal)
```

---

## Step 2: Install Prerequisites on Your GCP Server

Once you're SSH'd in, install the required tools:

### Install Git (if not already installed)

```bash
# Check if git is installed
git --version

# If not, install it
sudo apt-get update
sudo apt-get install -y git
```

### Install Go 1.23

```bash
# Download Go
cd ~
wget https://go.dev/dl/go1.23.0.linux-amd64.tar.gz

# Remove old Go installation (if exists)
sudo rm -rf /usr/local/go

# Extract and install
sudo tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz

# Add to PATH (add these to your ~/.bashrc or ~/.profile)
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc

# Reload your shell configuration
source ~/.bashrc

# Verify installation
go version
# Should show: go version go1.23.0 linux/amd64
```

### Install Node.js and pnpm

```bash
# Install Node.js v20 using NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify Node.js
node --version
# Should show: v20.x.x

# Install pnpm via npm
sudo npm install -g pnpm

# Verify pnpm
pnpm --version
```

### Install PostgreSQL

```bash
# Install PostgreSQL 16
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify it's running
sudo systemctl status postgresql
```

---

## Step 3: Clone Chainlink Repository to Your Server

```bash
# Go to your home directory (or wherever you want Chainlink)
cd ~

# Clone the Chainlink repository
git clone https://github.com/smartcontractkit/chainlink.git

# Navigate into it
cd chainlink

# Check out a specific version (optional, but recommended)
git checkout v2.17.0  # Replace with latest stable version

# Or stay on the current branch
git branch
```

**Note:** The Chainlink repo is now on your GCP server at `~/chainlink`

---

## Step 4: Set Up PostgreSQL Database

```bash
# Switch to postgres user
sudo -u postgres psql

# Inside PostgreSQL prompt, create a user and database:
CREATE USER chainlink WITH PASSWORD 'your_secure_password_here';
CREATE DATABASE chainlink_db OWNER chainlink;
GRANT ALL PRIVILEGES ON DATABASE chainlink_db TO chainlink;
\q

# Test the connection
psql -U chainlink -d chainlink_db -h localhost
# Enter the password when prompted
# Type \q to exit
```

---

## Step 5: Build Chainlink

```bash
# Make sure you're in the chainlink directory
cd ~/chainlink

# Install dependencies and build Chainlink
make install

# This will:
# - Install Go dependencies
# - Install Node dependencies via pnpm
# - Build the chainlink binary
# - Install it to $GOPATH/bin (which is in your PATH)

# Verify installation
chainlink version
```

**Note:** The build process can take 5-10 minutes depending on your server specs.

---

## Step 6: Configure Chainlink

### Create Configuration Directory

```bash
# Create a directory for Chainlink configuration
mkdir -p ~/.chainlink
cd ~/.chainlink
```

### Create Config File

```bash
# Create config.toml
nano config.toml
```

Add this basic configuration (adjust as needed):

```toml
[Log]
Level = 'info'

[WebServer]
SecureCookies = false
TLS.HTTPSPort = 0

[Insecure]
DevWebServer = true

[[EVM]]
ChainID = '1'  # Change to your network (1 = Ethereum mainnet, 11155111 = Sepolia, etc.)

[[EVM.Nodes]]
Name = 'primary'
WSURL = 'wss://YOUR_ETH_NODE_WEBSOCKET_URL'  # Replace with your Ethereum node WS URL
HTTPURL = 'https://YOUR_ETH_NODE_HTTP_URL'   # Replace with your Ethereum node HTTP URL
```

**Important:** Replace the Ethereum node URLs with your actual node endpoints (Alchemy, Infura, or your own node).

### Create Secrets File

```bash
# Create .api file for Chainlink UI credentials
nano .api
```

Add your admin email and password (create your own):
```
your-admin@email.com
your_secure_password_here
```

```bash
# Create .password file for wallet password
nano .password
```

Add a secure password for your Chainlink wallet:
```
your_wallet_password_here
```

### Set Permissions

```bash
chmod 600 ~/.chainlink/.api
chmod 600 ~/.chainlink/.password
chmod 600 ~/.chainlink/config.toml
```

---

## Step 7: Start Chainlink Node

### First Time Setup - Create Wallet

```bash
# Start Chainlink in setup mode
chainlink node start
```

Follow the prompts to:
1. Create a new wallet or import existing one
2. Note down your wallet address
3. **IMPORTANT:** Save your mnemonic phrase securely!

Press `Ctrl+C` to stop after setup is complete.

### Start as Background Service (Recommended)

Create a systemd service:

```bash
sudo nano /etc/systemd/system/chainlink.service
```

Add this content (adjust paths as needed):

```ini
[Unit]
Description=Chainlink Node
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/home/YOUR_USERNAME/.chainlink
ExecStart=/home/YOUR_USERNAME/go/bin/chainlink node start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable Chainlink to start on boot
sudo systemctl enable chainlink

# Start Chainlink
sudo systemctl start chainlink

# Check status
sudo systemctl status chainlink

# View logs
sudo journalctl -u chainlink -f
```

---

## Step 8: Access Chainlink UI

### Option 1: SSH Port Forwarding (Secure - Recommended)

On your **local machine**, create an SSH tunnel:

```bash
gcloud compute ssh YOUR_INSTANCE_NAME --zone=YOUR_ZONE -- -L 6688:localhost:6688

# OR with standard SSH:
ssh -L 6688:localhost:6688 YOUR_USERNAME@YOUR_GCP_IP
```

Then open in your local browser: http://localhost:6688

### Option 2: Allow External Access via Firewall

**Warning:** Less secure - only for development!

```bash
# Create GCP firewall rule
gcloud compute firewall-rules create allow-chainlink-ui \
    --allow tcp:6688 \
    --source-ranges YOUR_LOCAL_IP/32 \
    --description "Allow Chainlink UI access"
```

Then open in your browser: http://YOUR_GCP_EXTERNAL_IP:6688

### Login

- Email: (the one you put in `.api` file)
- Password: (the one you put in `.api` file)

---

## Step 9: Fund Your Node

Your Chainlink node needs:
1. **ETH** - To pay for gas fees
2. **LINK** - To fulfill oracle requests (if applicable)

```bash
# Get your node's wallet address
chainlink keys eth list

# Send ETH and LINK to that address
```

---

## Step 10: Verify Everything is Working

```bash
# Check if Chainlink is running
sudo systemctl status chainlink

# Check logs
sudo journalctl -u chainlink -f

# List your keys
chainlink keys eth list

# Check if you can access the API
curl http://localhost:6688
```

---

## Summary: What You Just Did

✅ Installed prerequisites (Go, Node.js, PostgreSQL)
✅ Cloned Chainlink repo to `~/chainlink`
✅ Built Chainlink from source
✅ Configured Chainlink with database and network settings
✅ Created wallet and admin credentials
✅ Started Chainlink as a service
✅ Accessed Chainlink UI

---

## Now You Can Integrate Oraclez!

Now that Chainlink is installed on your GCP server, you can:

1. **Test Oraclez connection:**
   ```bash
   cd ~/chainlink
   ./examples/test_oraclez_connection.sh
   ```

2. **Create bridge to Oraclez:**
   ```bash
   ./scripts/setup_oraclez_bridge.sh
   ```

3. **Create jobs:**
   ```bash
   cat examples/oraclez_job_spec.toml
   ```

See `ORACLEZ_QUICKSTART_EXISTING.md` for the next steps!

---

## Troubleshooting

### Build Fails

```bash
# Make sure you have all prerequisites
go version  # Should be 1.23
node --version  # Should be v20.x
pnpm --version

# Try cleaning and rebuilding
cd ~/chainlink
make clean
make install
```

### PostgreSQL Connection Errors

```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Test connection
psql -U chainlink -d chainlink_db -h localhost

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

### Can't Access Chainlink UI

```bash
# Check if Chainlink is listening on port 6688
sudo netstat -tulpn | grep 6688

# Check firewall
sudo ufw status

# Check Chainlink logs
sudo journalctl -u chainlink -f
```

### "Permission Denied" Errors

```bash
# Make sure files have correct ownership
sudo chown -R $USER:$USER ~/chainlink
sudo chown -R $USER:$USER ~/.chainlink

# Make scripts executable
chmod +x ~/chainlink/scripts/*.sh
chmod +x ~/chainlink/examples/*.sh
```

---

## Quick Reference Commands

```bash
# Start Chainlink
sudo systemctl start chainlink

# Stop Chainlink
sudo systemctl stop chainlink

# Restart Chainlink
sudo systemctl restart chainlink

# View logs
sudo journalctl -u chainlink -f

# Check status
sudo systemctl status chainlink

# Chainlink CLI commands
chainlink admin login
chainlink jobs list
chainlink bridges list
chainlink keys eth list
```
