#!/usr/bin/env bash
# Beads workflow context recovery hook
# Runs on SessionStart and PreCompact to provide issue tracking context

# Only run if .beads directory exists (beads-enabled repo)
if [ -d ".beads" ]; then
    # Run bd prime to inject beads context
    bd prime
fi
