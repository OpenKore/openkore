"""
Test fixes and patches to apply.

This file documents all the fixes needed for the comprehensive tests.
"""

# Fix 1: ChatMessage uses message_id not id
# All ChatMessage(..., id="1", ...) should be ChatMessage(..., message_id="1", ...)

# Fix 2: Import DailyQuestCategory in coordinator tests
# Add: from ai_sidecar.quests.daily import DailyQuestCategory

# Fix 3: Fix coordinator.py line 183 - should use DailyQuestCategory not self.daily.DailyQuestCategory
# The coordinator imports DailyQuestCategory and should use it directly

# Fix 4: party_manager.py assign_roles doesn't handle "sniper" - need to add it
# Line 444: elif "hunter" in job or "archer" in job or "bard" in job or "dancer" in job:
# Should include "sniper"

# Fix 5: Fix target_hp_percent condition evaluation - when target_state is None, should return False

# Fix 6: config needs "friend" key in PARTY_ACCEPT_CRITERIA (it has "friend_list")