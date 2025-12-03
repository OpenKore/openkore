#!/bin/bash
# OpenKore AI - Linux Run Script with DragonflyDB Check

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function: Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function: Print colored message
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

echo "========================================="
echo "  OpenKore AI - Startup"
echo "========================================="
echo ""

# Check if DragonflyDB/Redis is running
echo "Checking cache server (DragonflyDB/Redis)..."

if command_exists docker; then
    # Check if dragonfly container exists
    if docker ps -a --format '{{.Names}}' | grep -q '^dragonfly$'; then
        # Check if it's running
        if docker ps --format '{{.Names}}' | grep -q '^dragonfly$'; then
            print_status "DragonflyDB is running"
        else
            print_warning "DragonflyDB container exists but not running"
            echo "Starting DragonflyDB..."
            docker start dragonfly
            if [ $? -eq 0 ]; then
                print_status "DragonflyDB started successfully"
                sleep 2  # Give it time to start
            else
                print_error "Failed to start DragonflyDB"
                echo "Try running: docker start dragonfly"
                exit 1
            fi
        fi
    else
        print_warning "DragonflyDB container not found"
        echo ""
        echo "Would you like to create and start DragonflyDB now? (y/n)"
        read -r create_dragonfly
        
        if [ "$create_dragonfly" = "y" ] || [ "$create_dragonfly" = "Y" ]; then
            echo "Pulling DragonflyDB image..."
            docker pull docker.dragonflydb.io/dragonflydb/dragonfly:latest
            
            echo "Creating DragonflyDB container..."
            docker run -d \
                --name dragonfly \
                -p 6379:6379 \
                --restart unless-stopped \
                docker.dragonflydb.io/dragonflydb/dragonfly:latest
            
            if [ $? -eq 0 ]; then
                print_status "DragonflyDB created and started"
                sleep 2  # Give it time to start
            else
                print_error "Failed to create DragonflyDB"
                exit 1
            fi
        else
            print_error "DragonflyDB is required. Please run ./install.sh first"
            exit 1
        fi
    fi
else
    # Check if Redis is running (alternative)
    if command_exists redis-cli; then
        redis-cli ping > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_status "Redis is running"
        else
            print_warning "Redis is not responding"
            echo "Try starting Redis with: sudo systemctl start redis-server"
            echo "Or on macOS: brew services start redis"
        fi
    else
        print_warning "Neither Docker nor Redis found"
        echo "Please install Docker or Redis. Run ./install.sh for automatic installation"
        exit 1
    fi
fi

echo ""
echo "Starting OpenKore AI Sidecar..."
echo "========================================="
echo ""

# Navigate to ai_sidecar and activate environment
cd ai_sidecar

if [ ! -d ".venv" ]; then
    print_error "Virtual environment not found!"
    echo "Please run ./install.sh first"
    exit 1
fi

# Activate virtual environment
source .venv/bin/activate

# Check if .env exists
if [ ! -f ".env" ]; then
    print_error ".env file not found!"
    echo "Please create ai_sidecar/.env with your configuration"
    echo "You can copy from .env.example"
    exit 1
fi

# Set PYTHONPATH and run
export PYTHONPATH="$(pwd)/.."
python main.py "$@"