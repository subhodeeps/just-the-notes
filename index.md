---
layout: page
title: Hey!
permalink: /:path/
description: "Landing page. Summary of content."
nav_order: 1
has_children: false
has_toc: false
---

These pages contain notes and references on subjects I find interesting. Broadly, they cover topics in theoretical physics—primarily classical and semiclassical gravity, with a strong focus on black holes—as well as other related areas. You'll also find notes on scientific computing and quantitative programming, along with tutorials from various domains of computational physics, as well as pages with links to resources and articles I've found useful.

<div>
  <h2>Topics by Subject</h2>
  <ul>
    {% assign all_tags = "" | split: "," %}

    {% for entry in site.pages %}
      {% unless entry.url contains '.json' or entry.url contains '.csv' or entry.url contains '.css' or entry.url contains '.txt' or entry.url contains 'home' or entry.url contains 'tuffo' or entry.url contains 'marmellata' or entry.url contains 'jam' %}
        {% assign current_tags = entry.tags %}
        {% if current_tags %}
          {% assign all_tags = all_tags | concat: current_tags %}
        {% endif %}
      {% endunless %}
    {% endfor %}

    {% assign sorted_tags = all_tags | uniq | sort %}
    {% assign total_tags = sorted_tags | size %}
    {% assign half_tags = total_tags | divided_by: 2 %}

    <div style="float: left; width: 50%;">
      {% for tag in sorted_tags offset: half_tags %}
        <h3>{{ tag }}</h3>
        <ul>
          {% assign sorted_pages = site.pages | sort: 'title' %}
          {% for page in sorted_pages %}
            {% unless page.url contains '.json' or page.url contains '.csv' or page.url contains '.css' or page.url contains '.txt' or page.url contains 'home' or page.url contains 'tuffo' or page.url contains 'marmellata' or page.url contains 'jam' %}
              {% if page.tags contains tag %}
                <li>
                  <a href="{{page.url }}">{{ page.title }}</a>
                </li>
              {% endif %}
            {% endunless %}
          {% endfor %}
        </ul>
      {% endfor %}
    </div>

    <div style="float: left; width: 50%;">
      {% for tag in sorted_tags limit: half_tags %}
        <h3>{{ tag }}</h3>
        <ul>
          {% assign sorted_pages = site.pages | sort: 'title' %}
          {% for page in sorted_pages %}
            {% unless page.url contains '.json' or page.url contains '.csv' or page.url contains '.css' or page.url contains '.txt' or page.url contains 'home' or page.url contains 'tuffo' or page.url contains 'marmellata' or page.url contains 'jam' %}
              {% if page.tags contains tag %}
                <li>
                  <a href="{{page.url}}">{{ page.title }}</a>
                </li>
              {% endif %}
            {% endunless %}
          {% endfor %}
        </ul>
      {% endfor %}
    </div>

  </ul>
</div>

<p>Here are all the notes in this garden, along with their links, visualized as a graph.</p>

