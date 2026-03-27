setDefaultTab("Bg")

local ConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
local BG_PATH = "/bot/" .. ConfigName .. "/img/"

storage.bgPlayer = storage.bgPlayer or {
    currentBG = nil,
    opacity = "99",
    bgColor = "#000000"
}

local selectedBG = nil
local selectedBGWidget = nil

-- Opacity presets: AA hex values
local opacityPresets = {
    {label = "100%", value = "FF"},
    {label = "80%",  value = "CC"},
    {label = "60%",  value = "99"},
    {label = "40%",  value = "66"},
    {label = "20%",  value = "33"}
}

local function loadBGFiles()
    local files = {}
    if g_resources.directoryExists(BG_PATH) then
        local allFiles = g_resources.listDirectoryFiles(BG_PATH, false, false)
        for _, file in ipairs(allFiles) do
            local ext = file:split(".")
            ext = ext[#ext]:lower()
            if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "apng" then
                table.insert(files, file)
            end
        end
    end
    return files
end

local bgUI = setupUI([[
Panel
  height: 290

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text: Background Selector
    text-align: center
    font: verdana-11px-rounded
    color: orange

  TextList
    id: bgList
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 100
    margin-top: 5
    vertical-scrollbar: bgScrollBar
    focusable: false

  VerticalScrollBar
    id: bgScrollBar
    anchors.top: bgList.top
    anchors.bottom: bgList.bottom
    anchors.right: bgList.right
    step: 14
    pixels-scroll: true

  Panel
    id: controls
    anchors.top: bgList.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    margin-top: 8

    Button
      id: applyBtn
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Aplicar
      width: 55
      height: 20

    Button
      id: clearBtn
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Limpar
      width: 55
      height: 20
      margin-left: 5

    Button
      id: refreshBtn
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Refresh
      width: 55
      height: 20

  Panel
    id: opacityPanel
    anchors.top: controls.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    margin-top: 5

    Label
      id: opacityLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Opacidade:
      font: verdana-11px-rounded
      color: white
      width: 60

    Button
      id: opDown
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: -
      width: 20
      height: 20
      margin-left: 3

    Label
      id: opValue
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: 60%
      text-align: center
      font: verdana-11px-rounded
      color: orange
      width: 35
      margin-left: 3

    Button
      id: opUp
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: +
      width: 20
      height: 20
      margin-left: 3

  Panel
    id: targetPanel
    anchors.top: opacityPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    margin-top: 3

    BotSwitch
      id: applyWindow
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Janela
      width: 55
      height: 20

    BotSwitch
      id: applyPanel
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Painel
      width: 55
      height: 20
      margin-left: 5

    BotSwitch
      id: applyContents
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Conteudo
      width: 55
      height: 20

  Panel
    id: bgColorPanel
    anchors.top: targetPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    margin-top: 5

    Label
      id: bgColorLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Cor Fundo:
      font: verdana-11px-rounded
      color: white
      width: 65

    TextEdit
      id: bgColorInput
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      width: 75
      height: 20
      margin-left: 3
      font: verdana-11px-rounded

    Button
      id: bgColorApply
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Aplicar
      width: 50
      height: 20
      margin-left: 5

  Label
    id: currentBG
    anchors.top: bgColorPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: --
    text-align: center
    font: verdana-11px-rounded
    color: white
    margin-top: 5
]])

-- Initialize target toggles from storage
storage.bgPlayer.applyWindow = storage.bgPlayer.applyWindow ~= false
storage.bgPlayer.applyPanel = storage.bgPlayer.applyPanel ~= false
storage.bgPlayer.applyContents = storage.bgPlayer.applyContents ~= false

bgUI.targetPanel.applyWindow:setOn(storage.bgPlayer.applyWindow)
bgUI.targetPanel.applyPanel:setOn(storage.bgPlayer.applyPanel)
bgUI.targetPanel.applyContents:setOn(storage.bgPlayer.applyContents)

-- Opacity index management
local currentOpacityIdx = 3 -- default 60%
for i, preset in ipairs(opacityPresets) do
    if preset.value == (storage.bgPlayer.opacity or "99") then
        currentOpacityIdx = i
        break
    end
end
bgUI.opacityPanel.opValue:setText(opacityPresets[currentOpacityIdx].label)

local function selectBGEntry(widget)
    if selectedBGWidget then
        selectedBGWidget:setBackgroundColor("alpha")
        selectedBGWidget:setColor("white")
    end
    selectedBGWidget = widget
    selectedBG = widget.file
    widget:setBackgroundColor("#ffffff33")
    widget:setColor("orange")
end

local function refreshBGList()
    bgUI.bgList:destroyChildren()
    selectedBG = nil
    selectedBGWidget = nil

    local files = loadBGFiles()

    if #files == 0 then
        local label = g_ui.createWidget("Label", bgUI.bgList)
        label:setText("Pasta: " .. BG_PATH)
        label:setColor("gray")
        label:setFont("verdana-11px-rounded")
        return
    end

    for _, file in ipairs(files) do
        local label = g_ui.createWidget("Label", bgUI.bgList)
        label:setText(file)
        label:setFont("verdana-11px-rounded")
        label:setColor("white")
        label:setHeight(16)
        label:setTextOffset({x = 3, y = 0})
        label.file = file

        label.onMouseRelease = function(widget, mousePos, mouseButton)
            if mouseButton == MouseLeftButton then
                selectBGEntry(widget)
                return true
            end
        end

        label.onDoubleClick = function(widget)
            selectBGEntry(widget)
            applyBG(widget.file)
            return true
        end
    end
end

function applyBG(file)
    local path = BG_PATH .. file
    if not g_resources.fileExists(path) then
        bgUI.currentBG:setText("Erro: arquivo nao encontrado")
        bgUI.currentBG:setColor("red")
        return
    end

    local opacityHex = storage.bgPlayer.opacity or "99"
    local imageColor = "#FFFFFF" .. opacityHex

    -- Apply to botWindow (full window)
    if storage.bgPlayer.applyWindow then
        modules.game_bot.botWindow:setImageSource(path)
        modules.game_bot.botWindow:setImageColor(imageColor)
        modules.game_bot.botWindow:setBackgroundColor(storage.bgPlayer.bgColor or "#000000")
    end

    -- Apply to botPanel (inner content panel)
    if storage.bgPlayer.applyPanel then
        local botPanel = modules.game_bot.contentsPanel.botPanel
        if botPanel then
            botPanel:setImageSource(path)
            botPanel:setImageColor(imageColor)
        end
    end

    -- Apply to contentsPanel (original behavior)
    if storage.bgPlayer.applyContents then
        modules.game_bot.botWindow.contentsPanel:setImageSource(path)
        modules.game_bot.botWindow.contentsPanel:setImageColor(imageColor)
    end

    storage.bgPlayer.currentBG = file
    bgUI.currentBG:setText("Atual: " .. file)
    bgUI.currentBG:setColor("#00ff00")
end

function clearBG()
    -- Clear all targets
    modules.game_bot.botWindow:setImageSource("")
    modules.game_bot.botWindow.contentsPanel:setImageSource("")
    local botPanel = modules.game_bot.contentsPanel.botPanel
    if botPanel then
        botPanel:setImageSource("")
    end

    storage.bgPlayer.currentBG = nil
    bgUI.currentBG:setText("--")
    bgUI.currentBG:setColor("white")
end

-- Opacity controls
bgUI.opacityPanel.opUp.onClick = function()
    if currentOpacityIdx > 1 then
        currentOpacityIdx = currentOpacityIdx - 1
        storage.bgPlayer.opacity = opacityPresets[currentOpacityIdx].value
        bgUI.opacityPanel.opValue:setText(opacityPresets[currentOpacityIdx].label)
        if storage.bgPlayer.currentBG then
            applyBG(storage.bgPlayer.currentBG)
        end
    end
end

bgUI.opacityPanel.opDown.onClick = function()
    if currentOpacityIdx < #opacityPresets then
        currentOpacityIdx = currentOpacityIdx + 1
        storage.bgPlayer.opacity = opacityPresets[currentOpacityIdx].value
        bgUI.opacityPanel.opValue:setText(opacityPresets[currentOpacityIdx].label)
        if storage.bgPlayer.currentBG then
            applyBG(storage.bgPlayer.currentBG)
        end
    end
end

-- Target toggle handlers
bgUI.targetPanel.applyWindow.onClick = function(widget)
    storage.bgPlayer.applyWindow = widget:isOn()
    if not widget:isOn() then
        modules.game_bot.botWindow:setImageSource("")
    end
    if storage.bgPlayer.currentBG then
        applyBG(storage.bgPlayer.currentBG)
    end
end

bgUI.targetPanel.applyPanel.onClick = function(widget)
    storage.bgPlayer.applyPanel = widget:isOn()
    if not widget:isOn() then
        local botPanel = modules.game_bot.contentsPanel.botPanel
        if botPanel then botPanel:setImageSource("") end
    end
    if storage.bgPlayer.currentBG then
        applyBG(storage.bgPlayer.currentBG)
    end
end

bgUI.targetPanel.applyContents.onClick = function(widget)
    storage.bgPlayer.applyContents = widget:isOn()
    if not widget:isOn() then
        modules.game_bot.botWindow.contentsPanel:setImageSource("")
    end
    if storage.bgPlayer.currentBG then
        applyBG(storage.bgPlayer.currentBG)
    end
end

-- Background color input
bgUI.bgColorPanel.bgColorInput:setText(storage.bgPlayer.bgColor or "#000000")

bgUI.bgColorPanel.bgColorApply.onClick = function()
    local newColor = bgUI.bgColorPanel.bgColorInput:getText()
    if newColor and newColor:len() >= 4 then
        storage.bgPlayer.bgColor = newColor
        if storage.bgPlayer.currentBG then
            applyBG(storage.bgPlayer.currentBG)
        else
            -- Aplica cor de fundo mesmo sem imagem
            if storage.bgPlayer.applyWindow then
                modules.game_bot.botWindow:setBackgroundColor(newColor)
            end
        end
        bgUI.bgColorPanel.bgColorInput:setColor(newColor)
    end
end

-- Button handlers
bgUI.controls.applyBtn.onClick = function()
    if selectedBG then
        applyBG(selectedBG)
    else
        bgUI.currentBG:setText("Selecione um background")
        bgUI.currentBG:setColor("yellow")
    end
end

bgUI.controls.clearBtn.onClick = function()
    clearBG()
end

bgUI.controls.refreshBtn.onClick = function()
    refreshBGList()
    bgUI.currentBG:setText("Lista atualizada")
    bgUI.currentBG:setColor("yellow")
end

refreshBGList()

-- Auto-apply saved BG on load
if storage.bgPlayer.currentBG then
    schedule(500, function()
        applyBG(storage.bgPlayer.currentBG)
    end)
end
