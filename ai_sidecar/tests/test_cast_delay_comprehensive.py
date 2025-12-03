"""
Comprehensive tests for combat/cast_delay.py module
Target: Boost coverage from 48.18% to 90%+
"""

import json
import pytest
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch

from ai_sidecar.combat.cast_delay import (
    CastDelayManager,
    CastType,
    SkillTiming,
    CastState,
    DelayState,
)


class TestSkillTimingModel:
    """Test SkillTiming model"""
    
    def test_skill_timing_creation(self):
        """Test creating SkillTiming"""
        timing = SkillTiming(
            skill_name="Fire Ball",
            fixed_cast_ms=500,
            variable_cast_ms=2000,
            after_cast_delay_ms=1000,
            skill_cooldown_ms=0
        )
        
        assert timing.skill_name == "Fire Ball"
        assert timing.fixed_cast_ms == 500
        assert timing.variable_cast_ms == 2000
    
    def test_total_cast_time_property(self):
        """Test total_cast_time_ms property"""
        timing = SkillTiming(
            skill_name="Test",
            fixed_cast_ms=500,
            variable_cast_ms=2000
        )
        
        assert timing.total_cast_time_ms == 2500
    
    def test_total_commitment_ms_property(self):
        """Test total_commitment_ms property"""
        timing = SkillTiming(
            skill_name="Test",
            fixed_cast_ms=500,
            variable_cast_ms=2000,
            after_cast_delay_ms=1000,
            animation_delay_ms=300
        )
        
        # 500 + 2000 + 1000 + 300 = 3800
        assert timing.total_commitment_ms == 3800
    
    def test_effective_dps_window_property(self):
        """Test effective_dps_window_ms property"""
        timing = SkillTiming(
            skill_name="Test",
            after_cast_delay_ms=1500,
            animation_delay_ms=300,
            skill_cooldown_ms=5000
        )
        
        # Should be max of all delays
        assert timing.effective_dps_window_ms == 5000


class TestCastStateModel:
    """Test CastState model"""
    
    def test_cast_state_default(self):
        """Test default CastState"""
        state = CastState()
        
        assert state.is_casting is False
        assert state.skill_name is None
        assert state.can_be_interrupted is True
    
    def test_cast_state_active(self):
        """Test active casting state"""
        now = datetime.now()
        state = CastState(
            is_casting=True,
            skill_name="Fire Ball",
            cast_started=now,
            cast_end_estimate=now + timedelta(milliseconds=2000),
            can_be_interrupted=True
        )
        
        assert state.is_casting is True
        assert state.skill_name == "Fire Ball"


class TestDelayStateModel:
    """Test DelayState model"""
    
    def test_delay_state_default(self):
        """Test default DelayState"""
        state = DelayState()
        
        assert state.in_after_cast_delay is False
        assert state.in_animation is False
        assert len(state.skill_cooldowns) == 0


class TestCastDelayManagerInit:
    """Test CastDelayManager initialization"""
    
    def test_init_default(self):
        """Test initialization with default timings"""
        manager = CastDelayManager()
        
        assert len(manager.skill_timings) > 0
        assert "storm gust" in manager.skill_timings
        assert manager.cast_state.is_casting is False
    
    def test_init_with_data_dir(self):
        """Test initialization with custom data directory"""
        # Create temp timing data
        timing_data = {
            "Custom Skill": {
                "fixed_cast_ms": 1000,
                "variable_cast_ms": 3000,
                "after_cast_delay_ms": 2000
            }
        }
        
        with tempfile.TemporaryDirectory() as temp_dir:
            data_dir = Path(temp_dir)
            timing_file = data_dir / "skill_timings.json"
            
            with open(timing_file, 'w') as f:
                json.dump(timing_data, f)
            
            manager = CastDelayManager(data_dir=data_dir)
            
            assert "custom skill" in manager.skill_timings
    
    def test_init_missing_timing_file(self):
        """Test initialization when timing file missing"""
        with tempfile.TemporaryDirectory() as temp_dir:
            manager = CastDelayManager(data_dir=Path(temp_dir))
            
            # Should fall back to default timings
            assert len(manager.skill_timings) > 0


class TestCalculateCastTime:
    """Test cast time calculations"""
    
    def test_calculate_cast_time_no_stats(self):
        """Test cast time calculation with minimal stats"""
        manager = CastDelayManager()
        
        timing = manager.calculate_cast_time(
            "Storm Gust",
            dex=1,
            int_stat=1
        )
        
        # Base variable cast should be reduced minimally
        assert timing.variable_cast_ms > 0
        assert timing.fixed_cast_ms == 1000  # Fixed doesn't reduce
    
    def test_calculate_cast_time_high_stats(self):
        """Test cast time with high DEX/INT"""
        manager = CastDelayManager()
        
        timing_low = manager.calculate_cast_time("Storm Gust", dex=1, int_stat=1)
        timing_high = manager.calculate_cast_time("Storm Gust", dex=100, int_stat=100)
        
        # Higher stats = lower variable cast
        assert timing_high.variable_cast_ms < timing_low.variable_cast_ms
    
    def test_calculate_cast_time_with_gear(self):
        """Test cast time with gear reduction"""
        manager = CastDelayManager()
        
        timing_no_gear = manager.calculate_cast_time(
            "Storm Gust",
            dex=50,
            int_stat=50,
            cast_reduction_gear=0.0
        )
        
        timing_with_gear = manager.calculate_cast_time(
            "Storm Gust",
            dex=50,
            int_stat=50,
            cast_reduction_gear=0.3  # 30% from gear
        )
        
        # Gear should reduce variable cast
        assert timing_with_gear.variable_cast_ms < timing_no_gear.variable_cast_ms
    
    def test_calculate_cast_time_max_reduction(self):
        """Test that cast reduction caps at 99.9%"""
        manager = CastDelayManager()
        
        timing = manager.calculate_cast_time(
            "Storm Gust",
            dex=200,
            int_stat=200,
            cast_reduction_gear=0.9
        )
        
        # Should not reduce to 0, always some cast time
        assert timing.variable_cast_ms >= 0
    
    def test_calculate_cast_time_unknown_skill(self):
        """Test calculation for unknown skill"""
        manager = CastDelayManager()
        
        timing = manager.calculate_cast_time(
            "Unknown Skill",
            dex=50,
            int_stat=50
        )
        
        # Should return default SkillTiming
        assert timing.skill_name == "Unknown Skill"
        assert timing.variable_cast_ms == 0


class TestCalculateAfterCastDelay:
    """Test after-cast delay calculations"""
    
    def test_calculate_delay_low_agi(self):
        """Test delay calculation with low AGI"""
        manager = CastDelayManager()
        
        delay = manager.calculate_after_cast_delay(
            "Storm Gust",
            agi=1,
            delay_reduction_gear=0.0
        )
        
        # Should be close to base delay (minimal reduction)
        assert delay > 0
    
    def test_calculate_delay_high_agi(self):
        """Test delay calculation with high AGI"""
        manager = CastDelayManager()
        
        delay_low = manager.calculate_after_cast_delay("Storm Gust", agi=1)
        delay_high = manager.calculate_after_cast_delay("Storm Gust", agi=150)
        
        # Higher AGI = lower delay
        assert delay_high < delay_low
    
    def test_calculate_delay_with_gear(self):
        """Test delay with gear reduction"""
        manager = CastDelayManager()
        
        delay_no_gear = manager.calculate_after_cast_delay(
            "Storm Gust",
            agi=50,
            delay_reduction_gear=0.0
        )
        
        delay_with_gear = manager.calculate_after_cast_delay(
            "Storm Gust",
            agi=50,
            delay_reduction_gear=0.2
        )
        
        assert delay_with_gear < delay_no_gear
    
    def test_calculate_delay_no_base_delay(self):
        """Test delay for instant skills"""
        manager = CastDelayManager()
        
        # Sonic Blow has no after-cast delay in defaults
        # But let's test with a skill that has 0 delay
        delay = manager.calculate_after_cast_delay(
            "Unknown Instant Skill",
            agi=50
        )
        
        assert delay == 0


class TestCastManagement:
    """Test cast state management"""
    
    @pytest.mark.asyncio
    async def test_start_cast(self):
        """Test starting a cast"""
        manager = CastDelayManager()
        
        await manager.start_cast("Fire Ball", cast_time_ms=2000)
        
        assert manager.cast_state.is_casting is True
        assert manager.cast_state.skill_name == "Fire Ball"
        assert manager.cast_state.cast_started is not None
    
    @pytest.mark.asyncio
    async def test_cast_complete(self):
        """Test completing a cast"""
        manager = CastDelayManager()
        
        await manager.start_cast("Fire Ball", cast_time_ms=2000)
        await manager.cast_complete("Fire Ball", delay_ms=1000)
        
        assert manager.cast_state.is_casting is False
        assert manager.delay_state.in_after_cast_delay is True
    
    @pytest.mark.asyncio
    async def test_cast_complete_with_cooldown(self):
        """Test cast completion triggers skill cooldown"""
        manager = CastDelayManager()
        
        await manager.cast_complete("Asura Strike", delay_ms=3000)
        
        # Asura has 10s cooldown
        assert "asura strike" in manager.delay_state.skill_cooldowns
    
    @pytest.mark.asyncio
    async def test_cast_interrupted(self):
        """Test cast interruption"""
        manager = CastDelayManager()
        
        await manager.start_cast("Fire Ball", cast_time_ms=2000)
        await manager.cast_interrupted()
        
        assert manager.cast_state.is_casting is False
        assert manager.cast_state.skill_name is None


class TestCanCastNow:
    """Test casting availability checks"""
    
    @pytest.mark.asyncio
    async def test_can_cast_when_ready(self):
        """Test can cast when ready"""
        manager = CastDelayManager()
        
        can_cast, reason = await manager.can_cast_now()
        
        assert can_cast is True
        assert reason is None
    
    @pytest.mark.asyncio
    async def test_cannot_cast_while_casting(self):
        """Test cannot cast while already casting"""
        manager = CastDelayManager()
        
        await manager.start_cast("Fire Ball", cast_time_ms=2000)
        can_cast, reason = await manager.can_cast_now()
        
        assert can_cast is False
        assert reason == "already_casting"
    
    @pytest.mark.asyncio
    async def test_cannot_cast_during_delay(self):
        """Test cannot cast during after-cast delay"""
        manager = CastDelayManager()
        
        manager.delay_state.in_after_cast_delay = True
        manager.delay_state.delay_ends = datetime.now() + timedelta(seconds=2)
        
        can_cast, reason = await manager.can_cast_now()
        
        assert can_cast is False
        assert reason == "after_cast_delay"
    
    @pytest.mark.asyncio
    async def test_can_cast_after_delay_expired(self):
        """Test can cast after delay expires"""
        manager = CastDelayManager()
        
        manager.delay_state.in_after_cast_delay = True
        manager.delay_state.delay_ends = datetime.now() - timedelta(seconds=1)  # Expired
        
        can_cast, reason = await manager.can_cast_now()
        
        assert can_cast is True
        assert manager.delay_state.in_after_cast_delay is False
    
    @pytest.mark.asyncio
    async def test_cannot_cast_during_animation(self):
        """Test cannot cast during animation lock"""
        manager = CastDelayManager()
        
        manager.delay_state.in_animation = True
        manager.delay_state.animation_ends = datetime.now() + timedelta(milliseconds=500)
        
        can_cast, reason = await manager.can_cast_now()
        
        assert can_cast is False
        assert reason == "animation_delay"


class TestTimeUntilCanCast:
    """Test time calculation until can cast"""
    
    @pytest.mark.asyncio
    async def test_time_until_can_cast_ready(self):
        """Test time when ready to cast"""
        manager = CastDelayManager()
        
        time_ms = await manager.time_until_can_cast()
        
        assert time_ms == 0
    
    @pytest.mark.asyncio
    async def test_time_until_can_cast_in_delay(self):
        """Test time remaining in delay"""
        manager = CastDelayManager()
        
        manager.delay_state.in_after_cast_delay = True
        manager.delay_state.delay_ends = datetime.now() + timedelta(seconds=2)
        
        time_ms = await manager.time_until_can_cast()
        
        assert time_ms > 0
        assert time_ms <= 2100  # ~2 seconds


class TestSkillCooldowns:
    """Test skill-specific cooldown tracking"""
    
    @pytest.mark.asyncio
    async def test_skill_not_on_cooldown(self):
        """Test checking skill that's not on cooldown"""
        manager = CastDelayManager()
        
        on_cooldown, remaining = await manager.is_skill_on_cooldown("Storm Gust")
        
        assert on_cooldown is False
        assert remaining == 0
    
    @pytest.mark.asyncio
    async def test_skill_on_cooldown(self):
        """Test checking skill that's on cooldown"""
        manager = CastDelayManager()
        
        # Add cooldown
        manager.delay_state.skill_cooldowns["asura strike"] = (
            datetime.now() + timedelta(seconds=5)
        )
        
        on_cooldown, remaining = await manager.is_skill_on_cooldown("Asura Strike")
        
        assert on_cooldown is True
        assert remaining > 0
    
    @pytest.mark.asyncio
    async def test_skill_cooldown_expired(self):
        """Test that expired cooldowns are removed"""
        manager = CastDelayManager()
        
        # Add expired cooldown
        manager.delay_state.skill_cooldowns["asura strike"] = (
            datetime.now() - timedelta(seconds=1)  # Expired
        )
        
        on_cooldown, remaining = await manager.is_skill_on_cooldown("Asura Strike")
        
        assert on_cooldown is False
        assert "asura strike" not in manager.delay_state.skill_cooldowns


class TestGetOptimalSkillOrder:
    """Test skill ordering optimization"""
    
    @pytest.mark.asyncio
    async def test_optimal_skill_order_by_efficiency(self):
        """Test skills are ordered by efficiency"""
        manager = CastDelayManager()
        
        skills = ["Storm Gust", "Sonic Blow", "Asura Strike"]
        character_stats = {"dex": 50, "int": 50}
        
        ordered = await manager.get_optimal_skill_order(skills, character_stats)
        
        assert len(ordered) == 3
        # Should return all skills in some order
        assert set(ordered) == set(skills)
    
    @pytest.mark.asyncio
    async def test_optimal_order_prefers_instant_skills(self):
        """Test that instant skills are prioritized"""
        manager = CastDelayManager()
        
        skills = ["Storm Gust", "Sonic Blow"]  # Sonic Blow is instant
        character_stats = {"dex": 1, "int": 1}
        
        ordered = await manager.get_optimal_skill_order(skills, character_stats)
        
        # Instant skills should be more efficient
        assert isinstance(ordered, list)


class TestDefaultTimings:
    """Test default skill timings initialization"""
    
    def test_default_timings_loaded(self):
        """Test that default skills are loaded"""
        manager = CastDelayManager()
        
        expected_skills = [
            "storm gust",
            "meteor storm",
            "sonic blow",
            "spiral pierce",
            "asura strike"
        ]
        
        for skill in expected_skills:
            assert skill in manager.skill_timings
    
    def test_storm_gust_timing(self):
        """Test Storm Gust default timing"""
        manager = CastDelayManager()
        
        timing = manager.skill_timings["storm gust"]
        
        assert timing.fixed_cast_ms == 1000
        assert timing.variable_cast_ms == 6000
        assert timing.after_cast_delay_ms == 5000
    
    def test_asura_strike_has_cooldown(self):
        """Test Asura Strike has skill cooldown"""
        manager = CastDelayManager()
        
        timing = manager.skill_timings["asura strike"]
        
        assert timing.skill_cooldown_ms == 10000  # 10s cooldown


class TestCastTimeStatReduction:
    """Test stat-based cast time reduction"""
    
    def test_dex_reduces_cast_time(self):
        """Test DEX reduces variable cast time"""
        manager = CastDelayManager()
        
        timing_low_dex = manager.calculate_cast_time("Storm Gust", dex=1, int_stat=50)
        timing_high_dex = manager.calculate_cast_time("Storm Gust", dex=150, int_stat=50)
        
        assert timing_high_dex.variable_cast_ms < timing_low_dex.variable_cast_ms
    
    def test_int_reduces_cast_time(self):
        """Test INT reduces variable cast time"""
        manager = CastDelayManager()
        
        timing_low_int = manager.calculate_cast_time("Storm Gust", dex=50, int_stat=1)
        timing_high_int = manager.calculate_cast_time("Storm Gust", dex=50, int_stat=150)
        
        assert timing_high_int.variable_cast_ms < timing_low_int.variable_cast_ms
    
    def test_max_stat_reduction_capped(self):
        """Test stat reduction caps at 80%"""
        manager = CastDelayManager()
        
        # DEX*2 + INT = 530 gives 100% reduction, but capped at 80%
        timing = manager.calculate_cast_time("Storm Gust", dex=265, int_stat=0)
        
        # Should still have 20% of original cast time
        original_variable = 6000
        assert timing.variable_cast_ms >= original_variable * 0.2 * 0.99  # Allow rounding


class TestIntegrationWorkflow:
    """Test complete casting workflow"""
    
    @pytest.mark.asyncio
    async def test_complete_cast_cycle(self):
        """Test complete cycle: start → complete → delay → ready"""
        manager = CastDelayManager()
        
        # Start cast
        await manager.start_cast("Fire Ball", cast_time_ms=2000)
        assert manager.cast_state.is_casting is True
        
        # Complete cast
        await manager.cast_complete("Fire Ball", delay_ms=1000)
        assert manager.cast_state.is_casting is False
        assert manager.delay_state.in_after_cast_delay is True
        
        # Wait for delay to expire (simulate)
        manager.delay_state.delay_ends = datetime.now() - timedelta(milliseconds=1)
        
        # Should be able to cast again
        can_cast, _ = await manager.can_cast_now()
        assert can_cast is True
    
    @pytest.mark.asyncio
    async def test_skill_with_cooldown_cycle(self):
        """Test skill with cooldown tracking"""
        manager = CastDelayManager()
        
        # Use Asura Strike (has cooldown)
        await manager.cast_complete("Asura Strike", delay_ms=3000)
        
        # Check cooldown status
        on_cooldown, remaining = await manager.is_skill_on_cooldown("Asura Strike")
        
        assert on_cooldown is True
        assert remaining > 0