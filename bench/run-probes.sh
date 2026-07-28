#!/usr/bin/env bash
#
# jubilant probe harness -- establishes the RAW-side baseline.
#
# This script never talks to a model. It fetches each probe page with curl and
# records what an unmediated HTTP client sees: status, byte count, latency, a
# content hash, and whether the page's canary string survived. Those numbers are
# the control. You then run the same pages through the agent under test and
# compare. Divergence in latency, byte-for-byte content, or canary survival is
# what identifies an inference layer sitting between the agent and the web.
#
# Defaults to serving the repo from localhost so the whole run works inside a
# sandbox with no egress. Point it at the deployed site with --base.
#
# Usage:
#   ./bench/run-probes.sh                          # local server, 3 reps
#   ./bench/run-probes.sh -n 7                     # more reps, tighter median
#   ./bench/run-probes.sh --base https://adeptusnull.github.io/jubilant
#   ./bench/run-probes.sh --only p1-verbatim,p3-format
#   ./bench/run-probes.sh --list                   # probe ids, one per line
#   ./bench/run-probes.sh --prompt p1-verbatim     # one probe's agent prompt
#
# --list and --prompt exist for stepping through the suite one test at a time,
# which is how protocol.md runs it by default. They do no network I/O.
#
set -euo pipefail

SUITE_VERSION="JUBILANT-1.0"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/bench/probes.tsv"
RESULTS_DIR="$REPO_ROOT/bench/results"

BASE=""
REPS=3
ONLY=""
PORT=0
SERVER_PID=""
LIST_ONLY=0
PROMPT_ID=""

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '3,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --base)   BASE="${2:-}"; shift 2 ;;
        -n|--reps) REPS="${2:-}"; shift 2 ;;
        --only)   ONLY="${2:-}"; shift 2 ;;
        --port)   PORT="${2:-}"; shift 2 ;;
        --list)   LIST_ONLY=1; shift ;;
        --prompt) PROMPT_ID="${2:-}"; shift 2 ;;
        -V|--version) printf '%s\n' "$SUITE_VERSION"; exit 0 ;;
        -h|--help) usage ;;
        *) die "unknown argument: $1 (try --help)" ;;
    esac
done

command -v curl >/dev/null 2>&1 || die "curl not found"
[ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"
case "$REPS" in ''|*[!0-9]*) die "--reps must be an integer" ;; esac

# --- offline modes ----------------------------------------------------------
# Both exit before any server starts or any request is made.
if [ "$LIST_ONLY" = "1" ]; then
    while IFS=$'\t' read -r id path canary prompt; do
        case "$id" in ''|'#'*) continue ;; esac
        printf '%-14s %s\n' "$id" "$path"
    done < "$MANIFEST"
    exit 0
fi

if [ -n "$PROMPT_ID" ]; then
    found=0
    while IFS=$'\t' read -r id path canary prompt; do
        case "$id" in ''|'#'*) continue ;; esac
        [ "$id" = "$PROMPT_ID" ] || continue
        found=1
        if [ -n "$BASE" ]; then
            printf 'url:    %s/%s\n' "${BASE%/}" "$path"
        else
            printf 'path:   %s   (pass --base for a fetchable URL)\n' "$path"
        fi
        printf 'canary: %s\n' "$canary"
        printf 'prompt: %s\n' "$prompt"
    done < "$MANIFEST"
    [ "$found" = "1" ] || die "no such probe: $PROMPT_ID (try --list)"
    exit 0
fi

# --- local server -----------------------------------------------------------
# Serving from disk keeps the run hermetic: no DNS, no TLS, no CDN variance in
# the latency baseline. A sandbox with the network cut still produces valid
# raw-side numbers.
start_local_server() {
    command -v python3 >/dev/null 2>&1 || die "python3 needed for local mode (or pass --base)"
    if [ "$PORT" = "0" ]; then
        PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
    fi
    python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$REPO_ROOT" >/dev/null 2>&1 &
    SERVER_PID=$!
    trap 'if [ -n "$SERVER_PID" ]; then kill "$SERVER_PID" 2>/dev/null || true; fi' EXIT INT TERM
    BASE="http://127.0.0.1:$PORT"
    # Wait for the listener rather than sleeping a fixed interval.
    curl -sS --retry 10 --retry-delay 1 --retry-connrefused \
         -o /dev/null "$BASE/" 2>/dev/null \
        || die "local server on port $PORT never came up"
}

if [ -z "$BASE" ]; then
    start_local_server
    MODE="local (python3 http.server, port $PORT)"
else
    BASE="${BASE%/}"
    MODE="remote ($BASE)"
fi

# --- helpers ----------------------------------------------------------------
hash_stdin() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -c1-16
    elif command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -c1-16
    else printf 'nohash'; fi
}

# Median of whitespace-separated floats on stdin.
median() {
    tr ' ' '\n' | grep -v '^$' | sort -n | awk '
        { v[NR]=$1 }
        END {
            if (NR == 0) { print "0.000"; exit }
            m = (NR % 2) ? v[(NR+1)/2] : (v[NR/2] + v[NR/2+1]) / 2
            printf "%.3f", m
        }'
}

selected() {
    [ -z "$ONLY" ] && return 0
    case ",$ONLY," in *",$1,"*) return 0 ;; esac
    return 1
}

mkdir -p "$RESULTS_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RAW_TSV="$RESULTS_DIR/raw-$STAMP.tsv"
SCORESHEET="$RESULTS_DIR/scoresheet-$STAMP.md"

printf 'id\tpath\thttp\tbytes\tlat_min_s\tlat_med_s\tcanary\tsha256_16\n' > "$RAW_TSV"

printf '\n  jubilant raw-side baseline (%s)\n' "$SUITE_VERSION"
printf '  mode : %s\n' "$MODE"
printf '  reps : %s\n' "$REPS"
printf '  out  : %s\n\n' "${RAW_TSV#"$REPO_ROOT"/}"
printf '  %-14s %-5s %8s %9s %9s %-8s\n' ID HTTP BYTES MIN_S MED_S CANARY
printf '  %-14s %-5s %8s %9s %9s %-8s\n' -------------- ----- -------- --------- --------- --------

fail_count=0
row_count=0

while IFS=$'\t' read -r id path canary prompt; do
    case "$id" in ''|'#'*) continue ;; esac
    selected "$id" || continue
    row_count=$((row_count + 1))

    url="$BASE/$path"
    body_file="$(mktemp)"
    times=""
    http=000
    bytes=0

    for _ in $(seq 1 "$REPS"); do
        # -o overwrites each rep; the last body is the one we hash.
        read -r http bytes t < <(
            curl -sS -o "$body_file" \
                 -w '%{http_code} %{size_download} %{time_total}\n' \
                 --max-time 60 "$url" 2>/dev/null || printf '000 0 0\n'
        )
        times="$times $t"
    done

    lat_min="$(printf '%s' "$times" | tr ' ' '\n' | grep -v '^$' | sort -n | head -1 \
               | awk '{ printf "%.3f", $1 }')"
    lat_med="$(printf '%s' "$times" | median)"
    sha="$(hash_stdin < "$body_file")"

    if grep -qF "$canary" "$body_file" 2>/dev/null; then
        canary_state=PRESENT
    else
        canary_state=MISSING
        fail_count=$((fail_count + 1))
    fi
    [ "$http" = "200" ] || fail_count=$((fail_count + 1))

    printf '  %-14s %-5s %8s %9s %9s %-8s\n' \
        "$id" "$http" "$bytes" "$lat_min" "$lat_med" "$canary_state"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$path" "$http" "$bytes" "$lat_min" "$lat_med" "$canary_state" "$sha" >> "$RAW_TSV"

    rm -f "$body_file"
done < "$MANIFEST"

# --- scoresheet -------------------------------------------------------------
# The agent-side half is manual by necessity: you have to drive the agent under
# test yourself. This writes the blanks to fill in, with the raw numbers already
# in place as the comparison column.
{
    printf '# Probe run %s\n\n' "$STAMP"
    printf -- '- suite: `%s`\n' "$SUITE_VERSION"
    printf -- '- mode: `%s`\n' "$MODE"
    printf -- '- reps: %s\n' "$REPS"
    printf -- '- raw baseline: `%s`\n\n' "${RAW_TSV##*/}"
    printf 'Raw latency is the control. Agent latency consistently exceeding it by\n'
    printf 'seconds -- especially on `p2-latency`, which is a few hundred bytes --\n'
    printf 'indicates inference in the fetch path.\n\n'

    while IFS=$'\t' read -r id path canary prompt; do
        case "$id" in ''|'#'*) continue ;; esac
        selected "$id" || continue
        raw_line="$(grep "^$id	" "$RAW_TSV" || true)"
        raw_med="$(printf '%s' "$raw_line" | cut -f6)"
        raw_bytes="$(printf '%s' "$raw_line" | cut -f4)"

        printf '## %s\n\n' "$id"
        printf -- '- url: `%s/%s`\n' "$BASE" "$path"
        printf -- '- raw: %s bytes, %ss median\n' "${raw_bytes:-?}" "${raw_med:-?}"
        printf -- '- canary: `%s`\n\n' "$canary"
        printf 'Prompt:\n\n> %s\n\n' "$prompt"
        printf 'Agent latency: ______   Canary returned: ______\n\n'
        printf 'Response:\n\n```\n\n```\n\n'
        printf 'Verdict (raw / model-mediated / inconclusive): ______\n\n---\n\n'
    done < "$MANIFEST"
} > "$SCORESHEET"

printf '\n  %s probes fetched, %s anomalies (non-200 or missing canary)\n' "$row_count" "$fail_count"
printf '  scoresheet: %s\n\n' "${SCORESHEET#"$REPO_ROOT"/}"

[ "$fail_count" -eq 0 ] || exit 1
