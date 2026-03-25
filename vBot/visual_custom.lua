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
    styleMacros = true,
    transparentBotButtons = true
}

corText = storage.visualCustom.corText or "#00AAFF"

local vcUI = setupUI([[
Panel
  height: 151

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

  BotSwitch
    id: switchButtons
    anchors.top: colorRow.bottom
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

  BotSwitch
    id: switchTransparentButtons
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: Botoes Transparentes
    height: 18
    margin-top: 3
]])

vcUI.colorRow.colorInput:setText(corText)
vcUI.switchButtons:setOn(storage.visualCustom.styleButtons)
vcUI.switchTabs:setOn(storage.visualCustom.styleTabs)
vcUI.switchSeparators:setOn(storage.visualCustom.hideSeparators)
vcUI.switchMacros:setOn(storage.visualCustom.styleMacros)
vcUI.switchTransparentButtons:setOn(storage.visualCustom.transparentBotButtons)

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
    if not storage.visualCustom.transparentBotButtons then return end

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

-- Recursively revert transparent style from all buttons in a widget tree
local function revertTransparentRecursive(widget)
    if not widget then return end
    local className = widget:getClassName()

    if className == "BotSwitch" or className == "UIBotSwitch" then
        widget:setStyle("BotSwitch")
    elseif className == "UIButton" or className == "Button" then
        widget:setStyle("Button")
    end

    if widget.getChildren then
        for _, child in pairs(widget:getChildren()) do
            revertTransparentRecursive(child)
        end
    end
end

function revertTransparentBotButtons()
    local botPanel = modules.game_bot.botWindow.contentsPanel.botPanel
    if botPanel then
        local content = botPanel:recursiveGetChildById("content")
        if content then
            revertTransparentRecursive(content)
        end
    end

    local rootWidget = g_ui.getRootWidget()
    if rootWidget then
        for _, child in pairs(rootWidget:getChildren()) do
            local className = child:getClassName()
            if className == "UIWindow" or className == "MainWindow" or className == "UIMainWindow" then
                revertTransparentRecursive(child)
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
                macro(200, function()
                    widget:setColor(widget:isOn() and corText or "white")
                end)
            end
        end
    end
end

local function applyAllVisuals()
    applyButtonStyle()
    applySeparatorHide()
    -- Tabs need a small delay since they may not be fully loaded
    schedule(200, function()
        applyTabStyle()
    end)
    if storage.visualCustom.transparentBotButtons then
        schedule(400, function()
            applyTransparentBotButtons()
        end)
    end
end

-- =============================================
-- UI Event handlers
-- =============================================

vcUI.colorRow.applyColor.onClick = function()
    local newColor = vcUI.colorRow.colorInput:getText()
    if newColor and newColor:len() >= 4 then
        corText = newColor
        storage.visualCustom.corText = newColor
        applyAllVisuals()
        if storage.visualCustom.styleMacros then
            schedule(300, function()
                applyMacrosBorder()
            end)
        end
        if storage.visualCustom.transparentBotButtons then
            schedule(400, function()
                applyTransparentBotButtons()
            end)
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

vcUI.switchTransparentButtons.onClick = function(widget)
    storage.visualCustom.transparentBotButtons = widget:isOn()
    if widget:isOn() then
        schedule(300, applyTransparentBotButtons)
    else
        schedule(300, revertTransparentBotButtons)
    end
end

-- Apply on load
schedule(300, function()
    applyAllVisuals()
end)

-- Recurring macro to keep transparent buttons applied (handles tab switches and late-loaded widgets)
macro(1000, function()
    if storage.visualCustom.transparentBotButtons then
        applyTransparentBotButtons()
    end
end)
