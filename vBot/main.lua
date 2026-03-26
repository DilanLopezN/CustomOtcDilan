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
-- ESPECIAIS - Fugas, Traps, Combos e Buffs
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

espPanel4 = g_ui.createWidget("espPanel")
espPanel4:setId("4")

espPanel5 = g_ui.createWidget("espPanel")
espPanel5:setId("5")

espPanel6 = g_ui.createWidget("espPanel")
espPanel6:setId("6")

espPanel7 = g_ui.createWidget("espPanel")
espPanel7:setId("7")


-- =============================================
-- TAB: FUGAS (dinamico)
-- =============================================
EspTabBar:addTab("Fugas", espPanel1)
        UI.Separator(fugasContent)
        color= UI.Label("Fugas (tempo em segundos):",fugasContent)
color:setColor("red")
        UI.Separator(fugasContent)

-- Storage: lista de fugas
if type(storage.esp_fugas_list) ~= "table" then
  storage.esp_fugas_list = {}
end

-- Atribui IDs unicos para cada fuga existente
local fugaIdCounter = 0
for _, f in ipairs(storage.esp_fugas_list) do
  if f.uid and f.uid >= fugaIdCounter then
    fugaIdCounter = f.uid + 1
  end
end
for _, f in ipairs(storage.esp_fugas_list) do
  if not f.uid then
    f.uid = fugaIdCounter
    fugaIdCounter = fugaIdCounter + 1
  end
end

-- Storage: posicoes e visibilidade dos widgets na tela (por uid)
if type(storage.esp_fugas_widgets_pos) ~= "table" then
  storage.esp_fugas_widgets_pos = {}
end
if type(storage.esp_fugas_widgets_show) ~= "table" then
  storage.esp_fugas_widgets_show = {}
end

local fugaActive = false
local fugaCooldownEnd = {}   -- [uid] = timestamp quando CD termina
local fugaActiveEnd = {}     -- [uid] = timestamp quando ativo termina
local fugaUsesLeft = {}      -- [uid] = usos restantes antes do CD
local fugaWidgets = {}
local fugaScreenWidgets = {} -- [uid] = screen widget

-- Limpar widgets de fuga orfaos de execucoes anteriores
local root = g_ui.getRootWidget()
if root then
  local toRemove = {}
  for _, child in ipairs(root:getChildren()) do
    if child:getId() and child:getId():find("^fugaScreenWidget_") then
      table.insert(toRemove, child)
    end
  end
  for _, w in ipairs(toRemove) do
    w:destroy()
  end
end

-- Estado de pausa para traps e combos (controlado pelas fugas)
local trapsWereOn = false
local combosWereOn = false

-- Funcao para criar widget na tela de uma fuga
local function createFugaScreenWidget(uid, fugaData, displayIndex)
  if not fugaData then return end

  -- Destroi widget antigo se existir
  if fugaScreenWidgets[uid] then
    fugaScreenWidgets[uid]:destroy()
    fugaScreenWidgets[uid] = nil
  end

  local screenWidget = g_ui.loadUIFromString([[
UIWidget
  background-color: #000000cc
  opacity: 0.90
  height: 26
  width: 280
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
    text-auto-resize: true
]], g_ui.getRootWidget())

  -- Posicao salva ou padrao
  local savedPos = storage.esp_fugas_widgets_pos[uid]
  if savedPos and savedPos.x and savedPos.y then
    screenWidget:breakAnchors()
    screenWidget:move(savedPos.x, savedPos.y)
  else
    screenWidget:breakAnchors()
    screenWidget:move(300, 50 + (displayIndex - 1) * 34)
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
    storage.esp_fugas_widgets_pos[uid] = { x = widget:getX(), y = widget:getY() }
    return true
  end

  local spellName = fugaData.text or ("Fuga #" .. displayIndex)
  screenWidget.statusText:setText(spellName .. " | PRONTA")

  -- Sempre visivel quando criado (so e criado se checkbox ativo)
  screenWidget:show()

  screenWidget:setId("fugaScreenWidget_" .. uid)
  fugaScreenWidgets[uid] = screenWidget
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
  local uid = fugaData.uid
  local entry = setupUI([[
Panel
  height: 260
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
    height: 22
    margin-top: 1

  Panel
    id: row1
    anchors.top: spellEdit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
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
    height: 24
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
    height: 24
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
    height: 24
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

  Panel
    id: row5
    anchors.top: row4.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Quantidade:
      color: #AADDFF
      text-auto-resize: true
    TextEdit
      id: qtdEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row6
    anchors.top: row5.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: CD Qtd(s):
      color: #AADDFF
      text-auto-resize: true
    TextEdit
      id: cdQtdEdit
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
  entry.row5.qtdEdit:setText(tostring(fugaData.quantidade or 1))
  entry.row6.cdQtdEdit:setText(tostring(fugaData.cdQuantidade or 2))

  -- Tooltips explicativos para cada campo
  entry.spellEdit:setTooltip("Nome da spell de fuga que sera usada (ex: utani hur)")
  entry.row1.hpEdit:setTooltip("Porcentagem de HP para ativar a fuga (ex: 50 = ativa quando HP <= 50%)")
  entry.row2.activeEdit:setTooltip("Tempo em segundos que a fuga fica ativa apos ser usada")
  entry.row3.cdEdit:setTooltip("Tempo de cooldown em segundos apos usar todas as cargas")
  entry.row4.orderEdit:setTooltip("Prioridade da fuga (menor numero = maior prioridade)")
  entry.row5.qtdEdit:setTooltip("Quantidade de vezes que vai usar antes de entrar em cooldown")
  entry.row6.cdQtdEdit:setTooltip("Cooldown em segundos entre cada uso quando tem multiplas cargas")

  -- Estilo: fundo transparente e texto neon azul nos inputs
  local fugaInputs = {entry.spellEdit, entry.row1.hpEdit, entry.row2.activeEdit, entry.row3.cdEdit, entry.row4.orderEdit, entry.row5.qtdEdit, entry.row6.cdQtdEdit}
  for _, input in ipairs(fugaInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  -- Checkbox "mostrar na tela"
  entry.showOnScreen:setChecked(storage.esp_fugas_widgets_show[uid] or false)
  entry.showOnScreen.onClick = function(w)
    local checked = not w:isChecked()
    w:setChecked(checked)
    storage.esp_fugas_widgets_show[uid] = checked
    if checked then
      if not fugaScreenWidgets[uid] then
        createFugaScreenWidget(uid, fugaData, index)
      else
        fugaScreenWidgets[uid]:show()
      end
    else
      if fugaScreenWidgets[uid] then
        fugaScreenWidgets[uid]:hide()
      end
    end
  end

  -- Criar widget na tela somente se checkbox ativo (evita duplicacao no restart)
  if storage.esp_fugas_widgets_show[uid] then
    createFugaScreenWidget(uid, fugaData, index)
  end

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
  entry.row5.qtdEdit.onTextChange = function(w, text)
    storage.esp_fugas_list[index].quantidade = tonumber(text) or 1
  end
  entry.row6.cdQtdEdit.onTextChange = function(w, text)
    storage.esp_fugas_list[index].cdQuantidade = tonumber(text) or 2
  end

  entry.removeBtn.onClick = function(w)
    -- Destroi widget da tela
    if fugaScreenWidgets[uid] then
      fugaScreenWidgets[uid]:destroy()
      fugaScreenWidgets[uid] = nil
    end
    -- Limpa storage por uid
    storage.esp_fugas_widgets_show[uid] = nil
    storage.esp_fugas_widgets_pos[uid] = nil
    -- Limpa cooldowns
    fugaCooldownEnd[uid] = nil
    fugaActiveEnd[uid] = nil
    fugaUsesLeft[uid] = nil
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
  for uid, sw in pairs(fugaScreenWidgets) do
    if sw and sw.destroy then sw:destroy() end
  end
  fugaScreenWidgets = {}

  -- Limpa storage de show/pos para uids que nao existem mais
  local validUids = {}
  for _, f in ipairs(storage.esp_fugas_list) do
    if f.uid then validUids[f.uid] = true end
  end
  for uid, _ in pairs(storage.esp_fugas_widgets_show) do
    if not validUids[uid] then
      storage.esp_fugas_widgets_show[uid] = nil
      storage.esp_fugas_widgets_pos[uid] = nil
    end
  end

  for i, fugaData in ipairs(storage.esp_fugas_list) do
    createFugaWidget(i, fugaData)
  end
end

-- Add button click
addBtn.addFuga.onClick = function(w)
  local newIndex = #storage.esp_fugas_list + 1
  local newUid = fugaIdCounter
  fugaIdCounter = fugaIdCounter + 1
  table.insert(storage.esp_fugas_list, {
    text = "fuga " .. newIndex,
    hp = 50,
    activeTime = 3,
    cooldown = 10,
    order = newIndex,
    quantidade = 1,
    cdQuantidade = 2,
    uid = newUid
  })
  refreshFugas()
end

-- Load existing fugas on start
refreshFugas()

-- Macro para atualizar os widgets na tela (status visual)
macro(200, function()
  for uid, sw in pairs(fugaScreenWidgets) do
    -- Encontrar fuga data pelo uid
    local fugaData = nil
    local fugaIndex = nil
    for i, f in ipairs(storage.esp_fugas_list) do
      if f.uid == uid then
        fugaData = f
        fugaIndex = i
        break
      end
    end

    if sw and fugaData then
      local spellName = fugaData.text or ("Fuga #" .. (fugaIndex or "?"))
      local activeEnd = fugaActiveEnd[uid] or 0
      local cdEnd = fugaCooldownEnd[uid] or 0
      local qtd = tonumber(fugaData.quantidade) or 1
      local usesRemaining = fugaUsesLeft[uid]

      if activeEnd > 0 and now < activeEnd then
        local remaining = math.ceil((activeEnd - now) / 1000)
        local usesInfo = ""
        if qtd > 1 and usesRemaining then
          usesInfo = " [" .. usesRemaining .. "x]"
        end
        sw.statusText:setText(spellName .. " | ATIVA: " .. remaining .. "s" .. usesInfo)
        sw.statusText:setColor("#FFFF00")
      elseif cdEnd > 0 and now < cdEnd then
        local remaining = math.ceil((cdEnd - now) / 1000)
        sw.statusText:setText(spellName .. " | CD: " .. remaining .. "s")
        sw.statusText:setColor("#FF4444")
      else
        local usesInfo = ""
        if qtd > 1 then
          local left = usesRemaining or qtd
          usesInfo = " [" .. left .. "x]"
        end
        sw.statusText:setText(spellName .. " | PRONTA" .. usesInfo)
        sw.statusText:setColor("#00FF00")
      end
    end
  end
end)

-- Kai: usa kai automaticamente quando paralizado ou lento
if not storage.esp_auto_kai then
  storage.esp_auto_kai = { enabled = false, spell = "kai" }
end

UI.Separator(fugasContent)
color = UI.Label("Kai (Anti-Paralyze):", fugasContent)
color:setColor("#FF88FF")

local autoKaiMacro = macro(100, "Kai", function()
  if isInPz() then return end
  local spellKai = storage.esp_auto_kai.spell or "kai"
  if spellKai:len() == 0 then return end
  if isParalyzed() and not getSpellCoolDown(spellKai) then
    say(spellKai)
  end
end, fugasContent)

addTextEdit("esp_auto_kai_spell", storage.esp_auto_kai.spell or "kai", function(widget, text)
  storage.esp_auto_kai.spell = text
end, fugasContent)

-- Estilo neon azul para input do kai
schedule(100, function()
  local function styleFugasAddTextEdits(widget)
    if not widget then return end
    local children = widget:getChildren()
    if not children then return end
    for _, child in ipairs(children) do
      if child.getClassName and child:getClassName() == "TextEdit" and child:getId() == "esp_auto_kai_spell" then
        child:setBackgroundColor("#00000033")
        child:setColor("#00DDFF")
      end
    end
  end
  styleFugasAddTextEdits(fugasContent)
end)

UI.Separator(fugasContent)

-- Main fuga macro (com suporte a quantidade e pausa de traps/combos)
EspFugaMacro = macro(200, "Fugas Especiais", function()
  local hp = player:getHealthPercent()

  -- Monta lista ordenada por campo ordem
  local fugaList = {}
  for i, f in ipairs(storage.esp_fugas_list) do
    if f.text and f.text:len() > 0 then
      table.insert(fugaList, { index = i, data = f, uid = f.uid })
    end
  end

  table.sort(fugaList, function(a, b)
    return (tonumber(a.data.order) or a.index) < (tonumber(b.data.order) or b.index)
  end)

  for _, fuga in ipairs(fugaList) do
    local i = fuga.index
    local f = fuga.data
    local uid = fuga.uid

    local hpThreshold = tonumber(f.hp) or 50
    local cooldownMs  = (tonumber(f.cooldown) or 10) * 1000
    local activeTimeMs = (tonumber(f.activeTime) or 3) * 1000
    local maxUses = tonumber(f.quantidade) or 1
    local cdQtdMs = (tonumber(f.cdQuantidade) or 2) * 1000

    -- Se o HP ainda nao chegou nessa prioridade, para
    if hp > hpThreshold then
      break
    end

    local cdEnd = fugaCooldownEnd[uid] or 0

    -- Inicializa usos restantes se necessario
    if not fugaUsesLeft[uid] then
      fugaUsesLeft[uid] = maxUses
    end

    if not fugaActive and now >= cdEnd then
      -- Pausa combos e traps (salva estado anterior)
      if not fugaActive then
        trapsWereOn = EspTrapMacro and EspTrapMacro:isOn() or false
        combosWereOn = EspComboMacro and EspComboMacro:isOn() or false
      end

      fugaActive = true

      if EspComboMacro and EspComboMacro:isOn() then EspComboMacro.setOff() end
      if EspTrapMacro and EspTrapMacro:isOn() then EspTrapMacro.setOff() end

      say(f.text)

      fugaUsesLeft[uid] = fugaUsesLeft[uid] - 1

      if fugaUsesLeft[uid] <= 0 then
        -- Acabou os usos, entra em cooldown total
        fugaUsesLeft[uid] = maxUses
        fugaActiveEnd[uid] = now + activeTimeMs
        fugaCooldownEnd[uid] = now + activeTimeMs + cooldownMs

        schedule(activeTimeMs, function()
          fugaActive = false
          -- Restaura traps e combos ao estado anterior
          if combosWereOn and EspComboMacro and not EspComboMacro:isOn() then EspComboMacro.setOn() end
          if trapsWereOn and EspTrapMacro and not EspTrapMacro:isOn() then EspTrapMacro.setOn() end
        end)
      else
        -- Ainda tem usos, cooldown curto entre usos
        fugaActiveEnd[uid] = now + activeTimeMs
        fugaCooldownEnd[uid] = now + cdQtdMs

        schedule(activeTimeMs, function()
          fugaActive = false
          -- Restaura traps e combos ao estado anterior
          if combosWereOn and EspComboMacro and not EspComboMacro:isOn() then EspComboMacro.setOn() end
          if trapsWereOn and EspTrapMacro and not EspTrapMacro:isOn() then EspTrapMacro.setOn() end
        end)
      end

      break
    end
  end
end, fugasContent)



-- =============================================
-- TAB: TRAPS (dinamico - adicionar/remover/ordenar)
-- =============================================
EspTabBar:addTab("Traps", espPanel2)
local trapsContent = espPanel2.scrollArea
        UI.Separator(trapsContent)
        color= UI.Label("Traps / Armadilhas:",trapsContent)
color:setColor("red")
        UI.Separator(trapsContent)

-- Storage: lista de traps (formato novo)
if type(storage.esp_trap_list) ~= "table" then
  -- Migrar do formato antigo se existir
  if storage.esp_trap then
    storage.esp_trap_list = {}
    for k = 1, 6 do
      local key = "text" .. k
      if storage.esp_trap[key] and storage.esp_trap[key]:len() > 0 then
        table.insert(storage.esp_trap_list, {
          text = storage.esp_trap[key],
          cooldown = 5,
          trapTime = 3,
          hpPercent = 100,
          await = false
        })
      end
    end
  else
    storage.esp_trap_list = {}
  end
end

-- Atribui IDs unicos para cada trap existente
local trapIdCounter = 0
for _, t in ipairs(storage.esp_trap_list) do
  if t.uid and t.uid >= trapIdCounter then
    trapIdCounter = t.uid + 1
  end
end
for _, t in ipairs(storage.esp_trap_list) do
  if not t.uid then
    t.uid = trapIdCounter
    trapIdCounter = trapIdCounter + 1
  end
end

local trapCooldownEnd = {}   -- [uid] = timestamp quando CD termina
local trapActiveEnd = {}     -- [uid] = timestamp quando trap ativa termina (tempo trapado)
local trapWidgets = {}

-- Funcao para criar widget de uma trap
local function createTrapWidget(index, trapData)
  local uid = trapData.uid
  local entry = setupUI([[
Panel
  height: 190
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #FF4444
    font: verdana-11px-rounded
    text: Trap

  Button
    id: upBtn
    anchors.top: parent.top
    anchors.right: downBtn.left
    margin-right: 3
    width: 20
    height: 18
    text: ^
    color: #AAFFAA

  Button
    id: downBtn
    anchors.top: parent.top
    anchors.right: removeBtn.left
    margin-right: 3
    width: 20
    height: 18
    text: v
    color: #AAFFAA

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

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
    height: 22
    margin-top: 1

  Panel
    id: row1
    anchors.top: spellEdit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 3
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Cooldown(s):
      color: white
      text-auto-resize: true
    TextEdit
      id: cdEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row2
    anchors.top: row1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Tempo Trapado(s):
      color: white
      text-auto-resize: true
    TextEdit
      id: trapTimeEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row3
    anchors.top: row2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: % Vida Inimigo:
      color: white
      text-auto-resize: true
    TextEdit
      id: hpEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row4
    anchors.top: row3.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    CheckBox
      id: awaitCheck
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Await (esperar trap anterior)
      color: #AAFFAA
      text-auto-resize: true

  ]], trapsContent)

  entry.title:setText("Trap #" .. index)
  entry.spellEdit:setText(trapData.text or "")
  entry.row1.cdEdit:setText(tostring(trapData.cooldown or 5))
  entry.row2.trapTimeEdit:setText(tostring(trapData.trapTime or 3))
  entry.row3.hpEdit:setText(tostring(trapData.hpPercent or 100))
  entry.row4.awaitCheck:setChecked(trapData.await or false)

  -- Estilo: fundo transparente e texto neon azul nos inputs
  local trapInputs = {entry.spellEdit, entry.row1.cdEdit, entry.row2.trapTimeEdit, entry.row3.hpEdit}
  for _, input in ipairs(trapInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_trap_list[index].text = text
  end
  entry.row1.cdEdit.onTextChange = function(w, text)
    storage.esp_trap_list[index].cooldown = tonumber(text) or 5
  end
  entry.row2.trapTimeEdit.onTextChange = function(w, text)
    storage.esp_trap_list[index].trapTime = tonumber(text) or 3
  end
  entry.row3.hpEdit.onTextChange = function(w, text)
    storage.esp_trap_list[index].hpPercent = tonumber(text) or 100
  end
  entry.row4.awaitCheck.onClick = function(w)
    local checked = not w:isChecked()
    w:setChecked(checked)
    storage.esp_trap_list[index].await = checked
  end

  -- Botao mover para cima
  entry.upBtn.onClick = function(w)
    if index > 1 then
      local tmp = storage.esp_trap_list[index]
      storage.esp_trap_list[index] = storage.esp_trap_list[index - 1]
      storage.esp_trap_list[index - 1] = tmp
      refreshTraps()
    end
  end

  -- Botao mover para baixo
  entry.downBtn.onClick = function(w)
    if index < #storage.esp_trap_list then
      local tmp = storage.esp_trap_list[index]
      storage.esp_trap_list[index] = storage.esp_trap_list[index + 1]
      storage.esp_trap_list[index + 1] = tmp
      refreshTraps()
    end
  end

  entry.removeBtn.onClick = function(w)
    trapCooldownEnd[uid] = nil
    trapActiveEnd[uid] = nil
    table.remove(storage.esp_trap_list, index)
    refreshTraps()
  end

  table.insert(trapWidgets, entry)
  return entry
end

-- Refresh all trap widgets
function refreshTraps()
  for _, w in ipairs(trapWidgets) do
    w:destroy()
  end
  trapWidgets = {}
  for i, trapData in ipairs(storage.esp_trap_list) do
    createTrapWidget(i, trapData)
  end
end

-- Botao adicionar trap
local addTrapBtn = setupUI([[
Panel
  height: 25
  Button
    id: addTrap
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Trap
]], trapsContent)

addTrapBtn.addTrap.onClick = function(w)
  local newIndex = #storage.esp_trap_list + 1
  local newUid = trapIdCounter
  trapIdCounter = trapIdCounter + 1
  table.insert(storage.esp_trap_list, {
    text = "trap " .. newIndex,
    cooldown = 5,
    trapTime = 3,
    hpPercent = 100,
    await = false,
    uid = newUid
  })
  refreshTraps()
end

-- Load existing traps on start
refreshTraps()

-- Macro de traps: usa baseado em ordem, cooldown, % vida, await
EspTrapMacro = macro(200, "Traps", function()
  if not g_game.isAttacking() then return end

  local target = g_game.getAttackingCreature()
  if not target then return end

  local targetHpPercent = target:getHealthPercent()

  for i, trap in ipairs(storage.esp_trap_list) do
    if trap.text and trap.text:len() > 0 then
      local uid = trap.uid
      local cooldownMs = (tonumber(trap.cooldown) or 5) * 1000
      local trapTimeMs = (tonumber(trap.trapTime) or 3) * 1000
      local hpThreshold = tonumber(trap.hpPercent) or 100
      local cdEnd = trapCooldownEnd[uid] or 0
      local activeEnd = trapActiveEnd[uid] or 0

      -- Verifica se o await esta ativo: se sim, checa se a trap anterior ainda esta ativa ou em cd
      if trap.await and i > 1 then
        local prevTrap = storage.esp_trap_list[i - 1]
        if prevTrap and prevTrap.uid then
          local prevActiveEnd = trapActiveEnd[prevTrap.uid] or 0
          local prevCdEnd = trapCooldownEnd[prevTrap.uid] or 0
          -- So continua se a trap anterior terminou o tempo trapado E esta em cooldown
          if now < prevActiveEnd then
            -- Trap anterior ainda esta ativa, espera
            break
          end
          if now < prevCdEnd then
            -- Trap anterior em CD, pode usar esta se elegivel
          end
        end
      end

      -- Checa % vida do oponente
      if targetHpPercent <= hpThreshold then
        -- Checa se nao esta em cooldown e nao esta ativa
        if now >= cdEnd and now >= activeEnd then
          say(trap.text)
          trapActiveEnd[uid] = now + trapTimeMs
          trapCooldownEnd[uid] = now + trapTimeMs + cooldownMs
          break  -- Usa uma trap por ciclo
        end
      end
    end
  end
end, trapsContent)


-- =============================================
-- TAB: COMBOS (dinamico - adicionar/remover)
-- =============================================
EspTabBar:addTab("Combos", espPanel3)
local combosContent = espPanel3.scrollArea
        UI.Separator(combosContent)
        color= UI.Label("Combo de Ataque:",combosContent)
color:setColor("red")
        UI.Separator(combosContent)

-- Storage: lista de combos
if type(storage.esp_combo_list) ~= "table" then
  -- Migrar do formato antigo se existir
  if storage.esp_combo then
    storage.esp_combo_list = {}
    for k = 1, 6 do
      local key = "text" .. k
      if storage.esp_combo[key] and storage.esp_combo[key]:len() > 0 then
        table.insert(storage.esp_combo_list, { text = storage.esp_combo[key] })
      end
    end
  else
    storage.esp_combo_list = {}
  end
end

local comboWidgets = {}

-- Funcao para criar widget de um combo
local function createComboWidget(index, comboData)
  local entry = setupUI([[
Panel
  height: 54
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #FFD700
    font: verdana-11px-rounded
    text: Combo

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

  TextEdit
    id: spellEdit
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 22
    margin-top: 3

  ]], combosContent)

  entry.title:setText("Combo #" .. index)
  entry.spellEdit:setText(comboData.text or "")

  -- Estilo: fundo transparente e texto neon azul
  entry.spellEdit:setBackgroundColor("#00000033")
  entry.spellEdit:setColor("#00DDFF")

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_combo_list[index].text = text
  end

  entry.removeBtn.onClick = function(w)
    table.remove(storage.esp_combo_list, index)
    refreshCombos()
  end

  table.insert(comboWidgets, entry)
  return entry
end

-- Refresh all combo widgets
function refreshCombos()
  for _, w in ipairs(comboWidgets) do
    w:destroy()
  end
  comboWidgets = {}
  for i, comboData in ipairs(storage.esp_combo_list) do
    createComboWidget(i, comboData)
  end
end

-- Botao adicionar combo
local addComboBtn = setupUI([[
Panel
  height: 25
  Button
    id: addCombo
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Combo
]], combosContent)

addComboBtn.addCombo.onClick = function(w)
  local newIndex = #storage.esp_combo_list + 1
  table.insert(storage.esp_combo_list, {
    text = "magia " .. newIndex
  })
  refreshCombos()
end

-- Load existing combos on start
refreshCombos()

-- Macro de combo
EspComboMacro = macro(200, "Combo Especial", function()
  if g_game.isAttacking() then
    for _, combo in ipairs(storage.esp_combo_list) do
      if combo.text and combo.text:len() > 0 then
        say(combo.text)
      end
    end
  end
end, combosContent)


-- =============================================
-- TAB: BUFFS (dinamico - adicionar/remover)
-- =============================================
EspTabBar:addTab("Buffs", espPanel4)
local buffsContent = espPanel4.scrollArea
        UI.Separator(buffsContent)
        color= UI.Label("Buffs (tempo em segundos):",buffsContent)
color:setColor("#00CCFF")
        UI.Separator(buffsContent)

-- Storage: lista de buffs
if type(storage.esp_buffs_list) ~= "table" then
  storage.esp_buffs_list = {}
end

-- Atribui IDs unicos para cada buff existente
local buffIdCounter = 0
for _, b in ipairs(storage.esp_buffs_list) do
  if b.uid and b.uid >= buffIdCounter then
    buffIdCounter = b.uid + 1
  end
end
for _, b in ipairs(storage.esp_buffs_list) do
  if not b.uid then
    b.uid = buffIdCounter
    buffIdCounter = buffIdCounter + 1
  end
end

local buffCooldownEnd = {}   -- [uid] = timestamp quando CD termina
local buffActiveEnd = {}     -- [uid] = timestamp quando ativo termina
local buffWidgets = {}

-- Funcao para criar widget de um buff
local function createBuffWidget(index, buffData)
  local uid = buffData.uid
  local entry = setupUI([[
Panel
  height: 132
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #00CCFF
    font: verdana-11px-rounded
    text: Buff

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

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
    height: 22
    margin-top: 1

  Panel
    id: row1
    anchors.top: spellEdit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 3
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Tempo Ativo(s):
      color: white
      text-auto-resize: true
    TextEdit
      id: activeEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row2
    anchors.top: row1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
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

  ]], buffsContent)

  entry.title:setText("Buff #" .. index)
  entry.spellEdit:setText(buffData.text or "")
  entry.row1.activeEdit:setText(tostring(buffData.activeTime or 10))
  entry.row2.cdEdit:setText(tostring(buffData.cooldown or 30))

  -- Estilo: fundo transparente e texto neon azul nos inputs
  local buffInputs = {entry.spellEdit, entry.row1.activeEdit, entry.row2.cdEdit}
  for _, input in ipairs(buffInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_buffs_list[index].text = text
  end
  entry.row1.activeEdit.onTextChange = function(w, text)
    storage.esp_buffs_list[index].activeTime = tonumber(text) or 10
  end
  entry.row2.cdEdit.onTextChange = function(w, text)
    storage.esp_buffs_list[index].cooldown = tonumber(text) or 30
  end

  entry.removeBtn.onClick = function(w)
    buffCooldownEnd[uid] = nil
    buffActiveEnd[uid] = nil
    table.remove(storage.esp_buffs_list, index)
    refreshBuffs()
  end

  table.insert(buffWidgets, entry)
  return entry
end

-- Refresh all buff widgets
function refreshBuffs()
  for _, w in ipairs(buffWidgets) do
    w:destroy()
  end
  buffWidgets = {}
  for i, buffData in ipairs(storage.esp_buffs_list) do
    createBuffWidget(i, buffData)
  end
end

-- Botao adicionar buff
local addBuffBtn = setupUI([[
Panel
  height: 25
  Button
    id: addBuff
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Buff
]], buffsContent)

addBuffBtn.addBuff.onClick = function(w)
  local newIndex = #storage.esp_buffs_list + 1
  local newUid = buffIdCounter
  buffIdCounter = buffIdCounter + 1
  table.insert(storage.esp_buffs_list, {
    text = "buff " .. newIndex,
    activeTime = 10,
    cooldown = 30,
    uid = newUid
  })
  refreshBuffs()
end

-- Load existing buffs on start
refreshBuffs()

-- Macro de buffs: auto-usa quando tempo ativo acabar e nao estiver em CD
EspBuffMacro = macro(200, "Buffs Auto", function()
  if isInPz() then return end
  -- Nao usa buffs durante fuga ativa
  if fugaActive then return end

  for _, b in ipairs(storage.esp_buffs_list) do
    if b.text and b.text:len() > 0 then
      local uid = b.uid
      local activeTimeMs = (tonumber(b.activeTime) or 10) * 1000
      local cooldownMs = (tonumber(b.cooldown) or 30) * 1000
      local activeEnd = buffActiveEnd[uid] or 0
      local cdEnd = buffCooldownEnd[uid] or 0

      -- Se o buff nao esta ativo e nao esta em CD, usa
      if now >= activeEnd and now >= cdEnd then
        say(b.text)
        buffActiveEnd[uid] = now + activeTimeMs
        buffCooldownEnd[uid] = now + activeTimeMs + cooldownMs
      end
    end
  end
end, buffsContent)


-- =============================================
-- TAB: ATAQUE % (dinamico - adicionar/remover)
-- =============================================
EspTabBar:addTab("Ataque %", espPanel5)
local ataqueContent = espPanel5.scrollArea
        UI.Separator(ataqueContent)
        color= UI.Label("Ataques por HP% do Inimigo:",ataqueContent)
color:setColor("#FF6600")
        UI.Separator(ataqueContent)

-- Storage: lista de ataques
if type(storage.esp_ataque_list) ~= "table" then
  storage.esp_ataque_list = {}
end

-- Atribui IDs unicos para cada ataque existente
local ataqueIdCounter = 0
for _, a in ipairs(storage.esp_ataque_list) do
  if a.uid and a.uid >= ataqueIdCounter then
    ataqueIdCounter = a.uid + 1
  end
end
for _, a in ipairs(storage.esp_ataque_list) do
  if not a.uid then
    a.uid = ataqueIdCounter
    ataqueIdCounter = ataqueIdCounter + 1
  end
end

local ataqueCooldownEnd = {}  -- [uid] = timestamp quando CD termina
local ataqueWidgets = {}

-- Widget de cooldowns na tela
storage.espAtkWidgetPos = storage.espAtkWidgetPos or {x = 10, y = 300}

local espAtkWidget = setupUI([[
UIWidget
  background-color: black
  font: verdana-11px-rounded
  opacity: 0.70
  padding: 5 10
  focusable: true
  phantom: false
  draggable: true
  text-auto-resize: true
]], g_ui.getRootWidget())

espAtkWidget:setPosition({x = storage.espAtkWidgetPos.x, y = storage.espAtkWidgetPos.y})

espAtkWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = {
        x = mousePos.x - widget:getX(),
        y = mousePos.y - widget:getY()
    }
    return true
end

espAtkWidget.onDragMove = function(widget, mousePos)
    widget:move(
        mousePos.x - widget.movingReference.x,
        mousePos.y - widget.movingReference.y
    )
    return true
end

espAtkWidget.onDragLeave = function(widget, pos)
    storage.espAtkWidgetPos.x = widget:getX()
    storage.espAtkWidgetPos.y = widget:getY()
    return true
end

-- Macro para atualizar widget de cooldowns na tela
macro(100, function()
    local text = ""
    for _, atk in ipairs(storage.esp_ataque_list) do
        if atk.spell and atk.spell ~= "" then
            local uid = atk.uid
            local cdTime = ataqueCooldownEnd[uid] or 0
            local remaining = math.max(0, math.ceil((cdTime - now) / 1000))
            local name = atk.name and atk.name ~= "" and atk.name or atk.spell
            text = text .. name .. ": " .. remaining .. "s\n"
        end
    end
    if text ~= "" then
        espAtkWidget:setText(text:sub(1, -2))
        espAtkWidget:show()
    else
        espAtkWidget:hide()
    end
end)

-- Macro principal de ataque por HP%
EspAtaqueMacro = macro(100, "Ataque HP% Esp", function()
    if not g_game.isAttacking() then return end
    if isInPz() then return end
    -- Nao ataca durante fuga ativa
    if fugaActive then return end

    local target = g_game.getAttackingCreature()
    if not target or not target:isPlayer() then return end

    local targetHp = target:getHealthPercent()

    for _, atk in ipairs(storage.esp_ataque_list) do
        if atk.spell and atk.spell ~= "" and targetHp <= (atk.hp or 100) then
            local uid = atk.uid
            if now >= (ataqueCooldownEnd[uid] or 0) then
                say(atk.spell)
                ataqueCooldownEnd[uid] = now + ((atk.cd or 2) * 1000)
                return
            end
        end
    end
end, ataqueContent)

-- Funcao para criar widget de um ataque
local function createAtaqueWidget(index, ataqueData)
  local uid = ataqueData.uid
  local entry = setupUI([[
Panel
  height: 175
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #FF6600
    font: verdana-11px-rounded
    text: Ataque

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

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
    height: 22
    margin-top: 1

  Panel
    id: row1
    anchors.top: spellEdit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 3
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Nome (tela):
      color: #AADDFF
      text-auto-resize: true
    TextEdit
      id: nameEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 100

  Panel
    id: row2
    anchors.top: row1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
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
    id: row3
    anchors.top: row2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
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

  ]], ataqueContent)

  entry.title:setText("Ataque #" .. index)
  entry.spellEdit:setText(ataqueData.spell or "")
  entry.row1.nameEdit:setText(ataqueData.name or "")
  entry.row2.hpEdit:setText(tostring(ataqueData.hp or 90))
  entry.row3.cdEdit:setText(tostring(ataqueData.cd or 2))

  -- Tooltips
  entry.spellEdit:setTooltip("Nome da spell de ataque (ex: jutsu choku)")
  entry.row1.nameEdit:setTooltip("Nome exibido no widget da tela (opcional, usa spell se vazio)")
  entry.row2.hpEdit:setTooltip("HP% do inimigo para ativar (ex: 90 = ataca quando HP <= 90%)")
  entry.row3.cdEdit:setTooltip("Cooldown em segundos entre usos")

  -- Estilo: fundo transparente e texto neon
  local atkInputs = {entry.spellEdit, entry.row1.nameEdit, entry.row2.hpEdit, entry.row3.cdEdit}
  for _, input in ipairs(atkInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_ataque_list[index].spell = text
  end
  entry.row1.nameEdit.onTextChange = function(w, text)
    storage.esp_ataque_list[index].name = text
  end
  entry.row2.hpEdit.onTextChange = function(w, text)
    storage.esp_ataque_list[index].hp = tonumber(text) or 90
  end
  entry.row3.cdEdit.onTextChange = function(w, text)
    storage.esp_ataque_list[index].cd = tonumber(text) or 2
  end

  entry.removeBtn.onClick = function(w)
    ataqueCooldownEnd[uid] = nil
    table.remove(storage.esp_ataque_list, index)
    refreshAtaques()
  end

  table.insert(ataqueWidgets, entry)
  return entry
end

-- Refresh all ataque widgets
function refreshAtaques()
  for _, w in ipairs(ataqueWidgets) do
    w:destroy()
  end
  ataqueWidgets = {}
  for i, ataqueData in ipairs(storage.esp_ataque_list) do
    createAtaqueWidget(i, ataqueData)
  end
end

-- Botao adicionar ataque
local addAtaqueBtn = setupUI([[
Panel
  height: 25
  Button
    id: addAtaque
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Ataque
]], ataqueContent)

addAtaqueBtn.addAtaque.onClick = function(w)
  local newIndex = #storage.esp_ataque_list + 1
  local newUid = ataqueIdCounter
  ataqueIdCounter = ataqueIdCounter + 1
  table.insert(storage.esp_ataque_list, {
    spell = "ataque " .. newIndex,
    name = "",
    hp = 90,
    cd = 2,
    uid = newUid
  })
  refreshAtaques()
end

-- Load existing ataques on start
refreshAtaques()


-- =============================================
-- TAB: STACK (dinamico - adicionar/remover)
-- =============================================
EspTabBar:addTab("Stack", espPanel6)
local stackContent = espPanel6.scrollArea
        UI.Separator(stackContent)
        color= UI.Label("Stack (ataque direcional rapido):",stackContent)
color:setColor("#FF00FF")
        UI.Separator(stackContent)

-- Storage: lista de stacks
if type(storage.esp_stack_list) ~= "table" then
  storage.esp_stack_list = {}
end

-- Atribui IDs unicos para cada stack existente
local stackIdCounter = 0
for _, s in ipairs(storage.esp_stack_list) do
  if s.uid and s.uid >= stackIdCounter then
    stackIdCounter = s.uid + 1
  end
end
for _, s in ipairs(storage.esp_stack_list) do
  if not s.uid then
    s.uid = stackIdCounter
    stackIdCounter = stackIdCounter + 1
  end
end

local stackCooldownEnd = {}  -- [uid] = timestamp quando CD termina
local stackWidgets = {}

-- Constantes de direcao
local DIR_NORTH = 0
local DIR_EAST = 1
local DIR_SOUTH = 2
local DIR_WEST = 3

local WASD_KEYS = {"W", "A", "S", "D", "E", "Z", "Q", "C"}
local ARROW_KEYS = {"Up", "Down", "Left", "Right"}

-- Mapeamento de direcoes para Stack
local stackDirections = {
    ["W"] = function(fromPos, toPos, further)
        if (fromPos.y < toPos.y) then
            local distance = math.abs(fromPos.y - toPos.y)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    ["D"] = function(fromPos, toPos, further)
        if (fromPos.x > toPos.x) then
            local distance = math.abs(fromPos.x - toPos.x)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    ["S"] = function(fromPos, toPos, further)
        if (fromPos.y > toPos.y) then
            local distance = math.abs(fromPos.y - toPos.y)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    ["A"] = function(fromPos, toPos, further)
        if (fromPos.x < toPos.x) then
            local distance = math.abs(fromPos.x - toPos.x)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    ["C"] = function(fromPos, toPos, further)
        if (fromPos.x > toPos.x and fromPos.y > toPos.y) then
            local distance = math.sqrt(math.abs(fromPos.x - toPos.x)^2 + math.abs(fromPos.y - toPos.y)^2)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    ["Z"] = function(fromPos, toPos, further)
        if (fromPos.x < toPos.x and fromPos.y > toPos.y) then
            local distance = math.sqrt(math.abs(fromPos.x - toPos.x)^2 + math.abs(fromPos.y - toPos.y)^2)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    ["Q"] = function(fromPos, toPos, further)
        if (fromPos.x < toPos.x and fromPos.y < toPos.y) then
            local distance = math.sqrt(math.abs(fromPos.x - toPos.x)^2 + math.abs(fromPos.y - toPos.y)^2)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    ["E"] = function(fromPos, toPos, further)
        if (fromPos.x > toPos.x and fromPos.y < toPos.y) then
            local distance = math.sqrt(math.abs(fromPos.x - toPos.x)^2 + math.abs(fromPos.y - toPos.y)^2)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end
}

-- Mapear Arrow Keys para as mesmas funcoes do WASD
stackDirections["Up"] = stackDirections["W"]
stackDirections["Down"] = stackDirections["S"]
stackDirections["Left"] = stackDirections["A"]
stackDirections["Right"] = stackDirections["D"]

-- Funcao para obter spectators
local function getStackSpectators()
    local specs = getSpectators()
    if (#specs == 0) then
        local tiles = g_map.getTiles(posz())
        for _, tile in ipairs(tiles) do
            for _, spec in ipairs(tile:getCreatures()) do
                table.insert(specs, spec)
            end
        end
    end
    return specs
end

-- Funcao para buscar monstro na direcao (mais distante dentro do alcance)
local function getStackingMonster(dir, maxDistance)
    local isInCorrectDirection = stackDirections[dir]
    if not isInCorrectDirection then return end
    local stack
    local specs = getStackSpectators()
    local playerPos = pos()
    for _, spec in ipairs(specs) do
        local specPos = spec:getPosition()
        if specPos then
            local status, distance = isInCorrectDirection(specPos, playerPos, stack)
            if status and spec:isMonster() then
                if getDistanceBetween(specPos, playerPos) <= maxDistance then
                    if spec:canShoot() then
                        stack = {spec = spec, distance = distance}
                    end
                end
            end
        end
    end
    return stack and stack.spec
end

-- Widget de cooldowns na tela para Stack
storage.espStackWidgetPos = storage.espStackWidgetPos or {x = 10, y = 350}

local espStackWidget = setupUI([[
UIWidget
  background-color: black
  font: verdana-11px-rounded
  opacity: 0.70
  padding: 5 10
  focusable: true
  phantom: false
  draggable: true
  text-auto-resize: true
]], g_ui.getRootWidget())

espStackWidget:setPosition({x = storage.espStackWidgetPos.x, y = storage.espStackWidgetPos.y})

espStackWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = {
        x = mousePos.x - widget:getX(),
        y = mousePos.y - widget:getY()
    }
    return true
end

espStackWidget.onDragMove = function(widget, mousePos)
    widget:move(
        mousePos.x - widget.movingReference.x,
        mousePos.y - widget.movingReference.y
    )
    return true
end

espStackWidget.onDragLeave = function(widget, pos)
    storage.espStackWidgetPos.x = widget:getX()
    storage.espStackWidgetPos.y = widget:getY()
    return true
end

-- Macro para atualizar widget de cooldowns Stack na tela
macro(100, function()
    local text = ""
    for _, stk in ipairs(storage.esp_stack_list) do
        if stk.spell and stk.spell ~= "" then
            local uid = stk.uid
            local cdTime = stackCooldownEnd[uid] or 0
            local remaining = math.max(0, math.ceil((cdTime - now) / 1000))
            local name = stk.name and stk.name ~= "" and stk.name or stk.spell
            text = text .. name .. ": " .. remaining .. "s\n"
        end
    end
    if text ~= "" then
        espStackWidget:setText(text:sub(1, -2))
        espStackWidget:show()
    else
        espStackWidget:hide()
    end
end)

-- Macro principal de Stack
EspStackMacro = macro(50, "Stack Esp", function()
    if isInPz() then return end
    if fugaActive then return end

    for _, stk in ipairs(storage.esp_stack_list) do
        if stk.spell and stk.spell ~= "" then
            local uid = stk.uid
            if now >= (stackCooldownEnd[uid] or 0) then
                local selectedKeys = stk.key == "WASD" and WASD_KEYS or ARROW_KEYS
                local isMousePressed = g_mouse.isPressed(3)
                for _, dir in ipairs(selectedKeys) do
                    if isMousePressed and modules.corelib.g_keyboard.isKeyPressed(dir) then
                        local creature = getStackingMonster(dir, stk.distance or 5)
                        if creature then
                            say(stk.spell)
                            g_game.attack(creature)
                            schedule(50, function() g_game.attack(nil) end)
                            schedule(200, function()
                                g_game.cancelAttack()
                            end)
                            stackCooldownEnd[uid] = now + ((stk.cd or 2) * 1000)
                            return
                        end
                    end
                end
            end
        end
    end
end, stackContent)

-- Funcao para criar widget de um Stack
local function createStackWidget(index, stackData)
  local uid = stackData.uid
  local entry = setupUI([[
Panel
  height: 210
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #FF00FF
    font: verdana-11px-rounded
    text: Stack

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

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
    height: 22
    margin-top: 1

  Panel
    id: row1
    anchors.top: spellEdit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 3
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Nome (tela):
      color: #AADDFF
      text-auto-resize: true
    TextEdit
      id: nameEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 100

  Panel
    id: row2
    anchors.top: row1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Teclas:
      color: white
      text-auto-resize: true
    ComboBox
      id: keyCombo
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 100

  Panel
    id: row3
    anchors.top: row2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Distancia:
      color: white
      text-auto-resize: true
    TextEdit
      id: distEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row4
    anchors.top: row3.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
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

  ]], stackContent)

  entry.title:setText("Stack #" .. index)
  entry.spellEdit:setText(stackData.spell or "")
  entry.row1.nameEdit:setText(stackData.name or "")
  entry.row3.distEdit:setText(tostring(stackData.distance or 5))
  entry.row4.cdEdit:setText(tostring(stackData.cd or 2))

  -- ComboBox de teclas
  entry.row2.keyCombo:addOption("WASD")
  entry.row2.keyCombo:addOption("Arrows")
  entry.row2.keyCombo:setCurrentOption(stackData.key or "WASD")

  -- Tooltips
  entry.spellEdit:setTooltip("Spell de ataque (ex: exori vis)")
  entry.row1.nameEdit:setTooltip("Nome exibido no widget da tela (opcional)")
  entry.row2.keyCombo:setTooltip("WASD + EQZC (diagonais) ou Arrow Keys")
  entry.row3.distEdit:setTooltip("Distancia maxima para atacar (1-10)")
  entry.row4.cdEdit:setTooltip("Cooldown em segundos entre usos")

  -- Estilo neon
  local stkInputs = {entry.spellEdit, entry.row1.nameEdit, entry.row3.distEdit, entry.row4.cdEdit}
  for _, input in ipairs(stkInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_stack_list[index].spell = text
  end
  entry.row1.nameEdit.onTextChange = function(w, text)
    storage.esp_stack_list[index].name = text
  end
  entry.row2.keyCombo.onOptionChange = function(w, text)
    storage.esp_stack_list[index].key = text
  end
  entry.row3.distEdit.onTextChange = function(w, text)
    storage.esp_stack_list[index].distance = tonumber(text) or 5
  end
  entry.row4.cdEdit.onTextChange = function(w, text)
    storage.esp_stack_list[index].cd = tonumber(text) or 2
  end

  entry.removeBtn.onClick = function(w)
    stackCooldownEnd[uid] = nil
    table.remove(storage.esp_stack_list, index)
    refreshStacks()
  end

  table.insert(stackWidgets, entry)
  return entry
end

-- Refresh all stack widgets
function refreshStacks()
  for _, w in ipairs(stackWidgets) do
    w:destroy()
  end
  stackWidgets = {}
  for i, stackData in ipairs(storage.esp_stack_list) do
    createStackWidget(i, stackData)
  end
end

-- Botao adicionar stack
local addStackBtn = setupUI([[
Panel
  height: 25
  Button
    id: addStack
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Stack
]], stackContent)

addStackBtn.addStack.onClick = function(w)
  local newIndex = #storage.esp_stack_list + 1
  local newUid = stackIdCounter
  stackIdCounter = stackIdCounter + 1
  table.insert(storage.esp_stack_list, {
    spell = "stack " .. newIndex,
    name = "",
    key = "WASD",
    distance = 5,
    cd = 2,
    uid = newUid
  })
  refreshStacks()
end

-- Load existing stacks on start
refreshStacks()


-- =============================================
-- TAB: RETAS (dinamico - adicionar/remover)
-- =============================================
EspTabBar:addTab("Retas", espPanel7)
local retasContent = espPanel7.scrollArea
        UI.Separator(retasContent)
        color= UI.Label("Retas (alinhar e atacar em reta):",retasContent)
color:setColor("#00FF88")
        UI.Separator(retasContent)

-- Storage: lista de retas
if type(storage.esp_retas_list) ~= "table" then
  storage.esp_retas_list = {}
end

-- Atribui IDs unicos para cada reta existente
local retasIdCounter = 0
for _, r in ipairs(storage.esp_retas_list) do
  if r.uid and r.uid >= retasIdCounter then
    retasIdCounter = r.uid + 1
  end
end
for _, r in ipairs(storage.esp_retas_list) do
  if not r.uid then
    r.uid = retasIdCounter
    retasIdCounter = retasIdCounter + 1
  end
end

local retasCooldownEnd = {}  -- [uid] = timestamp quando CD termina
local retasDelayEnd = 0      -- delay global para autowalk
local retasWidgets = {}

-- Funcoes auxiliares para Retas
local function correctDirection()
    local dir = player:getDirection()
    return dir <= 3 and dir or dir < 6 and 1 or 3
end

local function getLowestBetween(p1, p2)
    local distx = math.abs(p1.x - p2.x)
    local disty = math.abs(p1.y - p2.y)
    return math.min(distx, disty)
end

local function preciseDistance(p1, p2)
    local distx = math.abs(p1.x - p2.x)
    local disty = math.abs(p1.y - p2.y)
    return math.sqrt(distx * distx + disty * disty)
end

local retasDirections = {
    {x = 0, y = -1},  -- Norte
    {x = 1, y = 0},   -- Leste
    {x = 0, y = 1},   -- Sul
    {x = -1, y = 0}   -- Oeste
}

-- Funcao para obter a criatura sendo atacada no battlePanel
local ATTACKING_COLORS = {"#FF0000", "#ff0000", "red"}
local function getAttackingCreature()
    local battlePanel = g_ui.getRootWidget():recursiveGetChildById('battlePanel')
    if not battlePanel then return g_game.getAttackingCreature() end
    local playerPos = pos()
    for _, child in ipairs(battlePanel:getChildren()) do
        local creature = child.creature
        if creature then
            local creaturePos = creature:getPosition()
            if creaturePos and creaturePos.z == playerPos.z then
                if child.color and table.find(ATTACKING_COLORS, child.color) then
                    return creature
                end
            end
        end
    end
    return g_game.getAttackingCreature()
end

-- Funcao para calcular posicao de uso (tile adjacente)
local function getUsePosition(targetPos)
    local playerPos = player:getPosition()
    local tPos = {x = targetPos.x, y = targetPos.y, z = targetPos.z}
    local distance = {
        x = math.abs(playerPos.x - tPos.x),
        y = math.abs(playerPos.y - tPos.y)
    }
    if distance.y >= distance.x then
        if tPos.y > playerPos.y or
           (tPos.y < playerPos.y and tPos.x < playerPos.x) or
           (tPos.y < playerPos.y and tPos.x > playerPos.x) then
            tPos.x = tPos.x + 1
        elseif tPos.x > playerPos.x or
               (tPos.x < playerPos.x and tPos.y > playerPos.y) or
               (tPos.x > playerPos.y and tPos.x < playerPos.x) then
            tPos.x = tPos.x - 1
        end
    else
        if tPos.x < playerPos.x or
           tPos.y > playerPos.y or
           (tPos.x > playerPos.x and tPos.y > playerPos.y) then
            tPos.y = tPos.y + 1
        elseif tPos.y < playerPos.y or
               (tPos.y > playerPos.y and tPos.x > playerPos.x) or
               (tPos.x < playerPos.x and tPos.y < playerPos.y) then
            tPos.y = tPos.y - 1
        end
    end
    return tPos
end

-- Funcao canUseReta - verifica se pode usar reta no alvo
local function canUseReta(creature)
    local creaturePos = creature:getPosition()
    if not creaturePos then return end

    local playerPos = pos()
    local distance = getDistanceBetween(playerPos, creaturePos)
    local lowest = getLowestBetween(playerPos, creaturePos)

    -- Cenario 1: Em linha reta, dist 1-4
    if distance > 0 and distance <= 4 and lowest == 0 then
        local direction = correctDirection()
        if playerPos.x > creaturePos.x then
            turn(DIR_WEST)
            return direction == DIR_WEST
        elseif playerPos.x < creaturePos.x then
            turn(DIR_EAST)
            return direction == DIR_EAST
        elseif playerPos.y > creaturePos.y then
            turn(DIR_NORTH)
            return direction == DIR_NORTH
        elseif playerPos.y < creaturePos.y then
            turn(DIR_SOUTH)
            return direction == DIR_SOUTH
        end

    -- Cenario 2: Muito perto mas nao em linha reta (diagonal)
    elseif distance <= 1 then
        if lowest ~= 0 or distance == 0 then
            local closestPos
            for _, dir in ipairs(retasDirections) do
                local adjPos = {
                    x = creaturePos.x + dir.x,
                    y = creaturePos.y + dir.y,
                    z = creaturePos.z
                }
                if not closestPos or
                   preciseDistance(adjPos, playerPos) < preciseDistance(closestPos, playerPos) then
                    local tile = g_map.getTile(adjPos)
                    if tile and tile:isWalkable() and tile:isPathable() then
                        closestPos = adjPos
                    end
                end
            end
            if closestPos then
                player:autoWalk(closestPos)
                retasDelayEnd = now + 300
                return
            end
        end

    -- Cenario 3: Longe demais, usa tile adjacente
    else
        local usePos = getUsePosition(creaturePos)
        if not usePos then return end
        local tile = g_map.getTile(usePos)
        if not tile then return end
        g_game.use(tile:getTopThing())
    end
end

-- Widget de cooldowns na tela para Retas
storage.espRetasWidgetPos = storage.espRetasWidgetPos or {x = 10, y = 400}

local espRetasWidget = setupUI([[
UIWidget
  background-color: black
  font: verdana-11px-rounded
  opacity: 0.70
  padding: 5 10
  focusable: true
  phantom: false
  draggable: true
  text-auto-resize: true
]], g_ui.getRootWidget())

espRetasWidget:setPosition({x = storage.espRetasWidgetPos.x, y = storage.espRetasWidgetPos.y})

espRetasWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = {
        x = mousePos.x - widget:getX(),
        y = mousePos.y - widget:getY()
    }
    return true
end

espRetasWidget.onDragMove = function(widget, mousePos)
    widget:move(
        mousePos.x - widget.movingReference.x,
        mousePos.y - widget.movingReference.y
    )
    return true
end

espRetasWidget.onDragLeave = function(widget, pos)
    storage.espRetasWidgetPos.x = widget:getX()
    storage.espRetasWidgetPos.y = widget:getY()
    return true
end

-- Macro para atualizar widget de cooldowns Retas na tela
macro(100, function()
    local text = ""
    for _, ret in ipairs(storage.esp_retas_list) do
        if ret.spell and ret.spell ~= "" then
            local uid = ret.uid
            local cdTime = retasCooldownEnd[uid] or 0
            local remaining = math.max(0, math.ceil((cdTime - now) / 1000))
            local name = ret.name and ret.name ~= "" and ret.name or ret.spell
            text = text .. name .. ": " .. remaining .. "s\n"
        end
    end
    if text ~= "" then
        espRetasWidget:setText(text:sub(1, -2))
        espRetasWidget:show()
    else
        espRetasWidget:hide()
    end
end)

-- Macro principal de Retas
EspRetasMacro = macro(100, "Retas Esp", function()
    if isInPz() then return end
    if fugaActive then return end
    if retasDelayEnd >= now then return end

    local target = getAttackingCreature()
    if not target then return end

    for _, ret in ipairs(storage.esp_retas_list) do
        if ret.spell and ret.spell ~= "" then
            local uid = ret.uid
            if now >= (retasCooldownEnd[uid] or 0) then
                local shouldActivate = false
                if ret.key == "AUTO" then
                    shouldActivate = true
                else
                    shouldActivate = modules.corelib.g_keyboard.isKeyPressed(ret.key)
                end
                if shouldActivate then
                    if canUseReta(target) then
                        say(ret.spell)
                        retasCooldownEnd[uid] = now + ((ret.cd or 2) * 1000)
                        return
                    end
                end
            end
        end
    end
end, retasContent)

-- Funcao para criar widget de uma Reta
local function createRetaWidget(index, retaData)
  local uid = retaData.uid
  local entry = setupUI([[
Panel
  height: 210
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #00FF88
    font: verdana-11px-rounded
    text: Reta

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

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
    height: 22
    margin-top: 1

  Panel
    id: row1
    anchors.top: spellEdit.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 3
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Nome (tela):
      color: #AADDFF
      text-auto-resize: true
    TextEdit
      id: nameEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 100

  Panel
    id: row2
    anchors.top: row1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Tecla:
      color: white
      text-auto-resize: true
    ComboBox
      id: keyCombo
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 100

  Panel
    id: row3
    anchors.top: row2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 2
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Distancia:
      color: white
      text-auto-resize: true
    TextEdit
      id: distEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  Panel
    id: row4
    anchors.top: row3.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
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

  ]], retasContent)

  entry.title:setText("Reta #" .. index)
  entry.spellEdit:setText(retaData.spell or "")
  entry.row1.nameEdit:setText(retaData.name or "")
  entry.row3.distEdit:setText(tostring(retaData.distance or 4))
  entry.row4.cdEdit:setText(tostring(retaData.cd or 2))

  -- ComboBox de teclas para Reta
  entry.row2.keyCombo:addOption("AUTO")
  entry.row2.keyCombo:addOption("F1")
  entry.row2.keyCombo:addOption("F2")
  entry.row2.keyCombo:addOption("F3")
  entry.row2.keyCombo:addOption("F4")
  entry.row2.keyCombo:addOption("F5")
  entry.row2.keyCombo:addOption("F6")
  entry.row2.keyCombo:addOption("F7")
  entry.row2.keyCombo:addOption("F8")
  entry.row2.keyCombo:addOption("F9")
  entry.row2.keyCombo:addOption("F10")
  entry.row2.keyCombo:addOption("F11")
  entry.row2.keyCombo:addOption("F12")
  entry.row2.keyCombo:setCurrentOption(retaData.key or "AUTO")

  -- Tooltips
  entry.spellEdit:setTooltip("Spell de ataque em reta (ex: exori gran)")
  entry.row1.nameEdit:setTooltip("Nome exibido no widget da tela (opcional)")
  entry.row2.keyCombo:setTooltip("AUTO = sempre ativo, ou tecla para ativar")
  entry.row3.distEdit:setTooltip("Distancia maxima para reta (1-10)")
  entry.row4.cdEdit:setTooltip("Cooldown em segundos entre usos")

  -- Estilo neon
  local retInputs = {entry.spellEdit, entry.row1.nameEdit, entry.row3.distEdit, entry.row4.cdEdit}
  for _, input in ipairs(retInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_retas_list[index].spell = text
  end
  entry.row1.nameEdit.onTextChange = function(w, text)
    storage.esp_retas_list[index].name = text
  end
  entry.row2.keyCombo.onOptionChange = function(w, text)
    storage.esp_retas_list[index].key = text
  end
  entry.row3.distEdit.onTextChange = function(w, text)
    storage.esp_retas_list[index].distance = tonumber(text) or 4
  end
  entry.row4.cdEdit.onTextChange = function(w, text)
    storage.esp_retas_list[index].cd = tonumber(text) or 2
  end

  entry.removeBtn.onClick = function(w)
    retasCooldownEnd[uid] = nil
    table.remove(storage.esp_retas_list, index)
    refreshRetas()
  end

  table.insert(retasWidgets, entry)
  return entry
end

-- Refresh all retas widgets
function refreshRetas()
  for _, w in ipairs(retasWidgets) do
    w:destroy()
  end
  retasWidgets = {}
  for i, retaData in ipairs(storage.esp_retas_list) do
    createRetaWidget(i, retaData)
  end
end

-- Botao adicionar reta
local addRetaBtn = setupUI([[
Panel
  height: 25
  Button
    id: addReta
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Reta
]], retasContent)

addRetaBtn.addReta.onClick = function(w)
  local newIndex = #storage.esp_retas_list + 1
  local newUid = retasIdCounter
  retasIdCounter = retasIdCounter + 1
  table.insert(storage.esp_retas_list, {
    spell = "reta " .. newIndex,
    name = "",
    key = "AUTO",
    distance = 4,
    cd = 2,
    uid = newUid
  })
  refreshRetas()
end

-- Load existing retas on start
refreshRetas()


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

-- =============================================
-- PERFIS - Sistema de perfis por personagem
-- =============================================
do
  local perfilConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
  local PERFIS_DIR = "/bot/" .. perfilConfigName .. "/vBot_perfis/"

  -- Criar diretorio de perfis se nao existir
  if not g_resources.directoryExists(PERFIS_DIR) then
    g_resources.makeDir(PERFIS_DIR)
  end

  -- Storage para perfis
  if type(storage.perfis_data) ~= "table" then
    storage.perfis_data = {}
  end
  if not storage.perfis_current then
    storage.perfis_current = nil
  end

  -- Funcao para sanitizar nome de arquivo
  local function sanitizeName(name)
    return name:gsub("[^%w_%-]", "_")
  end

  -- Deep copy via json para evitar referencias compartilhadas
  local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local status, encoded = pcall(json.encode, t)
    if status and encoded then
      local ok, decoded = pcall(json.decode, encoded)
      if ok then return decoded end
    end
    return t
  end

  -- Converte chaves string numericas para chaves numericas (fix JSON decode)
  local function fixNumericKeys(t)
    if type(t) ~= "table" then return t end
    local fixed = {}
    for k, v in pairs(t) do
      local numKey = tonumber(k)
      if numKey then
        fixed[numKey] = v
      else
        fixed[k] = v
      end
    end
    return fixed
  end

  -- Funcao para coletar dados do perfil atual
  local function collectProfileData()
    local data = {}
    -- Fugas
    data.esp_fugas_list = deepCopy(storage.esp_fugas_list or {})
    data.esp_fugas_widgets_show = deepCopy(storage.esp_fugas_widgets_show or {})
    data.esp_fugas_widgets_pos = deepCopy(storage.esp_fugas_widgets_pos or {})
    -- Traps
    data.esp_trap_list = deepCopy(storage.esp_trap_list or {})
    -- Combos
    data.esp_combo_list = deepCopy(storage.esp_combo_list or {})
    -- Buffs
    data.esp_buffs_list = deepCopy(storage.esp_buffs_list or {})
    -- Ataques
    data.esp_ataque_list = deepCopy(storage.esp_ataque_list or {})
    -- Stack
    data.esp_stack_list = deepCopy(storage.esp_stack_list or {})
    -- Retas
    data.esp_retas_list = deepCopy(storage.esp_retas_list or {})
    -- Kai
    data.esp_auto_kai = deepCopy(storage.esp_auto_kai or {})
    -- Ingame scripts
    data.ingame_hotkeys = storage.ingame_hotkeys or ""
    -- Background
    data.bgPlayer = deepCopy(storage.bgPlayer or {})
    return data
  end

  -- Funcao para salvar perfil em arquivo
  local function saveProfile(charName)
    if not charName or charName:len() == 0 then return end
    local data = collectProfileData()
    data._originalName = charName  -- salvar nome original dentro do JSON
    local sName = sanitizeName(charName)
    local fileName = PERFIS_DIR .. sName .. ".json"
    local status, result = pcall(function()
      return json.encode(data, 2)
    end)
    if status and result then
      g_resources.writeFileContents(fileName, result)
      storage.perfis_current = charName
      -- Salvar na lista de perfis conhecidos (usar nome sanitizado)
      if not table.find(storage.perfis_data, sName) then
        table.insert(storage.perfis_data, sName)
      end
    end
  end

  -- Funcao para carregar perfil de arquivo
  local function loadProfile(charName)
    if not charName or charName:len() == 0 then return false end
    local sName = sanitizeName(charName)
    local fileName = PERFIS_DIR .. sName .. ".json"
    if not g_resources.fileExists(fileName) then return false end

    local fileContent = g_resources.readFileContents(fileName)
    if not fileContent or fileContent:len() == 0 then
      -- Arquivo vazio/corrompido, remover
      g_resources.deleteFile(fileName)
      return false
    end

    local status, data = pcall(function()
      return json.decode(fileContent)
    end)
    if not status or not data then return false end

    -- Aplicar dados do perfil (deep copy + fix chaves numericas)
    if data.esp_fugas_list then storage.esp_fugas_list = deepCopy(data.esp_fugas_list) end
    if data.esp_fugas_widgets_show then storage.esp_fugas_widgets_show = fixNumericKeys(deepCopy(data.esp_fugas_widgets_show)) end
    if data.esp_fugas_widgets_pos then storage.esp_fugas_widgets_pos = fixNumericKeys(deepCopy(data.esp_fugas_widgets_pos)) end
    if data.esp_trap_list then storage.esp_trap_list = deepCopy(data.esp_trap_list)
    elseif data.esp_trap then
      -- Migrar formato antigo do perfil
      storage.esp_trap_list = {}
      for k = 1, 6 do
        local key = "text" .. k
        if data.esp_trap[key] and data.esp_trap[key]:len() > 0 then
          table.insert(storage.esp_trap_list, {
            text = data.esp_trap[key], cooldown = 5, trapTime = 3, hpPercent = 100, await = false
          })
        end
      end
    end
    if data.esp_combo_list then storage.esp_combo_list = deepCopy(data.esp_combo_list) end
    if data.esp_buffs_list then storage.esp_buffs_list = deepCopy(data.esp_buffs_list) end
    if data.esp_ataque_list then storage.esp_ataque_list = deepCopy(data.esp_ataque_list) end
    if data.esp_stack_list then storage.esp_stack_list = deepCopy(data.esp_stack_list) end
    if data.esp_retas_list then storage.esp_retas_list = deepCopy(data.esp_retas_list) end
    if data.esp_auto_kai then storage.esp_auto_kai = deepCopy(data.esp_auto_kai) end
    if data.ingame_hotkeys ~= nil then storage.ingame_hotkeys = data.ingame_hotkeys end
    if data.bgPlayer then storage.bgPlayer = deepCopy(data.bgPlayer) end

    storage.perfis_current = data._originalName or charName

    -- Aplicar background se salvo
    if storage.bgPlayer and storage.bgPlayer.currentBG then
      schedule(300, function()
        if applyBG then applyBG(storage.bgPlayer.currentBG) end
      end)
    end

    -- Recarregar UI das fugas/combos/buffs/traps/ataques
    schedule(200, function()
      if refreshFugas then refreshFugas() end
      if refreshCombos then refreshCombos() end
      if refreshBuffs then refreshBuffs() end
      if refreshTraps then refreshTraps() end
      if refreshAtaques then refreshAtaques() end
      if refreshStacks then refreshStacks() end
      if refreshRetas then refreshRetas() end
    end)

    return true
  end

  -- Funcao para listar perfis salvos
  local function listProfiles()
    local profiles = {}
    if g_resources.directoryExists(PERFIS_DIR) then
      local files = g_resources.listDirectoryFiles(PERFIS_DIR, false, false)
      for _, file in ipairs(files) do
        if file:find("%.json$") then
          local fullPath = PERFIS_DIR .. file
          local content = g_resources.readFileContents(fullPath)
          if content and content:len() > 2 then
            local name = file:gsub("%.json$", "")
            table.insert(profiles, name)
          else
            -- Arquivo vazio/corrompido, remover
            g_resources.deleteFile(fullPath)
          end
        end
      end
    end
    return profiles
  end

  -- Funcao para deletar perfil
  local function deleteProfile(sName)
    if not sName or sName:len() == 0 then return end
    local fileName = PERFIS_DIR .. sanitizeName(sName) .. ".json"
    if g_resources.fileExists(fileName) then
      g_resources.deleteFile(fileName)
    end
    -- Remover da lista (perfis_data usa nomes sanitizados)
    for i, name in ipairs(storage.perfis_data) do
      if name == sName then
        table.remove(storage.perfis_data, i)
        break
      end
    end
    -- Limpar perfis_current se era o perfil deletado
    if storage.perfis_current and sanitizeName(storage.perfis_current) == sanitizeName(sName) then
      storage.perfis_current = nil
    end
  end

  -- UI do botao Perfis
  local perfisPanelName = "perfisPanel"
  local perfisUI = setupUI([[
Panel
  height: 35

  Button
    id: editPerfis
    color: #00DDFF
    font: verdana-11px-rounded
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 35
    text: - PERFIS -

  ]], parent)
  perfisUI:setId(perfisPanelName)

  -- Janela de perfis
  local PerfisWindow
  rootWidget = g_ui.getRootWidget()
  if rootWidget then
    PerfisWindow = g_ui.loadUIFromString([[
MainWindow
  !text: tr('- Perfis -')
  size: 350 420
  color: #00DDFF
  @onEscape: self:hide()

  Label
    id: currentLabel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text: Perfil atual: Nenhum
    text-align: center
    font: verdana-11px-rounded
    color: #00FF88
    height: 20

  Label
    id: charLabel
    anchors.top: currentLabel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: Personagem: --
    text-align: center
    font: verdana-11px-rounded
    color: #AADDFF
    height: 20
    margin-top: 5

  TextList
    id: profileList
    anchors.top: charLabel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 200
    margin-top: 10
    vertical-scrollbar: profileScrollBar
    focusable: false

  VerticalScrollBar
    id: profileScrollBar
    anchors.top: profileList.top
    anchors.bottom: profileList.bottom
    anchors.right: profileList.right
    step: 14
    pixels-scroll: true

  Panel
    id: controls
    anchors.top: profileList.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 30
    margin-top: 10

    Button
      id: saveBtn
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Salvar
      width: 65
      height: 25
      color: #00FF88

    Button
      id: loadBtn
      anchors.left: saveBtn.right
      anchors.verticalCenter: parent.verticalCenter
      text: Carregar
      width: 65
      height: 25
      margin-left: 5
      color: #FFDD00

    Button
      id: deleteBtn
      anchors.left: loadBtn.right
      anchors.verticalCenter: parent.verticalCenter
      text: Deletar
      width: 65
      height: 25
      margin-left: 5
      color: #FF4444

    Button
      id: refreshBtn
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Refresh
      width: 55
      height: 25

  Label
    id: statusLabel
    anchors.top: controls.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: --
    text-align: center
    font: verdana-11px-rounded
    color: white
    height: 20
    margin-top: 5

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-top: 5
    margin-right: 5
]], rootWidget)
    PerfisWindow:hide()

    local selectedProfile = nil
    local selectedProfileWidget = nil

    local function selectProfileEntry(widget)
      if selectedProfileWidget then
        selectedProfileWidget:setBackgroundColor("alpha")
        selectedProfileWidget:setColor("white")
      end
      selectedProfileWidget = widget
      selectedProfile = widget.profileName
      widget:setBackgroundColor("#ffffff33")
      widget:setColor("#00DDFF")
    end

    local function refreshProfileList()
      PerfisWindow.profileList:destroyChildren()
      selectedProfile = nil
      selectedProfileWidget = nil

      local profiles = listProfiles()
      if #profiles == 0 then
        local label = g_ui.createWidget("Label", PerfisWindow.profileList)
        label:setText("Nenhum perfil salvo")
        label:setColor("gray")
        label:setFont("verdana-11px-rounded")
        return
      end

      for _, name in ipairs(profiles) do
        local label = g_ui.createWidget("Label", PerfisWindow.profileList)
        -- Ler nome original do JSON para exibir nome bonito
        local displayName = name
        local fullPath = PERFIS_DIR .. name .. ".json"
        if g_resources.fileExists(fullPath) then
          local ok, d = pcall(function()
            return json.decode(g_resources.readFileContents(fullPath))
          end)
          if ok and d and d._originalName then
            displayName = d._originalName
          end
        end
        label:setText(displayName)
        label:setFont("verdana-11px-rounded")
        label:setColor("white")
        label:setHeight(18)
        label:setTextOffset({x = 3, y = 0})
        label.profileName = name

        -- Destacar perfil atual
        if storage.perfis_current and sanitizeName(storage.perfis_current) == name then
          label:setColor("#00FF88")
        end

        label.onMouseRelease = function(widget, mousePos, mouseButton)
          if mouseButton == MouseLeftButton then
            selectProfileEntry(widget)
            return true
          end
        end

        label.onDoubleClick = function(widget)
          selectProfileEntry(widget)
          loadProfile(name)
          PerfisWindow.statusLabel:setText("Perfil '" .. name .. "' carregado!")
          PerfisWindow.statusLabel:setColor("#00FF88")
          refreshProfileList()
          return true
        end
      end
    end

    -- Atualizar info do personagem atual
    local function updateCharInfo()
      local charName = player and player:getName() or "--"
      PerfisWindow.charLabel:setText("Personagem: " .. charName)
      if storage.perfis_current then
        PerfisWindow.currentLabel:setText("Perfil atual: " .. storage.perfis_current)
      else
        PerfisWindow.currentLabel:setText("Perfil atual: Nenhum")
      end
    end

    -- Salvar automaticamente ao detectar personagem
    local function autoSaveCurrentProfile()
      if player then
        local charName = player:getName()
        if charName and charName:len() > 0 then
          saveProfile(charName)
        end
      end
    end

    -- Botoes
    PerfisWindow.controls.saveBtn.onClick = function()
      if player then
        local charName = player:getName()
        if charName and charName:len() > 0 then
          saveProfile(charName)
          -- Recarregar UI para garantir sincronizacao
          schedule(100, function()
            if refreshFugas then refreshFugas() end
            if refreshCombos then refreshCombos() end
            if refreshBuffs then refreshBuffs() end
            if refreshTraps then refreshTraps() end
            if refreshAtaques then refreshAtaques() end
            if refreshStacks then refreshStacks() end
            if refreshRetas then refreshRetas() end
          end)
          PerfisWindow.statusLabel:setText("Perfil '" .. charName .. "' salvo!")
          PerfisWindow.statusLabel:setColor("#00FF88")
          refreshProfileList()
          updateCharInfo()
        end
      else
        PerfisWindow.statusLabel:setText("Nenhum personagem logado")
        PerfisWindow.statusLabel:setColor("red")
      end
    end

    PerfisWindow.controls.loadBtn.onClick = function()
      if selectedProfile then
        if loadProfile(selectedProfile) then
          PerfisWindow.statusLabel:setText("Perfil '" .. selectedProfile .. "' carregado!")
          PerfisWindow.statusLabel:setColor("#00FF88")
        else
          PerfisWindow.statusLabel:setText("Erro ao carregar perfil")
          PerfisWindow.statusLabel:setColor("red")
        end
        refreshProfileList()
        updateCharInfo()
      else
        PerfisWindow.statusLabel:setText("Selecione um perfil")
        PerfisWindow.statusLabel:setColor("yellow")
      end
    end

    PerfisWindow.controls.deleteBtn.onClick = function()
      if selectedProfile then
        deleteProfile(selectedProfile)
        PerfisWindow.statusLabel:setText("Perfil '" .. selectedProfile .. "' deletado!")
        PerfisWindow.statusLabel:setColor("#FF4444")
        refreshProfileList()
      else
        PerfisWindow.statusLabel:setText("Selecione um perfil")
        PerfisWindow.statusLabel:setColor("yellow")
      end
    end

    PerfisWindow.controls.refreshBtn.onClick = function()
      refreshProfileList()
      updateCharInfo()
      PerfisWindow.statusLabel:setText("Lista atualizada")
      PerfisWindow.statusLabel:setColor("yellow")
    end

    PerfisWindow.closeButton.onClick = function()
      PerfisWindow:hide()
    end

    perfisUI.editPerfis.onClick = function()
      updateCharInfo()
      refreshProfileList()
      PerfisWindow:show()
      PerfisWindow:raise()
      PerfisWindow:focus()
    end

    -- Auto-save periodico a cada 60 segundos
    macro(60000, "Perfil Auto-Save", function()
      autoSaveCurrentProfile()
    end)

    -- Auto-detectar e carregar perfil ao iniciar
    schedule(1000, function()
      if player then
        local charName = player:getName()
        if charName and charName:len() > 0 then
          local fileName = PERFIS_DIR .. sanitizeName(charName) .. ".json"
          if g_resources.fileExists(fileName) then
            -- Perfil existe, carregar automaticamente
            loadProfile(charName)
          else
            -- Novo personagem, salvar perfil inicial
            saveProfile(charName)
          end
        end
      end
    end)
  end
end

UI.Separator()


-- Aumentar largura do painel do bot para caber mais tabs
schedule(100, function()
    local botWindow = modules.game_bot.contentsPanel
    if botWindow then
        local parent = botWindow:getParent()
        if parent then
            parent:setWidth(350) -- Aumenta de ~200 para 350
        end
    end
end)