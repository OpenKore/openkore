#!/bin/bash
#
# OpenKore-AI Bridge System Validation Script
# Tests all bridge components and dependencies
#
# Usage: ./validate_bridges.sh
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_pass() {
    echo -e "  ${GREEN}✅ $1${NC}"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "  ${RED}❌ $1${NC}"
    echo -e "     ${YELLOW}→ $2${NC}"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "  ${YELLOW}⚠️  $1${NC}"
    echo -e "     ${YELLOW}→ $2${NC}"
    ((CHECKS_WARNING++))
}

print_section() {
    echo -e "\n${BLUE}📦 $1${NC}"
}

# Start validation
clear
echo -e "${GREEN}"
cat << "EOF"
   ___                   _  __              _    ___  
  / _ \ _ __   ___ _ __ | |/ /___  _ __ ___      / \ |
 | | | | '_ \ / _ \ '_ \| ' // _ \| '__/ _ \    / _ \|
 | |_| | |_) |  __/ | | | . \ (_) | | |  __/   / ___ \
  \___/| .__/ \___|_| |_|_|\_\___/|_|  \___|  /_/   \_\
       |_|                                              
          Bridge System Validation
EOF
echo -e "${NC}"

print_header "System Environment Validation"

# Check OS
print_section "Operating System"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    check_pass "Linux detected: $(uname -sr)"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    check_pass "macOS detected: $(uname -sr)"
else
    check_warn "Unsupported OS: $OSTYPE" "Script designed for Linux/macOS"
fi

# Check architecture
if [[ $(uname -m) == "x86_64" ]]; then
    check_pass "Architecture: x86_64"
else
    check_warn "Architecture: $(uname -m)" "x86_64 recommended for best compatibility"
fi

print_header "Core Dependencies Check"

# Check Perl
print_section "Perl Installation"
if command -v perl &> /dev/null; then
    PERL_VERSION=$(perl -e 'print $^V' 2>/dev/null || echo "unknown")
    check_pass "Perl installed: $PERL_VERSION"
else
    check_fail "Perl not found" "Install: sudo apt-get install perl (Debian/Ubuntu) or brew install perl (macOS)"
fi

# Check Python
print_section "Python Installation"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [[ $PYTHON_MAJOR -ge 3 ]] && [[ $PYTHON_MINOR -ge 9 ]]; then
        check_pass "Python $PYTHON_VERSION installed"
    else
        check_warn "Python $PYTHON_VERSION installed" "Python 3.9+ recommended, 3.12+ optimal"
    fi
else
    check_fail "Python 3 not found" "Install: sudo apt-get install python3 (Debian/Ubuntu) or brew install python3 (macOS)"
fi

print_header "Perl Module Dependencies"

# Check ZMQ::FFI
print_section "ZeroMQ Perl Binding"
if perl -MZMQ::FFI -e 'print "installed\n"' &> /dev/null; then
    check_pass "ZMQ::FFI module installed"
else
    check_fail "ZMQ::FFI not found" "Install: cpanm ZMQ::FFI or sudo apt-get install libzmq3-dev && cpanm ZMQ::FFI"
fi

# Check JSON::XS
print_section "JSON Parser"
if perl -MJSON::XS -e 'print "installed\n"' &> /dev/null; then
    check_pass "JSON::XS module installed"
else
    check_warn "JSON::XS not found" "Install: cpanm JSON::XS (improves performance but JSON::PP fallback available)"
fi

# Check Time::HiRes
print_section "High-Resolution Timer"
if perl -MTime::HiRes -e 'print "installed\n"' &> /dev/null; then
    check_pass "Time::HiRes module installed"
else
    check_warn "Time::HiRes not found" "Usually included with Perl, install: cpanm Time::HiRes"
fi

print_header "OpenKore Plugin Files"

# Check AI_Bridge plugin
print_section "AI Bridge Plugin"
if [ -f "plugins/AI_Bridge.pl" ]; then
    check_pass "AI_Bridge.pl found"
    
    # Check if plugin is loadable (basic syntax check)
    if perl -c plugins/AI_Bridge.pl &> /dev/null; then
        check_pass "AI_Bridge.pl syntax valid"
    else
        check_fail "AI_Bridge.pl has syntax errors" "Run: perl -c plugins/AI_Bridge.pl for details"
    fi
else
    check_fail "AI_Bridge.pl not found" "Plugin should be at: plugins/AI_Bridge.pl"
fi

# Check chat bridge plugin
print_section "Chat Bridge Plugin"
if [ -f "plugins/godtier_chat_bridge.pl" ]; then
    check_pass "godtier_chat_bridge.pl found"
    
    # Check syntax
    if perl -c plugins/godtier_chat_bridge.pl &> /dev/null; then
        check_pass "godtier_chat_bridge.pl syntax valid"
    else
        check_fail "godtier_chat_bridge.pl has syntax errors" "Run: perl -c plugins/godtier_chat_bridge.pl"
    fi
else
    check_warn "godtier_chat_bridge.pl not found" "Chat features will be limited without this plugin"
fi

print_header "Python AI Sidecar Dependencies"

# Check if ai_sidecar directory exists
print_section "AI Sidecar Directory"
if [ -d "ai_sidecar" ]; then
    check_pass "ai_sidecar directory found"
else
    check_fail "ai_sidecar directory not found" "Ensure you're in the openkore-AI root directory"
    exit 1
fi

# Check Python virtual environment
print_section "Python Virtual Environment"
if [ -d "ai_sidecar/.venv" ] || [ -d "ai_sidecar/venv" ]; then
    check_pass "Python virtual environment found"
else
    check_warn "No virtual environment found" "Recommended: cd ai_sidecar && python3 -m venv .venv"
fi

# Check requirements.txt
print_section "Python Requirements File"
if [ -f "ai_sidecar/requirements.txt" ]; then
    check_pass "requirements.txt found"
else
    check_fail "requirements.txt not found" "File should be at: ai_sidecar/requirements.txt"
fi

# Check Python dependencies (if venv exists)
if [ -d "ai_sidecar/.venv" ]; then
    print_section "Python Dependencies (Virtual Environment)"
    
    # Activate venv and check packages
    source ai_sidecar/.venv/bin/activate 2>/dev/null || true
    
    # Check pyzmq
    if python3 -c "import zmq" &> /dev/null; then
        check_pass "pyzmq installed"
    else
        check_fail "pyzmq not installed" "Install: pip install pyzmq>=25.1.0"
    fi
    
    # Check pydantic
    if python3 -c "import pydantic" &> /dev/null; then
        check_pass "pydantic installed"
    else
        check_fail "pydantic not installed" "Install: pip install pydantic>=2.5.0"
    fi
    
    # Check structlog
    if python3 -c "import structlog" &> /dev/null; then
        check_pass "structlog installed"
    else
        check_warn "structlog not installed" "Install: pip install structlog (improves logging)"
    fi
    
    deactivate 2>/dev/null || true
else
    check_warn "Cannot check Python dependencies" "No virtual environment activated"
fi

print_header "Configuration Files"

# Check AI Sidecar config
print_section "AI Sidecar Configuration"
if [ -f "ai_sidecar/config.yaml" ] || [ -f "ai_sidecar/.env" ]; then
    if [ -f "ai_sidecar/config.yaml" ]; then
        check_pass "config.yaml found"
    fi
    if [ -f "ai_sidecar/.env" ]; then
        check_pass ".env found"
    fi
else
    check_warn "No configuration files found" "Copy ai_sidecar/.env.example to ai_sidecar/.env and configure"
fi

# Check OpenKore config
print_section "OpenKore Configuration"
if [ -f "control/config.txt" ]; then
    check_pass "control/config.txt found"
else
    check_warn "control/config.txt not found" "OpenKore may not be configured yet"
fi

print_header "Network Connectivity"

# Check ZeroMQ port
print_section "ZeroMQ Port Availability"
if command -v netstat &> /dev/null; then
    if netstat -tuln 2>/dev/null | grep -q ':5555 '; then
        check_warn "Port 5555 already in use" "AI Sidecar may already be running, or another service is using this port"
    else
        check_pass "Port 5555 available"
    fi
elif command -v ss &> /dev/null; then
    if ss -tuln 2>/dev/null | grep -q ':5555 '; then
        check_warn "Port 5555 already in use" "AI Sidecar may already be running, or another service is using this port"
    else
        check_pass "Port 5555 available"
    fi
else
    check_warn "Cannot check port availability" "Install netstat or ss to verify port 5555"
fi

# Test localhost connectivity
print_section "Localhost Connectivity"
if ping -c 1 127.0.0.1 &> /dev/null; then
    check_pass "Localhost (127.0.0.1) reachable"
else
    check_fail "Cannot ping localhost" "Network configuration issue"
fi

print_header "Optional Dependencies"

# Check DragonflyDB/Redis
print_section "Memory Store (Optional)"
if command -v redis-cli &> /dev/null; then
    if redis-cli -h localhost -p 6379 ping &> /dev/null; then
        check_pass "Redis/DragonflyDB running on localhost:6379"
    else
        check_warn "Redis/DragonflyDB not running" "Optional but recommended for session memory"
    fi
else
    check_warn "redis-cli not found" "Optional: Install DragonflyDB or Redis for session memory"
fi

# Check Docker (for DragonflyDB)
print_section "Docker (Optional)"
if command -v docker &> /dev/null; then
    check_pass "Docker installed: $(docker --version 2>/dev/null | cut -d' ' -f3)"
    
    # Check if DragonflyDB container exists
    if docker ps 2>/dev/null | grep -q dragonfly; then
        check_pass "DragonflyDB container running"
    else
        check_warn "No DragonflyDB container running" "Optional: docker run -d -p 6379:6379 docker.dragonflydb.io/dragonflydb/dragonfly"
    fi
else
    check_warn "Docker not installed" "Optional but recommended for easy DragonflyDB setup"
fi

# Check GPU (CUDA)
print_section "GPU Support (Optional)"
if command -v nvidia-smi &> /dev/null; then
    check_pass "NVIDIA GPU detected"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | while read line; do
        echo -e "     ${GREEN}→ $line${NC}"
    done
else
    check_warn "No NVIDIA GPU detected" "Optional: GPU mode requires NVIDIA GPU with CUDA support"
fi

print_header "Final Summary"

echo ""
echo -e "${GREEN}✅ Checks Passed: ${CHECKS_PASSED}${NC}"
if [ $CHECKS_WARNING -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warnings: ${CHECKS_WARNING}${NC}"
fi
if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Checks Failed: ${CHECKS_FAILED}${NC}"
fi
echo ""

# Final verdict
if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ VALIDATION PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo -e "  1. Start AI Sidecar: ${YELLOW}cd ai_sidecar && python main.py${NC}"
    echo -e "  2. Start OpenKore:   ${YELLOW}./start.pl${NC}"
    echo -e "  3. Monitor logs for bridge connection"
    echo ""
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ VALIDATION FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Please fix the errors above before proceeding${NC}"
    echo ""
    echo -e "${BLUE}📚 Resources:${NC}"
    echo -e "  • Documentation: ${YELLOW}docs/GODTIER-RO-AI-DOCUMENTATION.md${NC}"
    echo -e "  • Testing Guide: ${YELLOW}docs/BRIDGE_TESTING_GUIDE.md${NC}"
    echo -e "  • Troubleshooting: ${YELLOW}BRIDGE_TROUBLESHOOTING.md${NC}"
    echo ""
    exit 1
fi