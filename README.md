# Server Stats Script

This project provides a Bash script `server-stats.sh` that analyzes basic server performance statistics on any Linux system. It is a practical exercise inspired by roadmap.sh projects to gain hands-on experience monitoring server resources.

---

## Features
- **CPU usage** (sampled over a given interval)
- **Memory usage** (Total, Used, Available, Percentage)
- **Disk usage** (Total, Used, Free, Percentage)
- **Top N processes by CPU usage**
- **Top N processes by memory usage**
- **Extra stats**:
  - OS version
  - Uptime and load average
  - Logged-in users
  - Failed login attempts (if available)

---

## Requirements
- Linux system with `/proc` mounted
- Standard tools: `awk`, `sed`, `grep`, `df`, `ps`, `who`, `uptime`, `head`, `sort`, `cut`
- Optional: `lastb` (from `util-linux`) for failed login attempts

---

## Installation
1. Clone or copy the script file to your server.
2. Make it executable:
   ```bash
   chmod +x server-stats.sh
   ```

---

## Usage
Run the script directly:
```bash
./server-stats.sh
```

### Options
- **`-n <N>`**: Number of processes to display in Top lists (default: 5)
- **`-i <seconds>`**: CPU sampling interval in seconds (default: 1)
- **`-h`**: Show help message

### Examples
- Show top 10 processes:
  ```bash
  ./server-stats.sh -n 10
  ```

- Sample CPU over 2 seconds:
  ```bash
  ./server-stats.sh -i 2
  ```

---

## Sample Output
```text
Server Performance Report — 2025-09-23 19:00:00 UTC
Host: myserver | OS: Ubuntu 22.04.3 LTS
up 2 hours, 10 minutes | load avg (1,5,15): 0.03 0.05 0.10

CPU Usage
----------------------------------------
Total CPU usage: 12.45% (sample: 1s)

Memory Usage
----------------------------------------
Total: 15.6 GiB
Used : 6.3 GiB (40.52%)
Free : 9.3 GiB (Avail)

Disk Usage (All non-tmpfs/devtmpfs)
----------------------------------------
Total: 480.0 GiB
Used : 210.3 GiB (43.80%)
Free : 269.7 GiB

Top 5 Processes by CPU
----------------------------------------
   PID  COMMAND               %CPU   %MEM
  2034  chrome                20.0    5.2
  1450  firefox               15.0    4.7
  ...

Top 5 Processes by Memory
----------------------------------------
   PID  COMMAND               %CPU   %MEM
  1450  firefox               15.0    4.7
  2034  chrome                20.0    5.2
  ...

Extras
----------------------------------------
Logged-in users: 2
Failed login attempts (since last rotate): 0
```

---

## Stretch Goals
- Add JSON output option for monitoring integration.
- Collect network stats from `/proc/net/dev`.
- Add temperature sensors.
- Create a `systemd` timer to run periodically and log results.

---

## License
This project is for learning purposes and provided under the MIT License.
