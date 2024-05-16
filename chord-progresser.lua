-- Function to parse the chord progression string
function parse_chord_progression(chord_str)
  local phrases = {}
  for phrase in string.gmatch(chord_str, "[^,|]+") do
    local notes = {}
    for note in string.gmatch(phrase, "[^%s]+") do
      table.insert(notes, note)
    end
    table.insert(phrases, notes)
  end
  return phrases
end

-- Function to convert flat notes to sharp notes
function convert_flat_to_sharp(note)
  local flat_to_sharp = {
    ["Ab"] = "G#",
    ["Bb"] = "A#",
    ["Db"] = "C#",
    ["Eb"] = "D#",
    ["Gb"] = "F#"
  }

  for flat, sharp in pairs(flat_to_sharp) do
    note = note:gsub(flat, sharp)
  end
  return note
end

-- Function to check if a phrase already exists in the instrument
function phrase_exists(instrument, phrase_name, notes)
  for _, phrase in ipairs(instrument.phrases) do
    if phrase.name == phrase_name then
      local match = true
      for i, note in ipairs(notes) do
        note = convert_flat_to_sharp(note)
        if phrase:line(1).note_columns[i].note_string ~= note then
          match = false
          break
        end
      end
      if match then
        return true
      end
    end
  end
  return false
end

-- Function to create a Phrase from the parsed chords and add it to the instrument
function create_phrase(instrument, phrase_name, notes, phrase_index)
  if phrase_exists(instrument, phrase_name, notes) then
    return
  end

  local phrase = instrument:insert_phrase_at(phrase_index)
  phrase.name = phrase_name
  phrase:clear() -- Clear existing notes

  for i, note in ipairs(notes) do
    note = convert_flat_to_sharp(note)
    phrase:line(1).note_columns[i].note_string = note
  end
end

-- Main function to handle user input and generate Phrases
function main()
  local vb = renoise.ViewBuilder()
  local dialog_content = vb:column {
    vb:text { text = "Enter chord progression:" },
    vb:multiline_textfield { id = "chord_input", width = 300, height = 100 },
    vb:button {
      text = "Generate Phrases",
      notifier = function()
        local chord_str = vb.views.chord_input.text
        local chord_lines = {}

        for line in string.gmatch(chord_str, "[^\n]+") do
          table.insert(chord_lines, line)
        end

        local song = renoise.song()
        local instrument = song.selected_instrument

        for i = 1, #chord_lines, 2 do
          if i + 1 > #chord_lines then break end

          local phrase_names_str = chord_lines[i]:gsub("|%s*$", ""):gsub(",%s*$", "")
          local chord_notes_str = chord_lines[i + 1]:gsub("|%s*$", ""):gsub(",%s*$", "")

          if phrase_names_str:match("%S") and chord_notes_str:match("%S") then
            local phrase_names = parse_chord_progression(phrase_names_str)
            local chord_notes = parse_chord_progression(chord_notes_str)

            if #phrase_names ~= #chord_notes then
              renoise.app():show_error("The number of phrases and chord notes must match.")
              return
            end

            for j = 1, #phrase_names do
              create_phrase(instrument, table.concat(phrase_names[j], ""), chord_notes[j], #instrument.phrases + 1)
            end
          end
        end

        renoise.app():show_message("Phrases generated successfully!")
      end
    }
  }

  renoise.app():show_custom_dialog("Chord Progression to Phrases", dialog_content)
end

main()
