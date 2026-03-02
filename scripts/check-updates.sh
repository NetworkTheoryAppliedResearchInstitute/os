#!/bin/sh
# NTARI OS Update Checker

set -e

CACHE_FILE="/var/cache/ntari/updates-available"
LAST_CHECK="/var/cache/ntari/last-update-check"

# Create cache directory
mkdir -p /var/cache/ntari

# Check if we should run (once per day)
if [ -f "$LAST_CHECK" ]; then
	LAST_CHECK_TIME=$(cat "$LAST_CHECK")
	NOW=$(date +%s)
	DIFF=$((NOW - LAST_CHECK_TIME))

	# Skip if checked in last 24 hours
	if [ $DIFF -lt 86400 ]; then
		if [ -f "$CACHE_FILE" ]; then
			cat "$CACHE_FILE"
		fi
		exit 0
	fi
fi

# Update package index
apk update > /dev/null 2>&1

# Check for updates
UPDATES=$(apk version -l '<' | wc -l)

if [ "$UPDATES" -gt 0 ]; then
	echo "$UPDATES updates available"
	echo "$UPDATES" > "$CACHE_FILE"

	# Send notification
	logger -t ntari-updates "$UPDATES package updates available"
else
	echo "System is up to date"
	rm -f "$CACHE_FILE"
fi

# Record check time
date +%s > "$LAST_CHECK"
