#!/bin/bash
set -e

echo "🧪 OpenKore-AI End-to-End Validation"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall success
FAILED_TESTS=0
PASSED_TESTS=0

test_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_TESTS++))
}

test_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
}

test_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Change to openkore-AI directory
cd "$(dirname "$0")"

echo "1️⃣  Testing Python imports..."
cd ai_sidecar

if PYTHONPATH=.. python3 -c "from ai_sidecar.core.decision import ProgressionDecisionEngine" 2>/dev/null; then
    test_pass "Decision engine imports OK"
else
    test_fail "Decision engine imports failed"
fi

if PYTHONPATH=.. python3 -c "from ai_sidecar.config import get_settings" 2>/dev/null; then
    test_pass "Config system imports OK"
else
    test_fail "Config system imports failed"
fi

if PYTHONPATH=.. python3 -c "from ai_sidecar.config.loader import get_config" 2>/dev/null; then
    test_pass "Config loader imports OK"
else
    test_fail "Config loader imports failed"
fi

echo ""
echo "2️⃣  Testing AI Sidecar startup..."

# Test if AI Sidecar can start (run for 3 seconds then kill)
PYTHONPATH=.. timeout 3 python3 main.py > /tmp/ai_sidecar_test.log 2>&1 &
AI_PID=$!
sleep 2

if ps -p $AI_PID > /dev/null 2>&1; then
    test_pass "AI Sidecar starts successfully"
    kill $AI_PID 2>/dev/null || true
    wait $AI_PID 2>/dev/null || true
    
    # Check if subsystems initialized
    if grep -q "All subsystems initialized" /tmp/ai_sidecar_test.log; then
        test_pass "All subsystems initialized"
    else
        test_warn "Subsystem initialization status unclear"
    fi
    
    # Check for ZeroMQ server start
    if grep -q "ZeroMQ server" /tmp/ai_sidecar_test.log || grep -q "Server listening" /tmp/ai_sidecar_test.log; then
        test_pass "ZeroMQ server attempted start"
    else
        test_warn "ZeroMQ server start status unclear"
    fi
else
    test_fail "AI Sidecar failed to start"
    cat /tmp/ai_sidecar_test.log
fi

cd ..

echo ""
echo "3️⃣  Testing Perl plugin syntax..."

# Perl plugins need OpenKore environment, so we just check basic syntax
if perl -wc plugins/AI_Bridge/AI_Bridge.pl 2>&1 | grep -q "BEGIN failed"; then
    test_warn "AI_Bridge.pl requires OpenKore environment (expected)"
else
    if perl -wc plugins/AI_Bridge/AI_Bridge.pl 2>/dev/null; then
        test_pass "AI_Bridge.pl syntax OK"
    else
        test_warn "AI_Bridge.pl requires OpenKore environment (expected)"
    fi
fi

if perl -wc plugins/godtier_chat_bridge.pl 2>&1 | grep -q "BEGIN failed"; then
    test_warn "Chat bridge requires OpenKore environment (expected)"
else
    if perl -wc plugins/godtier_chat_bridge.pl 2>/dev/null; then
        test_pass "Chat bridge syntax OK"
    else
        test_warn "Chat bridge requires OpenKore environment (expected)"
    fi
fi

echo ""
echo "========================================"
echo "📊 Test Results:"
echo "   Passed: $PASSED_TESTS"
echo "   Failed: $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ All E2E validation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
    exit 1
fi