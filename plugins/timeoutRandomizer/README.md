# timeoutRandomizer plugin
### by @billabong93	

This plugin lets you configure random ranges for specific entries in `control/timeouts.txt` without modifying the core parser.

## Usage
1. Add `timeoutRandomizer` to your `sys.txt` list so OpenKore loads it.
2. Create/Edit `control/timeout_randomizer.txt` and add the timeouts you want to randomize. Each line should contain the timeout name followed by either a single value or a minimum and maximum value. When the `profiles` plugin is in use, the configuration is loaded from the selected profile folder (for example, `profiles/bot1/timeout_randomizer.txt`).
3. Reload the configuration (`reload timeouts`, `reload timeout_randomizer`, or restart OpenKore).

Example configuration:
```
ai_teleport 1 8
ai_attack 0.6..1.4
ai 3
```
The plugin chooses an initial random value when the timeout is first used. For timers that rely on `Utils::timeOut`, the plugin rolls a new value every time the timer completes and is restarted (either by `timeOut()` or by code that refreshes the timeout's `time` field). For other delays that simply read the configured value (such as `ai_items_take_start`), a fresh random value is generated on each AI tick so every new use receives an independent delay.