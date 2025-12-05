# ===================================
# OpenKore Plugin Configuration Guide
# ===================================

This guide explains how OpenKore's plugin system works and how to configure
plugins for automatic loading on startup.

## Quick Start

The AI Bridge System plugins are **ALREADY ENABLED** by default in fresh
installations via the `control/sys.txt` file. You don't need to do anything
for basic AI functionality to work.

Look for these console messages on startup:
  [Plugin] Loading plugin plugins/AI_Bridge.pl...
  [Plugin] Loading plugin plugins/godtier_chat_bridge.pl...

## Plugin Loading System

OpenKore loads plugins from the `plugins/` directory and one level of
subdirectories (e.g., `plugins/subfolder/`). Plugin files must have a `.pl`
extension (Perl scripts).

### Configuration File: control/sys.txt

The `control/sys.txt` file controls which plugins load automatically. If this
file doesn't exist, OpenKore loads ALL plugins by default.

### Loading Modes

Configure plugin loading using the `loadPlugins` setting in sys.txt:

**Mode 0: Disabled**
  loadPlugins 0
  
  No plugins load automatically. Use manual `plugin load` commands.

**Mode 1: Load All (Default without sys.txt)**
  loadPlugins 1
  
  Loads every plugin found in the plugins/ directory.

**Mode 2: Selective Loading (RECOMMENDED)**
  loadPlugins 2
  loadPlugins_list AI_Bridge
  loadPlugins_list godtier_chat_bridge
  
  Only loads plugins explicitly listed. Best for production.

**Mode 3: Selective Skipping**
  loadPlugins 3
  skipPlugins_list debugPlugin
  skipPlugins_list testPlugin
  
  Loads all plugins EXCEPT those listed.

## Required Plugins for AI Functionality

These plugins are CRITICAL and enabled by default:

### AI_Bridge
  Location: plugins/AI_Bridge.pl
  Purpose: Core bridge between OpenKore and AI Sidecar
  Status: Required for AI automation
  
  This plugin enables OpenKore to communicate with the Python AI Sidecar,
  allowing autonomous decision-making, learning, and adaptive gameplay.

### godtier_chat_bridge
  Location: plugins/godtier_chat_bridge.pl
  Purpose: Advanced chat processing and NPC interaction
  Status: Required for AI chat features
  
  Handles natural language processing, NPC dialogue automation, and
  intelligent chat responses using AI capabilities.

⚠️  WARNING: Disabling these plugins will break AI automation!

## Managing Plugins

### Viewing Loaded Plugins

In OpenKore console, type:
  plugin list

This shows all currently loaded plugins with their status.

### Loading Plugins Manually

To load a plugin without restarting:
  plugin load plugins/PluginName.pl

Example:
  plugin load plugins/eventMacro/eventMacro.pl

### Unloading Plugins

To unload a running plugin:
  plugin unload PluginName

Example:
  plugin unload eventMacro

### Reloading Plugins

To reload a plugin (useful during development):
  plugin reload PluginName

Example:
  plugin reload AI_Bridge

## Adding New Plugins

1. Place the plugin file (.pl) in the `plugins/` directory or a subdirectory
2. Add the plugin name to sys.txt (if using Mode 2):
   
   loadPlugins_list newPluginName

3. Restart OpenKore, or use `plugin load` command

## Popular Optional Plugins

### eventMacro
  Advanced macro automation system with conditional logic
  
  To enable:
    loadPlugins_list eventMacro

### autoShopAuto
  Automatic shop management and vending
  
  To enable:
    loadPlugins_list autoShopAuto

### needs
  Intelligent item and resource management
  
  To enable:
    loadPlugins_list needs

## Disabling AI Plugins

If you need to run OpenKore without AI (manual play), you have options:

**Option 1: Disable All Plugins**
  Edit control/sys.txt:
    loadPlugins 0

**Option 2: Skip AI Plugins Only**
  Edit control/sys.txt:
    loadPlugins 3
    skipPlugins_list AI_Bridge
    skipPlugins_list godtier_chat_bridge

**Option 3: Remove sys.txt**
  Delete or rename control/sys.txt
  Plugins will load based on default behavior (usually all plugins)

## Troubleshooting

### "Plugin X failed to load"
  - Check that the plugin file exists in plugins/ directory
  - Verify the plugin name matches the filename (case-sensitive)
  - Look for syntax errors in the plugin file
  - Check plugin dependencies

### "Loading all plugins (by default)"
  - This means sys.txt doesn't exist or has no loadPlugins setting
  - Create control/sys.txt to control plugin loading

### AI features not working
  - Verify AI_Bridge and godtier_chat_bridge are loading
  - Check console for "[AI_Bridge] Plugin loaded" message
  - Ensure AI Sidecar (Python) is running
  - Review docs/AI_SIDECAR_BRIDGE_GUIDE.md

### Plugin conflicts
  - Some plugins may conflict with each other
  - Try loading plugins one at a time to identify conflicts
  - Check plugin documentation for known incompatibilities

## Configuration Files

- `control/sys.txt` - Active plugin configuration (already configured)
- `control/sys.txt.example` - Template with detailed comments
- `control/config.txt` - Game-specific settings (not for plugins)

## Further Reading

- Plugin Writing Tutorial: https://openkore.com/wiki/How_to_write_plugins_for_OpenKore
- OpenKore Documentation: https://openkore.com/wiki/
- AI Bridge Guide: docs/AI_SIDECAR_BRIDGE_GUIDE.md

## Support

If you need help with plugin configuration:
1. Check OpenKore forums: https://forums.openkore.com
2. Review plugin source code for configuration options
3. Check GitHub issues for known problems

===================================
Last Updated: 2024
OpenKore AI Integration Project
===================================