-- Helper: salva perfil atual (OK de confirmacao)
-- Global para ser acessivel pelo sistema de perfis em main.lua
function saveEspeciaisProfile()
  if player then
    local charName = player:getName()
    if charName and charName:len() > 0 then
      local perfilConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
      local PERFIS_DIR = "/bot/" .. perfilConfigName .. "/vBot_perfis/"
      if not g_resources.directoryExists(PERFIS_DIR) then
        g_resources.makeDir(PERFIS_DIR)
      end
      local function deepCopyJson(t)
        if type(t) ~= "table" then return t end
        local ok, enc = pcall(json.encode, t)
        if ok and enc then
          local ok2, dec = pcall(json.decode, enc)
          if ok2 then return dec end
        end
        return t
      end
      local data = {}
      data.esp_fugas_list = deepCopyJson(storage.esp_fugas_list or {})
      data.esp_fugas_widgets_show = deepCopyJson(storage.esp_fugas_widgets_show or {})
      data.esp_fugas_widgets_pos = deepCopyJson(storage.esp_fugas_widgets_pos or {})
      data.esp_trap_list = deepCopyJson(storage.esp_trap_list or {})
      data.esp_combo_slots = deepCopyJson(storage.esp_combo_slots or {})
      data.esp_combo_selected = storage.esp_combo_selected or 1
      data.esp_buffs_list = deepCopyJson(storage.esp_buffs_list or {})
      data.esp_ataque_list = deepCopyJson(storage.esp_ataque_list or {})
      data.esp_stack_list = deepCopyJson(storage.esp_stack_list or {})
      data.esp_retas_list = deepCopyJson(storage.esp_retas_list or {})
      data.esp_perseguir_list = deepCopyJson(storage.esp_perseguir_list or {})
      data.esp_auto_kai = deepCopyJson(storage.esp_auto_kai or {})
      data.ingame_hotkeys = storage.ingame_hotkeys or ""
      data.bgPlayer = deepCopyJson(storage.bgPlayer or {})
      data._originalName = charName
      local sName = charName:gsub("[^%w_%-]", "_")
      local fileName = PERFIS_DIR .. sName .. ".json"
      local ok, result = pcall(function() return json.encode(data, 2) end)
      if ok and result then
        g_resources.writeFileContents(fileName, result)
        storage.perfis_current = charName
        if type(storage.perfis_data) ~= "table" then storage.perfis_data = {} end
        if not table.find(storage.perfis_data, sName) then
          table.insert(storage.perfis_data, sName)
        end
      end
    end
  end
end


-- =============================================
-- TAB: FUGAS (dinamico)
-- =============================================
EspTabBar:addTab("Fugas", espPanel1)
local fugasContent = espPanel1.scrollArea
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

-- Botao OK para salvar fugas
local okFugasBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Fugas
]], fugasContent)
okFugasBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end

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

-- Botao OK para salvar traps
local okTrapsBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Traps
]], trapsContent)
okTrapsBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end

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
-- TAB: COMBOS (5 slots, cada combo = lista de jutsus)
-- =============================================
EspTabBar:addTab("Combos", espPanel3)
local combosContent = espPanel3.scrollArea
        UI.Separator(combosContent)

-- ===== Storage: 5 combo slots =====
if type(storage.esp_combo_slots) ~= "table" then
  storage.esp_combo_slots = {}
  for s = 1, 5 do
    storage.esp_combo_slots[s] = { name = "Combo " .. s, jutsus = {} }
  end
  if type(storage.esp_combo_list) == "table" and #storage.esp_combo_list > 0 then
    for _, old in ipairs(storage.esp_combo_list) do
      if old.text and old.text:len() > 0 then
        table.insert(storage.esp_combo_slots[1].jutsus, { text = old.text })
      end
    end
  end
end
for s = 1, 5 do
  if not storage.esp_combo_slots[s] then
    storage.esp_combo_slots[s] = { name = "Combo " .. s, jutsus = {} }
  end
  if type(storage.esp_combo_slots[s].jutsus) ~= "table" then
    storage.esp_combo_slots[s].jutsus = {}
  end
end

if type(storage.esp_combo_selected) ~= "number" or storage.esp_combo_selected < 1 or storage.esp_combo_selected > 5 then
  storage.esp_combo_selected = 1
end

local comboWidgets = {}

-- ===== Header: "Selecionar Combo" com ComboBox dropdown =====
local comboSelectPanel = setupUI([[
Panel
  height: 26
  margin-top: 3
  Label
    id: headerLabel
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: Combo:
    color: red
    font: verdana-11px-rounded
    text-auto-resize: true
  ComboBox
    id: comboSelect
    anchors.left: headerLabel.right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 8
    height: 20
]], combosContent)

local comboSelectSyncing = false

local function updateComboSelect()
  comboSelectSyncing = true
  comboSelectPanel.comboSelect:clearOptions()
  for s = 1, 5 do
    local slot = storage.esp_combo_slots[s]
    local name = (slot and slot.name and slot.name:len() > 0) and slot.name or ("Combo " .. s)
    local jutsuCount = (slot and slot.jutsus) and #slot.jutsus or 0
    comboSelectPanel.comboSelect:addOption(s .. ". " .. name .. " (" .. jutsuCount .. " jutsus)")
  end
  local sel = storage.esp_combo_selected
  comboSelectPanel.comboSelect:setCurrentIndex(sel)
  comboSelectSyncing = false
end

comboSelectPanel.comboSelect.onOptionChange = function(widget)
  if comboSelectSyncing then return end
  local text = widget:getCurrentOption().text
  local idx = tonumber(text:match("^(%d+)%.")) or 1
  storage.esp_combo_selected = idx
  refreshCombos()
end

UI.Separator(combosContent)

-- ===== Combo name edit para o combo selecionado =====
local comboNamePanel = setupUI([[
Panel
  height: 24
  margin-top: 2
  Label
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: Renomear:
    color: #AADDFF
    text-auto-resize: true
  TextEdit
    id: nameEdit
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 150
]], combosContent)
comboNamePanel.nameEdit:setBackgroundColor("#00000033")
comboNamePanel.nameEdit:setColor("#FFD700")

comboNamePanel.nameEdit.onTextChange = function(w, text)
  local sel = storage.esp_combo_selected
  storage.esp_combo_slots[sel].name = text
  updateComboSelect()
end

UI.Separator(combosContent)

-- ===== Jutsu widget creation (simplificado) =====
local function createJutsuWidget(slotIndex, jutsuIndex, jutsuData)
  local entry = setupUI([[
Panel
  height: 30
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    color: #FFD700
    font: verdana-11px-rounded
    text: Jutsu

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 22
    text: X

  TextEdit
    id: spellEdit
    anchors.left: title.right
    anchors.right: removeBtn.left
    anchors.verticalCenter: parent.verticalCenter
    height: 22
    margin-left: 5
    margin-right: 5

  ]], combosContent)

  entry.title:setText("#" .. jutsuIndex)
  entry.spellEdit:setText(jutsuData.text or "")
  entry.spellEdit:setBackgroundColor("#00000033")
  entry.spellEdit:setColor("#00DDFF")

  entry.spellEdit.onTextChange = function(w, text)
    local slot = storage.esp_combo_slots[slotIndex]
    if slot and slot.jutsus[jutsuIndex] then
      slot.jutsus[jutsuIndex].text = text
    end
  end

  entry.removeBtn.onClick = function(w)
    local slot = storage.esp_combo_slots[slotIndex]
    if slot then
      table.remove(slot.jutsus, jutsuIndex)
    end
    refreshCombos()
  end

  table.insert(comboWidgets, entry)
  return entry
end

-- ===== Containers for dynamic widgets =====
local addJutsuBtnWidget = nil
local okCombosBtnWidget = nil

-- ===== Refresh: rebuild jutsu widgets for selected combo =====
function refreshCombos()
  for _, w in ipairs(comboWidgets) do
    w:destroy()
  end
  comboWidgets = {}

  if addJutsuBtnWidget then addJutsuBtnWidget:destroy() addJutsuBtnWidget = nil end
  if okCombosBtnWidget then okCombosBtnWidget:destroy() okCombosBtnWidget = nil end

  local sel = storage.esp_combo_selected
  local slot = storage.esp_combo_slots[sel]
  if not slot then return end

  comboNamePanel.nameEdit:setText(slot.name or ("Combo " .. sel))
  updateComboSelect()

  for i, jutsuData in ipairs(slot.jutsus) do
    createJutsuWidget(sel, i, jutsuData)
  end

  -- Botao adicionar jutsu
  addJutsuBtnWidget = setupUI([[
Panel
  height: 25
  margin-top: 3
  Button
    id: addJutsu
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Jutsu
]], combosContent)

  addJutsuBtnWidget.addJutsu.onClick = function(w)
    local curSel = storage.esp_combo_selected
    local curSlot = storage.esp_combo_slots[curSel]
    if curSlot then
      table.insert(curSlot.jutsus, { text = "" })
      refreshCombos()
    end
  end

  -- Botao OK salvar
  okCombosBtnWidget = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Combos
]], combosContent)
  okCombosBtnWidget.okBtn.onClick = function()
    saveEspeciaisProfile()
  end
end

-- Load on start
updateComboSelect()
refreshCombos()

-- ===== Macro: executa TODOS os jutsus do combo na sequencia e recomeça =====
EspComboMacro = macro(100, "Combo Especial", function()
  if not g_game.isAttacking() then return end
  local sel = storage.esp_combo_selected
  local slot = storage.esp_combo_slots[sel]
  if not slot then return end

  for _, jutsu in ipairs(slot.jutsus) do
    if jutsu.text and jutsu.text:len() > 0 then
      say(jutsu.text)
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

-- Botao OK para salvar buffs
local okBuffsBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Buffs
]], buffsContent)
okBuffsBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end

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

-- Botao OK para salvar ataques
local okAtaquesBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Ataques
]], ataqueContent)
okAtaquesBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end


-- =============================================
-- TAB: STACK (dinamico - adicionar/remover)
-- Novo sistema: Botao direito do mouse + tecla direcional
-- Suporta WASD (8 direcoes) e Arrows (4 direcoes)
-- =============================================
EspTabBar:addTab("Stack", espPanel6)
local stackContent = espPanel6.scrollArea
        UI.Separator(stackContent)
        color= UI.Label("Stack (botao do meio + direcional):",stackContent)
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

-- Teclas por modo
local WASD_KEYS  = {"W", "A", "S", "D", "E", "Z", "Q", "C"}
local ARROW_KEYS = {"Up", "Down", "Left", "Right"}

-- Mapeamento Arrow Keys -> funcoes equivalentes ao WASD
local ASSERT_DIR_KEYS = {
    ["Up"]    = "W",
    ["Down"]  = "S",
    ["Left"]  = "A",
    ["Right"] = "D"
}

-- Distancia euclidiana (para diagonais)
local function stackPreciseDistance(p1, p2)
    local distx = math.abs(p1.x - p2.x)
    local disty = math.abs(p1.y - p2.y)
    return math.sqrt(distx * distx + disty * disty)
end

-- Mapa de direcoes: cada funcao recebe (pos_monstro, pos_player, melhor_ate_agora)
-- Retorna (true, distancia) se o monstro esta na direcao correta E eh mais distante
local stackDirections = {
    -- W = Norte: monstro acima do player (monstro.y < player.y)
    ["W"] = function(fromPos, toPos, further)
        if (fromPos.y < toPos.y) then
            local distance = math.abs(fromPos.y - toPos.y)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    -- D = Leste: monstro a direita do player (monstro.x > player.x)
    ["D"] = function(fromPos, toPos, further)
        if (fromPos.x > toPos.x) then
            local distance = math.abs(fromPos.x - toPos.x)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    -- S = Sul: monstro abaixo do player (monstro.y > player.y)
    ["S"] = function(fromPos, toPos, further)
        if (fromPos.y > toPos.y) then
            local distance = math.abs(fromPos.y - toPos.y)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    -- A = Oeste: monstro a esquerda do player (monstro.x < player.x)
    ["A"] = function(fromPos, toPos, further)
        if (fromPos.x < toPos.x) then
            local distance = math.abs(fromPos.x - toPos.x)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    -- C = Diagonal Sudoeste: monstro.x > player.x E monstro.y > player.y
    ["C"] = function(fromPos, toPos, further)
        if (fromPos.x > toPos.x and fromPos.y > toPos.y) then
            local distance = stackPreciseDistance(fromPos, toPos)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    -- Z = Diagonal Sudeste: monstro.x < player.x E monstro.y > player.y
    ["Z"] = function(fromPos, toPos, further)
        if (fromPos.x < toPos.x and fromPos.y > toPos.y) then
            local distance = stackPreciseDistance(fromPos, toPos)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    -- Q = Diagonal Nordeste: monstro.x < player.x E monstro.y < player.y
    ["Q"] = function(fromPos, toPos, further)
        if (fromPos.x < toPos.x and fromPos.y < toPos.y) then
            local distance = stackPreciseDistance(fromPos, toPos)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end,
    -- E = Diagonal Noroeste: monstro.x > player.x E monstro.y < player.y
    ["E"] = function(fromPos, toPos, further)
        if (fromPos.x > toPos.x and fromPos.y < toPos.y) then
            local distance = stackPreciseDistance(fromPos, toPos)
            if (not further or further.distance < distance) then
                return true, distance
            end
        end
    end
}

-- Mapeia Arrow Keys para as mesmas funcoes do WASD
for arrowKey, wasdKey in pairs(ASSERT_DIR_KEYS) do
    stackDirections[arrowKey] = stackDirections[wasdKey]
end

-- Funcao para obter spectators (com fallback)
local function getStackSpecs(multifloor)
    local specs = getSpectators(multifloor)
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

-- Busca o MONSTRO MAIS DISTANTE na direcao especificada, dentro do alcance
local function getStackingMonster(dir, maxDistance)
    local isInCorrectDirection = stackDirections[dir]
    if (not isInCorrectDirection) then return end

    local stack
    local specs = getStackSpecs()
    local playerPos = pos()

    for _, spec in ipairs(specs) do
        local specPos = spec:getPosition()
        if specPos then
            local status, distance = isInCorrectDirection(specPos, playerPos, stack)
            if (status and spec:isMonster()) then
                if (getDistanceBetween(specPos, playerPos) <= maxDistance) then
                    if (spec:canShoot()) then
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
-- Funciona com: BOTAO DO MEIO DO MOUSE + TECLA DIRECIONAL
EspStackMacro = macro(50, "Stack Esp", function()
    if isInPz() then return end
    if fugaActive then return end

    -- Precisa do botao do meio do mouse pressionado
    local isMousePressed = g_mouse.isPressed(3)
    if not isMousePressed then return end

    for _, stk in ipairs(storage.esp_stack_list) do
        if stk.spell and stk.spell ~= "" and stk.enabled ~= false then
            local uid = stk.uid
            if now >= (stackCooldownEnd[uid] or 0) then
                -- Define as teclas baseado na config ("WASD" ou "Arrows")
                local selectedKeys = stk.key == "Arrows" and ARROW_KEYS or WASD_KEYS

                for _, dir in ipairs(selectedKeys) do
                    if modules.corelib.g_keyboard.isKeyPressed(dir) then
                        local creature = getStackingMonster(dir, stk.distance or 5)

                        if creature then
                            -- 1. Ataca o monstro (seleciona como alvo)
                            g_game.attack(creature)

                            -- 2. Apos 50ms, solta o poder (cast da spell)
                            local spellText = stk.spell
                            schedule(50, function()
                                say(spellText)
                            end)

                            -- 3. Apos 200ms, cancela o ataque (envia attack nil)
                            schedule(200, function()
                                g_game.attack(nil)
                            end)

                            -- 4. Apos 400ms, cancela definitivamente
                            schedule(400, function()
                                g_game.cancelAttack()
                            end)

                            stackCooldownEnd[uid] = now + ((stk.cd or 2) * 1000)
                            return true
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
  height: 190
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

  -- ComboBox de teclas: WASD (8 direcoes com diagonais) ou Arrows (4 direcoes)
  entry.row2.keyCombo:addOption("WASD")
  entry.row2.keyCombo:addOption("Arrows")
  entry.row2.keyCombo:setCurrentOption(stackData.key or "WASD")

  -- Tooltips
  entry.spellEdit:setTooltip("Spell de ataque (ex: exori vis)")
  entry.row1.nameEdit:setTooltip("Nome exibido no widget da tela (opcional)")
  entry.row2.keyCombo:setTooltip("WASD = 8 direcoes (W/A/S/D + Q/E/Z/C), Arrows = 4 direcoes")
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

-- Botao OK para salvar stacks
local okStacksBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Stacks
]], stackContent)
okStacksBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end


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

-- Funcao canUseReta - verifica se pode usar reta no alvo
local function canUseReta(creature, maxDist)
    local creaturePos = creature:getPosition()
    if not creaturePos then return false end

    local playerPos = pos()
    if playerPos.z ~= creaturePos.z then return false end

    local dx = creaturePos.x - playerPos.x
    local dy = creaturePos.y - playerPos.y
    local adx = math.abs(dx)
    local ady = math.abs(dy)

    maxDist = maxDist or 4

    -- Mesma posicao, nao faz nada
    if adx == 0 and ady == 0 then return false end

    -- Cenario 1: Ja esta em linha reta e dentro da distancia
    if adx == 0 and ady <= maxDist then
        -- Linha vertical
        local targetDir = dy > 0 and 2 or 0  -- SUL ou NORTE
        local currentDir = correctDirection()
        if currentDir == targetDir then
            return true
        else
            turn(targetDir)
            return false
        end
    elseif ady == 0 and adx <= maxDist then
        -- Linha horizontal
        local targetDir = dx > 0 and 1 or 3  -- LESTE ou OESTE
        local currentDir = correctDirection()
        if currentDir == targetDir then
            return true
        else
            turn(targetDir)
            return false
        end
    end

    -- Cenario 2: Nao esta em linha reta, tenta alinhar caminhando
    if adx <= 2 and ady <= 2 then
        local bestPos = nil
        local bestDist = 999
        for _, d in ipairs(retasDirections) do
            local adjPos = {
                x = creaturePos.x + d.x,
                y = creaturePos.y + d.y,
                z = creaturePos.z
            }
            -- Verifica se a posicao adjacente esta em linha com o alvo
            local ddx = math.abs(adjPos.x - creaturePos.x)
            local ddy = math.abs(adjPos.y - creaturePos.y)
            if (ddx == 0 or ddy == 0) then
                local dist = preciseDistance(adjPos, playerPos)
                if dist < bestDist then
                    local tile = g_map.getTile(adjPos)
                    if tile and tile:isWalkable() then
                        bestPos = adjPos
                        bestDist = dist
                    end
                end
            end
        end
        if bestPos then
            player:autoWalk(bestPos)
            retasDelayEnd = now + 400
        end
    end

    return false
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

    -- Auto-ativar Turn target quando tem retas configuradas
    if Turn and Turn.macro and Turn.macro.isOff and Turn.macro.isOff() then
        if #storage.esp_retas_list > 0 then
            Turn.macro.setOn()
        end
    end

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
                    -- Verifica % de vida do alvo (se configurado)
                    local hpLimit = ret.hpPercent or 100
                    local targetHp = target:getHealthPercent()
                    if targetHp and targetHp <= hpLimit then
                        local maxDist = ret.distance or 4
                        if canUseReta(target, maxDist) then
                            say(ret.spell)
                            retasCooldownEnd[uid] = now + ((ret.cd or 2) * 1000)
                            return
                        end
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
  height: 240
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
      text: % Vida alvo:
      color: #FFAA00
      text-auto-resize: true
    TextEdit
      id: hpEdit
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
  entry.row5.hpEdit:setText(tostring(retaData.hpPercent or 100))

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
  entry.row5.hpEdit:setTooltip("Usa reta somente se vida do alvo <= este % (1-100)")

  -- Estilo neon
  local retInputs = {entry.spellEdit, entry.row1.nameEdit, entry.row3.distEdit, entry.row4.cdEdit, entry.row5.hpEdit}
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
  entry.row5.hpEdit.onTextChange = function(w, text)
    local val = tonumber(text) or 100
    if val < 1 then val = 1 end
    if val > 100 then val = 100 end
    storage.esp_retas_list[index].hpPercent = val
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
    hpPercent = 100,
    uid = newUid
  })
  refreshRetas()
end

-- Load existing retas on start
refreshRetas()

-- Botao OK para salvar retas
local okRetasBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Retas
]], retasContent)
okRetasBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end


-- =============================================
-- TAB: PERSEGUIR (dinamico - adicionar/remover)
-- Se inimigo targetado >= 4 sqm, usa a skill configurada
-- Se <= 3 sqm, nao faz nada
-- =============================================
EspTabBar:addTab("Perseguir", espPanel8)
local perseguirContent = espPanel8.scrollArea
        UI.Separator(perseguirContent)
        color= UI.Label("Perseguir (skill se alvo >= 4 sqm):",perseguirContent)
color:setColor("#FF8800")
        UI.Separator(perseguirContent)

-- Storage: lista de perseguir
if type(storage.esp_perseguir_list) ~= "table" then
  storage.esp_perseguir_list = {}
end

-- Atribui IDs unicos para cada perseguir existente
local perseguirIdCounter = 0
for _, p in ipairs(storage.esp_perseguir_list) do
  if p.uid and p.uid >= perseguirIdCounter then
    perseguirIdCounter = p.uid + 1
  end
end
for _, p in ipairs(storage.esp_perseguir_list) do
  if not p.uid then
    p.uid = perseguirIdCounter
    perseguirIdCounter = perseguirIdCounter + 1
  end
end

local perseguirCooldownEnd = {}  -- [uid] = timestamp quando CD termina
local perseguirWidgets = {}

-- Widget de cooldowns na tela para Perseguir
storage.espPerseguirWidgetPos = storage.espPerseguirWidgetPos or {x = 10, y = 450}

local espPerseguirWidget = setupUI([[
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

espPerseguirWidget:setPosition({x = storage.espPerseguirWidgetPos.x, y = storage.espPerseguirWidgetPos.y})

espPerseguirWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = {
        x = mousePos.x - widget:getX(),
        y = mousePos.y - widget:getY()
    }
    return true
end

espPerseguirWidget.onDragMove = function(widget, mousePos)
    widget:move(
        mousePos.x - widget.movingReference.x,
        mousePos.y - widget.movingReference.y
    )
    return true
end

espPerseguirWidget.onDragLeave = function(widget, pos)
    storage.espPerseguirWidgetPos.x = widget:getX()
    storage.espPerseguirWidgetPos.y = widget:getY()
    return true
end

-- Macro para atualizar widget de cooldowns Perseguir na tela
macro(100, function()
    local text = ""
    for _, per in ipairs(storage.esp_perseguir_list) do
        if per.spell and per.spell ~= "" then
            local uid = per.uid
            local cdTime = perseguirCooldownEnd[uid] or 0
            local remaining = math.max(0, math.ceil((cdTime - now) / 1000))
            local name = per.name and per.name ~= "" and per.name or per.spell
            text = text .. name .. ": " .. remaining .. "s\n"
        end
    end
    if text ~= "" then
        espPerseguirWidget:setText(text:sub(1, -2))
        espPerseguirWidget:show()
    else
        espPerseguirWidget:hide()
    end
end)

-- Macro principal de Perseguir
-- Logica: se o inimigo targetado tiver ate 3 sqm de distancia, nao faz nada
-- Se tiver 4 ou mais sqm, usa a skill configurada
EspPerseguirMacro = macro(100, "Perseguir Esp", function()
    if isInPz() then return end
    if fugaActive then return end

    local target = g_game.getAttackingCreature()
    if not target then return end

    local targetPos = target:getPosition()
    if not targetPos then return end

    local playerPos = pos()
    if not playerPos then return end

    -- Verificar se esta no mesmo andar
    if targetPos.z ~= playerPos.z then return end

    local distance = getDistanceBetween(playerPos, targetPos)

    -- Se distancia <= 3, nao faz nada
    if distance <= 3 then return end

    -- Se distancia >= 4, usa a skill configurada
    for _, per in ipairs(storage.esp_perseguir_list) do
        if per.spell and per.spell ~= "" and per.enabled ~= false then
            local uid = per.uid
            if now >= (perseguirCooldownEnd[uid] or 0) then
                say(per.spell)
                perseguirCooldownEnd[uid] = now + ((per.cd or 2) * 1000)
                return
            end
        end
    end
end, perseguirContent)

-- Funcao para criar widget de um Perseguir
local function createPerseguirWidget(index, perData)
  local uid = perData.uid
  local entry = setupUI([[
Panel
  height: 150
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #FF8800
    font: verdana-11px-rounded
    text: Perseguir

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
      text: CD(s):
      color: white
      text-auto-resize: true
    TextEdit
      id: cdEdit
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 55

  ]], perseguirContent)

  entry.title:setText("Perseguir #" .. index)
  entry.spellEdit:setText(perData.spell or "")
  entry.row1.nameEdit:setText(perData.name or "")
  entry.row2.cdEdit:setText(tostring(perData.cd or 2))

  -- Tooltips
  entry.spellEdit:setTooltip("Spell usada quando alvo esta a 4+ sqm (ex: jutsu shunshin)")
  entry.row1.nameEdit:setTooltip("Nome exibido no widget da tela (opcional)")
  entry.row2.cdEdit:setTooltip("Cooldown em segundos entre usos")

  -- Estilo neon
  local perInputs = {entry.spellEdit, entry.row1.nameEdit, entry.row2.cdEdit}
  for _, input in ipairs(perInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_perseguir_list[index].spell = text
  end
  entry.row1.nameEdit.onTextChange = function(w, text)
    storage.esp_perseguir_list[index].name = text
  end
  entry.row2.cdEdit.onTextChange = function(w, text)
    storage.esp_perseguir_list[index].cd = tonumber(text) or 2
  end

  entry.removeBtn.onClick = function(w)
    perseguirCooldownEnd[uid] = nil
    table.remove(storage.esp_perseguir_list, index)
    refreshPerseguir()
  end

  table.insert(perseguirWidgets, entry)
  return entry
end

-- Refresh all perseguir widgets
function refreshPerseguir()
  for _, w in ipairs(perseguirWidgets) do
    w:destroy()
  end
  perseguirWidgets = {}
  for i, perData in ipairs(storage.esp_perseguir_list) do
    createPerseguirWidget(i, perData)
  end
end

-- Botao adicionar perseguir
local addPerseguirBtn = setupUI([[
Panel
  height: 25
  Button
    id: addPerseguir
    color: green
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Perseguir
]], perseguirContent)

addPerseguirBtn.addPerseguir.onClick = function(w)
  local newIndex = #storage.esp_perseguir_list + 1
  local newUid = perseguirIdCounter
  perseguirIdCounter = perseguirIdCounter + 1
  table.insert(storage.esp_perseguir_list, {
    spell = "perseguir " .. newIndex,
    name = "",
    cd = 2,
    uid = newUid
  })
  refreshPerseguir()
end

-- Load existing perseguir on start
refreshPerseguir()

-- Botao OK para salvar perseguir
local okPerseguirBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Perseguir
]], perseguirContent)
okPerseguirBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end


-- =============================================
-- TAB: GENJUTSUS (Defensivo/Ofensivo por HP%)
-- Defensivo: solta baseado na vida do MEU personagem + sem fuga disponivel
-- Ofensivo: solta baseado na vida do OPONENTE
-- =============================================
EspTabBar:addTab("Genjutsus", espPanel9)
local genjutsuContent = espPanel9.scrollArea
        UI.Separator(genjutsuContent)
        color= UI.Label("Genjutsus (Defensivo / Ofensivo):",genjutsuContent)
color:setColor("#CC00FF")
        UI.Separator(genjutsuContent)

-- Storage: lista de genjutsus
if type(storage.esp_genjutsu_list) ~= "table" then
  storage.esp_genjutsu_list = {}
end

-- Atribui IDs unicos para cada genjutsu existente
local genjutsuIdCounter = 0
for _, g in ipairs(storage.esp_genjutsu_list) do
  if g.uid and g.uid >= genjutsuIdCounter then
    genjutsuIdCounter = g.uid + 1
  end
end
for _, g in ipairs(storage.esp_genjutsu_list) do
  if not g.uid then
    g.uid = genjutsuIdCounter
    genjutsuIdCounter = genjutsuIdCounter + 1
  end
end

local genjutsuCooldownEnd = {}  -- [uid] = timestamp quando CD termina
local genjutsuWidgets = {}

-- Widget de cooldowns na tela
storage.espGenjutsuWidgetPos = storage.espGenjutsuWidgetPos or {x = 10, y = 400}

local espGenjutsuWidget = setupUI([[
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

espGenjutsuWidget:setPosition({x = storage.espGenjutsuWidgetPos.x, y = storage.espGenjutsuWidgetPos.y})

espGenjutsuWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = {
        x = mousePos.x - widget:getX(),
        y = mousePos.y - widget:getY()
    }
    return true
end

espGenjutsuWidget.onDragMove = function(widget, mousePos)
    widget:move(
        mousePos.x - widget.movingReference.x,
        mousePos.y - widget.movingReference.y
    )
    return true
end

espGenjutsuWidget.onDragLeave = function(widget, pos)
    storage.espGenjutsuWidgetPos.x = widget:getX()
    storage.espGenjutsuWidgetPos.y = widget:getY()
    return true
end

-- Funcao auxiliar: verifica se alguma fuga esta disponivel (off cooldown)
local function isAnyFugaAvailable()
  if type(storage.esp_fugas_list) ~= "table" then return false end
  local hp = player:getHealthPercent()
  for _, f in ipairs(storage.esp_fugas_list) do
    if f.text and f.text:len() > 0 then
      local hpThreshold = tonumber(f.hp) or 50
      if hp <= hpThreshold then
        local uid = f.uid
        local cdEnd = fugaCooldownEnd[uid] or 0
        if now >= cdEnd and not fugaActive then
          return true
        end
      end
    end
  end
  return false
end

-- Macro para atualizar widget de cooldowns na tela
macro(100, function()
    local text = ""
    for _, gen in ipairs(storage.esp_genjutsu_list) do
        if gen.spell and gen.spell ~= "" then
            local uid = gen.uid
            local cdTime = genjutsuCooldownEnd[uid] or 0
            local remaining = math.max(0, math.ceil((cdTime - now) / 1000))
            local name = gen.name and gen.name ~= "" and gen.name or gen.spell
            local tipo = gen.tipo == "defensivo" and "[D]" or "[O]"
            text = text .. tipo .. " " .. name .. ": " .. remaining .. "s\n"
        end
    end
    if text ~= "" then
        espGenjutsuWidget:setText(text:sub(1, -2))
        espGenjutsuWidget:show()
    else
        espGenjutsuWidget:hide()
    end
end)

-- Macro principal de genjutsu
EspGenjutsuMacro = macro(100, "Genjutsus Esp", function()
    if not g_game.isAttacking() then return end
    if isInPz() then return end
    if fugaActive then return end

    local target = g_game.getAttackingCreature()
    if not target or not target:isPlayer() then return end

    local myHp = player:getHealthPercent()
    local targetHp = target:getHealthPercent()

    for _, gen in ipairs(storage.esp_genjutsu_list) do
        if gen.spell and gen.spell ~= "" then
            local uid = gen.uid
            local hpThreshold = tonumber(gen.hp) or 50

            if gen.tipo == "defensivo" then
                -- Defensivo: solta quando MEU HP <= threshold E nenhuma fuga disponivel
                if myHp <= hpThreshold and not isAnyFugaAvailable() then
                    if now >= (genjutsuCooldownEnd[uid] or 0) then
                        say(gen.spell)
                        genjutsuCooldownEnd[uid] = now + ((gen.cd or 5) * 1000)
                        return
                    end
                end
            else
                -- Ofensivo: solta quando HP do OPONENTE <= threshold
                if targetHp <= hpThreshold then
                    if now >= (genjutsuCooldownEnd[uid] or 0) then
                        say(gen.spell)
                        genjutsuCooldownEnd[uid] = now + ((gen.cd or 5) * 1000)
                        return
                    end
                end
            end
        end
    end
end, genjutsuContent)

-- Funcao para criar widget de um genjutsu
local function createGenjutsuWidget(index, genData)
  local uid = genData.uid
  local entry = setupUI([[
Panel
  height: 220
  margin-top: 3

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    color: #CC00FF
    font: verdana-11px-rounded
    text: Genjutsu

  Button
    id: removeBtn
    color: red
    anchors.top: parent.top
    anchors.right: parent.right
    width: 20
    height: 18
    text: X

  Panel
    id: rowTipo
    anchors.top: removeBtn.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    margin-top: 3
    Label
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Tipo:
      color: #FFCC00
      text-auto-resize: true
    ComboBox
      id: tipoCombo
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 120

  Label
    id: hpInfo
    anchors.top: rowTipo.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 3
    color: #AADDFF
    font: verdana-11px-rounded
    text-auto-resize: true

  Label
    id: lbl1
    anchors.top: hpInfo.bottom
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
      id: hpLabel
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

  ]], genjutsuContent)

  entry.title:setText("Genjutsu #" .. index)
  entry.spellEdit:setText(genData.spell or "")
  entry.row1.nameEdit:setText(genData.name or "")
  entry.row2.hpEdit:setText(tostring(genData.hp or 50))
  entry.row3.cdEdit:setText(tostring(genData.cd or 5))

  -- ComboBox tipo: Defensivo / Ofensivo
  entry.rowTipo.tipoCombo:addOption("Defensivo")
  entry.rowTipo.tipoCombo:addOption("Ofensivo")

  -- Selecionar o tipo correto
  if genData.tipo == "ofensivo" then
    entry.rowTipo.tipoCombo:setCurrentIndex(2)
  else
    entry.rowTipo.tipoCombo:setCurrentIndex(1)
  end

  -- Funcao para atualizar label de info baseado no tipo
  local function updateHpInfo(tipo)
    if tipo == "defensivo" then
      entry.hpInfo:setText("Solta no oponente quando MEU HP <= X%\ne nenhuma fuga disponivel")
      entry.hpInfo:setColor("#00FF88")
    else
      entry.hpInfo:setText("Solta no oponente quando HP DELE <= X%")
      entry.hpInfo:setColor("#FF6600")
    end
  end
  updateHpInfo(genData.tipo or "defensivo")

  -- Tooltips
  entry.spellEdit:setTooltip("Nome da spell de genjutsu (ex: genjutsu sharingan)")
  entry.row1.nameEdit:setTooltip("Nome exibido no widget da tela (opcional, usa spell se vazio)")
  entry.row2.hpEdit:setTooltip("HP% para ativar o genjutsu")
  entry.row3.cdEdit:setTooltip("Cooldown em segundos entre usos")

  -- Estilo: fundo transparente e texto neon
  local genInputs = {entry.spellEdit, entry.row1.nameEdit, entry.row2.hpEdit, entry.row3.cdEdit}
  for _, input in ipairs(genInputs) do
    input:setBackgroundColor("#00000033")
    input:setColor("#00DDFF")
  end

  entry.spellEdit.onTextChange = function(w, text)
    storage.esp_genjutsu_list[index].spell = text
  end
  entry.row1.nameEdit.onTextChange = function(w, text)
    storage.esp_genjutsu_list[index].name = text
  end
  entry.row2.hpEdit.onTextChange = function(w, text)
    storage.esp_genjutsu_list[index].hp = tonumber(text) or 50
  end
  entry.row3.cdEdit.onTextChange = function(w, text)
    storage.esp_genjutsu_list[index].cd = tonumber(text) or 5
  end

  entry.rowTipo.tipoCombo.onOptionChange = function(w, text)
    local selectedTipo = (text == "Ofensivo") and "ofensivo" or "defensivo"
    storage.esp_genjutsu_list[index].tipo = selectedTipo
    updateHpInfo(selectedTipo)
  end

  entry.removeBtn.onClick = function(w)
    genjutsuCooldownEnd[uid] = nil
    table.remove(storage.esp_genjutsu_list, index)
    refreshGenjutsus()
  end

  table.insert(genjutsuWidgets, entry)
  return entry
end

-- Refresh all genjutsu widgets
function refreshGenjutsus()
  for _, w in ipairs(genjutsuWidgets) do
    w:destroy()
  end
  genjutsuWidgets = {}
  for i, genData in ipairs(storage.esp_genjutsu_list) do
    createGenjutsuWidget(i, genData)
  end
end

-- Botao adicionar genjutsu
local addGenjutsuBtn = setupUI([[
Panel
  height: 25
  Button
    id: addGenjutsu
    color: #CC00FF
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: + Adicionar Genjutsu
]], genjutsuContent)

addGenjutsuBtn.addGenjutsu.onClick = function(w)
  local newIndex = #storage.esp_genjutsu_list + 1
  local newUid = genjutsuIdCounter
  genjutsuIdCounter = genjutsuIdCounter + 1
  table.insert(storage.esp_genjutsu_list, {
    spell = "genjutsu " .. newIndex,
    name = "",
    tipo = "defensivo",
    hp = 30,
    cd = 5,
    uid = newUid
  })
  refreshGenjutsus()
end

-- Load existing genjutsus on start
refreshGenjutsus()

-- Botao OK para salvar genjutsus
local okGenjutsuBtn = setupUI([[
Panel
  height: 25
  margin-top: 5
  Button
    id: okBtn
    color: #00FF88
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    text: OK - Salvar Genjutsus
]], genjutsuContent)
okGenjutsuBtn.okBtn.onClick = function()
  saveEspeciaisProfile()
end

