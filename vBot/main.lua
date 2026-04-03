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
      schedule(1500, function()
        widget:setText("Salvar Tudo")
        widget:setColor("#00FF88")
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

  -- Funcao para limpar storage do perfil (para perfis novos)
  local function clearProfileStorage()
    storage.esp_fugas_list = {}
    storage.esp_fugas_widgets_show = {}
    storage.esp_fugas_widgets_pos = {}
    storage.esp_trap_list = {}
    storage.esp_combo_slots = {}
    storage.esp_combo_selected = 1
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
    -- Combos (5 slots)
    data.esp_combo_slots = deepCopy(storage.esp_combo_slots or {})
    data.esp_combo_selected = storage.esp_combo_selected or 1
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
    if data.esp_combo_slots then
      storage.esp_combo_slots = deepCopy(data.esp_combo_slots)
      storage.esp_combo_selected = data.esp_combo_selected or 1
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
    end
    if data.esp_buffs_list then storage.esp_buffs_list = deepCopy(data.esp_buffs_list) end
    if data.esp_ataque_list then storage.esp_ataque_list = deepCopy(data.esp_ataque_list) end
    if data.esp_stack_list then storage.esp_stack_list = deepCopy(data.esp_stack_list) end
    if data.esp_retas_list then storage.esp_retas_list = deepCopy(data.esp_retas_list) end
    if data.esp_perseguir_list then storage.esp_perseguir_list = deepCopy(data.esp_perseguir_list) end
    if data.esp_auto_kai then storage.esp_auto_kai = deepCopy(data.esp_auto_kai) end
    if data.ingame_hotkeys ~= nil then storage.ingame_hotkeys = data.ingame_hotkeys end
    if data.bgPlayer then storage.bgPlayer = deepCopy(data.bgPlayer) end
    if data.esp_genjutsu_list then storage.esp_genjutsu_list = deepCopy(data.esp_genjutsu_list) end
    if data.esp_anti_burst ~= nil then storage.esp_anti_burst = data.esp_anti_burst end

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
