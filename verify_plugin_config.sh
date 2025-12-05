#!/bin/bash
###############################################################################
# Plugin Configuration Verification Script
###############################################################################
# This script verifies that the AI Bridge plugins are correctly configured
# for automatic loading in OpenKore.

set -e

echo "====================================="
echo "OpenKore Plugin Configuration Check"
echo "====================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if control/sys.txt exists
echo "1. Checking configuration files..."
if [ -f "control/sys.txt" ]; then
    echo -e "${GREEN}✓${NC} control/sys.txt found"
else
    echo -e "${RED}✗${NC} control/sys.txt not found"
    echo "   Creating from template..."
    if [ -f "control/sys.txt.example" ]; then
        cp control/sys.txt.example control/sys.txt
        echo -e "${GREEN}✓${NC} Created control/sys.txt from template"
    else
        echo -e "${RED}✗${NC} Template not found - manual creation required"
        exit 1
    fi
fi

echo ""

# Check if plugins exist
echo "2. Checking plugin files..."

if [ -f "plugins/AI_Bridge/AI_Bridge.pl" ]; then
    echo -e "${GREEN}✓${NC} AI_Bridge.pl found in plugins/AI_Bridge/"
else
    echo -e "${RED}✗${NC} AI_Bridge.pl not found"
    exit 1
fi

if [ -f "plugins/godtier_chat_bridge.pl" ]; then
    echo -e "${GREEN}✓${NC} godtier_chat_bridge.pl found in plugins/"
else
    echo -e "${RED}✗${NC} godtier_chat_bridge.pl not found"
    exit 1
fi

echo ""

# Check sys.txt configuration
echo "3. Verifying sys.txt configuration..."

if grep -q "loadPlugins 2" control/sys.txt; then
    echo -e "${GREEN}✓${NC} Plugin loading mode set to 2 (selective)"
else
    echo -e "${YELLOW}!${NC} loadPlugins mode not set to 2"
fi

if grep -q "loadPlugins_list AI_Bridge" control/sys.txt; then
    echo -e "${GREEN}✓${NC} AI_Bridge configured for auto-load"
else
    echo -e "${RED}✗${NC} AI_Bridge not in loadPlugins_list"
    exit 1
fi

if grep -q "loadPlugins_list godtier_chat_bridge" control/sys.txt; then
    echo -e "${GREEN}✓${NC} godtier_chat_bridge configured for auto-load"
else
    echo -e "${RED}✗${NC} godtier_chat_bridge not in loadPlugins_list"
    exit 1
fi

echo ""

# Check documentation
echo "4. Checking documentation..."

if [ -f "control/README_PLUGINS.txt" ]; then
    echo -e "${GREEN}✓${NC} Plugin documentation found"
else
    echo -e "${YELLOW}!${NC} Plugin documentation missing"
fi

echo ""

# Summary
echo "====================================="
echo "Verification Summary"
echo "====================================="
echo ""
echo "Configuration Status: ${GREEN}READY${NC}"
echo ""
echo "Next Steps:"
echo "  1. Start AI Sidecar:"
echo "     cd ai_sidecar && python main.py"
echo ""
echo "  2. Start OpenKore:"
echo "     perl start.pl"
echo ""
echo "  3. Watch for these messages:"
echo "     [Plugins] Loading plugin plugins/AI_Bridge/AI_Bridge.pl..."
echo "     [AI_Bridge] Plugin loaded"
echo "     [Plugins] Loading plugin plugins/godtier_chat_bridge.pl..."
echo "     [ChatBridge] Plugin loaded"
echo "     ✅ God-Tier AI activated!"
echo ""
echo "Documentation:"
echo "  - Plugin Guide: control/README_PLUGINS.txt"
echo "  - Config Template: control/sys.txt.example"
echo "  - Main README: README.md (Plugin Auto-Loading section)"
echo ""
echo "====================================="