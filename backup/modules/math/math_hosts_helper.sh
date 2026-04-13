#!/usr/bin/env bash
# Helper script for /etc/hosts modification. Called via sudo -n (non-interactive).
# Usage: math_hosts_helper.sh block|unblock

HOSTS_MARKER="# MATH_MODE_BLOCK"

BLOCKED_DOMAINS=(
    "youtube.com"
    "www.youtube.com"
    "m.youtube.com"
    "youtu.be"
    "music.youtube.com"
    "www.reddit.com"
    "reddit.com"
    "twitter.com"
    "x.com"
)

case "${1:-}" in
    block)
        # Check if already blocked
        if grep -q "$HOSTS_MARKER" /etc/hosts 2>/dev/null; then
            exit 0
        fi
        {
            echo ""
            echo "$HOSTS_MARKER"
            for domain in "${BLOCKED_DOMAINS[@]}"; do
                echo "127.0.0.1  $domain"
            done
            echo "$HOSTS_MARKER"
        } >> /etc/hosts
        ;;
    unblock)
        sed -i "/$HOSTS_MARKER/,/$HOSTS_MARKER/d" /etc/hosts
        ;;
    *)
        echo "Usage: $0 {block|unblock}"
        exit 1
        ;;
esac
