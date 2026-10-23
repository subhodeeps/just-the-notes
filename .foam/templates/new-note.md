---
foam_template:
  name: New note
  description: A draft in _drafts with Chirpy front matter. To publish it, move it to _posts as YYYY-MM-DD-slug.md and fill in the date.
  filepath: "_drafts/${FOAM_SLUG}.md"
title: "${FOAM_TITLE}"
short_title: "${FOAM_TITLE}" # in the note graph
description: ""
date: ${FOAM_DATE_YEAR}-${FOAM_DATE_MONTH}-${FOAM_DATE_DATE} ${FOAM_DATE_HOUR}:${FOAM_DATE_MINUTE}:00 +0530
categories: []
tags: []
math: false
---

${FOAM_SELECTED_TEXT}
