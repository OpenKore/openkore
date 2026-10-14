# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

OpenKore is a headless Ragnarok Online bot client written in Perl. In this workspace it plays against the rAthena server in `../rathena/` (see `../CLAUDE.md` for how the three repos fit together).

## Commands

```bash
make                                   # build XSTools (C++/XS) via bundled SCons: python src/scons-local-3.1.2/scons.py
make clean
perl openkore.pl                       # run the bot (uses control/, tables/, plugins/ by default)
perl openkore.pl --control=DIR --tables=DIR --plugins=DIR --config=FILE --interface=Console --command="..."
make test                              # cd src/test && perl unittests.pl
cd src/test && perl unittests.pl FieldTest            # one test module
cd src/test && perl unittests.pl Utils::TextReaderTest
perltidy --profile=.perltidyrc FILE.pm # formatting (tabs, 4-col indent, 132-col lines)
```

- XSTools must be built before running the bot or tests. The compiled module ends up in `src/auto/XSTools/`; Windows ships prebuilt `XSTools.dll`/`NetRedirect.dll` in the repo root.
- **macOS:** `make` calls `python`, which macOS doesn't have. Build with `python3.11 src/scons-local-3.1.2/scons.py` instead (SCons 3.1.2 needs Python ≤ 3.11) after `brew install python@3.11 readline`. `SConstruct` looks for Homebrew readline under both `/opt/homebrew` and `/usr/local`, and falls back to the Perl headers in the Xcode SDK. The result is `src/auto/XSTools/XSTools.bundle`. System Perl refuses relative bundle paths, so test with `perl -I"$PWD/src" ...`, not `-Isrc`.
- Tests are `Test::More` modules in `src/test/` that each expose `sub start`. A new test must be added to the `@tests` list in `src/test/unittests.pl` or it won't run by default. CI (`.github/workflows/build_XSTools.yml`) builds XSTools and runs these tests on Windows with Strawberry Perl 5.12 and 5.32, so code must stay compatible with **Perl 5.12**.
- Every directory has a `Distfiles` manifest used by `makedist.sh`. When you add a new source file, list it in that directory's `Distfiles`.

## Architecture

**Startup and main loop.** `openkore.pl` parses CLI args (`src/Settings.pm`), loads `control/sys.txt`, picks an interface (`src/Interface/`: Console, Wx, Tk, Vx, Win32, Socket), then repeatedly calls `mainLoop()` in `src/functions.pl`. `mainLoop` is a state machine: load plugins → load data files (`loadDataFiles`, which registers every control/table file) → init networking → init portals → prompt for login info → `STATE_INITIALIZED`. Once initialized, each tick runs `mainLoop_initialized()`: it processes network I/O and calls `AI::CoreLogic::iterate`.

**Global state.** Most shared state lives as package globals exported from `src/Globals.pm` (`%config`, `$char`, `$field`, `$net`, `$messageSender`, `$packetParser`, actor lists like `$monstersList`/`$playersList`, `%timeout`, …). Most modules `use Globals` and read these directly rather than passing them around.

**AI.** Behaviour is a stack-based action queue in `src/AI.pm` (`AI::queue`, `AI::action`, `AI::args`, `AI::dequeue`, `AI::is`, `AI::inQueue`). `src/AI/CoreLogic.pm::iterate` calls a long sequence of `process*` functions every tick (auto-storage, auto-sell/buy, attack, take, random walk, route, and so on). Each one checks the head of the queue and/or config, then queues or advances actions. Newer, longer-lived behaviours are `Task` objects (`src/Task/*.pm`, e.g. `Task::Route`, `Task::MapRoute`, `Task::TalkNPC`, `Task::UseSkill`) run by `src/TaskManager.pm`. They are composable through `Task::WithSubtask` and `Task::Chained`.

**Network / packets** (the part most tied to rAthena):
- The `[server]` block in `tables/servers.txt` sets `serverType` (e.g. `kRO_RagexeRE_2020_04_01b`), `addTableFolders`, and optionally `recvpackets`. The `[Localhost]` entry is the one used for a local rAthena.
- `Network::PacketParser::create` turns `serverType` into a class name. `kRO_RagexeRE_2020_04_01b` loads `Network::Receive::kRO::RagexeRE_2020_04_01b` and the matching `Network::Send::…`. These per-version classes form a long inheritance chain by date. Each one only overrides what changed: entries in `$self->{packet_list}` (`switch => [handler_name, unpack_template, [field names]]`) or `*_pack` templates.
- Packet **handlers** are methods named after `handler_name`, mostly in the huge base `src/Network/Receive.pm` (plus `Receive/ServerType0.pm`). `PacketParser::parse` unpacks the fields, calls an optional `parse_<handler>`, fires the `packet_pre/<handler>` hook (a plugin can set `$args->{return}` to drop the packet), calls the handler, and then fires `packet/<handler>`.
- **Sending** is the same in reverse. `Network::Send::send*` methods call `$self->reconstruct({switch => 'handler_name', ...})`, which resolves the switch through `packet_lut` and packs with `packet_list`, or calls a custom `reconstruct_<handler>`.
- Packet lengths come from `recvpackets.txt` in the server's table folder (e.g. `tables/kRO/RagexeRE_2020_04_01b/recvpackets.txt`), which feeds `Network::MessageTokenizer`. When rAthena's `PACKETVER` changes, the bot's `serverType`/recvpackets must change to a matching date.
- `XKore` modes (`src/Network/XKore*.pm`) let the bot attach to or proxy a real client instead of connecting directly.

**Data files.** `control/` holds user behaviour config (`config.txt`, `mon_control.txt`, `items_control.txt`, `timeouts.txt`, …). `tables/` holds game data and packet tables, layered by `addTableFolders` (for example `translated/kRO_english;kRO`, falling back to the top-level `tables/`). Parsers are in `src/FileParsers.pm`. Map field data lives in `fields/`.

**Plugins.** `plugins/<name>/*.pl` call `Plugins::register(...)` and `Plugins::addHooks([...])` (`src/Plugins.pm`). Which plugins load is set by `loadPlugins`/`loadPlugins_list` in `control/sys.txt`. `plugins/needs-review/` holds unmaintained plugins that aren't loaded by default. Grep for `Plugins::callHook('...')` to find hook points. Console commands are registered in `src/Commands.pm`, and plugins can add their own with `Commands::register`.

**claudeBridge** (`plugins/claudeBridge/`) is this fork's plugin for AI control. `claudeBridge.pl` runs a JSON HTTP API on 127.0.0.1:7777 inside the main loop (a `Base::WebServer` subclass driven by `mainLoop_post`, GET only). It exposes `/state`, `/nearby`, `/inventory`, `/skills`, `/npc`, `/events` (hook and log ring buffer), `/command` (`Commands::run` with captured console output), `/config`, `/map` (a character grid of the field's walkability: the fit to `cols` x `rows`, or `scale` cells per character; `all=1` marks a block walkable when any of its cells is; `markers=0` draws the terrain alone) and `/walkable`. With `claudeBridge_charName` set, it also creates and selects the character without the interactive menu. `mcp_server.py` (a Python `mcp` 2.x `MCPServer`, run with `uv run --script`) turns that API into MCP tools. The workspace's `bot/` folder runs it; see `../CLAUDE.md`.

**Poseidon** (`src/Poseidon/`, `start-poseidon.exe`) is a separate query server that forwards GameGuard challenges to a real client. It is irrelevant against a private rAthena server.

## Conventions

- Indent with tabs (see `.editorconfig`/`.perltidyrc`); `use strict` in every module.
- User-facing strings go through `Translation` (`T()`/`TF()`), and logging through `Log` (`message`, `warning`, `error`, `debug $msg, "domain"`).
- Module docs use the `##` comment format in `src/doc/` style (`make doc` runs `src/doc/createdoc.pl`).
