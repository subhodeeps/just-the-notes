# frozen_string_literal: true
require 'json'

class BidirectionalLinksGenerator < Jekyll::Generator
  def generate(site)
    graph_nodes = []
    graph_edges = []
    note_titles = []

    # Assume that 'index.md' is in the root directory
    # index_file = site.pages.find { |page| page.name == 'index.md' }
    
    # Check if 'index.md' exists
    # return unless index_file
    link_extension = !!site.config["use_html_extension"] ? '.html' : ''
    # Get all notes from the 'docs' folder
    all_docs = site.pages.select { |page| page.path.start_with?('docs/') }

 # Convert all Wiki/Roam-style double-bracket link syntax to plain HTML
    # anchor tag elements (<a>) with "internal-link" CSS class
    all_docs.each do |current_note|
      all_docs.each do |note_potentially_linked_to|
        note_title_regexp_pattern = Regexp.escape(
          File.basename(
            note_potentially_linked_to.basename,
            File.extname(note_potentially_linked_to.basename)
          )
        ).gsub('\_', '[ _]').gsub('\-', '[ -]').capitalize

        title_from_data = note_potentially_linked_to.data['title']
        if title_from_data
          title_from_data = Regexp.escape(title_from_data)
        end

       new_href = "#{site.baseurl}#{note_potentially_linked_to.url}#{link_extension}"
       linked_page_title = note_potentially_linked_to.data['title']
       anchor_tag = "<a href='#{new_href}'>#{linked_page_title || '\\1'}<a>"

        # Replace double-bracketed links with label using note title
        # [[A note about cats|this is a link to the note about cats]]
        current_note.content.gsub!(
          /\[\[#{note_title_regexp_pattern}\|(.+?)(?=\])\]\]/i,
          anchor_tag
        )

        # Replace double-bracketed links with label using note filename
        # [[cats|this is a link to the note about cats]]
        current_note.content.gsub!(
          /\[\[#{title_from_data}\|(.+?)(?=\])\]\]/i,
          anchor_tag
        )

        # Replace double-bracketed links using note title
        # [[a note about cats]]
        current_note.content.gsub!(
          /\[\[(#{title_from_data})\]\]/i,
          anchor_tag
        )

        # Replace double-bracketed links using note filename
        # [[cats]]
        current_note.content.gsub!(
          /\[\[(#{note_title_regexp_pattern})\]\]/i,
          anchor_tag
        )
      end

      # At this point, all remaining double-bracket-wrapped words are
      # pointing to non-existing pages, so let's turn them into disabled
      # links by greying them out and changing the cursor
      current_note.content = current_note.content.gsub(
        /\[\[([^\]]+)\]\]/i, # match on the remaining double-bracket links
        <<~HTML.delete("\n") # replace with this HTML (\\1 is what was inside the brackets)
          <span title='There is no note that matches this link.' class='invalid-link'>
            <span class='invalid-link-brackets'>[[</span>
            \\1
            <span class='invalid-link-brackets'>]]</span></span>
        HTML
      )
    end


    

    # Get all notes from the 'docs' folder
    all_notes = site.pages.select { |page| page.path.start_with?('docs/') }

    # Print the title of each note and store it in the note_titles array
    all_notes.each do |current_note|
      note_title = current_note.data['title']
      puts "Note Title: #{note_title}"
      note_titles << note_title
    end

    # Write note_titles array to a JSON file
    json_file_path = '_data/note_titles.json'
    begin
      File.write(json_file_path, JSON.dump(note_titles))
      puts "JSON file successfully written to #{json_file_path}"
    rescue StandardError => e
      puts "Error writing file: #{e.message}"
    end

    # Generate the graph based on the filtered notes
    all_notes.each do |current_note|
      # Nodes: Graph
      graph_nodes << {
        id: note_id_from_note(current_note),
        path: "#{site.baseurl}#{current_note.url}",
        label: current_note.data['title'],
      }

      # Edges: Graph
      all_notes.each do |other_note|
        next if current_note == other_note

        if other_note.content.include?(current_note.url)
          graph_edges << {
            source: note_id_from_note(other_note),
            target: note_id_from_note(current_note),
          }
        end
      end
    end

    # Write the graph to a JSON file
    json_graph_path = '_data/notes_graph.json'
    begin
      File.write(json_graph_path, JSON.dump({
        edges: graph_edges,
        nodes: graph_nodes,
      }))
      puts "Graph JSON file successfully written to #{json_graph_path}"
    rescue StandardError => e
      puts "Error writing graph file: #{e.message}"
    end
  end

  def note_id_from_note(note)
    note.data['title'].bytes.join
  end
end
