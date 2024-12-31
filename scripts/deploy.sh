#!/bin/bash

LOG_FILE="/var/log/codedeploy_dependencies.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"

echo "Starting dependency installation..." >> "$LOG_FILE"

# Locate deployment-archive
DEPLOY_DIR=$(find "$DEPLOY_ROOT" -type d -name "deployment-archive" | head -n 1)
if [ -z "$DEPLOY_DIR" ]; then
    echo "Error: Deployment directory (deployment-archive) not found under $DEPLOY_ROOT." >> "$LOG_FILE"
    exit 1
fi

APP_ZIP="$DEPLOY_DIR/app.zip"

# Ensure application directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "Creating application directory: $APP_DIR" >> "$LOG_FILE"
    sudo mkdir -p "$APP_DIR"
    sudo chown ec2-user:ec2-user "$APP_DIR"
    sudo chmod 755 "$APP_DIR"
fi

# Extract app.zip
if [ -f "$APP_ZIP" ]; then
    echo "Extracting application files from $APP_ZIP to $APP_DIR..." >> "$LOG_FILE"
    sudo unzip -o "$APP_ZIP" -d "$APP_DIR" >> "$LOG_FILE" 2>&1
else
    echo "Error: app.zip not found at $APP_ZIP" >> "$LOG_FILE"
    exit 1
fi

# Set up and activate virtual environment
echo "Setting up virtual environment..." >> "$LOG_FILE"
if [ ! -d "$APP_DIR/venv" ]; then
    python3 -m venv "$APP_DIR/venv" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create virtual environment." >> "$LOG_FILE"
        exit 1
    fi
fi

source "$APP_DIR/venv/bin/activate"
if [ $? -ne 0 ]; then
    echo "Error: Failed to activate virtual environment." >> "$LOG_FILE"
    exit 1
fi

# Upgrade pip to the latest version
echo "Upgrading pip..." >> "$LOG_FILE"
pip install --upgrade pip >> "$LOG_FILE" 2>&1

# Install dependencies
REQ_FILE="$APP_DIR/requirements.txt"
if [ -f "$REQ_FILE" ]; then
    echo "Installing dependencies from $REQ_FILE..." >> "$LOG_FILE"
    pip install -r "$REQ_FILE" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install dependencies from $REQ_FILE." >> "$LOG_FILE"
        deactivate
        exit 1
    fi
else
    echo "Error: requirements.txt not found in $APP_DIR. Installing Flask and Gunicorn as fallback..." >> "$LOG_FILE"
    pip install flask gunicorn >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Flask or Gunicorn." >> "$LOG_FILE"
        deactivate
        exit 1
    fi
fi

# Verify Flask installation
python3 -c "import flask" >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Flask module is not installed." >> "$LOG_FILE"
    deactivate
    exit 1
fi

# Verify Gunicorn installation
if [ ! -f "$APP_DIR/venv/bin/gunicorn" ]; then
    echo "Error: Gunicorn is not installed correctly." >> "$LOG_FILE"
    deactivate
    exit 1
fi

echo "Dependencies installed successfully." >> "$LOG_FILE"
deactivate
exit 0
