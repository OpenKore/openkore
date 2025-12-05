#!/bin/bash
################################################################################
# OpenKore AI Sidecar - Automated Installation Script for Linux
#
# This script automates the installation of the God-Tier AI Sidecar system.
# It handles prerequisite checking, virtual environment setup, dependency
# installation, and verification.
#
# Usage:
#   ./install.sh [OPTIONS]
#
# Options:
#   --force     Force reinstall even if already installed
#   --verbose   Enable verbose output for debugging
#   -h, --help  Show this help message
#
# Requirements:
#   - Python 3.10+ with pip and venv
#   - Git (for cloning repository)
#   - Internet connection (for downloading packages)
#
# Exit Codes:
#   0 - Success
#   1 - Python version check failed
#   2 - pip not found
#   3 - python3-venv not available
#   4 - Virtual environment creation failed
#   5 - pip upgrade failed
#   6 - Dependency installation failed
#   7 - Installation verification failed
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

################################################################################
# Configuration
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
PYTHON_MIN_VERSION="3.10"
REQUIRED_PYTHON_VERSION_CODE=31000  # 3.10.0 in numeric format

# Default options
FORCE_INSTALL=false
VERBOSE=false

################################################################################
# Color codes for output
################################################################################

if [[ -t 1 ]]; then
    # Terminal supports colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    # No color support
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

################################################################################
# Helper Functions
################################################################################

# Print functions
print_header() {
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_step() {
    echo -e "${BLUE}${BOLD}[$1/$2]${NC} $3"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Show usage
show_usage() {
    cat << EOF
${BOLD}OpenKore AI Sidecar - Automated Installation Script${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    --force         Force reinstall even if already installed
    --verbose       Enable verbose output for debugging
    -h, --help      Show this help message

${BOLD}DESCRIPTION:${NC}
    This script automates the installation of the AI Sidecar for OpenKore.
    It performs the following steps:
    
    1. Checks Python version (requires 3.10+)
    2. Verifies pip and python3-venv availability
    3. Creates a virtual environment in .venv/
    4. Upgrades pip, setuptools, and wheel
    5. Installs the ai-sidecar package in editable mode
    6. Verifies the installation

${BOLD}EXAMPLES:${NC}
    # Standard installation
    $0

    # Force reinstall with verbose output
    $0 --force --verbose

    # Show help
    $0 --help

${BOLD}REQUIREMENTS:${NC}
    - Python 3.10 or higher
    - pip package manager
    - python3-venv module
    - Internet connection

For more information, see: ${SCRIPT_DIR}/INSTALL.md
EOF
}

# Compare version numbers
version_ge() {
    # Returns 0 if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Get Python version as numeric code
get_python_version_code() {
    local python_cmd=$1
    $python_cmd -c 'import sys; print(sys.version_info.major * 10000 + sys.version_info.minor * 100 + sys.version_info.micro)' 2>/dev/null || echo 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

################################################################################
# Parse command-line arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done
}

################################################################################
# Installation Steps
################################################################################

# Step 1: Check Python version
check_python_version() {
    print_step 1 7 "Checking Python version..."
    
    # Try different Python commands
    local python_cmd=""
    for cmd in python3 python python3.12 python3.11 python3.10; do
        if command_exists "$cmd"; then
            python_cmd="$cmd"
            print_verbose "Found Python command: $python_cmd"
            break
        fi
    done
    
    if [[ -z "$python_cmd" ]]; then
        print_error "Python not found. Please install Python 3.10 or higher."
        echo ""
        print_info "Installation instructions:"
        echo "  Ubuntu/Debian: sudo apt install python3.12 python3.12-venv"
        echo "  Fedora/RHEL:   sudo dnf install python3.12"
        echo "  Arch Linux:    sudo pacman -S python"
        exit 1
    fi
    
    # Get Python version
    local python_version=$($python_cmd --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
    local python_version_code=$(get_python_version_code "$python_cmd")
    
    print_verbose "Python version: $python_version (code: $python_version_code)"
    print_verbose "Required version: ${PYTHON_MIN_VERSION} (code: ${REQUIRED_PYTHON_VERSION_CODE})"
    
    if [[ $python_version_code -lt $REQUIRED_PYTHON_VERSION_CODE ]]; then
        print_error "Python ${python_version} is installed, but Python ${PYTHON_MIN_VERSION}+ is required."
        echo ""
        print_info "Please upgrade Python to version ${PYTHON_MIN_VERSION} or higher."
        echo "  Current:  Python ${python_version}"
        echo "  Required: Python ${PYTHON_MIN_VERSION}+"
        exit 1
    fi
    
    # Export for use in other functions
    export PYTHON_CMD="$python_cmd"
    
    print_success "Python ${python_version} detected (${python_cmd})"
}

# Step 2: Check pip availability
check_pip() {
    print_step 2 7 "Checking pip availability..."
    
    # Check if pip is available via python -m pip
    if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
        print_error "pip is not available for ${PYTHON_CMD}."
        echo ""
        print_info "Please install pip:"
        echo "  Ubuntu/Debian: sudo apt install python3-pip"
        echo "  Fedora/RHEL:   sudo dnf install python3-pip"
        echo "  Arch Linux:    sudo pacman -S python-pip"
        echo ""
        echo "Or use the official installer:"
        echo "  curl https://bootstrap.pypa.io/get-pip.py | ${PYTHON_CMD}"
        exit 2
    fi
    
    local pip_version=$($PYTHON_CMD -m pip --version | grep -oP '\d+\.\d+(\.\d+)?')
    print_success "pip ${pip_version} is available"
}

# Step 3: Check python3-venv (for Debian/Ubuntu systems)
check_venv() {
    print_step 3 7 "Checking python3-venv availability..."
    
    # Try to import venv module
    if ! $PYTHON_CMD -c "import venv" >/dev/null 2>&1; then
        # Detect distribution
        if command_exists apt-get; then
            print_error "python3-venv module is not installed."
            echo ""
            print_info "Installing python3-venv is required on Debian/Ubuntu systems."
            echo "  Run: sudo apt install python3.12-venv"
            echo "  Or:  sudo apt install python3-venv"
            exit 3
        elif command_exists dnf; then
            print_warning "venv module not found. It should be included with Python."
            print_info "If needed, install: sudo dnf install python3-devel"
        elif command_exists pacman; then
            print_warning "venv module not found. It should be included with Python."
        else
            print_error "venv module is not available for ${PYTHON_CMD}."
            echo ""
            print_info "Please install the venv module for your distribution."
            exit 3
        fi
    else
        print_success "python3-venv is available"
    fi
}

# Step 4: Create virtual environment
create_venv() {
    print_step 4 7 "Creating virtual environment..."
    
    # Check if venv already exists
    if [[ -d "$VENV_DIR" ]]; then
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            print_warning "Virtual environment exists. Removing due to --force flag..."
            rm -rf "$VENV_DIR"
            print_verbose "Removed existing virtual environment"
        else
            print_warning "Virtual environment already exists at: $VENV_DIR"
            print_info "Use --force to recreate the virtual environment"
            return 0
        fi
    fi
    
    # Create virtual environment
    print_verbose "Creating virtual environment at: $VENV_DIR"
    if ! $PYTHON_CMD -m venv "$VENV_DIR" 2>&1 | tee /tmp/venv_creation.log; then
        print_error "Failed to create virtual environment."
        echo ""
        print_info "Error log:"
        cat /tmp/venv_creation.log
        rm -f /tmp/venv_creation.log
        exit 4
    fi
    rm -f /tmp/venv_creation.log
    
    print_success "Virtual environment created at: $VENV_DIR"
}

# Step 5: Activate virtual environment and upgrade pip
activate_and_upgrade_pip() {
    print_step 5 7 "Activating virtual environment and upgrading pip..."
    
    # Activate virtual environment
    if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
        print_error "Virtual environment activation script not found."
        exit 4
    fi
    
    # Source the activation script
    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"
    print_verbose "Virtual environment activated"
    
    # Upgrade pip, setuptools, and wheel
    print_verbose "Upgrading pip, setuptools, and wheel..."
    if [[ "$VERBOSE" == "true" ]]; then
        python -m pip install --upgrade pip setuptools wheel
    else
        python -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1
    fi
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to upgrade pip, setuptools, and wheel."
        exit 5
    fi
    
    local pip_version=$(python -m pip --version | grep -oP '\d+\.\d+(\.\d+)?')
    print_success "pip upgraded to version ${pip_version}"
}

# Step 6: Install dependencies
install_dependencies() {
    print_step 6 7 "Installing dependencies..."
    
    # Check if pyproject.toml exists
    if [[ ! -f "$SCRIPT_DIR/pyproject.toml" ]]; then
        print_error "pyproject.toml not found at: $SCRIPT_DIR/pyproject.toml"
        echo ""
        print_info "Make sure you're running this script from the project root."
        exit 6
    fi
    
    print_verbose "Installing ai-sidecar package in editable mode..."
    
    # Install in editable mode
    if [[ "$VERBOSE" == "true" ]]; then
        python -m pip install -e "$SCRIPT_DIR"
    else
        echo -n "   Installing packages... "
        if python -m pip install -e "$SCRIPT_DIR" >/dev/null 2>&1; then
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${RED}Failed${NC}"
            print_error "Failed to install dependencies."
            echo ""
            print_info "Try running with --verbose flag for more details:"
            echo "  $0 --verbose"
            exit 6
        fi
    fi
    
    print_success "Dependencies installed successfully"
}

# Step 7: Verify installation
verify_installation() {
    print_step 7 7 "Verifying installation..."
    
    # Test 1: Import ai_sidecar module
    print_verbose "Testing ai_sidecar module import..."
    if ! python -c "import ai_sidecar" 2>/dev/null; then
        print_error "Failed to import ai_sidecar module."
        echo ""
        print_info "The package was installed but cannot be imported."
        print_info "This might indicate a configuration issue in pyproject.toml"
        exit 7
    fi
    print_verbose "Module import: OK"
    
    # Test 2: Check core dependencies
    print_verbose "Testing core dependencies..."
    if ! python -c "import zmq, pydantic, structlog, aiofiles" 2>/dev/null; then
        print_warning "Some core dependencies may not be properly installed."
        print_info "The installation completed, but some imports failed."
    else
        print_verbose "Core dependencies: OK"
    fi
    
    # Test 3: Try to get version (if available)
    print_verbose "Checking package version..."
    local version=$(python -c "import ai_sidecar; print(getattr(ai_sidecar, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
    if [[ "$version" != "unknown" ]]; then
        print_verbose "Package version: $version"
    fi
    
    # Test 4: Check if main module exists
    if [[ -f "$SCRIPT_DIR/ai_sidecar/main.py" ]]; then
        print_verbose "Main module found: ai_sidecar/main.py"
    fi
    
    print_success "Installation verified successfully"
}

# Display completion message
show_completion_message() {
    print_header "🎉 Installation Complete!"
    
    echo -e "${GREEN}${BOLD}✅ AI Sidecar has been successfully installed!${NC}\n"
    
    echo -e "${BOLD}📋 Next Steps:${NC}\n"
    
    echo -e "${CYAN}1.${NC} ${BOLD}Activate the virtual environment:${NC}"
    echo -e "   ${BLUE}source ${VENV_DIR}/bin/activate${NC}\n"
    
    echo -e "${CYAN}2.${NC} ${BOLD}Configure your environment (optional):${NC}"
    echo -e "   ${BLUE}cp .env.example .env${NC}"
    echo -e "   ${BLUE}nano .env${NC}  # or use your preferred editor\n"
    
    echo -e "${CYAN}3.${NC} ${BOLD}Start the AI Sidecar:${NC}"
    if [[ -d "$SCRIPT_DIR/ai_sidecar" ]]; then
        echo -e "   ${BLUE}cd ai_sidecar${NC}"
    fi
    echo -e "   ${BLUE}python main.py${NC}\n"
    
    echo -e "${CYAN}4.${NC} ${BOLD}In another terminal, start OpenKore:${NC}"
    echo -e "   ${BLUE}cd ${SCRIPT_DIR}${NC}"
    echo -e "   ${BLUE}./start.pl${NC}  # or perl openkore.pl\n"
    
    echo -e "${BOLD}📚 Documentation:${NC}"
    echo -e "   • Installation Guide: ${BLUE}${SCRIPT_DIR}/INSTALL.md${NC}"
    echo -e "   • Project README:     ${BLUE}${SCRIPT_DIR}/README.md${NC}"
    echo -e "   • AI Sidecar Docs:    ${BLUE}${SCRIPT_DIR}/ai_sidecar/README.md${NC}\n"
    
    echo -e "${BOLD}💡 Tips:${NC}"
    echo -e "   • Use ${CYAN}--verbose${NC} flag for detailed output during installation"
    echo -e "   • Use ${CYAN}--force${NC} flag to reinstall if needed"
    echo -e "   • Check logs if you encounter issues\n"
    
    echo -e "${YELLOW}⚠️  Remember:${NC} Always activate the virtual environment before running the AI Sidecar!"
    echo -e "   ${BLUE}source ${VENV_DIR}/bin/activate${NC}\n"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show header
    clear
    print_header "🚀 OpenKore AI Sidecar - Automated Installation"
    
    echo -e "${BOLD}Project:${NC} God-Tier AI Sidecar for OpenKore"
    echo -e "${BOLD}Version:${NC} 3.0.0"
    echo -e "${BOLD}Location:${NC} $SCRIPT_DIR"
    echo ""
    
    if [[ "$FORCE_INSTALL" == "true" ]]; then
        print_warning "Force install mode enabled - will recreate virtual environment"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Verbose mode enabled"
    fi
    
    echo ""
    
    # Run installation steps
    check_python_version
    check_pip
    check_venv
    create_venv
    activate_and_upgrade_pip
    install_dependencies
    verify_installation
    
    # Show completion message
    show_completion_message
}

################################################################################
# Script Entry Point
################################################################################

# Trap errors
trap 'print_error "Installation failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@"

exit 0