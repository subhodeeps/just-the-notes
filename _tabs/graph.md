---
# the default layout is 'page'
title: Graph
icon: fas fa-diagram-project
order: 3
panel_graph: false # the page shows the whole graph, so the right panel leaves it out
---

The graph shows every note on the site, coloured by its category. Solid lines join notes that link to each other, and faint dotted lines join notes that share tags. Hover over a note to see its title, and click it to open it. On a touch screen, tap a note once to see its title and again to open it.

{% include notes-graph.html page=true %}
