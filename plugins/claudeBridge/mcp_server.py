# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp>=2.2,<3", "httpx>=0.27"]
# ///
"""openkore MCP server: lets Claude play a Ragnarok Online character through OpenKore.

It talks to the claudeBridge OpenKore plugin (claudeBridge.pl, same folder) over
HTTP on 127.0.0.1. The bot must be running with that plugin loaded.

Run:  uv run --script mcp_server.py      (stdio transport)
Env:  OPENKORE_BRIDGE_URL    default http://127.0.0.1:7777
      OPENKORE_BRIDGE_TOKEN  the plugin's claudeBridge_token, if set
"""

from __future__ import annotations

import asyncio
import functools
import json
import logging
import os
import time
from typing import Any, Literal
from urllib.parse import quote, urlencode

import httpx
from mcp.server.mcpserver import MCPServer
from mcp.types import ToolAnnotations

BRIDGE_URL = os.environ.get("OPENKORE_BRIDGE_URL", "http://127.0.0.1:7777").rstrip("/")
BRIDGE_TOKEN = os.environ.get("OPENKORE_BRIDGE_TOKEN", "")

INSTRUCTIONS = """\
You control one Ragnarok Online character through OpenKore, a bot client.

OpenKore's own AI does the real-time work: walking, auto-attacking (attackAuto),
looting, sitting to regenerate, and its config decides how. You are the player's
brain: look at the situation, choose goals, steer the AI with commands and config,
then let it run and react to what happens.

Play loop:
1. get_status and look_around to see where you are and what is near.
2. Decide a goal (level up on a map, reach an NPC, finish a dialog, buy potions...).
3. Act: move_to, attack, talk_to_npc / npc_reply, use_item, use_skill, or configure
   the AI (e.g. lockMap to farm a map, attackAuto 2 to fight what is around).
4. wait_for the relevant events (target_died, self_died, base_level_changed,
   npc_talk_responses, log/pm...) instead of polling get_status in a loop.
5. Reassess and repeat.

Ids: monster, player, NPC, item and portal "id" values from look_around, and item
"id" values from get_inventory, are OpenKore list indexes. They can change when
the list changes, so look again before acting on an old id.
"""

READ_ONLY = ToolAnnotations(read_only_hint=True, open_world_hint=False)
ACTION = ToolAnnotations(read_only_hint=False, destructive_hint=False, open_world_hint=False)
DESTRUCTIVE = ToolAnnotations(read_only_hint=False, destructive_hint=True, open_world_hint=False)

# Console commands run_command refuses: irreversible item moves (use the dedicated
# tools), arbitrary code, raw packets, leaving the game and runtime changes.
BLOCKED_COMMANDS = {
    "eval": "runs arbitrary Perl code",
    "send": "sends raw packets",
    "sendraw": "sends raw packets",
    "drop": "use drop_item",
    "sell": "use sell_items",
    "storage": "use storage_move",
    "cart": "moves items irreversibly",
    "deal": "trades items with other players",
    "vender": "opens a vending shop",
    "openshop": "opens a vending shop",
    "closeshop": "closes the vending shop",
    "quit": "stops the bot",
    "relog": "disconnects the bot",
    "charselect": "leaves the game",
    "reload": "reloads OpenKore files",
    "plugin": "changes loaded plugins",
    "conf": "use configure",
    "dump": "stops the bot",
    "rc": "reloads OpenKore code",
    "rc2": "reloads OpenKore code",
    "switchconf": "swaps the whole config file",
    "timeout": "changes bot timeouts",
    "misc_conf": "changes bot settings",
    "connect": "changes the connection",
    "create": "creates a character",
}
# Verbs refused by prefix: the gm* commands run GM-only server commands.
BLOCKED_COMMAND_PREFIXES = ("gm",)

# Config keys that hold credentials or connection settings; never read or written here.
SECRET_KEY_MARKERS = ("pass", "pin", "token", "secret", "username", "master", "server", "char", "email", "alias_", "claudebridge_")


def is_secret_key(key: str) -> bool:
    k = key.lower()
    return any(m in k for m in SECRET_KEY_MARKERS)

# Config keys configure may change: behaviour settings, not account or connection.
CONFIG_KEYS = {
    "attackAuto", "attackAuto_party", "attackAuto_onlyWhenSafe", "attackDistance",
    "attackMaxDistance", "attackUseWeapon", "attackCanSnipe", "attackCheckLOS",
    "itemsTakeAuto", "itemsGatherAuto", "itemsMaxWeight", "itemsMaxWeight_sellOrStore",
    "lockMap", "lockMap_x", "lockMap_y", "lockMap_randX", "lockMap_randY",
    "route_randomWalk", "route_randomWalk_inTown", "route_randomWalk_maxRouteTime",
    "route_step", "runFromTarget", "runFromTarget_dist",
    "sitAuto_hp_lower", "sitAuto_hp_upper", "sitAuto_sp_lower", "sitAuto_sp_upper",
    "sitAuto_idle", "sitAuto_look",
    "teleportAuto_hp", "teleportAuto_idle", "teleportAuto_search", "teleportAuto_minAggressives",
    "teleportAuto_deadly", "teleportAuto_maxDmg",
    "saveMap", "saveMap_warpToBuyOrSell", "dcOnDeath", "autoTalkCont", "partyAuto",
    "sellAuto", "storageAuto", "buyAuto",
}
CONFIG_PREFIXES = ("useSelf_item_", "useSelf_skill_", "attackSkillSlot_", "attackComboSlot_",
                   "buyAuto_", "sellAuto_", "storageAuto_", "getAuto_")

server = MCPServer("openkore", instructions=INSTRUCTIONS)
_client = httpx.AsyncClient(timeout=15)
logging.getLogger("httpx").setLevel(logging.WARNING)


class BridgeError(Exception):
    pass


async def bridge(path: str, **params: Any) -> dict[str, Any]:
    """GET a claudeBridge endpoint and return its JSON."""
    params = {k: v for k, v in params.items() if v is not None}
    if BRIDGE_TOKEN:
        params["token"] = BRIDGE_TOKEN
    url = f"{BRIDGE_URL}{path}"
    if params:
        url += "?" + urlencode(params, quote_via=quote)
    try:
        response = await _client.get(url)
    except httpx.HTTPError as exc:
        raise BridgeError(
            f"OpenKore bridge not reachable at {BRIDGE_URL} ({exc.__class__.__name__}). "
            "Is the bot running? Start it with bot/bot.command start."
        ) from exc
    data = response.json()
    if response.status_code != 200:
        raise BridgeError(data.get("error") or f"HTTP {response.status_code}")
    return data


WALK_SNAP_RADIUS = 5  # move_to on a blocked cell walks to the nearest open cell this close


async def command(cmd: str) -> dict[str, Any]:
    result = await bridge("/command", cmd=cmd)
    return {"command": cmd, "output": result.get("output", [])}


# Per event type, the data keys worth sending (chat payloads repeat the text under
# several keys; dialog text can be long). Other events keep every key, minus raw
# packet copies, with long strings cut. The data is always a dict, never a string.
EVENT_DATA_KEYS = {
    "packet_pubMsg": ("pubMsgUser", "pubMsg"),
    "packet_privMsg": ("privMsgUser", "privMsg"),
    "packet_partyMsg": ("MsgUser", "Msg"),
    "packet_guildMsg": ("MsgUser", "Msg"),
    "packet_sentPM": ("to", "msg"),
    "packet_sysMsg": ("Msg",),
    "packet_localBroadcast": ("Msg",),
    "npc_talk": ("name", "ID", "msg"),
    "npc_talk_responses": ("name", "responses"),
}
MAX_EVENT_STRING = 1500
DROPPED_EVENT_KEYS = ("RawMsg", "raw")


def _compact_value(value: Any) -> Any:
    if isinstance(value, str):
        return value if len(value) <= MAX_EVENT_STRING else value[-MAX_EVENT_STRING:]
    if isinstance(value, dict):
        return {k: _compact_value(v) for k, v in value.items() if k not in DROPPED_EVENT_KEYS}
    if isinstance(value, list):
        return [_compact_value(v) for v in value[:50]]
    return value


def compact_event(event: dict[str, Any]) -> dict[str, Any]:
    data = event.get("data")
    out: dict[str, Any] = {"seq": event["seq"], "type": event["type"]}
    if isinstance(event.get("time"), (int, float)):
        out["time"] = round(event["time"], 1)
    if isinstance(data, dict) and "text" in data and event["type"].startswith("log/"):
        out["domain"] = data.get("domain")
        out["text"] = data["text"][:300]
    elif isinstance(data, dict) and data:
        keys = EVENT_DATA_KEYS.get(event["type"])
        picked = {k: data[k] for k in keys if k in data} if keys else data
        out["data"] = _compact_value(picked)
    elif data not in (None, {}, []):
        out["data"] = _compact_value(data)
    return out


def event_keys(event: dict[str, Any]) -> list[str]:
    """Names an event can be matched by: its type, and for console messages also
    log/<domain> (e.g. log/pm, log/publicchat), since the type is only log/message."""
    keys = [event["type"]]
    data = event.get("data")
    if event["type"].startswith("log/") and isinstance(data, dict) and data.get("domain"):
        keys.append(f"log/{data['domain']}")
    return keys


def matches(event: dict[str, Any], wanted: list[str] | None) -> bool:
    if not wanted:
        return True
    keys = [k.lower() for k in event_keys(event)]
    return any(k.startswith(w.lower()) for w in wanted for k in keys)


async def brief_status() -> dict[str, Any]:
    s = await bridge("/state")
    if not s.get("inGame"):
        return {"inGame": False}
    keys = ("name", "baseLevel", "jobLevel", "hp", "hpMax", "sp", "spMax", "map", "x", "y",
            "dead", "sitting", "currentAction", "weight", "weightMax")
    return {k: s.get(k) for k in keys}


async def npc_state(since_seq: int, wait_seconds: float = 6.0, closing: bool = False) -> dict[str, Any]:
    """The NPC dialog after an action, once the server has answered: the dialog
    closed, a new menu arrived, or new text stopped coming for a moment.
    The state from before the action does not count, and the wait is bounded."""
    deadline = time.monotonic() + wait_seconds
    quiet_since: float | None = None
    last_count = 0
    while True:
        npc = await bridge("/npc")
        new = [e for e in npc.get("recent", []) if e["seq"] > since_seq]
        talk = npc.get("talk") or {}
        closed = any(e["type"] == "npc_talk_done" for e in new)
        if closing:
            # Before an action the dialog is open, so "no dialog" means it closed.
            closed = closed or not npc.get("active")
            answered = closed
        else:
            # When opening a dialog, "no dialog yet" means the NPC hasn't answered.
            new_menu = any(e["type"] == "npc_talk_responses" for e in new)
            if len(new) != last_count:
                last_count, quiet_since = len(new), time.monotonic()
            quiet = bool(new) and quiet_since is not None and time.monotonic() - quiet_since > 1.5
            answered = closed or new_menu or quiet
        if answered or time.monotonic() >= deadline:
            break
        await asyncio.sleep(0.4)
    choices = talk.get("responses") or []
    return {
        "active": npc.get("active"),
        "npc": talk.get("name") or next((e["data"].get("name") for e in new if isinstance(e.get("data"), dict) and e["data"].get("name")), None),
        "text": talk.get("msg"),
        "choices": [{"index": i, "text": c} for i, c in enumerate(choices)],
        "closed": closed,
        "hint": "Answer with npc_reply: 'choose' with a choice index, 'continue' for Next, "
                "'number'/'text' when asked for input, 'close' to leave." if npc.get("active") else None,
    }


def game_tool(annotations: ToolAnnotations):
    """Registers a tool whose dict result is sent as compact JSON (cheaper to read
    than the default indented JSON). Bridge errors become {"error": ...}."""

    def decorate(fn):
        @functools.wraps(fn)
        async def wrapper(*args, **kwargs):
            try:
                result = await fn(*args, **kwargs)
            except BridgeError as exc:
                result = {"error": str(exc)}
            return json.dumps(result, separators=(",", ":"), ensure_ascii=False)

        wrapper.__annotations__ = {**fn.__annotations__, "return": "str"}
        return server.tool(annotations=annotations, structured_output=False)(wrapper)

    return decorate


##### Observation tools

@game_tool(READ_ONLY)
async def get_status() -> dict[str, Any]:
    """Character status: level, exp %, HP/SP, zeny, weight, stats and unspent points,
    map and position, status effects, and what OpenKore's AI is doing.
    latestSeq is the current event counter, usable as since_seq for wait_for."""
    return await bridge("/state")


@game_tool(READ_ONLY)
async def look_around(
    kinds: list[Literal["monsters", "players", "npcs", "items", "portals", "spells"]] | None = None,
    limit: int = 15,
) -> dict[str, Any]:
    """Nearby monsters, players, NPCs, items on the ground, portals and ground effects
    (spells), nearest first. Each entry has an id (use it with attack, talk_to_npc,
    pick_up, move_to portal), an oid that stays the same while the actor is around,
    name, position and distance in cells. Monsters show attackingMe and hpPercent when
    known; portals show destKnown."""
    return await bridge("/nearby", limit=max(1, min(limit, 50)),
                        kinds=",".join(kinds) if kinds else None)


@game_tool(READ_ONLY)
async def get_inventory() -> dict[str, Any]:
    """Inventory items with their inventory id (used by use_item, drop_item, sell_items,
    storage_move and equip commands), amount, type and whether they are equipped."""
    return await bridge("/inventory")


@game_tool(READ_ONLY)
async def get_skills(include_unlearned: bool = False) -> dict[str, Any]:
    """Skills with id (used by use_skill and raise_skill), level, SP cost, range and
    target type, plus unspent skill points. With include_unlearned, level-0 skills the
    character could learn (upgradable) are listed too."""
    return await bridge("/skills", all=1 if include_unlearned else None)


@game_tool(READ_ONLY)
async def describe_skill(skill: str) -> dict[str, Any]:
    """The in-game description of a skill (by id, handle such as NV_BASIC, or name),
    as a player would read it in the skill window."""
    return await bridge("/skill_info", skill=skill)


@game_tool(READ_ONLY)
async def describe_item(name_id: int) -> dict[str, Any]:
    """The in-game description of an item type (nameID from get_inventory or
    look_around), as a player would read it in the item window."""
    return await bridge("/item_info", nameID=name_id)


MAX_MAP_SCALE = 64  # cells per character the bridge accepts


@game_tool(READ_ONLY)
async def get_map_overview(
    cols: int = 40, rows: int = 20, scale: int = 0, all: bool = False, markers: bool = True
) -> dict[str, Any]:
    """A coarse map of the whole current field (like the minimap): rows of characters,
    '.' walkable, '#' blocked, '@' you, 'P' portal, 'N' npc, 'M' monster, 'p' player.
    Each character covers scale x scale cells; the top row is the north edge. By default
    the scale is the smallest that fits the map in cols x rows and a character is '.' when
    most of its sampled cells are. scale=N forces N cells per character (the map is then
    ceil(width/N) x ceil(height/N) characters: keep N large on a big map); all=true reads
    every cell and marks '.' when any cell of the block is walkable (terrain for a program,
    not a view); markers=false leaves out '@', 'P', 'N', 'M' and 'p'. gridCols and gridRows
    give the size of the grid."""
    fit = scale <= 0
    return await bridge(
        "/map",
        cols=max(10, min(cols, 120)) if fit else None,
        rows=max(5, min(rows, 60)) if fit else None,
        scale=None if fit else min(scale, MAX_MAP_SCALE),
        all=1 if all else None,
        markers=None if markers else 0,
    )


@game_tool(READ_ONLY)
async def get_npc_dialog() -> dict[str, Any]:
    """The NPC conversation state right now: whether a dialog is open, the NPC name,
    the accumulated text, the numbered choices, and the shop list when a shop is open."""
    npc = await bridge("/npc")
    talk = npc.get("talk") or {}
    choices = talk.get("responses") or []
    return {
        "active": npc.get("active"),
        "npc": talk.get("name"),
        "text": talk.get("msg"),
        "choices": [{"index": i, "text": c} for i, c in enumerate(choices)],
        "store": npc.get("store") or [],
        "store_npc": npc.get("storeNpc"),
    }


@game_tool(READ_ONLY)
async def get_config(key: str) -> dict[str, Any]:
    """Read one OpenKore config.txt behaviour setting (e.g. lockMap, attackAuto).
    Account and connection settings are not readable."""
    if is_secret_key(key):
        return {"error": f"'{key}' is not readable here"}
    return await bridge("/config", key=key)


@game_tool(READ_ONLY)
async def get_configs(keys: list[str]) -> dict[str, Any]:
    """Read several OpenKore config.txt behaviour settings in one call. Returns
    {"values": {key: value or null}}; account and connection settings are refused
    and listed under "refused"."""
    wanted = [k.strip() for k in keys if k and k.strip()]
    if not wanted:
        return {"error": "keys is required"}
    refused = [k for k in wanted if is_secret_key(k)]
    allowed = [k for k in wanted if not is_secret_key(k)]
    result: dict[str, Any] = {"values": {}}
    if allowed:
        data = await bridge("/config", keys=",".join(allowed))
        result["values"] = data.get("values") or {}
        refused += data.get("refused") or []
    if refused:
        result["refused"] = refused
    return result


@game_tool(READ_ONLY)
async def get_storage() -> dict[str, Any]:
    """The Kafra storage contents while it is open (talk to a Kafra employee and
    choose the storage first): {"open": bool, "items": [{id, nameID, name, amount,
    type}]}. The id is the storage id that storage_move take uses."""
    data = await bridge("/storage")
    return {"open": bool(data.get("open")), "title": data.get("title"), "items": data.get("items") or []}


@game_tool(READ_ONLY)
async def recent_events(since_seq: int | None = None, limit: int = 100) -> dict[str, Any]:
    """Game events: chat and private messages, NPC dialog, kills, deaths, exp, loot,
    level ups, map changes, warnings and errors. With since_seq, the events after that
    sequence number (oldest first); without it, the newest events. boot_id changes when
    the bot restarts (sequence numbers start again from 0); oldest_seq is the oldest
    event still kept."""
    data = await bridge("/events", since=since_seq, limit=max(1, min(limit, 200)))
    return {"latest_seq": data["latestSeq"], "oldest_seq": data.get("oldestSeq"),
            "boot_id": data.get("bootId"), "events": [compact_event(e) for e in data["events"]]}


@game_tool(READ_ONLY)
async def wait_for(
    event_types: list[str] | None = None,
    timeout_seconds: int = 30,
    since_seq: int | None = None,
) -> dict[str, Any]:
    """Wait until a game event happens, instead of polling get_status.

    event_types are prefixes of event types, e.g. ["target_died"], ["self_died",
    "base_level_changed"], ["npc_talk"], ["packet_privMsg"], ["log/error"]. Console
    messages match both their type (log/message, log/warning, log/error) and
    log/<domain> (log/pm, log/publicchat, log/exp, log/attacked...).
    Omit them to return on any event. Without since_seq, only events after this call
    count. Waits at most timeout_seconds (max 120) and returns the matching events,
    other recent events and a short status."""
    timeout = max(1, min(timeout_seconds, 120))
    cursor = since_seq if since_seq is not None else (await bridge("/events", limit=1))["latestSeq"]
    deadline = time.monotonic() + timeout
    collected: list[dict[str, Any]] = []
    while True:
        data = await bridge("/events", since=cursor, limit=200)
        for event in data["events"]:
            cursor = event["seq"]
            collected.append(event)
        matched = [e for e in collected if matches(e, event_types)]
        if matched or time.monotonic() >= deadline:
            break
        await asyncio.sleep(0.5)
    others = [e for e in collected if not matches(e, event_types)]
    return {
        "timed_out": not matched,
        "matched": [compact_event(e) for e in matched[-20:]],
        "other_events": [compact_event(e) for e in others[-15:]],
        "latest_seq": cursor,
        "status": await brief_status(),
    }


##### Action tools

@game_tool(ACTION)
async def move_to(x: int | None = None, y: int | None = None, map: str | None = None,
                  portal_id: int | None = None) -> dict[str, Any]:
    """Walk somewhere: coordinates on the current map (x, y), coordinates on another
    map (x, y, map), a whole map (map only; OpenKore routes through portals), or a
    nearby portal (portal_id from look_around). The AI walks in the background;
    use wait_for or get_status to follow it. Coordinates on a blocked cell of the
    current map walk to the nearest open cell within 5 cells instead ("adjusted"
    in the result); with none that close, nothing moves and the result is an error."""
    adjusted = None
    if portal_id is not None:
        cmd = f"move {portal_id}"
    elif x is not None and y is not None:
        cell = await bridge("/walkable", x=x, y=y, radius=WALK_SNAP_RADIUS)
        if cell.get("map") and (not map or map == cell["map"]):
            if not cell.get("inside"):
                return {"error": f"({x},{y}) is outside the map {cell['map']}"}
            if not cell.get("walkable"):
                near = cell.get("nearest")
                if not near:
                    return {
                        "error": f"({x},{y}) on {cell['map']} is blocked and no open cell is within "
                        f"{WALK_SNAP_RADIUS} cells of it; pick another spot"
                    }
                adjusted = {"from": {"x": x, "y": y}, "to": {"x": near["x"], "y": near["y"]}}
                x, y = near["x"], near["y"]
        cmd = f"move {x} {y}" + (f" {map}" if map else "")
    elif map:
        cmd = f"move {map}"
    else:
        return {"error": "give x and y, a map, or a portal_id"}
    result = await command(cmd)
    if adjusted:
        result["adjusted"] = adjusted
    return result


@game_tool(ACTION)
async def stop_moving() -> dict[str, Any]:
    """Stop walking (clears the current route)."""
    return await command("move stop")


@game_tool(ACTION)
async def attack(monster_id: int) -> dict[str, Any]:
    """Attack a monster by its id from look_around."""
    return await command(f"a {monster_id}")


@game_tool(ACTION)
async def pick_up(item_id: int) -> dict[str, Any]:
    """Pick up an item from the ground by its id from look_around (kind items)."""
    return await command(f"take {item_id}")


@game_tool(ACTION)
async def talk_to_npc(npc_id: int) -> dict[str, Any]:
    """Start a conversation with an NPC (id from look_around). OpenKore does not walk
    to it: the server accepts the talk from up to 14 cells away (move_to closer first
    when it is farther). Returns the dialog text and the numbered choices once the NPC
    answered."""
    seq = (await bridge("/npc"))["latestSeq"]
    result = await command(f"talk {npc_id}")
    dialog = await npc_state(seq, wait_seconds=10)
    return {**dialog, "output": result["output"]}


@game_tool(ACTION)
async def npc_reply(action: Literal["continue", "choose", "number", "text", "close"],
                    value: str | int | None = None) -> dict[str, Any]:
    """Answer the current NPC dialog: 'continue' (Next), 'choose' with value = choice
    index from the dialog, 'number' or 'text' with value when the NPC asks for input,
    'close' to end the conversation. Returns the updated dialog."""
    if action in ("choose", "number", "text") and value in (None, ""):
        return {"error": f"'{action}' needs a value"}
    current = await bridge("/npc")
    seq = current["latestSeq"]
    if action == "close":
        # While a menu is shown, OpenKore only accepts a menu answer: its extra last
        # choice "Cancel Chat" sends the real cancel. 'talk no' would leave the AI stuck.
        choices = (current.get("talk") or {}).get("responses") or []
        if choices and str(choices[-1]).lower().startswith("cancel chat"):
            cmd = f"talk resp {len(choices) - 1}"
        else:
            cmd = "talk no"
    else:
        cmd = {
            "continue": "talk cont",
            "choose": f"talk resp {value}",
            "number": f"talk num {value}",
            "text": f"talk text {value}",
        }[action]
    result = await command(cmd)
    dialog = await npc_state(seq, closing=action == "close")
    return {**dialog, "output": result["output"]}


@game_tool(ACTION)
async def use_item(item_id: int) -> dict[str, Any]:
    """Use an inventory item on yourself (potion, food, fly wing...), by inventory id."""
    return await command(f"is {item_id}")


@game_tool(ACTION)
async def equip(item_id: int) -> dict[str, Any]:
    """Equip an inventory item by inventory id."""
    return await command(f"eq {item_id}")


@game_tool(ACTION)
async def unequip(item_id: int) -> dict[str, Any]:
    """Take off an equipped item, by inventory id."""
    return await command(f"uneq {item_id}")


@game_tool(ACTION)
async def sit() -> dict[str, Any]:
    """Sit down (regenerates HP and SP faster; needs the Basic Skill at level 3)."""
    return await command("sit")


@game_tool(ACTION)
async def stand() -> dict[str, Any]:
    """Stand up."""
    return await command("stand")


@game_tool(ACTION)
async def emote(emotion: str) -> dict[str, Any]:
    """Show an emotion above the character (a name or number from OpenKore's emotion
    table, e.g. "heh", "ok", "hmm", "!", "?")."""
    return await command(f"e {emotion}")


@game_tool(ACTION)
async def use_skill(skill_id: int, target: Literal["self", "monster", "player", "ground"] = "self",
                    target_id: int | None = None, x: int | None = None, y: int | None = None,
                    level: int | None = None) -> dict[str, Any]:
    """Use a skill (skill_id from get_skills) on yourself, a monster or player
    (target_id from look_around), or a ground position (x, y)."""
    lv = f" {level}" if level else ""
    if target == "self":
        cmd = f"ss {skill_id}{lv}"
    elif target in ("monster", "player"):
        if target_id is None:
            return {"error": f"target '{target}' needs target_id"}
        cmd = f"{'sm' if target == 'monster' else 'sp'} {skill_id} {target_id}{lv}"
    else:
        if x is None or y is None:
            return {"error": "target 'ground' needs x and y"}
        cmd = f"sl {skill_id} {x} {y}{lv}"
    return await command(cmd)


@game_tool(ACTION)
async def raise_stat(stat: Literal["str", "agi", "vit", "int", "dex", "luk"], points: int = 1) -> dict[str, Any]:
    """Spend status points on a stat (1 to 20 points per call). Costs grow with the
    stat value; get_status shows statusPoints left."""
    points = max(1, min(points, 20))
    outputs: list[str] = []
    for _ in range(points):
        outputs += (await command(f"stat_add {stat}"))["output"]
        await asyncio.sleep(0.15)
    state = await bridge("/state")
    return {"output": outputs[-5:], "stats": state.get("stats"), "statusPoints": state.get("statusPoints")}


@game_tool(ACTION)
async def raise_skill(skill_id: int) -> dict[str, Any]:
    """Spend one skill point on a skill (skill_id from get_skills)."""
    return await command(f"skills add {skill_id}")


@game_tool(ACTION)
async def set_ai(mode: Literal["auto", "manual", "off"]) -> dict[str, Any]:
    """OpenKore AI mode. auto: fights, loots, walks and follows config on its own.
    manual: only does what you command. off: does nothing."""
    return await command({"auto": "ai on", "manual": "ai manual", "off": "ai off"}[mode])


@game_tool(ACTION)
async def configure(key: str, value: str) -> dict[str, Any]:
    """Change an OpenKore behaviour setting (saved to config.txt). Examples:
    lockMap prt_fild08 (farm that map), attackAuto 2 (attack what is around),
    route_randomWalk 1, sitAuto_hp_lower 40, itemsTakeAuto 2,
    useSelf_item_0 Red Potion + useSelf_item_0_hp "< 50%". Use value "none" to clear."""
    if is_secret_key(key) or (key not in CONFIG_KEYS and not key.startswith(CONFIG_PREFIXES)):
        return {"error": f"'{key}' is not an allowed behaviour setting",
                "allowed": sorted(CONFIG_KEYS), "allowed_prefixes": list(CONFIG_PREFIXES)}
    if "\n" in value or "\r" in value or ";;" in value:
        return {"error": "the value must be a single line without ';;'"}
    return await bridge("/config", key=key, value=value)


@game_tool(ACTION)
async def say(message: str, to: str | None = None,
              channel: Literal["public", "party", "guild"] = "public") -> dict[str, Any]:
    """Say something in public chat (everyone nearby reads it), in party or guild chat
    (channel), or whisper a player by name (to; the channel is then ignored)."""
    if to:
        cmd = f'pm "{to}" {message}'
    else:
        cmd = {"public": "c", "party": "p", "guild": "g"}[channel] + f" {message}"
    return await command(cmd)


@game_tool(ACTION)
async def run_command(command_line: str) -> dict[str, Any]:
    """Run any other OpenKore console command and get its output, e.g. "buy 0 10"
    (after opening an NPC shop), "respawn", "sit", "stand", "e 3" (emotion),
    "skills", "exp", "st" (stats), "ml" (monster list), "help <command>".
    Irreversible or unsafe commands are refused; use the dedicated tools."""
    verb = command_line.strip().split(maxsplit=1)[0].lower() if command_line.strip() else ""
    if not verb:
        return {"error": "empty command"}
    if ";;" in command_line:
        return {"error": "one command at a time (';;' is not allowed)"}
    if verb in BLOCKED_COMMANDS:
        return {"error": f"'{verb}' is not allowed here: {BLOCKED_COMMANDS[verb]}"}
    if verb.startswith(BLOCKED_COMMAND_PREFIXES):
        return {"error": f"'{verb}' is not allowed here: GM commands are not for the bot"}
    return await command(command_line.strip())


##### Irreversible item actions: dedicated tools with checks

async def unequipped_item(item_id: int) -> dict[str, Any]:
    inventory = await bridge("/inventory")
    item = next((i for i in inventory.get("items", []) if i["id"] == item_id), None)
    if item is None:
        raise BridgeError(f"no inventory item with id {item_id}")
    if item.get("equipped"):
        raise BridgeError(f"{item['name']} is equipped; unequip it first")
    return item


@game_tool(DESTRUCTIVE)
async def drop_item(item_id: int, amount: int | None = None) -> dict[str, Any]:
    """Drop an inventory item on the ground (other players can take it). Refuses
    equipped items."""
    item = await unequipped_item(item_id)
    result = await command(f"drop {item_id}" + (f" {amount}" if amount else ""))
    return {**result, "item": item["name"]}


@game_tool(DESTRUCTIVE)
async def sell_items(items: list[dict[str, int]]) -> dict[str, Any]:
    """Sell inventory items to the NPC shop that is open (talk to a merchant and
    choose Sell first). items: [{"item_id": 3, "amount": 5}, ...]. Refuses equipped
    items. Sells everything listed in one transaction."""
    if not items:
        return {"error": "no items"}
    try:
        names = []
        for entry in items:
            item = await unequipped_item(int(entry["item_id"]))
            names.append(item["name"])
        outputs: list[str] = []
        for entry in items:
            amount = entry.get("amount")
            outputs += (await command(f"sell {entry['item_id']}" + (f" {amount}" if amount else "")))["output"]
        outputs += (await command("sell done"))["output"]
        return {"sold": names, "output": outputs}
    except (BridgeError, KeyError, ValueError) as exc:
        try:
            await command("sell cancel")
        except BridgeError:
            pass
        return {"error": str(exc)}


@game_tool(DESTRUCTIVE)
async def storage_move(direction: Literal["put", "take"], item_id: int, amount: int | None = None) -> dict[str, Any]:
    """Move items between inventory and Kafra storage (open it with a Kafra NPC
    first). put: item_id is an inventory id (equipped items refused). take: item_id
    is a storage id (see get_storage)."""
    if direction == "put":
        await unequipped_item(item_id)
        cmd = f"storage add {item_id}"
    else:
        cmd = f"storage get {item_id}"
    return await command(cmd + (f" {amount}" if amount else ""))


if __name__ == "__main__":
    server.run()
