local version = "4.8"
local currentVersion
local available = false

storage.checkVersion = storage.checkVersion or 0

-- check max once per 12hours
if os.time() > storage.checkVersion + (12 * 60 * 60) then

    storage.checkVersion = os.time()
    
    HTTP.get("https://raw.githubusercontent.com/Vithrax/vBot/main/vBot/version.txt", function(data, err)
        if err then
          warn("[vBot updater]: Unable to check version:\n" .. err)
          return
        end

        currentVersion = data
        available = true
    end)

end


-- =============================================
-- ESPECIAIS - Fugas, Traps e Combos
-- =============================================

UI.Separator()

local especiaisPanelName = "listt"
  local ui = setupUI([[
Panel

  height: 35

  Button
    id: editEspeciais
    color: orange
    font: verdana-11px-rounded
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 35
    text: - ESPECIAIS -

  ]], parent)
  ui:setId(especiaisPanelName)

  if not storage[especiaisPanelName] then
    storage[especiaisPanelName] = {}
  end

rootWidget = g_ui.getRootWidget()
if rootWidget then
    EspeciaisWindow = UI.createWidget('espEspeciaisWindow', rootWidget)
    EspeciaisWindow:hide()
    EspTabBar = EspeciaisWindow.espTabBar
    EspTabBar:setContentWidget(EspeciaisWindow.espImagem)
   for v = 1, 1 do


espPanel1 = g_ui.createWidget("espPanel")
espPanel1:setId("panelButtons")
local fugasContent = espPanel1.scrollArea

espPanel2 = g_ui.createWidget("espPanel")
espPanel2:setId("2")

espPanel3 = g_ui.createWidget("espPanel")
espPanel3:setId("3")


-- =============================================
-- TAB: FUGAS (dinamico)
-- =============================================
EspTabBar:addTab("Fugas", espPanel1)
        color= UI.Label("by: @Donator",fugasContent)
color:setColor("orange")
        UI.Separator(fugasContent)
        color= UI.Label("Fugas (tempo em segundos):",fugasContent)
color:setColor("red")
        UI.Separator(fugasContent)

-- Storage: lista de fugas
if type(storage.esp_fugas_list) ~= "table" then
  storage.esp_fugas_list = {}
end

-- Storage: posicoes e visibilidade dos widgets na tela
if type(storage.esp_fugas_widgets_pos) ~= "table" then
  storage.esp_fugas_widgets_pos = {}
end
if type(storage.esp_fugas_widgets_show) ~= "table" then
  storage.esp_fugas_widgets_show = {}
end

local fugaActive = false
local fugaCooldowns = {}
local fugaWidgets = {}
local fugaScreenWidgets = {}
local fugaActiveUntil = {}

-- Funcao para criar widget na tela de uma fuga
local function createFugaScreenWidget(index)
  local fugaData = storage.esp_fugas_list[index]
  if not fugaData then return end

  -- Destroi widget antigo se existir
  if fugaScreenWidgets[index] then
    fugaScreenWidgets[index]:destroy()
    fugaScreenWidgets[index] = nil
  end

  local screenWidget = g_ui.loadUIFromString([[
UIWidget
  background-color: #000000cc
  opacity: 0.90
  height: 22
  width: 170
  focusable: true
  phantom: false
  draggable: true

  Label
    id: statusText
    anchors.fill: parent
    text-align: center
    font: verdana-11px-rounded
    color: green
    text: Pronta
    padding: 2
]], g_ui.getRootWidget())

  -- Posicao salva ou padrao
  local savedPos = storage.esp_fugas_widgets_pos[index]
  if savedPos and savedPos.x and savedPos.y then
    screenWidget:breakAnchors()
    screenWidget:move(savedPos.x, savedPos.y)
  else
    screenWidget:breakAnchors()
    screenWidget:move(300, 50 + (index - 1) * 30)
  end

  -- Drag handlers
  screenWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = { x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY() }
    return true
  end

  screenWidget.onDragMove = function(widget, mousePos)
    widget:move(mousePos.x - widget.movingReference.x, mousePos.y - widget.movingReference.y)
    return true
  end

  screenWidget.onDragLeave = function(widget)
    storage.esp_fugas_widgets_pos[index] = { x = widget:getX(), y = widget:getY() }
    return true
  end

  screenWidget.statusText:setText("Fuga #" .. index .. ": Pronta")

  -- Visibilidade conforme checkbox
  if storage.esp_fugas_widgets_show[index] then
    screenWidget:show()
  else
    screenWidget:hide()
  end

  fugaScreenWidgets[index] = screenWidget
  return screenWidget
end

-- Botao adicionar fuga via setupUI
local addBtn = setupUI([[
Panel
  height: 25
  Button
    id: addFuga
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Fuga
]], fugasContent)

-- Funcao para criar widget de uma fuga via setupUI
local function createFugaWidget(index, fugaData)
  local entry = setupUI([[
Panel
  height: 180
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #00FFFF
    font: verdana-11px-rounded
    text: Fuga

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

  CheckBox
    id: showOnScreen
    anchors.top: parent.top
    anchors.right: removeBtn.left
    margin-right: 5
    margin-top: 2
    text: Tela
    color: #AAFFAA
    text-auto-resize: true

  Label
    id: lbl1
    anchors.top: removeBtn.bottom
    anchors.left: parent.left
    margin-top: 3
    text: Spell:
    color: white
    text-auto-resize: true

  TextEdit
    id: spellEdit
    anchors.top: lbl1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18
    margin-top: 1

  Panel
    id: row1
    anchors.top: spellEdit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    margin-top: 3
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: HP%:
      color: white
      text-auto-resize: true
    TextEdit
      id: hpEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row2
    anchors.top: row1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Ativo(s):
      color: white
      text-auto-resize: true
    TextEdit
      id: activeEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row3
    anchors.top: row2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: CD(s):
      color: white
      text-auto-resize: true
    TextEdit
      id: cdEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row4
    anchors.top: row3.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Ordem:
      color: white
      text-auto-resize: true
    TextEdit
      id: orderEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  ]], fugasContent)

  entry.title:setText("Fuga #" .. index)
  entry.spellEdit:setText(fugaData.text or "")
  entry.row1.hpEdit:setText(tostring(fugaData.hp or 50))
  entry.row2.activeEdit:setText(tostring(fugaData.activeTime or 3))
  entry.row3.cdEdit:setText(tostring(fugaData.cooldown or 10))
  entry.row4.orderEdit:setText(tostring(fugaData.order or index))

  -- Checkbox "mostrar na tela"
  entry.showOnScreen:setChecked(storage.esp_fugas_widgets_show[index] or false)
  entry.showOnScreen.onClick = function(w)
    local checked = not w:isChecked()
    w:setChecked(checked)
    storage.esp_fugas_widgets_show[index] = checked
    if checked then
      if not fugaScreenWidgets[index] then
        createFugaScreenWidget(index)
      else
        fugaScreenWidgets[index]:show()
      end
    else
      if fugaScreenWidgets[index] then
        fugaScreenWidgets[index]:hide()
      end
    end
  end

  -- Criar widget na tela se checkbox ativo
  createFugaScreenWidget(index)

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_fugas_list[index].text = text
  end
  entry.row1.hpEdit.onTextChange = function(w, text)
    storage.esp_fugas_list[index].hp = tonumber(text) or 50
  end
  entry.row2.activeEdit.onTextChange = function(w, text)
    storage.esp_fugas_list[index].activeTime = tonumber(text) or 3
  end
  entry.row3.cdEdit.onTextChange = function(w, text)
    storage.esp_fugas_list[index].cooldown = tonumber(text) or 10
  end
  entry.row4.orderEdit.onTextChange = function(w, text)
    storage.esp_fugas_list[index].order = tonumber(text) or index
  end

  entry.removeBtn.onClick = function(w)
    -- Destroi widget da tela
    if fugaScreenWidgets[index] then
      fugaScreenWidgets[index]:destroy()
      fugaScreenWidgets[index] = nil
    end
    storage.esp_fugas_widgets_show[index] = nil
    storage.esp_fugas_widgets_pos[index] = nil
    table.remove(storage.esp_fugas_list, index)
    refreshFugas()
  end

  table.insert(fugaWidgets, entry)
  return entry
end

-- Refresh all fuga widgets
function refreshFugas()
  for _, w in ipairs(fugaWidgets) do
    w:destroy()
  end
  fugaWidgets = {}
  -- Destroi todos os widgets de tela
  for idx, sw in pairs(fugaScreenWidgets) do
    if sw and sw.destroy then sw:destroy() end
  end
  fugaScreenWidgets = {}
  for i, fugaData in ipairs(storage.esp_fugas_list) do
    createFugaWidget(i, fugaData)
  end
end

-- Add button click
addBtn.addFuga.onClick = function(w)
  local newIndex = #storage.esp_fugas_list + 1
  table.insert(storage.esp_fugas_list, {
    text = "fuga " .. newIndex,
    hp = 50,
    activeTime = 3,
    cooldown = 10,
    order = newIndex
  })
  refreshFugas()
end

-- Load existing fugas on start
refreshFugas()

-- Macro para atualizar os widgets na tela (status visual)
macro(200, function()
  for i, sw in pairs(fugaScreenWidgets) do
    if sw and storage.esp_fugas_list[i] then
      local f = storage.esp_fugas_list[i]
      local spellName = f.text or ("Fuga #" .. i)
      local cooldownMs = (tonumber(f.cooldown) or 10) * 1000
      local activeTimeMs = (tonumber(f.activeTime) or 3) * 1000
      local cdEnd = (fugaCooldowns[i] or 0) + cooldownMs
      local activeEnd = fugaActiveUntil[i] or 0

      if activeEnd > now then
        -- Fuga ativa
        local remaining = math.ceil((activeEnd - now) / 1000)
        sw.statusText:setText(spellName .. " | ATIVA: " .. remaining .. "s")
        sw.statusText:setColor("#FFFF00")
      elseif cdEnd > now then
        -- Em cooldown
        local remaining = math.ceil((cdEnd - now) / 1000)
        sw.statusText:setText(spellName .. " | CD: " .. remaining .. "s")
        sw.statusText:setColor("#FF4444")
      else
        -- Pronta
        sw.statusText:setText(spellName .. " | PRONTA")
        sw.statusText:setColor("#00FF00")
      end
    end
  end
end)

-- Main fuga macro
EspFugaMacro = macro(200, "Fugas Especiais", function()
  local hp = player:getHealthPercent()

  local fugaList = {}
  for i, f in ipairs(storage.esp_fugas_list) do
    if f.text and f.text:len() > 0 then
      table.insert(fugaList, { index = i, data = f })
    end
  end

  -- ordena por prioridade (ordem)
  table.sort(fugaList, function(a, b)
    return (tonumber(a.data.order) or a.index) < (tonumber(b.data.order) or b.index)
  end)

  for _, fuga in ipairs(fugaList) do
    local i = fuga.index
    local f = fuga.data

    local hpThreshold = tonumber(f.hp) or 50
    local cooldownMs  = (tonumber(f.cooldown) or 10) * 1000
    local activeTimeMs = (tonumber(f.activeTime) or 3) * 1000

    fugaCooldowns[i] = fugaCooldowns[i] or 0

    -- 🔒 REGRA CRÍTICA:
    -- se o HP ainda não chegou nessa prioridade,
    -- nenhuma fuga de ordem maior pode executar
    if hp > hpThreshold then
      break
    end

    if not fugaActive and (now - fugaCooldowns[i]) >= cooldownMs then
      fugaActive = true

      -- pausa combos e traps
      if EspComboMacro and EspComboMacro:isOn() then EspComboMacro.setOff() end
      if EspTrapMacro and EspTrapMacro:isOn() then EspTrapMacro.setOff() end

      say(f.text)

      fugaCooldowns[i] = now
      fugaActiveUntil[i] = now + activeTimeMs

      schedule(activeTimeMs, function()
        fugaActive = false
        if EspComboMacro and not EspComboMacro:isOn() then EspComboMacro.setOn() end
        if EspTrapMacro and not EspTrapMacro:isOn() then EspTrapMacro.setOn() end
      end)

      break
    end
  end
end, fugasContent)



-- =============================================
-- TAB: TRAPS
-- =============================================
EspTabBar:addTab("Traps", espPanel2)
local trapsContent = espPanel2.scrollArea
        color= UI.Label("by: @Donator",trapsContent)
color:setColor("orange")
        UI.Separator(trapsContent)
        color= UI.Label("Traps / Armadilhas:",trapsContent)
color:setColor("red")
        UI.Separator(trapsContent)

if not storage.esp_trap then
  storage.esp_trap = {
    text1 = "trap 1", text2 = "trap 2", text3 = "trap 3",
    text4 = "trap 4", text5 = "trap 5", text6 = "trap 6"
  }
end

EspTrapMacro = macro(200, "Traps", function()
  if g_game.isAttacking() then
    if storage.esp_trap.text1:len() > 0 then say(storage.esp_trap.text1) end
    if storage.esp_trap.text2:len() > 0 then say(storage.esp_trap.text2) end
    if storage.esp_trap.text3:len() > 0 then say(storage.esp_trap.text3) end
    if storage.esp_trap.text4:len() > 0 then say(storage.esp_trap.text4) end
    if storage.esp_trap.text5:len() > 0 then say(storage.esp_trap.text5) end
    if storage.esp_trap.text6:len() > 0 then say(storage.esp_trap.text6) end
  end
end, trapsContent)

addTextEdit("esp_trap_1", storage.esp_trap.text1 or "trap 1", function(widget, text)
  storage.esp_trap.text1 = text
end, trapsContent)
addTextEdit("esp_trap_2", storage.esp_trap.text2 or "trap 2", function(widget, text)
  storage.esp_trap.text2 = text
end, trapsContent)
addTextEdit("esp_trap_3", storage.esp_trap.text3 or "trap 3", function(widget, text)
  storage.esp_trap.text3 = text
end, trapsContent)
addTextEdit("esp_trap_4", storage.esp_trap.text4 or "trap 4", function(widget, text)
  storage.esp_trap.text4 = text
end, trapsContent)
addTextEdit("esp_trap_5", storage.esp_trap.text5 or "trap 5", function(widget, text)
  storage.esp_trap.text5 = text
end, trapsContent)
addTextEdit("esp_trap_6", storage.esp_trap.text6 or "trap 6", function(widget, text)
  storage.esp_trap.text6 = text
end, trapsContent)


-- =============================================
-- TAB: COMBOS
-- =============================================
EspTabBar:addTab("Combos", espPanel3)
local combosContent = espPanel3.scrollArea
        color= UI.Label("by: @Donator",combosContent)
color:setColor("orange")
        UI.Separator(combosContent)
        color= UI.Label("Combo de Ataque:",combosContent)
color:setColor("red")
        UI.Separator(combosContent)

if not storage.esp_combo then
  storage.esp_combo = {
    text1 = "magia 1", text2 = "magia 2", text3 = "magia 3",
    text4 = "magia 4", text5 = "magia 5", text6 = "magia 6"
  }
end

EspComboMacro = macro(200, "Combo Especial", function()
  if g_game.isAttacking() then
    if storage.esp_combo.text1:len() > 0 then say(storage.esp_combo.text1) end
    if storage.esp_combo.text2:len() > 0 then say(storage.esp_combo.text2) end
    if storage.esp_combo.text3:len() > 0 then say(storage.esp_combo.text3) end
    if storage.esp_combo.text4:len() > 0 then say(storage.esp_combo.text4) end
    if storage.esp_combo.text5:len() > 0 then say(storage.esp_combo.text5) end
    if storage.esp_combo.text6:len() > 0 then say(storage.esp_combo.text6) end
  end
end, combosContent)

addTextEdit("esp_combo_1", storage.esp_combo.text1 or "magia 1", function(widget, text)
  storage.esp_combo.text1 = text
end, combosContent)
addTextEdit("esp_combo_2", storage.esp_combo.text2 or "magia 2", function(widget, text)
  storage.esp_combo.text2 = text
end, combosContent)
addTextEdit("esp_combo_3", storage.esp_combo.text3 or "magia 3", function(widget, text)
  storage.esp_combo.text3 = text
end, combosContent)
addTextEdit("esp_combo_4", storage.esp_combo.text4 or "magia 4", function(widget, text)
  storage.esp_combo.text4 = text
end, combosContent)
addTextEdit("esp_combo_5", storage.esp_combo.text5 or "magia 5", function(widget, text)
  storage.esp_combo.text5 = text
end, combosContent)
addTextEdit("esp_combo_6", storage.esp_combo.text6 or "magia 6", function(widget, text)
  storage.esp_combo.text6 = text
end, combosContent)


end
end


  EspeciaisWindow.closeButton.onClick = function(widget)
    EspeciaisWindow:hide()
  end

  
  ui.editEspeciais.onClick = function(widget)
    EspeciaisWindow:show()
    EspeciaisWindow:raise()
    EspeciaisWindow:focus()
  end

UI.Separator()


-- Aumentar largura do painel do bot para caber mais tabs
schedule(100, function()
    local botWindow = modules.game_bot.contentsPanel
    if botWindow then
        local parent = botWindow:getParent()
        if parent then
            parent:setWidth(350) -- Aumenta de ~200 para 300
        end
    end
end)