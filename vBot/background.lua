setDefaultTab("Bg")

local ConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
local BG_PATH = "/bot/" .. ConfigName .. "/img/"

storage.bgPlayer = storage.bgPlayer or {
    currentBG = nil
}

local selectedBG = nil
local selectedBGWidget = nil

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
  height: 185

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

  Label
    id: currentBG
    anchors.top: controls.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: --
    text-align: center
    font: verdana-11px-rounded
    color: white
    margin-top: 5
]])

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
    if g_resources.fileExists(path) then
        modules.game_bot.botWindow.contentsPanel:setImageSource(path)
        storage.bgPlayer.currentBG = file
        bgUI.currentBG:setText("Atual: " .. file)
        bgUI.currentBG:setColor("#00ff00")
    else
        bgUI.currentBG:setText("Erro: arquivo nao encontrado")
        bgUI.currentBG:setColor("red")
    end
end

function clearBG()
    modules.game_bot.botWindow.contentsPanel:setImageSource("")
    storage.bgPlayer.currentBG = nil
    bgUI.currentBG:setText("--")
    bgUI.currentBG:setColor("white")
end

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

-- Aplica o BG salvo ao carregar
if storage.bgPlayer.currentBG then
    schedule(500, function()
        applyBG(storage.bgPlayer.currentBG)
    end)
end