#!/usr/bin/env bash
#
# Create a private note in _drafts/private, named as Foam names notes: today's date, then a
# name of your choice. The front matter follows .foam/templates/new-note.md.
#
#   bash tools/new-note.sh my-note "My Note"   # _drafts/private/2026-10-23-my-note.md
#
# The name is lowercased and its spaces become hyphens. The title is optional; without it, the
# name with spaces in place of hyphens is the title.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash tools/new-note.sh name [title]"
  exit 1
fi

name="$(echo "$1" | tr '[:upper:] ' '[:lower:]-')"
title="${2:-$(echo "$name" | tr '-' ' ')}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
file="$root/_drafts/private/$(date +%Y-%m-%d)-$name.md"

if [ -e "$file" ]; then
  echo "> $file already exists"
  exit 1
fi

mkdir -p "$(dirname "$file")"
cat >"$file" <<EOF
---
title: "$title"
short_title: "$title" # in the note graph
description: ""
date: $(date '+%Y-%m-%d %H:%M:00 %z')
categories: []
tags: []
primary_tags: [] # one to three tags for the note graph; empty means the first two tags
math: false
---

EOF

echo "> Created $file"
