#!/usr/bin/env bash
# server-stats.sh — Basic server performance analyzer
#
# Requirements:
#  - Linux system with /proc mounted
#  - Standard tools: awk, sed, grep, df, ps, who, uptime, head, sort, cut
#  - Optional: lastb (from util-linux) to read failed login attempts
#
# Usage:
#   chmod +x server-stats.sh
#   ./server-stats.sh            # default (top 5)
#   ./server-stats.sh -n 10      # show top 10 processes
#   ./server-stats.sh -i 1       # CPU sampling interval seconds (default: 1)
#   ./server-stats.sh -h         # help
#
set -euo pipefail

TOP_N=5
SAMPLE_INTERVAL=1

print_help() {
  cat <<EOF
server-stats.sh — Basic server performance analyzer

Options:
  -n <N>   Number of processes to display in Top lists (default: 5)
  -i <sec> CPU sampling interval in seconds (default: 1)
  -h       Show this help
EOF
}

while getopts ":n:i:h" opt; do
  case "$opt" in
    n) TOP_N=${OPTARG} ;;
    i) SAMPLE_INTERVAL=${OPTARG} ;;
    h) print_help; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;
  esac
done

hr() { printf '%*s\n' "$(tput cols 2>/dev/null || echo 80)" '' | tr ' ' '-'; }

# --- CPU Usage (percentage over SAMPLE_INTERVAL) ---
cpu_usage() {
  # Read /proc/stat twice and compute active vs total deltas
  # Fields: user nice system idle iowait irq softirq steal guest guest_nice
  read -r c1 user1 nice1 sys1 idle1 iowait1 irq1 sirq1 steal1 _ < /proc/stat
  sleep "$SAMPLE_INTERVAL"
  read -r c2 user2 nice2 sys2 idle2 iowait2 irq2 sirq2 steal2 _ < /proc/stat

  local idle_delta total1 total2 total_delta active_delta
  total1=$((user1+nice1+sys1+idle1+iowait1+irq1+sirq1+steal1))
  total2=$((user2+nice2+sys2+idle2+iowait2+irq2+sirq2+steal2))
  total_delta=$((total2-total1))
  idle_delta=$(( (idle2 + iowait2) - (idle1 + iowait1) ))
  active_delta=$((total_delta - idle_delta))

  awk -v a="$active_delta" -v t="$total_delta" 'BEGIN { if (t>0) printf "%.2f", (a*100.0)/t; else print "0.00" }'
}

# --- Memory Usage ---
mem_usage() {
  # Prefer MemAvailable to estimate "free" memory
  awk '
    /MemTotal:/ {total=$2}
    /MemAvailable:/ {avail=$2}
    END {
      used=total-avail; 
      pused=(used*100.0)/total;
      printf "%d %d %d %.2f\n", total, used, avail, pused
    }
  ' /proc/meminfo
}

# --- Disk Usage (sum across non-tmpfs/devtmpfs) ---
disk_usage_total() {
  # Use 1K blocks for consistency across systems
  df -P -k -x tmpfs -x devtmpfs | awk 'NR>1 {size+=$2; used+=$3; avail+=$4} END { 
    if (size==0) {printf "0 0 0 0.00\n"; exit} 
    pused = (used*100.0)/size; 
    printf "%d %d %d %.2f\n", size, used, avail, pused
  }'
}

# --- Top Processes ---
print_top_processes() {
  local field="$1"; shift
  local n="$1"; shift
  # Use ps portable columns; trim command to fit
  ps -eo pid,comm,%cpu,%mem --sort=-%${field} | awk -v n="$n" 'NR==1 {printf "%6s  %-20s  %6s  %6s\n", $1, $2, $3, $4; next} NR<=n+1 {printf "%6s  %-20s  %6s  %6s\n", $1, $2, $3, $4}'
}

# --- OS Version ---
os_version() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf "%s %s\n" "${NAME:-Linux}" "${VERSION:-}"
  else
    uname -sr
  fi
}

# --- Uptime & Load ---
uptime_info() {
  # Human readable uptime and load averages
  local up load
  up=$(uptime -p 2>/dev/null || true)
  load=$(awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg)
  printf "%s | load avg (1,5,15): %s\n" "${up:-Uptime N/A}" "$load"
}

# --- Logged-in Users ---
logged_in_users() {
  who 2>/dev/null | wc -l | tr -d ' '\n
}

# --- Failed login attempts (if lastb available and readable) ---
failed_login_attempts() {
  if command -v lastb >/dev/null 2>&1 && [ -r /var/log/btmp ]; then
    # Exclude summary line
    lastb -F -n 10000 2>/dev/null | awk 'END{print NR-1}'
  else
    echo "N/A"
  fi
}

# --- Pretty printers ---
fmt_bytes() {
  # Convert KiB to human-readable units
  awk '
    function human(x){
      split("KiB MiB GiB TiB", u)
      i=1; while (x>=1024 && i<4){x/=1024; i++}
      return sprintf("%.2f %s", x, u[i])
    }
    {print human($1)}'
}

print_header() {
  printf "\n%s\n%s\n" "$1" "$(hr)"
}

main() {
  echo "Server Performance Report — $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Host: $(hostname) | OS: $(os_version)"
  echo "$(uptime_info)"

  # CPU
  print_header "CPU Usage"
  local cpu
  cpu=$(cpu_usage)
  printf "Total CPU usage: %s%% (sample: %ss)\n" "$cpu" "$SAMPLE_INTERVAL"

  # Memory
  print_header "Memory Usage"
  read -r m_total m_used m_avail m_pused < <(mem_usage)
  printf "Total: %s\n" "$(echo "$m_total" | fmt_bytes)"
  printf "Used : %s (%.2f%%)\n" "$(echo "$m_used" | fmt_bytes)" "$m_pused"
  printf "Free : %s (Avail)\n" "$(echo "$m_avail" | fmt_bytes)"

  # Disk
  print_header "Disk Usage (All non-tmpfs/devtmpfs)"
  read -r d_size d_used d_avail d_pused < <(disk_usage_total)
  printf "Total: %s\n" "$(echo "$d_size" | fmt_bytes)"
  printf "Used : %s (%.2f%%)\n" "$(echo "$d_used" | fmt_bytes)" "$d_pused"
  printf "Free : %s\n" "$(echo "$d_avail" | fmt_bytes)"

  # Top processes by CPU
  print_header "Top ${TOP_N} Processes by CPU"
  print_top_processes cpu "$TOP_N"

  # Top processes by Memory
  print_header "Top ${TOP_N} Processes by Memory"
  print_top_processes mem "$TOP_N"

  # Extras
  print_header "Extras"
  printf "Logged-in users: %s\n" "$(logged_in_users)"
  printf "Failed login attempts (since last rotate): %s\n" "$(failed_login_attempts)"
}

main "$@"
