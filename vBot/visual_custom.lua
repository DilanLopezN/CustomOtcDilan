-- =============================================
-- Visual Customization System
-- Cor global, botoes, tabs, macros, separadores
-- =============================================

setDefaultTab("Bg")

storage.visualCustom = storage.visualCustom or {
    corText = "#00AAFF",
    styleButtons = true,
    styleTabs = true,
    hideSeparators = true,
    styleMacros = true
}

corText = storage.visualCustom.corText or "#00AAFF"

local vcUI = setupUI([[
Panel
  height: 175

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text: Visual Customization
    text-align: center
    font: verdana-11px-rounded
    color: orange

  Panel
    id: colorRow
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 22
    margin-top: 5

    Label
      id: colorLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Cor:
      font: verdana-11px-rounded
      color: white
      width: 30

    TextEdit
      id: colorInput
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      width: 75
      height: 20
      margin-left: 3
      font: verdana-11px-rounded

    Button
      id: applyColor
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Aplicar
      width: 50
      height: 20
      margin-left: 5

    Label
      id: colorPreview
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text:  ##
      font: verdana-11px-rounded
      width: 25
      margin-left: 3

  Panel
    id: presetRow
    anchors.top: colorRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 22
    margin-top: 3

    Button
      id: c1
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Azul
      width: 38
      height: 18

    Button
      id: c2
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Verm
      width: 38
      height: 18
      margin-left: 2

    Button
      id: c3
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Verde
      width: 38
      height: 18
      margin-left: 2

    Button
      id: c4
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Rosa
      width: 38
      height: 18
      margin-left: 2

    Button
      id: c5
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Roxo
      width: 38
      height: 18
      margin-left: 2

    Button
      id: c6
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Ouro
      width: 38
      height: 18
      margin-left: 2

  BotSwitch
    id: switchButtons
    anchors.top: presetRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: Estilizar Botoes
    height: 18
    margin-top: 5

  BotSwitch
    id: switchTabs
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: Estilizar Tabs
    height: 18
    margin-top: 3

  BotSwitch
    id: switchSeparators
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: Esconder Separadores
    height: 18
    margin-top: 3

  BotSwitch
    id: switchMacros
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: Estilizar Macros (cor dinamica)
    height: 18
    margin-top: 3

]])

vcUI.colorRow.colorInput:setText(corText)
vcUI.colorRow.colorInput:setColor(corText)
vcUI.colorRow.colorPreview:setColor(corText)
vcUI.switchButtons:setOn(storage.visualCustom.styleButtons)
vcUI.switchTabs:setOn(storage.visualCustom.styleTabs)
vcUI.switchSeparators:setOn(storage.visualCustom.hideSeparators)
vcUI.switchMacros:setOn(storage.visualCustom.styleMacros)

-- Preset colors
local colorPresets = {
    { id = "c1", color = "#00AAFF" },  -- Azul
    { id = "c2", color = "#FF3333" },  -- Vermelho
    { id = "c3", color = "#00FF88" },  -- Verde
    { id = "c4", color = "#FF69B4" },  -- Rosa
    { id = "c5", color = "#AA44FF" },  -- Roxo
    { id = "c6", color = "#FFD700" },  -- Ouro
}

-- Set preset button colors
for _, preset in ipairs(colorPresets) do
    local btn = vcUI.presetRow[preset.id]
    if btn then
        btn:setColor(preset.color)
    end
end

-- =============================================
-- Apply functions
-- =============================================

local function applyButtonStyle()
    if not storage.visualCustom.styleButtons then return end

    -- Window title color
    modules.game_bot.botWindow:setColor(corText)

    -- Config ComboBox
    modules.game_bot.contentsPanel.config:setColor(corText)
    modules.game_bot.contentsPanel.config:setImageSource("")
    modules.game_bot.contentsPanel.config:setBackgroundColor("alpha")
    modules.game_bot.contentsPanel.config:setBorderColor(corText)

    -- Edit button
    modules.game_bot.contentsPanel.editConfig:setImageSource("")
    modules.game_bot.contentsPanel.editConfig:setColor(corText)
    modules.game_bot.contentsPanel.editConfig:setBorderColor(corText)

    -- Enable button
    modules.game_bot.contentsPanel.enableButton:setImageSource("")
end

local function applyTabStyle()
    if not storage.visualCustom.styleTabs then return end

    local botTabs = modules.game_bot.contentsPanel and modules.game_bot.contentsPanel.botTabs
    if botTabs and botTabs.tabs then
        for _, tab in pairs(botTabs.tabs) do
            tab:setStyle("CustomTabBarButton")
            tab:setColor(corText)
            tab:setBorderColor(corText)
        end
    end
end

local function applySeparatorHide()
    if not storage.visualCustom.hideSeparators then return end

    if modules.game_bot.contentsPanel then
        for _, child in pairs(modules.game_bot.contentsPanel:getChildren()) do
            if child:getId():match("^widget%d+$") then
                child:hide()
            end
        end
    end
end

-- Style BotSwitch buttons: transparent background, green when on, wine when off
local function styleBotSwitch(widget)
    widget:setImageSource("")
    widget:setBackgroundColor("alpha")
    if widget:isOn() then
        widget:setColor("#00FF00")
        widget:setBorderColor("#00FF00")
    else
        widget:setColor("#800020")
        widget:setBorderColor("#800020")
    end
end

-- Style regular Button: transparent background, keep text color
local function styleButton(widget)
    widget:setImageSource("")
    widget:setBackgroundColor("alpha")
    widget:setBorderColor(corText)
end

-- Recursively apply transparent style to all buttons in a widget tree
local function applyTransparentRecursive(widget)
    if not widget then return end
    local className = widget:getClassName()

    if className == "BotSwitch" or className == "UIBotSwitch" then
        styleBotSwitch(widget)
    elseif className == "UIButton" or className == "Button" then
        styleButton(widget)
    end

    if widget.getChildren then
        for _, child in pairs(widget:getChildren()) do
            applyTransparentRecursive(child)
        end
    end
end

function applyTransparentBotButtons()
    -- Style buttons in the bot panel content
    local botPanel = modules.game_bot.botWindow.contentsPanel.botPanel
    if botPanel then
        local content = botPanel:recursiveGetChildById("content")
        if content then
            applyTransparentRecursive(content)
        end
    end

    -- Style buttons in all open windows (EspeciaisWindow, PerfisWindow, etc.)
    local rootWidget = g_ui.getRootWidget()
    if rootWidget then
        for _, child in pairs(rootWidget:getChildren()) do
            local className = child:getClassName()
            if className == "UIWindow" or className == "MainWindow" or className == "UIMainWindow" then
                applyTransparentRecursive(child)
            end
        end
    end
end

-- Global function: style all macro BotSwitches with dynamic color
function applyMacrosBorder()
    if not storage.visualCustom.styleMacros then return end

    local content = modules.game_bot.botWindow.contentsPanel.botPanel:recursiveGetChildById("content")
    if not content then return end
    for _, rootW in pairs(content:getChildren()) do
        if rootW:getClassName() ~= "UICheckBox" then
            rootW:setImageSource()
            rootW:setColor(rootW:isOn() and corText or "white")
            rootW.onMousePress = function(widget, mousePos, mouseButton)
                schedule(200, function()
                    widget:setColor(widget:isOn() and corText or "white")
                end)
            end
        end
    end
end

-- Aplicar corText aos botoes/labels principais (ESPECIAIS, Macro Delay, PERFIS)
local function applyMainButtonColors()
    if especiaisButton then
        especiaisButton:setColor(corText)
    end
    if macroDelayLabel then
        macroDelayLabel:setColor(corText)
    end
    if perfisButton then
        perfisButton:setColor(corText)
    end
end

function applyAllVisuals()
    applyButtonStyle()
    applySeparatorHide()
    applyMainButtonColors()
    -- Tabs need a small delay since they may not be fully loaded
    schedule(200, function()
        applyTabStyle()
    end)
    schedule(400, function()
        applyTransparentBotButtons()
    end)
end

-- =============================================
-- Color change function (used by Apply + presets)
-- =============================================

local function changeColor(newColor)
    if not newColor or newColor:len() < 4 then return end
    corText = newColor
    storage.visualCustom.corText = newColor
    vcUI.colorRow.colorInput:setText(newColor)
    vcUI.colorRow.colorInput:setColor(newColor)
    vcUI.colorRow.colorPreview:setColor(newColor)
    applyAllVisuals()
    if storage.visualCustom.styleMacros then
        schedule(300, function()
            applyMacrosBorder()
        end)
    end
    schedule(400, function()
        applyTransparentBotButtons()
    end)
end

-- =============================================
-- UI Event handlers
-- =============================================

vcUI.colorRow.applyColor.onClick = function()
    local newColor = vcUI.colorRow.colorInput:getText()
    changeColor(newColor)
end

-- Preset buttons
for _, preset in ipairs(colorPresets) do
    local btn = vcUI.presetRow[preset.id]
    if btn then
        btn.onClick = function()
            changeColor(preset.color)
        end
    end
end

vcUI.switchButtons.onClick = function(widget)
    storage.visualCustom.styleButtons = widget:isOn()
    if widget:isOn() then
        applyButtonStyle()
    end
end

vcUI.switchTabs.onClick = function(widget)
    storage.visualCustom.styleTabs = widget:isOn()
    if widget:isOn() then
        schedule(100, applyTabStyle)
    end
end

vcUI.switchSeparators.onClick = function(widget)
    storage.visualCustom.hideSeparators = widget:isOn()
    if widget:isOn() then
        applySeparatorHide()
    end
end

vcUI.switchMacros.onClick = function(widget)
    storage.visualCustom.styleMacros = widget:isOn()
    if widget:isOn() then
        schedule(300, applyMacrosBorder)
    end
end

-- Apply on load
schedule(300, function()
    applyAllVisuals()
end)
