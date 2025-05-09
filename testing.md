---
layout: page
title: Tech Help
description: >-
nav_order: 80
has_children: false
has_toc: false
tags:
    - tech-help
---

<!-- Your graph will be rendered here -->
<svg id="network-graph" width="800" height="600"></svg>

<!-- Include the JSON data directly -->
<script src="https://d3js.org/d3.v6.min.js"></script>
<script>

    const graphData = {{ site.data.notes_graph | jsonify }};


    const width = 800;
    const height = 600;

    const simulation = d3.forceSimulation(graphData.nodes)
        .force("link", d3.forceLink(graphData.edges).id(d => d.id))
        .force("charge", d3.forceManyBody().strength(-150))
        .force("center", d3.forceCenter(width / 2, height / 2))
        .force("x", d3.forceX())
        .force("y", d3.forceY());

    const svg = d3.select("#network-graph")
        .attr("width", width)
        .attr("height", height);

    const links = svg.selectAll("line")
        .data(graphData.edges)
        .enter()
        .append("line")
        .attr("stroke", "#aaa")
        .attr("stroke-width", 1);

    const nodes = svg.selectAll("circle")
        .data(graphData.nodes)
        .enter()
        .append("circle")
        .attr("r", 8)
        .attr("fill", "steelblue")
        .on("click", function(event, d) {
            window.open(d.path, '_blank');
        });

    const labels = svg.selectAll("text")
        .data(graphData.nodes)
        .enter()
        .append("text")
        .text(d => d.label)
        .attr("font-size", 10)
        .attr("dx", 12)
        .attr("dy", 4);

    simulation.on("tick", () => {
        links
            .attr("x1", d => d.source.x)
            .attr("y1", d => d.source.y)
            .attr("x2", d => d.target.x)
            .attr("y2", d => d.target.y);

        nodes
            .attr("cx", d => d.x)
            .attr("cy", d => d.y);

        labels
            .attr("x", d => d.x)
            .attr("y", d => d.y);
    });
</script>

