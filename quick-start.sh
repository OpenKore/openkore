#!/bin/bash
################################################################################
# OpenKore AI - Quick Start Script for Linux
#
# This script provides a one-click startup experience for the OpenKore AI bot
# system. It automatically starts both the AI Sidecar and OpenKore bot.
#
# Usage:
#   ./quick-start.sh [OPTIONS]
#
# First time setup:
#   chmod +x quick-start.sh
#   ./quick-start.sh
#
# Options:
#   -h, --help      Show this help message
#
# Requirements:
#   - Virtual environment must be installed (run ./install.sh first)
#   - AI Sidecar configured (optional .env file)
#   - Terminal emulator (gnome-terminal, xterm, konsole, etc.)
#
# To stop both services:
#   - Press Ctrl+C in each terminal window
#   - Or close the terminal windows
################################################################################

set -o pipefail  # Exit on pipe failure

################################################################################
# Configuration
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/ai_sidecar/.venv"
AI_SIDECAR_DIR="${SCRIPT_DIR}/ai_sidecar"
ENV_FILE="${AI_SIDECAR_DIR}/.env"
ENV_EXAMPLE="${AI_SIDECAR_DIR}/.env.example"
OPENKORE_SCRIPT="${SCRIPT_DIR}/start.pl"

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
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    # No color support
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
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
    echo -e "${CYAN}ℹ️  INFO: $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Show usage
show_usage() {
    cat << EOF
${BOLD}OpenKore AI - Quick Start Script${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help      Show this help message

${BOLD}DESCRIPTION:${NC}
    This script provides a one-click startup for the OpenKore AI system.
    It automatically:
    
    1. Verifies prerequisites (virtual environment, files)
    2. Checks/configures environment (.env file)
    3. Starts AI Sidecar in a new terminal
    4. Waits for AI Sidecar to initialize
    5. Starts OpenKore bot

${BOLD}FIRST TIME SETUP:${NC}
    Make the script executable:
    ${CYAN}chmod +x quick-start.sh${NC}

${BOLD}REQUIREMENTS:${NC}
    - Virtual environment must be installed
      Run: ${CYAN}./install.sh${NC}
    
    - AI Sidecar configured (optional .env file)
      File: ${CYAN}ai_sidecar/.env${NC}
    
    - Terminal emulator (gnome-terminal, xterm, konsole, etc.)

${BOLD}STOPPING SERVICES:${NC}
    To stop both services:
    • Press Ctrl+C in each terminal window
    • Or simply close the terminal windows

For installation help, run: ${CYAN}./install.sh --help${NC}
EOF
}

# Detect available terminal emulator
detect_terminal() {
    local terminals=(
        "gnome-terminal"
        "konsole"
        "xfce4-terminal"
        "mate-terminal"
        "xterm"
        "terminator"
        "tilix"
        "kitty"
        "alacritty"
    )
    
    for term in "${terminals[@]}"; do
        if command_exists "$term"; then
            echo "$term"
            return 0
        fi
    done
    
    return 1
}

# Get terminal launch command
get_terminal_command() {
    local terminal=$1
    local title=$2
    local command=$3
    
    case "$terminal" in
        gnome-terminal)
            echo "gnome-terminal --title=\"$title\" -- bash -c '$command; exec bash'"
            ;;
        konsole)
            echo "konsole --title \"$title\" -e bash -c '$command; exec bash'"
            ;;
        xfce4-terminal)
            echo "xfce4-terminal --title=\"$title\" -e \"bash -c '$command; exec bash'\""
            ;;
        mate-terminal)
            echo "mate-terminal --title=\"$title\" -e \"bash -c '$command; exec bash'\""
            ;;
        xterm)
            echo "xterm -T \"$title\" -e bash -c '$command; exec bash'"
            ;;
        terminator)
            echo "terminator --title=\"$title\" -e \"bash -c '$command; exec bash'\""
            ;;
        tilix)
            echo "tilix --title=\"$title\" -e \"bash -c '$command; exec bash'\""
            ;;
        kitty)
            echo "kitty --title \"$title\" bash -c '$command; exec bash'"
            ;;
        alacritty)
            echo "alacritty --title \"$title\" -e bash -c '$command; exec bash'"
            ;;
        *)
            return 1
            ;;
    esac
}

################################################################################
# Parse command-line arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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
# Main Functions
################################################################################

# Step 1: Check Prerequisites
check_prerequisites() {
    print_step 1 5 "Checking prerequisites..."
    
    # Check if we're in the correct directory
    if [[ ! -f "$SCRIPT_DIR/pyproject.toml" ]]; then
        print_error "pyproject.toml not found!"
        echo ""
        print_info "Please run this script from the openkore-AI directory."
        echo "Current directory: $PWD"
        return 1
    fi
    
    # Check if virtual environment exists
    if [[ ! -f "$VENV_DIR/bin/python" ]]; then
        print_error "Virtual environment not found!"
        echo ""
        print_info "The virtual environment does not exist at:"
        echo "  $VENV_DIR"
        echo ""
        print_info "Please run the installation script first:"
        echo "  ${GREEN}./install.sh${NC}"
        return 1
    fi
    
    # Check if AI Sidecar main.py exists
    if [[ ! -f "$AI_SIDECAR_DIR/main.py" ]]; then
        print_error "AI Sidecar main.py not found!"
        echo ""
        print_info "Expected at: $AI_SIDECAR_DIR/main.py"
        return 1
    fi
    
    # Check if OpenKore start.pl exists
    if [[ ! -f "$OPENKORE_SCRIPT" ]]; then
        print_error "OpenKore start.pl not found!"
        echo ""
        print_info "Expected at: $OPENKORE_SCRIPT"
        return 1
    fi
    
    # Check if perl is available
    if ! command_exists perl; then
        print_warning "Perl not found. OpenKore requires Perl to run."
        print_info "Install Perl:"
        echo "  Ubuntu/Debian: sudo apt install perl"
        echo "  Fedora/RHEL:   sudo dnf install perl"
        echo "  Arch Linux:    sudo pacman -S perl"
        return 1
    fi
    
    print_success "All prerequisites verified"
    return 0
}

# Step 2: Check Environment
check_environment() {
    print_step 2 5 "Checking environment configuration..."
    
    # Check if .env file exists
    if [[ -f "$ENV_FILE" ]]; then
        print_success "Environment file found: .env"
        return 0
    fi
    
    # .env doesn't exist, check if .env.example exists
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
        print_warning "No .env or .env.example file found"
        echo ""
        print_info "The AI Sidecar will use default settings."
        echo "You can create a .env file later for custom configuration."
        echo ""
        read -p "Continue with default settings? (Y/N): " continue_default
        if [[ "${continue_default^^}" == "Y" ]]; then
            echo ""
            print_info "Continuing with default settings..."
            return 0
        else
            return 1
        fi
    fi
    
    # .env.example exists, ask user if they want to copy it
    print_info "No .env file found"
    echo ""
    echo "A .env.example file is available with default configuration."
    echo ""
    read -p "Would you like to copy it to .env now? (Y/N): " copy_env
    
    if [[ "${copy_env^^}" == "Y" ]]; then
        echo ""
        print_info "Copying .env.example to .env..."
        if cp "$ENV_EXAMPLE" "$ENV_FILE"; then
            print_success "Environment file created: .env"
            echo ""
            print_info "You may want to edit the .env file to configure:"
            echo "  • API keys (OpenAI, Anthropic, etc.)"
            echo "  • Redis connection"
            echo "  • Log settings"
            echo ""
            read -p "Would you like to open .env for editing now? (Y/N): " edit_env
            if [[ "${edit_env^^}" == "Y" ]]; then
                echo ""
                print_info "Opening .env in editor..."
                # Try to find an editor
                if command_exists nano; then
                    nano "$ENV_FILE"
                elif command_exists vim; then
                    vim "$ENV_FILE"
                elif command_exists vi; then
                    vi "$ENV_FILE"
                elif command_exists gedit; then
                    gedit "$ENV_FILE" &
                else
                    print_warning "No text editor found. Please edit manually:"
                    echo "  $ENV_FILE"
                fi
            fi
            echo ""
            return 0
        else
            print_error "Failed to copy .env.example to .env"
            return 1
        fi
    else
        echo ""
        print_warning "Continuing without .env file"
        echo "The AI Sidecar will use default settings."
        echo ""
        read -p "Continue? (Y/N): " continue_no_env
        if [[ "${continue_no_env^^}" == "Y" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# Step 3: Start AI Sidecar
start_ai_sidecar() {
    print_step 3 5 "Starting AI Sidecar..."
    
    # Detect terminal emulator
    local terminal
    terminal=$(detect_terminal)
    if [[ $? -ne 0 ]]; then
        print_error "No suitable terminal emulator found!"
        echo ""
        print_info "Please install one of the following:"
        echo "  • gnome-terminal (recommended)"
        echo "  • konsole"
        echo "  • xterm"
        echo "  • xfce4-terminal"
        return 1
    fi
    
    echo ""
    print_info "Using terminal emulator: $terminal"
    
    # Prepare the command to run in new terminal
    local sidecar_command="echo ''; \
echo '============================================================================'; \
echo '   OpenKore AI - AI Sidecar'; \
echo '============================================================================'; \
echo ''; \
echo -e '${CYAN}[INFO]${NC} Activating virtual environment...'; \
source '$VENV_DIR/bin/activate' || { echo -e '${RED}[ERROR] Failed to activate virtual environment!${NC}'; read -p 'Press Enter to exit...'; exit 1; }; \
echo -e '${GREEN}[OK]${NC} Virtual environment activated'; \
echo ''; \
echo -e '${CYAN}[INFO]${NC} Starting AI Sidecar...'; \
echo ''; \
cd '$AI_SIDECAR_DIR' || exit 1; \
python main.py; \
echo ''; \
echo -e '${RED}AI Sidecar has stopped.${NC}'; \
read -p 'Press Enter to exit...'"
    
    # Get the appropriate terminal launch command
    local terminal_cmd
    terminal_cmd=$(get_terminal_command "$terminal" "OpenKore AI - AI Sidecar" "$sidecar_command")
    
    # Launch the terminal
    if eval "$terminal_cmd" &>/dev/null &; then
        print_success "AI Sidecar started in new terminal"
        return 0
    else
        print_error "Failed to start new terminal window"
        return 1
    fi
}

# Step 4: Wait for AI Sidecar to initialize
wait_for_sidecar() {
    print_step 4 5 "Waiting for AI Sidecar to initialize..."
    echo ""
    print_info "Waiting for AI Sidecar to initialize..."
    echo ""
    
    # Countdown from 3 seconds
    for i in 3 2 1; do
        echo "   Starting OpenKore in $i seconds..."
        sleep 1
    done
    
    echo ""
    print_success "AI Sidecar should be ready"
}

# Step 5: Start OpenKore
start_openkore() {
    print_step 5 5 "Starting OpenKore..."
    
    # Detect terminal emulator
    local terminal
    terminal=$(detect_terminal)
    if [[ $? -ne 0 ]]; then
        # If no terminal found, try to run directly
        print_warning "No terminal emulator found, starting OpenKore in current terminal..."
        echo ""
        cd "$SCRIPT_DIR" || return 1
        perl "$OPENKORE_SCRIPT"
        return $?
    fi
    
    echo ""
    print_info "Launching OpenKore in new terminal..."
    
    # Prepare the command to run in new terminal
    local openkore_command="cd '$SCRIPT_DIR' && perl '$OPENKORE_SCRIPT'; echo ''; echo -e '${RED}OpenKore has stopped.${NC}'; read -p 'Press Enter to exit...'"
    
    # Get the appropriate terminal launch command
    local terminal_cmd
    terminal_cmd=$(get_terminal_command "$terminal" "OpenKore AI - Bot" "$openkore_command")
    
    # Launch the terminal
    if eval "$terminal_cmd" &>/dev/null &; then
        print_success "OpenKore started in new terminal"
        return 0
    else
        print_error "Failed to start OpenKore"
        echo ""
        print_info "Make sure start.pl is present at:"
        echo "  $OPENKORE_SCRIPT"
        return 1
    fi
}

# Show success message
show_success_message() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}   All Services Started Successfully!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}Running Services:${NC}"
    echo -e "   ${GREEN}✓${NC} AI Sidecar    - Running in separate terminal"
    echo -e "   ${GREEN}✓${NC} OpenKore Bot  - Running in separate terminal"
    echo ""
    echo -e "${CYAN}${BOLD}Next Steps:${NC}"
    echo "   1. Monitor the AI Sidecar terminal for AI activity"
    echo "   2. Configure OpenKore bot settings as needed"
    echo "   3. The bot will use AI for decision-making"
    echo ""
    echo -e "${CYAN}${BOLD}To Stop Services:${NC}"
    echo -e "   • Press ${YELLOW}Ctrl+C${NC} in the AI Sidecar terminal"
    echo "   • Close the OpenKore terminal or type 'quit'"
    echo "   • Or close both terminal windows"
    echo ""
    echo -e "${CYAN}${BOLD}Troubleshooting:${NC}"
    echo "   • Check AI Sidecar terminal for connection status"
    echo "   • Verify .env configuration if using API keys"
    echo "   • See logs in ai_sidecar/logs/ for detailed info"
    echo ""
    echo -e "${CYAN}${BOLD}For help:${NC} ./quick-start.sh --help"
    echo ""
}

################################################################################
# Main Execution Flow
################################################################################

main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show header
    clear
    print_header "🚀 OpenKore AI - Quick Start"
    
    # Run startup steps
    if ! check_prerequisites; then
        echo ""
        exit 1
    fi
    
    echo ""
    
    if ! check_environment; then
        echo ""
        print_warning "Environment setup cancelled by user."
        echo ""
        exit 1
    fi
    
    echo ""
    
    if ! start_ai_sidecar; then
        echo ""
        print_error "Failed to start AI Sidecar!"
        echo ""
        exit 1
    fi
    
    echo ""
    
    wait_for_sidecar
    
    echo ""
    
    if ! start_openkore; then
        echo ""
        print_error "Failed to start OpenKore!"
        echo ""
        exit 1
    fi
    
    # Show success message
    show_success_message
}

################################################################################
# Script Entry Point
################################################################################

# Run main function
main "$@"

exit 0