local vb
local buttons
local key_bindings
local original_texts
local key_states = {
  control = false,
  alt = false,
  shift = false
}
local context_checkboxes = {}

_clibroot = "source/cLib/classes/"

require(_clibroot .. "cLib")
cLib.require(_clibroot .. "cParseXML")

-- キー割り当ての設定ファイルを読み込む関数
local function load_key_bindings(filename)
  local bindings = {}
  local key_conversion = {
    ["\\"] = "Backslash",
    ["["] = "LBracket",
  }

  -- XMLファイルを読み込み
  local file = io.open(filename, "r")
  if not file then
    error("Failed to open file: " .. filename)
  end
  local xml_data = file:read("*all")
  file:close()

  -- XMLをパース
  local x, err = cParseXML.parse(xml_data)
  if not x then
    error("Failed to parse XML: " .. err)
  end

  for _, category in ipairs(x.kids[3].kids[1].kids) do
    local identifier = category.kids[1].kids[1].value

    for _, keybinding in ipairs(category.kids[2].kids) do
      if #keybinding.kids >= 3 then
        local topic = keybinding.kids[1].kids[1].value
        local binding = keybinding.kids[2].kids[1].value
        local key = keybinding.kids[3].kids[1].value

        -- キー名の変換を適用
        key = key_conversion[key] or key

        local full_key = key:gsub(" ", ""):lower() -- 空白を削除し、小文字に変換

        -- 既に存在するキーのエントリがある場合、追加する
        if bindings[full_key] then
          table.insert(bindings[full_key], identifier .. ":" .. topic .. ":" .. binding)
        else
          bindings[full_key] = { identifier .. ":" .. topic .. ":" .. binding }
        end
      end
    end
  end

  return bindings
end

-- ファイルを開くダイアログを表示する関数
function show_open_file_dialog()
  local file_types = { "*.xml" } -- 許可するファイルタイプのリスト
  local title = "Open Key Bindings File"

  local file_path = renoise.app():prompt_for_filename_to_read(file_types, title)

  if file_path then
    renoise.app():show_status("Selected file: " .. file_path)
    return file_path
  else
    renoise.app():show_status("No file selected")
    return nil
  end
end

-- キー割り当ての設定ファイルを読み込む
local function load_bindings_from_file()
  local file_path = show_open_file_dialog()
  if file_path then
    return load_key_bindings(file_path)
  else
    return {}
  end
end

-- 音階名を表示するためのテーブル
local note_names = {
  z = "C-3",
  s = "C#3",
  x = "D-3",
  d = "D#3",
  c = "E-3",
  v = "F-3",
  g = "F#3",
  b = "G-3",
  h = "G#3",
  n = "A-3",
  j = "A#3",
  m = "B-3",
  [","] = "C-4",
  l = "C#4",
  ["."] = "D-4",
  [";"] = "D#4",
  ["/"] = "E-4",
  q = "C-4",
  ["2"] = "C#4",
  w = "D-4",
  ["3"] = "D#4",
  e = "E-4",
  r = "F-4",
  ["5"] = "F#4",
  t = "G-4",
  ["6"] = "G#-4",
  y = "A-4",
  ["7"] = "A#4",
  u = "B-4",
  i = "C-5",
  ["9"] = "C#5",
  o = "D-5",
  ["0"] = "D#5",
  p = "E-5",
  ["@"] = "F-5",
  ["["] = "G-5",
}

-- 機能名を改行する関数
local function format_binding_text(text)
  if not text:find(":") or #text == 1 then
    return text
  end

  local parts = {}
  for part in text:gmatch("[^:]+") do
    table.insert(parts, part)
  end

  local formatted_text = parts[1] .. ":\n" .. parts[2] .. ":\n"
  local binding = parts[3]

  local lines = {}
  local current_line = ""
  for word in binding:gmatch("%S+") do
    if #current_line + #word + 1 > 20 then
      table.insert(lines, current_line)
      current_line = word
    else
      if #current_line > 0 then
        current_line = current_line .. " " .. word
      else
        current_line = word
      end
    end
  end

  if #current_line > 0 then
    table.insert(lines, current_line)
  end

  return formatted_text .. table.concat(lines, "\n")
end

local function get_focused_lower_panel_name()
  local focus = renoise.app().window.active_lower_frame
  if focus == renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS then
    return "Track DSPs"
  elseif focus == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
    return "Track Automation"
  else
    return nil
  end
end

local function get_focused_middle_panel_name()
  local focus = renoise.app().window.active_middle_frame
  if focus == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    return "Pattern Editor"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_MIXER then
    return "Mixer"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    return "Phrase Editor"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES then
    return "Sample Keyzones"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
    return "Sample Editor"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION then
    -- return "Sample Modulation"
    return "Sample Modulation Matrix"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS then
    -- return "Sample Effects"
    return "Sample FX Mixer"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR then
    return "Plugin Editor"
  elseif focus == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR then
    return "MIDI Editor"
  else
    return nil
  end
end

local function get_focused_contexts()
  local contexts = {}
  for label, checkbox in pairs(context_checkboxes) do
    if checkbox.value then
      table.insert(contexts, label)
    end
  end

  local lower_panel = get_focused_lower_panel_name()
  if lower_panel then
    table.insert(contexts, lower_panel)
  end

  local middle_panel = get_focused_middle_panel_name()
  if middle_panel then
    table.insert(contexts, middle_panel)
  end

  return contexts
end

local function get_binding_text(modifiers, key_name)
  local key_conversion = {
    ["\\"] = "backslash",
    ["["] = "lbracket",
  }

  key_name = key_conversion[key_name:lower()] or key_name

  local full_key = (modifiers:gsub(" ", "") == "" and key_name or (modifiers:gsub(" ", "") .. "+" .. key_name)):lower()
  local texts = key_bindings[full_key] or { original_texts[key_name:lower()] or key_name }

  -- チェックボックスの状態を確認
  local show_texts = {}
  local contexts = get_focused_contexts()
  for _, text in ipairs(texts) do
    for _, label in ipairs(contexts) do
      if text:find(label .. ":") then
        table.insert(show_texts, text)
        break
      end
    end
  end

  local text = show_texts[1] or ""

  -- 修飾キーが押されていない場合は音階名を表示
  if modifiers == "" and note_names[key_name:lower()] then
    text = note_names[key_name:lower()]
  end

  return format_binding_text(text)
end

local modifier_states = {
  control = false,
  alt = false,
  shift = false
}

local function get_current_modifiers()
  local modifiers = {}
  if modifier_states.shift then
    table.insert(modifiers, "shift")
  end
  if modifier_states.alt then
    table.insert(modifiers, "alt")
  end
  if modifier_states.control then
    table.insert(modifiers, "control")
  end
  return table.concat(modifiers, "+")
end

local function update_button_texts()
  for key_name, button_info in pairs(buttons) do
    local key_text = get_binding_text(get_current_modifiers(), key_name)
    local key_lower = key_name:lower()
    if key_lower == "ctrl" and modifier_states.control then
      button_info.button.color = { 127, 127, 255 } -- 青色
    elseif key_lower == "alt" and modifier_states.alt then
      button_info.button.color = { 127, 255, 127 } -- 緑色
    elseif key_lower == "shift" and modifier_states.shift then
      button_info.button.color = { 255, 127, 127 } -- 赤色
    elseif key_text == "" then
      button_info.button.color = { 53, 53, 53 }  -- もっと暗い色（灰色）
    else
      button_info.button.color = { 102, 102, 102 } -- デフォルト色（暗い灰色）
    end
    button_info.text_element.text = key_text
  end
end

local function toggle_modifier_state(modifier)
  modifier_states[modifier] = not modifier_states[modifier]
  update_button_texts()
end

-- ボタンを作成する関数の修正
local function create_button(key, binding_text, button_width, button_height)
  local text_element = vb:text {
    text = binding_text ~= key and binding_text or "",
    width = button_width - 5,
    height = button_height - 5,
    align = "center",
    font = "bold"
  }

  local key_element = vb:text {
    text = key,
    width = button_width,
    height = button_height / 4,
    align = "right",
    font = "bold"
  }

  local button = vb:button {
    width = button_width,
    height = button_height,
    notifier = function()
      local key_lower = key:lower()
      if key_lower == "ctrl" then
        toggle_modifier_state("control")
      elseif key_lower == "alt" then
        toggle_modifier_state("alt")
      elseif key_lower == "shift" then
        toggle_modifier_state("shift")
      end
      renoise.app():show_status("Key pressed: " .. key)

      update_button_texts() -- 修飾キーの状態に基づいてボタンと文字を更新
    end
  }
  button:add_child(text_element)
  button:add_child(key_element)

  if binding_text == key then
    text_element.text = ""
    button.color = { 53, 53, 53 } -- もっと暗い色（灰色）
  end

  return button, text_element
end

-- 仮想キーボードを表示する関数の修正
function show_virtual_keyboard()
  key_bindings = load_bindings_from_file()

  vb = renoise.ViewBuilder()
  local dialog_title = "JIS Virtual Keyboard"

  -- コンテキストチェックボックスの作成
  local context_labels = {
    "Global", "Disk Browser", "Pattern Sequencer", "Pattern Matrix", "Phrase Map", "Instrument Box"
  }

  local context_view = vb:row {
    margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  }

  for _, label in ipairs(context_labels) do
    local checkbox = vb:checkbox {
      value = false,
      notifier = function()
        update_button_texts()
      end
    }
    context_checkboxes[label] = checkbox
    context_view:add_child(vb:row { checkbox, vb:text { text = label } })
  end

  -- JIS配列キーボードの定義
  local jis_keycodes = {
    { "Esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" },
    { "半/全", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "prevtrack", "\\", "Back" },
    { "Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "", "@", "Return" },
    { "Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "[" },
    { "Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "]", "RShift" },
    { "Ctrl", "Win", "Alt", "無変換", "Space", "変換", "かな", "RAlt", "App", "RControl" }
  }

  -- ボタンオブジェクトの辞書
  buttons = {}
  original_texts = {}

  -- キーボードのボタンを作成
  local keyboard_view = vb:column { id = "keyboard_view" }

  for row_index, row in ipairs(jis_keycodes) do
    local button_row = vb:row {}
    for key_index, key in ipairs(row) do
      if key ~= "" then
        local key_name = key:lower()
        if key_name == "\\" then
          key_name = "backslash"
        elseif key_name == "[" then
          key_name = "lbracket"
        end

        local binding_text = key_bindings[key_name] and key_bindings[key_name][1] or key
        binding_text = format_binding_text(binding_text)

        local button_width = 60 * 2.0
        if row_index == 2 and key_index == 1 then
          button_width = 60 * 2.0     -- "半/全"
        elseif row_index == 3 and key_index == 1 then
          button_width = 60 * 2.5     -- "Tab"
        elseif row_index == 4 and key_index == 1 then
          button_width = 60 * 3.0     -- "Caps"
        elseif row_index == 5 and key_index == 1 then
          button_width = 60 * 3.5     -- "Shift"
        elseif row_index == 6 and key_index == 5 then
          button_width = 60 * 6.0     -- "Space"
        elseif row_index == 6 then
          button_width = 60 * 2.5     -- 最下段のキー
        end

        local button_height = 60

        local button, text_element = create_button(key, binding_text, button_width, button_height)
        buttons[key_name] = { button = button, text_element = text_element }
        original_texts[key_name] = key
        button_row:add_child(button)
      end
    end
    keyboard_view:add_child(button_row)
  end

  -- ダイアログを表示
  renoise.app():show_custom_dialog(dialog_title, vb:column {
    context_view,
    keyboard_view
  })

  -- 初期状態で機能名を表示
  update_button_texts()
end

-- Tools メニューにダイアログを追加
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Open JIS Virtual Keyboard",
  invoke = function() show_virtual_keyboard() end
}

-- タイマーを設定して 0.1 秒ごとに修飾キーの状態をチェック
local function check_modifier_keys()
  local control_pressed = renoise.app().key_modifier_states["control"]
  local alt_pressed = renoise.app().key_modifier_states["alt"]
  local shift_pressed = renoise.app().key_modifier_states["shift"]

  if control_pressed ~= key_states.control then
    key_states.control = control_pressed
    toggle_modifier_state("control")
  end

  if alt_pressed ~= key_states.alt then
    key_states.alt = alt_pressed
    toggle_modifier_state("alt")
  end

  if shift_pressed ~= key_states.shift then
    key_states.shift = shift_pressed
    toggle_modifier_state("shift")
  end
end

renoise.app().window.active_middle_frame_observable:add_notifier(function()
  update_button_texts()
end)

renoise.app().window.active_lower_frame_observable:add_notifier(function()
  update_button_texts()
end)

-- 0.1 秒ごとに check_modifier_keys を実行するタイマーを設定
renoise.tool().app_idle_observable:add_notifier(function()
  check_modifier_keys()
end)

-- 初期設定
renoise.tool().app_new_document_observable:add_notifier(function()
  show_virtual_keyboard()
end)
