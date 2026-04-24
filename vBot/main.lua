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
    EspComboBox = EspeciaisWindow.espComboBox

    -- Salvar Tudo button with visual feedback
    EspeciaisWindow.salvarTudoBtn.onClick = function(widget)
      saveEspeciaisProfile()
      widget:setText("Salvo!")
      widget:setColor("#FFD700")
      schedule(800, function()
        widget:setText("Salvar Tudo")
        widget:setColor("#00FF88")
        EspeciaisWindow:hide()
      end)
    end

   for v = 1, 1 do


espPanel1 = g_ui.createWidget("espPanel")
espPanel1:setId("panelButtons")

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

espPanel8 = g_ui.createWidget("espPanel")
espPanel8:setId("8")

espPanel9 = g_ui.createWidget("espPanel")
espPanel9:setId("9")

-- Mapeamento de opcoes do ComboBox para paineis
local espPanelMap = {
  { name = "Fugas",     panel = espPanel1 },
  { name = "Traps",     panel = espPanel2 },
  { name = "Combos",    panel = espPanel3 },
  { name = "Buffs",     panel = espPanel4 },
  { name = "Ataque %",  panel = espPanel5 },
  { name = "Stack",     panel = espPanel6 },
  { name = "Retas",     panel = espPanel7 },
  { name = "Perseguir", panel = espPanel8 },
  { name = "Genjutsus", panel = espPanel9 },
}

-- Adiciona cada painel como filho de espImagem
for _, entry in ipairs(espPanelMap) do
  EspeciaisWindow.espImagem:addChild(entry.panel)
  entry.panel:fill('parent')
  entry.panel:hide()
end

-- Adiciona opcoes no ComboBox
for _, entry in ipairs(espPanelMap) do
  EspComboBox:addOption(entry.name)
end

-- Funcao para mostrar/esconder paineis
local function showEspPanel(name)
  for _, entry in ipairs(espPanelMap) do
    if entry.name == name then
      entry.panel:show()
      entry.panel:raise()
    else
      entry.panel:hide()
    end
  end
end

-- Selecao inicial
showEspPanel("Fugas")

-- Callback ao trocar opcao
EspComboBox.onOptionChange = function(widget)
  local selected = widget:getCurrentOption().text
  showEspPanel(selected)
end

-- Carrega todo o codigo das abas especiais de especiais.lua
-- (Fugas, Traps, Combos, Buffs, Ataque%, Stack, Retas, Perseguir, Genjutsus)
dofile("/vBot/especiais.lua")

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

-- =============================================
-- MACRO DELAY - Slider para delay dos macros especiais
-- =============================================
if not storage.esp_macro_delay then
  storage.esp_macro_delay = 50
end

local macroDelayPanel = setupUI([[
Panel
  height: 22
  background-color: alpha

  UIWidget
    id: btnLeft
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text-align: center
    color: #FFD700
    font: verdana-11px-rounded
    text: <<
    size: 20 20
    background-color: alpha
    image-source:
    image-border: 0

  UIWidget
    id: delayLabel
    anchors.left: btnLeft.right
    anchors.right: btnRight.left
    anchors.verticalCenter: parent.verticalCenter
    text-align: center
    color: #FFD700
    font: verdana-11px-rounded
    text: Macro Delay: 50ms
    background-color: alpha

  UIWidget
    id: btnRight
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text-align: center
    color: #FFD700
    font: verdana-11px-rounded
    text: >>
    size: 20 20
    background-color: alpha
    image-source:
    image-border: 0
]], parent)

macroDelayPanel:setBackgroundColor("alpha")

local function updateDelayLabel()
  macroDelayPanel.delayLabel:setText("Macro Delay: " .. storage.esp_macro_delay .. "ms")
end

updateDelayLabel()

macroDelayPanel.btnLeft.onMousePress = function(widget, mousePos, mouseButton)
  if mouseButton == 1 then
    storage.esp_macro_delay = math.max(50, storage.esp_macro_delay - 10)
    updateDelayLabel()
  end
end

macroDelayPanel.btnRight.onMousePress = function(widget, mousePos, mouseButton)
  if mouseButton == 1 then
    storage.esp_macro_delay = math.min(300, storage.esp_macro_delay + 10)
    updateDelayLabel()
  end
end

-- Expose widgets globally for visual_custom.lua color styling
macroDelayLabel = macroDelayPanel.delayLabel
macroDelayBtnLeft = macroDelayPanel.btnLeft
macroDelayBtnRight = macroDelayPanel.btnRight
especiaisButton = ui.editEspeciais

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

  -- Converte chaves string numericas para chaves numericas (fix JSON decode) - recursivo
  local function fixNumericKeys(t)
    if type(t) ~= "table" then return t end
    local fixed = {}
    for k, v in pairs(t) do
      local numKey = tonumber(k)
      local fixedValue = type(v) == "table" and fixNumericKeys(v) or v
      if numKey then
        fixed[numKey] = fixedValue
      else
        fixed[k] = fixedValue
      end
    end
    return fixed
  end

  -- Converter chaves numericas para string antes de salvar (evitar problemas JSON com chave 0)
  local function toStringKeys(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do
      result[tostring(k)] = type(v) == "table" and deepCopy(v) or v
    end
    return result
  end

  -- Funcao para limpar storage do perfil (para perfis novos)
  local function clearProfileStorage()
    storage.esp_fugas_list = {}
    storage.esp_fugas_widgets_show = {}
    storage.esp_fugas_widgets_pos = {}
    storage.esp_trap_list = {}
    storage.esp_combo_slots = {}
    storage.esp_combo_selected = 1
    storage.esp_combo_enabled = true
    storage.esp_buffs_list = {}
    storage.esp_ataque_list = {}
    storage.esp_stack_list = {}
    storage.esp_retas_list = {}
    storage.esp_perseguir_list = {}
    storage.esp_auto_kai = {}
    storage.ingame_hotkeys = ""
    storage.bgPlayer = {
      currentBG = nil,
      opacity = "99",
      bgColor = "#000000",
      applyWindow = true,
      applyPanel = true,
      applyContents = true
    }
    storage.esp_macro_delay = 50
    storage.esp_genjutsu_list = {}
    storage.esp_anti_burst = false
    storage.esp_anti_burst_drop = 40
    storage.esp_anti_burst_window = 1500
    storage.visualCustom = {}
    storage.friends_enemies = { friends = {}, enemies = {} }
  end

  -- Funcao para coletar dados do perfil atual
  local function collectProfileData()
    local data = {}
    -- Fugas
    data.esp_fugas_list = deepCopy(storage.esp_fugas_list or {})
    data.esp_fugas_widgets_show = toStringKeys(storage.esp_fugas_widgets_show or {})
    data.esp_fugas_widgets_pos = toStringKeys(storage.esp_fugas_widgets_pos or {})
    -- Traps
    data.esp_trap_list = deepCopy(storage.esp_trap_list or {})
    -- Combos (5 slots)
    data.esp_combo_slots = deepCopy(storage.esp_combo_slots or {})
    data.esp_combo_selected = storage.esp_combo_selected or 1
    data.esp_combo_enabled = storage.esp_combo_enabled ~= false
    -- Buffs
    data.esp_buffs_list = deepCopy(storage.esp_buffs_list or {})
    -- Ataques
    data.esp_ataque_list = deepCopy(storage.esp_ataque_list or {})
    -- Stack
    data.esp_stack_list = deepCopy(storage.esp_stack_list or {})
    -- Retas
    data.esp_retas_list = deepCopy(storage.esp_retas_list or {})
    -- Perseguir
    data.esp_perseguir_list = deepCopy(storage.esp_perseguir_list or {})
    -- Kai
    data.esp_auto_kai = deepCopy(storage.esp_auto_kai or {})
    -- Ingame scripts
    data.ingame_hotkeys = storage.ingame_hotkeys or ""
    -- Background
    data.bgPlayer = deepCopy(storage.bgPlayer or {})
    -- Macro Delay
    data.esp_macro_delay = storage.esp_macro_delay or 50
    -- Visual Custom (cores)
    data.visualCustom = deepCopy(storage.visualCustom or {})
    -- Genjutsus
    data.esp_genjutsu_list = deepCopy(storage.esp_genjutsu_list or {})
    -- Anti-Burst
    data.esp_anti_burst = storage.esp_anti_burst or false
    data.esp_anti_burst_drop = storage.esp_anti_burst_drop or 40
    data.esp_anti_burst_window = storage.esp_anti_burst_window or 1500
    -- Friends / Enemys
    data.friends_enemies = deepCopy(storage.friends_enemies or { friends = {}, enemies = {} })
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
    if data.esp_fugas_list then storage.esp_fugas_list = fixNumericKeys(deepCopy(data.esp_fugas_list)) end
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
    if data.esp_combo_slots then
      storage.esp_combo_slots = fixNumericKeys(deepCopy(data.esp_combo_slots))
      storage.esp_combo_selected = data.esp_combo_selected or 1
      if data.esp_combo_enabled ~= nil then
        storage.esp_combo_enabled = data.esp_combo_enabled
      end
    elseif data.esp_combo_list then
      -- Migrar formato antigo: lista unica -> slot 1
      storage.esp_combo_slots = {}
      for s = 1, 5 do
        storage.esp_combo_slots[s] = { name = "Combo " .. s, jutsus = {} }
      end
      for _, old in ipairs(data.esp_combo_list) do
        if old.text and old.text:len() > 0 then
          table.insert(storage.esp_combo_slots[1].jutsus, { text = old.text, cooldown = old.cooldown or 1000 })
        end
      end
      storage.esp_combo_selected = 1
      storage.esp_combo_enabled = true
    end
    if data.esp_buffs_list then storage.esp_buffs_list = fixNumericKeys(deepCopy(data.esp_buffs_list)) end
    if data.esp_ataque_list then storage.esp_ataque_list = fixNumericKeys(deepCopy(data.esp_ataque_list)) end
    if data.esp_stack_list then storage.esp_stack_list = fixNumericKeys(deepCopy(data.esp_stack_list)) end
    if data.esp_retas_list then storage.esp_retas_list = fixNumericKeys(deepCopy(data.esp_retas_list)) end
    if data.esp_perseguir_list then storage.esp_perseguir_list = fixNumericKeys(deepCopy(data.esp_perseguir_list)) end
    if data.esp_auto_kai then storage.esp_auto_kai = fixNumericKeys(deepCopy(data.esp_auto_kai)) end
    if data.ingame_hotkeys ~= nil then storage.ingame_hotkeys = data.ingame_hotkeys end
    if data.bgPlayer then storage.bgPlayer = deepCopy(data.bgPlayer) end
    if data.esp_genjutsu_list then storage.esp_genjutsu_list = fixNumericKeys(deepCopy(data.esp_genjutsu_list)) end
    if data.esp_anti_burst ~= nil then storage.esp_anti_burst = data.esp_anti_burst end
    if data.esp_anti_burst_drop ~= nil then storage.esp_anti_burst_drop = data.esp_anti_burst_drop end
    if data.esp_anti_burst_window ~= nil then storage.esp_anti_burst_window = data.esp_anti_burst_window end

    -- Friends / Enemys
    if data.friends_enemies and type(data.friends_enemies) == "table" then
      storage.friends_enemies = deepCopy(data.friends_enemies)
      if type(storage.friends_enemies.friends) ~= "table" then storage.friends_enemies.friends = {} end
      if type(storage.friends_enemies.enemies) ~= "table" then storage.friends_enemies.enemies = {} end
    else
      storage.friends_enemies = { friends = {}, enemies = {} }
    end
    schedule(300, function()
      if feRefreshAllMarks then pcall(feRefreshAllMarks) end
      if refreshFriendsList then pcall(refreshFriendsList) end
    end)

    -- Macro Delay
    if data.esp_macro_delay then
      storage.esp_macro_delay = data.esp_macro_delay
      schedule(200, function()
        if macroDelayPanel and macroDelayPanel.delayScroll then
          macroDelayPanel.delayScroll:setValue(storage.esp_macro_delay)
          macroDelayPanel.delayLabel:setText("Macro Delay: " .. storage.esp_macro_delay .. "ms")
        end
      end)
    end

    -- Visual Custom (cores)
    if data.visualCustom then
      storage.visualCustom = deepCopy(data.visualCustom)
      corText = storage.visualCustom.corText or "#00AAFF"
      schedule(400, function()
        if applyAllVisuals then applyAllVisuals() end
        if applyMacrosBorder then applyMacrosBorder() end
      end)
    end

    storage.perfis_current = data._originalName or charName

    -- Aplicar background se salvo, ou limpar se perfil nao tem BG
    schedule(300, function()
      if storage.bgPlayer and storage.bgPlayer.currentBG then
        if applyBG then applyBG(storage.bgPlayer.currentBG) end
      else
        if clearBG then clearBG() end
      end
      if refreshBGUI then refreshBGUI() end
    end)

    -- Reseta estado de runtime do combo ao trocar de perfil
    if espResetComboRuntime then pcall(espResetComboRuntime) end

    -- Recarregar UI das fugas/combos/buffs/traps/ataques
    schedule(200, function()
      if refreshFugas then refreshFugas() end
      if refreshCombos then refreshCombos() end
      if refreshBuffs then refreshBuffs() end
      if refreshTraps then refreshTraps() end
      if refreshAtaques then refreshAtaques() end
      if refreshStacks then refreshStacks() end
      if refreshRetas then refreshRetas() end
      if refreshPerseguir then refreshPerseguir() end
      if refreshGenjutsus then refreshGenjutsus() end
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
  perfisButton = perfisUI.editPerfis

  -- Janela de perfis
  local PerfisWindow
  rootWidget = g_ui.getRootWidget()
  if rootWidget then
    PerfisWindow = g_ui.loadUIFromString([[
MainWindow
  !text: tr('- Perfis -')
  size: 350 460
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

  Button
    id: resetProfileBtn
    anchors.top: controls.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 28
    margin-top: 8
    text: Reset Profile (limpa tudo)
    color: #FF3333
    font: verdana-11px-rounded

  Label
    id: statusLabel
    anchors.top: resetProfileBtn.bottom
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
            if refreshPerseguir then refreshPerseguir() end
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

    -- =========================================================
    -- Reset Profile: modal de confirmacao antes de limpar
    -- =========================================================
    local resetConfirmWindow = nil
    local function showResetConfirmModal()
      if resetConfirmWindow then
        pcall(function() resetConfirmWindow:destroy() end)
        resetConfirmWindow = nil
      end

      resetConfirmWindow = g_ui.loadUIFromString([[
MainWindow
  !text: tr('Confirmar Reset')
  size: 360 190
  color: #FF3333
  @onEscape: self:destroy()

  Label
    id: msg1
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    text-auto-resize: true
    text-wrap: true
    font: verdana-11px-rounded
    color: #FFCC00
    margin-top: 5
    text: ATENCAO! Esta acao e irreversivel.

  Label
    id: msg2
    anchors.top: msg1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    text-auto-resize: true
    text-wrap: true
    font: verdana-11px-rounded
    color: white
    margin-top: 8
    text: Todos os dados do perfil atual (fugas, traps, combos, buffs, ataques, stacks, retas, perseguir, genjutsus, kai, hotkeys, visuais, background e anti-burst) serao apagados.

  Label
    id: msg3
    anchors.top: msg2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    text-auto-resize: true
    font: verdana-11px-rounded
    color: #AADDFF
    margin-top: 6
    text: Deseja continuar?

  Button
    id: cancelBtn
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    margin-left: 5
    margin-bottom: 5
    width: 120
    height: 25
    text: Cancelar
    color: #AAAAAA

  Button
    id: confirmBtn
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-right: 5
    margin-bottom: 5
    width: 120
    height: 25
    text: Sim, resetar
    color: #FF3333
]], rootWidget)

      resetConfirmWindow:raise()
      resetConfirmWindow:focus()

      resetConfirmWindow.cancelBtn.onClick = function()
        resetConfirmWindow:destroy()
        resetConfirmWindow = nil
        PerfisWindow.statusLabel:setText("Reset cancelado")
        PerfisWindow.statusLabel:setColor("#AAAAAA")
      end

      resetConfirmWindow.confirmBtn.onClick = function()
        resetConfirmWindow:destroy()
        resetConfirmWindow = nil

        -- Oculta widgets de tela antes de limpar storages
        if espHideAllScreenWidgets then
          pcall(espHideAllScreenWidgets)
        end

        -- Reseta estado de runtime do combo para nao deixar indice "preso"
        if espResetComboRuntime then
          pcall(espResetComboRuntime)
        end

        -- Limpa o storage atual
        clearProfileStorage()

        -- Regrava o perfil do personagem atual vazio (se logado)
        if player then
          local charName = player:getName()
          if charName and charName:len() > 0 then
            saveProfile(charName)
          end
        end

        -- Recarrega todas as UIs
        schedule(100, function()
          if refreshFugas then refreshFugas() end
          if refreshCombos then refreshCombos() end
          if refreshBuffs then refreshBuffs() end
          if refreshTraps then refreshTraps() end
          if refreshAtaques then refreshAtaques() end
          if refreshStacks then refreshStacks() end
          if refreshRetas then refreshRetas() end
          if refreshPerseguir then refreshPerseguir() end
          if refreshGenjutsus then refreshGenjutsus() end
          if clearBG then clearBG() end
          if refreshBGUI then refreshBGUI() end
          refreshProfileList()
          updateCharInfo()
          -- Garante que widgets de tela sumam apos o refresh tambem
          if espHideAllScreenWidgets then
            pcall(espHideAllScreenWidgets)
          end
        end)

        PerfisWindow.statusLabel:setText("Perfil resetado!")
        PerfisWindow.statusLabel:setColor("#FF3333")
      end
    end

    PerfisWindow.resetProfileBtn.onClick = function()
      showResetConfirmModal()
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
            -- Novo personagem, limpar storage e salvar perfil vazio
            clearProfileStorage()
            saveProfile(charName)
            -- Refresh UI after clearing
            schedule(200, function()
              if refreshFugas then refreshFugas() end
              if refreshCombos then refreshCombos() end
              if refreshBuffs then refreshBuffs() end
              if refreshTraps then refreshTraps() end
              if refreshAtaques then refreshAtaques() end
              if refreshStacks then refreshStacks() end
              if refreshRetas then refreshRetas() end
              if refreshPerseguir then refreshPerseguir() end
              if clearBG then clearBG() end
              if refreshBGUI then refreshBGUI() end
            end)
          end
        end
      end
    end)
  end
end

-- =============================================
-- FRIENDS / ENEMYS - Marcadores F (amigo) e E (inimigo)
-- =============================================
do
  if type(storage.friends_enemies) ~= "table" then
    storage.friends_enemies = { friends = {}, enemies = {} }
  end
  if type(storage.friends_enemies.friends) ~= "table" then
    storage.friends_enemies.friends = {}
  end
  if type(storage.friends_enemies.enemies) ~= "table" then
    storage.friends_enemies.enemies = {}
  end

  local function normName(name)
    if not name then return nil end
    name = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
    if name:len() == 0 then return nil end
    return name:lower()
  end

  -- Expoe helpers globalmente para friends.lua consumir
  feIsFriend = function(name)
    local n = normName(name)
    if not n then return false end
    for _, v in ipairs(storage.friends_enemies.friends) do
      if normName(v) == n then return true end
    end
    return false
  end

  feIsEnemy = function(name)
    local n = normName(name)
    if not n then return false end
    for _, v in ipairs(storage.friends_enemies.enemies) do
      if normName(v) == n then return true end
    end
    return false
  end

  feAddFriend = function(name)
    if not name or name:len() == 0 then return end
    if feIsFriend(name) then return end
    table.insert(storage.friends_enemies.friends, name)
  end

  feAddEnemy = function(name)
    if not name or name:len() == 0 then return end
    if feIsEnemy(name) then return end
    table.insert(storage.friends_enemies.enemies, name)
  end

  feRemoveFriend = function(name)
    local n = normName(name)
    if not n then return end
    for i, v in ipairs(storage.friends_enemies.friends) do
      if normName(v) == n then
        table.remove(storage.friends_enemies.friends, i)
        return
      end
    end
  end

  feRemoveEnemy = function(name)
    local n = normName(name)
    if not n then return end
    for i, v in ipairs(storage.friends_enemies.enemies) do
      if normName(v) == n then
        table.remove(storage.friends_enemies.enemies, i)
        return
      end
    end
  end

  -- Botao no painel principal (abaixo de Perfis)
  local friendsPanelName = "friendsEnemiesPanel"
  local friendsUI = setupUI([[
Panel
  height: 35

  Button
    id: editFriends
    color: #FF66CC
    font: verdana-11px-rounded
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 35
    text: - FRIENDS / ENEMYS -

  ]], parent)
  friendsUI:setId(friendsPanelName)
  friendsButton = friendsUI.editFriends

  local rootW = g_ui.getRootWidget()
  local FriendsWindow
  if rootW then
    FriendsWindow = g_ui.loadUIFromString([[
MainWindow
  !text: tr('- Friends / Enemys -')
  size: 560 460
  color: #FF66CC
  @onEscape: self:hide()

  Label
    id: infoLabel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text: Adicione players como Friend (F verde) ou Enemy (E vermelho)
    text-align: center
    text-wrap: true
    text-auto-resize: true
    font: verdana-11px-rounded
    color: #AADDFF
    margin-top: 2

  TextEdit
    id: nameInput
    anchors.top: infoLabel.bottom
    anchors.left: parent.left
    margin-top: 8
    margin-left: 4
    height: 22
    width: 200

  Button
    id: addFriendBtn
    anchors.top: nameInput.top
    anchors.left: nameInput.right
    margin-left: 6
    height: 22
    width: 80
    color: #00FF66
    text: + Friend

  Button
    id: addEnemyBtn
    anchors.top: nameInput.top
    anchors.left: prev.right
    margin-left: 6
    height: 22
    width: 80
    color: #FF4444
    text: + Enemy

  Button
    id: removeNameBtn
    anchors.top: nameInput.top
    anchors.left: addEnemyBtn.right
    margin-left: 6
    height: 22
    width: 84
    color: #FFAA44
    text: - Remover

  Label
    id: friendsTitle
    anchors.top: nameInput.bottom
    anchors.left: parent.left
    anchors.right: parent.horizontalCenter
    margin-top: 8
    margin-left: 4
    margin-right: 3
    text: Friends
    color: #00FF66
    font: verdana-11px-rounded
    text-align: center

  ScrollablePanel
    id: friendsListPanel
    anchors.top: friendsTitle.bottom
    anchors.left: parent.left
    anchors.right: friendsScrollBar.left
    anchors.bottom: closeButton.top
    margin-top: 3
    margin-bottom: 6
    margin-left: 4
    margin-right: 3
    border: 1 #444444
    background-color: #00000033
    vertical-scrollbar: friendsScrollBar
    layout:
      type: verticalBox
      fit-children: false
      spacing: 2

  VerticalScrollBar
    id: friendsScrollBar
    anchors.top: friendsListPanel.top
    anchors.bottom: friendsListPanel.bottom
    anchors.right: parent.horizontalCenter
    margin-right: 3
    step: 20
    pixels-scroll: true

  Label
    id: enemiesTitle
    anchors.top: nameInput.bottom
    anchors.left: parent.horizontalCenter
    anchors.right: parent.right
    margin-top: 8
    margin-left: 3
    margin-right: 4
    text: Enemies
    color: #FF4444
    font: verdana-11px-rounded
    text-align: center

  ScrollablePanel
    id: enemiesListPanel
    anchors.top: enemiesTitle.bottom
    anchors.left: parent.horizontalCenter
    anchors.right: enemiesScrollBar.left
    anchors.bottom: closeButton.top
    margin-top: 3
    margin-bottom: 6
    margin-left: 3
    margin-right: 4
    border: 1 #444444
    background-color: #00000033
    vertical-scrollbar: enemiesScrollBar
    layout:
      type: verticalBox
      fit-children: false
      spacing: 2

  VerticalScrollBar
    id: enemiesScrollBar
    anchors.top: enemiesListPanel.top
    anchors.bottom: enemiesListPanel.bottom
    anchors.right: parent.right
    margin-right: 4
    step: 20
    pixels-scroll: true

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-right: 5
    margin-bottom: 5
  ]], rootW)
    FriendsWindow:hide()

    local friendsListPanel = FriendsWindow.friendsListPanel
    local enemiesListPanel = FriendsWindow.enemiesListPanel
    local input = FriendsWindow.nameInput
    local refreshList

    local function makeRow(name, kind)
      local parentList = (kind == "friends") and friendsListPanel or enemiesListPanel
      local row = g_ui.createWidget("Panel", parentList)
      row:setHeight(24)
      row:setBackgroundColor("alpha")
      row:addAnchor(AnchorLeft, "parent", AnchorLeft)
      row:addAnchor(AnchorRight, "parent", AnchorRight)

      local removeBtn = g_ui.createWidget("Button", row)
      removeBtn:setId("feRemoveBtn")
      removeBtn:addAnchor(AnchorRight, "parent", AnchorRight)
      removeBtn:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
      removeBtn:setMarginRight(6)
      removeBtn:setWidth(20)
      removeBtn:setHeight(18)
      removeBtn:setText("X")
      removeBtn:setColor("#FF5555")
      removeBtn:setTooltip("Remover da lista")

      local senseBtn = g_ui.createWidget("Button", row)
      senseBtn:setId("feSenseBtn")
      senseBtn:addAnchor(AnchorRight, "feRemoveBtn", AnchorLeft)
      senseBtn:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
      senseBtn:setMarginRight(6)
      senseBtn:setWidth(56)
      senseBtn:setHeight(18)
      senseBtn:setText("Sense")
      senseBtn:setColor("#AADDFF")
      senseBtn:setTooltip("Dar sense automatico nesse nome")

      local nameLbl = g_ui.createWidget("UILabel", row)
      nameLbl:setId("feNameLbl")
      nameLbl:addAnchor(AnchorLeft, "parent", AnchorLeft)
      nameLbl:addAnchor(AnchorRight, "feSenseBtn", AnchorLeft)
      nameLbl:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
      nameLbl:setMarginLeft(6)
      nameLbl:setMarginRight(6)
      nameLbl:setHeight(18)
      nameLbl:setFont("verdana-11px-rounded")
      nameLbl:setTextAutoResize(false)
      nameLbl:setTextWrap(false)
      nameLbl:setTextAlign(AlignLeft)
      if kind == "friends" then
        nameLbl:setColor("#00FF66")
      else
        nameLbl:setColor("#FF4444")
      end
      nameLbl:setText(name)
      nameLbl:setTooltip(name)

      removeBtn.onClick = function()
        if kind == "friends" then
          feRemoveFriend(name)
        else
          feRemoveEnemy(name)
        end
        refreshList()
        if feRefreshAllMarks then pcall(feRefreshAllMarks) end
      end

      senseBtn.onClick = function()
        if storage and storage.senseNames then
          storage.senseNames.lastName = name
          storage.senseNames.targetName = name
        end
        say('sense "' .. name)
      end

      return row
    end

    refreshList = function()
      friendsListPanel:destroyChildren()
      enemiesListPanel:destroyChildren()
      local friends = storage.friends_enemies.friends or {}
      local enemies = storage.friends_enemies.enemies or {}
      if #friends == 0 and #enemies == 0 then
        local empty = g_ui.createWidget("UILabel", friendsListPanel)
        empty:setText("(lista vazia)")
        empty:setColor("gray")
        empty:setFont("verdana-11px-rounded")
        empty:setTextAlign(AlignCenter)
        empty:setHeight(24)
        return
      end
      for _, nm in ipairs(friends) do makeRow(nm, "friends") end
      for _, nm in ipairs(enemies) do makeRow(nm, "enemies") end
    end

    local function addNames(kind)
      local txt = input:getText() or ""
      local names = string.split(txt, ",")
      for _, n in ipairs(names) do
        local nm = n:trim()
        if nm:len() > 0 then
          if kind == "friends" then
            feRemoveEnemy(nm)
            feAddFriend(nm)
          else
            feRemoveFriend(nm)
            feAddEnemy(nm)
          end
        end
      end
      input:setText("")
      refreshList()
      if feRefreshAllMarks then pcall(feRefreshAllMarks) end
    end

    local function removeNames()
      local txt = input:getText() or ""
      local names = string.split(txt, ",")
      for _, n in ipairs(names) do
        local nm = n:trim()
        if nm:len() > 0 then
          feRemoveFriend(nm)
          feRemoveEnemy(nm)
        end
      end
      input:setText("")
      refreshList()
      if feRefreshAllMarks then pcall(feRefreshAllMarks) end
    end

    FriendsWindow.addFriendBtn.onClick = function() addNames("friends") end
    FriendsWindow.addEnemyBtn.onClick = function() addNames("enemies") end
    FriendsWindow.removeNameBtn.onClick = removeNames

    input.onKeyPress = function(widget, keyCode, keyboardModifiers)
      if keyCode == 5 then
        addNames("friends")
        return true
      end
      return false
    end

    FriendsWindow.closeButton.onClick = function()
      FriendsWindow:hide()
    end

    friendsUI.editFriends.onClick = function()
      refreshList()
      FriendsWindow:show()
      FriendsWindow:raise()
      FriendsWindow:focus()
    end

    refreshFriendsList = refreshList
    refreshList()
  end
end

UI.Separator()

-- ===== Dano total acumulado (apenas tracking interno, sem spam) =====
local TotalDamage = 0
local LastDamageTime = 0

onTextMessage(function(Mode, Text)
    if string.find(Text, "due to your attack") then
        local Damage = tonumber(string.match(Text, "%d+"))
        if Damage then
            TotalDamage = TotalDamage + Damage
            LastDamageTime = now
        end
    end
end)

-- Reset dano acumulado apos 10s sem atacar (silencioso)
macro(1000, function()
    if TotalDamage > 0 and LastDamageTime > 0 and (now - LastDamageTime) > 10000 then
        TotalDamage = 0
        LastDamageTime = 0
    end
end)

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
