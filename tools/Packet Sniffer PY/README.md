# Packet Analyzer - RO Packet Analysis Tool

## What does it do?
Captures Ragnarok Online network packets and automatically generates Perl format suggestions for use in OpenKore.

## Basic Usage

### Simple Command
```bash
python packet_analyzer.py <IP> <PORT> [options]
```

### Example with IP Range (Gravity)
```bash
python packet_analyzer.py 172.65.0.0/16 * -o FreyaFull -i 4
```

**Command explanation:**
- `172.65.0.0/16` = Monitors ALL IPs in the 172.65.x.x range (Gravity network)
- `*` = Monitors ALL ports (not just a specific one)
- `-o FreyaFull` = Saves results to the "FreyaFull" folder
- `-i 4` = Uses network interface number 4

### Other Useful Options
```bash
# See which interfaces are available
python packet_analyzer.py --list-interfaces

# Silent mode (don't show packets on screen)
python packet_analyzer.py 172.65.0.0/16 * -o FreyaFull -i 4 -q

# Specific IP, specific port
python packet_analyzer.py 192.168.1.100 6900 -o MyServer
```

## What is generated?

### 1. File `perl_suggestions.txt`
Contains ready-to-use suggestions for OpenKore:
```perl
# 0x0825 - login_packet  
'0825' => ['login_packet', 'v V Z51 a17', [qw(len version username mac)]],

# 0x0437 - actor_action
'0437' => ['actor_action', 'a4 C', [qw(targetID action)]],
```

### 2. Folder `examples/`
Real examples of each captured packet type for you to verify if it's correct.

### 3. File `packet_analysis_report.json`
Complete report with statistics (more technical).

## Quick Installation

```bash
pip install scapy colorama
```

**Windows**: Download and install Npcap first.

## Permissions

- **Windows**: Run PowerShell as Administrator
- **Linux/Mac**: Use `sudo python packet_analyzer.py ...`

## Workflow

1. **Run the command** during a game session
2. **Stop with Ctrl+C** when you've captured enough
3. **Open the `perl_suggestions.txt` file** in the output folder
4. **Copy the suggestions** to your OpenKore recv/send file
5. **Test** if the packets work

## Practical Example

```bash
# 1. Start capture
python packet_analyzer.py 172.65.0.0/16 * -o MyAnalysis -i 4

# 2. Log into the game, walk around, use some skills
# 3. Stop with Ctrl+C

# 4. View results
cat MyAnalysis/perl_suggestions.txt
```

## Tips

- **Capture for 5-10 minutes** doing various actions in game
- **The more different actions**, the better the suggestions
- **Use `-q`** if you want to see less information on screen
- **Use `--list-interfaces`** if you don't know which interface to use

## Most Common Perl Formats

| Code | What it is | Example |
|---------|---------|---------|
| `a4` | 4-byte ID | Player ID, Item ID |
| `Z24` | Text up to 24 chars | Player name |
| `v` | Small number (0-65535) | HP, SP, quantity |
| `V` | Large number | Experience, Zeny |
| `C` | Tiny number (0-255) | Level, type |

## Troubleshooting

**Don't see packets?**
- Confirm server IP with `ping`
- Test with a different interface
- Use `sudo` (Linux/Mac) or Admin (Windows)