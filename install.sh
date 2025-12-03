#!/bin/bash
# OpenKore AI - Complete Installation Script for Linux
# This script installs all required dependencies from scratch

set -e

echo "========================================="
echo "  OpenKore AI - Complete Setup"
echo "========================================="
echo ""

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

# 1. Check/Install Python 3.12+
echo "========================================="
echo "Step 1: Python 3.12+ Installation"
echo "========================================="

if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
    print_status "Found Python $PYTHON_VERSION"
    
    # Check if version is 3.12 or higher
    MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [ "$MAJOR" -lt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 12 ]); then
        print_warning "Python 3.12+ recommended (found $PYTHON_VERSION)"
    fi
else
    print_error "Python not found. Installing..."
    
    if command_exists apt-get; then
        # Debian/Ubuntu
        echo "Installing Python on Debian/Ubuntu..."
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt-get update
        sudo apt-get install -y python3.12 python3.12-venv python3.12-dev python3-pip
        sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
        print_status "Python 3.12 installed"
        
    elif command_exists yum; then
        # CentOS/RHEL
        echo "Installing Python on CentOS/RHEL..."
        sudo yum install -y python3 python3-pip python3-devel
        print_status "Python installed"
        
    elif command_exists dnf; then
        # Fedora
        echo "Installing Python on Fedora..."
        sudo dnf install -y python3 python3-pip python3-devel
        print_status "Python installed"
        
    elif command_exists brew; then
        # macOS
        echo "Installing Python on macOS..."
        brew install python@3.12
        print_status "Python 3.12 installed"
        
    else
        print_error "Unable to auto-install Python."
        echo "Please install Python 3.12+ manually from python.org"
        exit 1
    fi
fi

# 2. Check/Install pip
echo ""
echo "========================================="
echo "Step 2: pip Installation"
echo "========================================="

if command_exists pip3; then
    print_status "pip already installed"
else
    print_warning "pip not found, installing..."
    if command_exists apt-get; then
        sudo apt-get install -y python3-pip
    elif command_exists yum; then
        sudo yum install -y python3-pip
    elif command_exists dnf; then
        sudo dnf install -y python3-pip
    else
        python3 -m ensurepip --upgrade
    fi
    print_status "pip installed"
fi

# 3. Check/Install Docker (for DragonflyDB)
echo ""
echo "========================================="
echo "Step 3: Docker Installation"
echo "========================================="

if command_exists docker; then
    print_status "Docker already installed: $(docker --version)"
else
    print_warning "Docker not found."
    echo ""
    echo "Docker is required to run DragonflyDB (Redis-compatible cache)."
    echo "Would you like to install Docker now? (y/n)"
    read -r install_docker
    
    if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
        echo "Installing Docker..."
        
        if command_exists apt-get; then
            # Ubuntu/Debian
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            print_status "Docker installed"
            print_warning "You may need to log out and back in for Docker group permissions"
            
        elif command_exists brew; then
            # macOS
            echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
            print_warning "After installing, re-run this script"
            exit 0
        else
            echo "Please install Docker manually from: https://docs.docker.com/get-docker/"
            print_warning "After installing, re-run this script"
            exit 0
        fi
    else
        print_warning "Skipping Docker. You can install Redis as alternative:"
        echo "  Ubuntu/Debian: sudo apt-get install redis-server"
        echo "  macOS: brew install redis"
    fi
fi

# 4. Setup DragonflyDB
echo ""
echo "========================================="
echo "Step 4: DragonflyDB Setup"
echo "========================================="

if command_exists docker; then
    # Check if dragonfly container already exists
    if docker ps -a --format '{{.Names}}' | grep -q '^dragonfly$'; then
        print_status "DragonflyDB container already exists"
        
        # Check if it's running
        if docker ps --format '{{.Names}}' | grep -q '^dragonfly$'; then
            print_status "DragonflyDB is running"
        else
            echo "Starting existing DragonflyDB container..."
            docker start dragonfly
            print_status "DragonflyDB started"
        fi
    else
        echo "Pulling DragonflyDB image..."
        docker pull docker.dragonflydb.io/dragonflydb/dragonfly:latest
        
        echo "Creating DragonflyDB container..."
        docker run -d \
            --name dragonfly \
            -p 6379:6379 \
            --restart unless-stopped \
            docker.dragonflydb.io/dragonflydb/dragonfly:latest
        
        print_status "DragonflyDB running on port 6379"
    fi
    
    echo ""
    echo "DragonflyDB commands:"
    echo "  Stop:    docker stop dragonfly"
    echo "  Start:   docker start dragonfly"
    echo "  Logs:    docker logs dragonfly"
    echo "  Remove:  docker rm -f dragonfly"
else
    print_warning "DragonflyDB not installed (Docker unavailable)"
    echo ""
    echo "Alternative: Install Redis"
    echo "  Ubuntu/Debian: sudo apt-get install redis-server"
    echo "  macOS: brew install redis"
    echo "  Then start: sudo systemctl start redis-server (or 'brew services start redis')"
fi

# 5. Setup Python Environment
echo ""
echo "========================================="
echo "Step 5: Python Environment Setup"
echo "========================================="

cd ai_sidecar

# Create virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv .venv
    print_status "Virtual environment created"
else
    print_status "Virtual environment already exists"
fi

# Activate and install dependencies
echo "Activating virtual environment..."
source .venv/bin/activate

echo "Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1

echo "Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    print_status "Dependencies installed"
else
    print_error "requirements.txt not found!"
    exit 1
fi

# 6. Create .env file
echo ""
echo "========================================="
echo "Step 6: Configuration"
echo "========================================="

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_status "Created .env from template"
        print_warning "Please edit ai_sidecar/.env with your settings"
    else
        print_warning ".env.example not found, creating basic .env"
        cat > .env << 'EOF'
# OpenKore AI Configuration
OPENAI_API_KEY=your_openai_api_key_here
REDIS_HOST=localhost
REDIS_PORT=6379
LOG_LEVEL=INFO
EOF
        print_status "Created basic .env file"
    fi
else
    print_status ".env file already exists"
fi

# 7. Installation Summary
echo ""
echo "========================================="
echo "  Installation Complete! 🎉"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Configure your settings:"
echo "   ${GREEN}nano ai_sidecar/.env${NC}"
echo ""
echo "2. Start the AI system:"
echo "   ${GREEN}./run.sh${NC}"
echo ""
echo "3. Launch OpenKore:"
echo "   ${GREEN}./start.exe${NC} or ${GREEN}./wxstart.exe${NC}"
echo ""
echo "========================================="
echo ""

# Check if user needs to log out for Docker
if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
    print_warning "Remember to log out and back in for Docker permissions!"
fi