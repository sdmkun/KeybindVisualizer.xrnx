--[[============================================================================
main.lua
============================================================================]]--

local vb
local buttons
local key_bindings
local original_texts

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
  local text = key_bindings[full_key] or original_texts[key_name:lower()] or key_name
  return format_binding_text(text)
end

local function key_handler(dialog, key)
  -- キーボードイベントが発生したときにボタンのテキストを更新
  local modifiers = key.modifiers:gsub(" ", "")

  for key_name, button in pairs(buttons) do
    local key_text = get_binding_text(modifiers, key_name)
    button.text = key_text
  end

  -- close on escape...
  if (key.modifiers == "" and key.name == "esc") then
    dialog:close()
  end
end

-- 仮想キーボードを表示する関数
function show_virtual_keyboard()
  key_bindings = load_bindings_from_file()

  vb = renoise.ViewBuilder()
  local dialog_title = "JIS Virtual Keyboard"

  -- JIS配列キーボードの定義
  local jis_keycodes = {
    { "半/全", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "^", "¥" },
    { "Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "@", "[" },
    { "Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", ":", "]" },
    { "Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "Shift" },
    { "Ctrl", "Alt", "Space", "無変換", "変換", "かな" }
  }

  -- ボタンオブジェクトの辞書
  buttons = {}
  original_texts = {}

  -- キーボードのボタンを作成
  local keyboard_view = vb:column { id = "keyboard_view" }

  for row_index, row in ipairs(jis_keycodes) do
    local button_row = vb:row {}
    for key_index, key in ipairs(row) do
      local binding_text = key_bindings[key:lower()] or key
      binding_text = format_binding_text(binding_text)

      local button_width = 60 * 2.5 -- デフォルトの幅を2.5倍に
      if row_index == 1 and key_index == 1 then
        button_width = 60 * 2.5     -- "半/全"
      elseif row_index == 2 and key_index == 1 then
        button_width = 60 * 3.0     -- "Tab"
      elseif row_index == 3 and key_index == 1 then
        button_width = 60 * 3.5     -- "Caps"
      elseif row_index == 4 and key_index == 1 then
        button_width = 60 * 4.0     -- "Shift"
      elseif row_index == 5 and key_index == 1 then
        button_width = 60 * 3.0     -- "Ctrl"
      elseif row_index == 5 and key_index == 2 then
        button_width = 60 * 4.0     -- "Alt"
      elseif row_index == 5 and key_index == 3 then
        button_width = 60 * 6.0     -- "Space"
      elseif row_index == 5 and (key_index == 4 or key_index == 5 or key_index == 6) then
        button_width = 60 * 3.0     -- "無変換", "変換", "かな"
      end

      local button = vb:button {
        text = binding_text,
        width = button_width,
        height = 40 * 2, -- 高さを2倍に
        notifier = function()
          renoise.app():show_status("Key pressed: " .. key)
        end
      }
      buttons[key:lower()] = button
      original_texts[key:lower()] = key
      button_row:add_child(button)
    end
    keyboard_view:add_child(button_row)
  end

  -- ダイアログを表示
  renoise.app():show_custom_dialog(dialog_title, keyboard_view, key_handler)
end

-- 初期設定
renoise.tool().app_new_document_observable:add_notifier(function()
  show_virtual_keyboard()
end)
