#!/bin/sh
# Auto-commit and push any changes in the HA config directory to GitHub.
# Triggered by a HA time-pattern automation.

cd /config || exit 1

git add -A

if git diff --cached --quiet; then
  exit 0
fi

git commit -m "Auto-commit: $(date '+%Y-%m-%d %H:%M')"
git push origin master
