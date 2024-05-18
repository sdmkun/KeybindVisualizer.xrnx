local vb
local buttons
local key_bindings
local original_texts
local key_states = {
  control = false,
  alt = false,
  shift = false
}

_clibroot = "source/cLib/classes/"

require(_clibroot .. "cLib")
cLib.require(_clibroot .. "cParseXML")

-- キー割り当ての設定ファイルを読み込む関数
local function load_key_bindings(filename)
  local bindings = {}

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

        local full_key = key:gsub(" ", ""):lower() -- 空白を削除し、小文字に変換
        bindings[full_key] = identifier .. ":" .. topic .. ":" .. binding
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
  z = "C",
  s = "C#",
  x = "D",
  d = "D#",
  c = "E",
  v = "F",
  g = "F#",
  b = "G",
  h = "G#",
  n = "A",
  j = "A#",
  m = "B",
  q = "C",
  ["2"] = "C#",
  w = "D",
  ["3"] = "D#",
  e = "E",
  r = "F",
  ["5"] = "F#",
  t = "G",
  ["6"] = "G#",
  y = "A",
  ["7"] = "A#",
  u = "B"
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
    if #current_line + #word + 1 > 25 then
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

local function get_binding_text(modifiers, key_name)
  local full_key = (modifiers:gsub(" ", "") == "" and key_name or (modifiers:gsub(" ", "") .. "+" .. key_name)):lower()
  local text = key_bindings[full_key] or ""

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

local function update_button_colors()
  for key, button_info in pairs(buttons) do
    local key_lower = key:lower()
    if key_lower == "ctrl" and modifier_states.control then
      button_info.button.color = { 127, 127, 255 } -- 青色
    elseif key_lower == "alt" and modifier_states.alt then
      button_info.button.color = { 127, 255, 127 } -- 緑色
    elseif key_lower == "shift" and modifier_states.shift then
      button_info.button.color = { 255, 127, 127 } -- 赤色
    else
      if button_info.text_element.text == "" then
        button_info.button.color = { 53, 53, 53 }  -- もっと暗い色（灰色）
      else
        button_info.button.color = { 102, 102, 102 } -- デフォルト色（暗い灰色）
      end
    end
  end
end

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
    height = button_height
  }
  button:add_child(text_element)
  button:add_child(key_element)

  if binding_text == key then
    text_element.text = ""
    button.color = { 53, 53, 53 } -- もっと暗い色（灰色）
  end

  return button, text_element
end

function update_binding_text()
  local modifiers = get_current_modifiers()
  -- ボタンのテキストを更新
  for key_name, button_info in pairs(buttons) do
    button_info.text_element.text = get_binding_text(modifiers, key_name)
  end
end

-- 仮想キーボードを表示する関数の修正
function show_virtual_keyboard()
  key_bindings = load_bindings_from_file()

  vb = renoise.ViewBuilder()
  local dialog_title = "JIS Virtual Keyboard"

  -- JIS配列キーボードの定義
  local jis_keycodes = {
    { "Esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" },
    { "半/全", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "^", "¥", "BackSpace" },
    { "Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "@", "[", "", "Enter" },
    { "Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", ":", "]" },
    { "Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "\\", "RShift" },
    { "Ctrl", "Win", "Alt", "無変換", "Space", "変換", "かな", "RAlt", "App", "RCtrl" }
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
        local binding_text = key_bindings[key:lower()] or key
        binding_text = format_binding_text(binding_text)

        local button_width = 60 * 2.5 -- デフォルトの幅を2.5倍に
        if row_index == 2 and key_index == 1 then
          button_width = 60 * 2.5     -- "半/全"
        elseif row_index == 3 and key_index == 1 then
          button_width = 60 * 3.0     -- "Tab"
        elseif row_index == 4 and key_index == 1 then
          button_width = 60 * 3.5     -- "Caps"
        elseif row_index == 5 and key_index == 1 then
          button_width = 60 * 4.0     -- "Shift"
        elseif row_index == 6 and key_index == 5 then
          button_width = 60 * 6.0     -- "Space"
        elseif row_index == 6 then
          button_width = 60 * 3.0     -- 最下段のキー
        end

        local button_height = 40 * 2 -- ボタンの高さを2倍に

        local button, text_element = create_button(key, binding_text, button_width, button_height)
        buttons[key:lower()] = { button = button, text_element = text_element }
        original_texts[key:lower()] = key
        button_row:add_child(button)
      end
    end
    keyboard_view:add_child(button_row)
  end

  -- ダイアログを表示
  renoise.app():show_custom_dialog(dialog_title, keyboard_view)
end

-- タイマーを設定して0.1秒ごとに修飾キーの状態をチェック
local function check_modifier_keys()
  local control_pressed = renoise.app().key_modifier_states["control"]
  local alt_pressed = renoise.app().key_modifier_states["alt"]
  local shift_pressed = renoise.app().key_modifier_states["shift"]

  if control_pressed == "pressed" then
    modifier_states.control = true
  else
    modifier_states.control = false
  end

  if alt_pressed == "pressed" then
    modifier_states.alt = true
  else
    modifier_states.alt = false
  end

  if shift_pressed == "pressed" then
    modifier_states.shift = true
  else
    modifier_states.shift = false
  end

  update_binding_text()
  update_button_colors()
end

-- 0.1秒ごとにcheck_modifier_keysを実行するタイマーを設定
renoise.tool().app_idle_observable:add_notifier(function()
  check_modifier_keys()
end)

-- 初期設定
renoise.tool().app_new_document_observable:add_notifier(function()
  show_virtual_keyboard()
end)
