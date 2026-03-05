setDefaultTab("Fugas")

UI.Separator()
UI.Label("Sistema de Fugas Automaticas")
UI.Separator()

-- Storage
storage.fugaSpells = storage.fugaSpells or {}
storage.fugaWidgetPos = storage.fugaWidgetPos or {x = 10, y = 150}
storage.fugaIgnoreHp = storage.fugaIgnoreHp or 0

-- Cooldowns em memoria
local fugaCooldowns = {}
local fugaDurations = {}
local fuga5Uses = 0
local fuga5LastUse = 0

-- Widget para mostrar cooldowns na tela
local fugaWidget = setupUI([[
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

fugaWidget:setPosition({x = storage.fugaWidgetPos.x, y = storage.fugaWidgetPos.y})

fugaWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = {x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY()}
    return true
end

fugaWidget.onDragMove = function(widget, mousePos)
    widget:move(mousePos.x - widget.movingReference.x, mousePos.y - widget.movingReference.y)
    return true
end

fugaWidget.onDragLeave = function(widget)
    storage.fugaWidgetPos.x = widget:getX()
    storage.fugaWidgetPos.y = widget:getY()
    return true
end

-- Função para verificar se alguma fuga com await está ativa
local function getActiveAwaitFuga()
    for i, fuga in ipairs(storage.fugaSpells) do
        if fuga.spell and fuga.spell ~= "" and fuga.await then
            local durTime = fugaDurations[i] or 0
            if durTime > 0 and now < durTime then
                return i, fuga
            end
        end
    end
    return nil, nil
end

-- Função para verificar se uma fuga específica está pronta
local function isFugaReady(i, fuga)
    local cdTime = fugaCooldowns[i] or 0
    
    if i == 5 and fuga.multiUse and fuga.multiUse > 1 then
        if fuga5Uses < fuga.multiUse then
            local multiDelay = (fuga.multiDelay or 2) * 1000
            if fuga5Uses == 0 or now >= fuga5LastUse + multiDelay then
                return true
            end
        elseif now >= cdTime then
            fuga5Uses = 0
            fuga5LastUse = 0
            return true
        end
        return false
    end
    
    return now >= cdTime
end

-- Função para usar uma fuga (3x say garantido)
local function useFuga(i, fuga)
    local duration = (fuga.duration or 0) * 1000
    local cd = (fuga.cd or 30) * 1000
    
    say(fuga.spell)
    say(fuga.spell)
    say(fuga.spell)
    
    if i == 5 and fuga.multiUse and fuga.multiUse > 1 then
        fuga5Uses = fuga5Uses + 1
        fuga5LastUse = now
        
        if fuga5Uses >= fuga.multiUse then
            fugaDurations[i] = duration > 0 and (now + duration) or 0
            fugaCooldowns[i] = now + (duration > 0 and duration or 0) + cd
        end
    else
        fugaDurations[i] = duration > 0 and (now + duration) or 0
        fugaCooldowns[i] = now + (duration > 0 and duration or 0) + cd
    end
    
    return true
end

-- Macro principal
macro(50, "Fugas Auto", function()
    if isInPz() then return end
    local hp = hppercent()
    
    local activeAwaitIdx, activeAwaitFuga = getActiveAwaitFuga()
    local ignoreHp = storage.fugaIgnoreHp or 0
    
    -- Se tem fuga await ativa E hp está acima do ignore, respeita o await
    if activeAwaitIdx and activeAwaitFuga and (ignoreHp <= 0 or hp > ignoreHp) then
        return
    end
    
    for i, fuga in ipairs(storage.fugaSpells) do
        if fuga.spell and fuga.spell ~= "" and hp <= (fuga.hp or 100) then
            if isFugaReady(i, fuga) then
                useFuga(i, fuga)
                return
            end
        end
    end
end)

-- Atualizar widget de cooldowns
macro(100, function()
    local lines = {}
    
    for i, fuga in ipairs(storage.fugaSpells) do
        if fuga.spell and fuga.spell ~= "" then
            local cdTime = fugaCooldowns[i] or 0
            local durTime = fugaDurations[i] or 0
            local name = fuga.spell
            local awaitMark = fuga.await and " [A]" or ""
            local status
            
            if i == 5 and fuga.multiUse and fuga.multiUse > 1 then
                local usesLeft = fuga.multiUse - fuga5Uses
                
                if durTime > 0 and now < durTime then
                    status = math.ceil((durTime - now) / 1000) .. "s [ATIVO]"
                elseif cdTime > 0 and now < cdTime then
                    status = math.ceil((cdTime - now) / 1000) .. "s [CD]"
                elseif fuga5Uses > 0 and fuga5Uses < fuga.multiUse then
                    status = usesLeft .. "x [RESTAM]"
                else
                    status = "PRONTO [" .. fuga.multiUse .. "x]"
                end
            else
                if durTime > 0 and now < durTime then
                    status = math.ceil((durTime - now) / 1000) .. "s [ATIVO]"
                elseif cdTime > 0 and now < cdTime then
                    status = math.ceil((cdTime - now) / 1000) .. "s [CD]"
                else
                    status = "PRONTO"
                end
            end
            
            table.insert(lines, name .. awaitMark .. ": " .. status)
        end
    end
    
    if #lines > 0 then
        fugaWidget:setText(table.concat(lines, "\n"))
        fugaWidget:show()
    else
        fugaWidget:hide()
    end
end)

UI.Separator()

-- Campo Ignore HP
UI.Label("Ignorar Await abaixo de HP%:")
UI.TextEdit(tostring(storage.fugaIgnoreHp), function(widget, text)
    storage.fugaIgnoreHp = tonumber(text) or 0
end)

UI.Separator()

-- Função auxiliar para criar campos de fuga
local function createFugaUI(index, defaults)
    storage.fugaSpells[index] = storage.fugaSpells[index] or defaults
    local fuga = storage.fugaSpells[index]
    
    UI.Label("Fuga " .. index .. ":")
    UI.TextEdit(fuga.spell or "", function(widget, text) fuga.spell = text end)
    UI.Label("HP% | Duracao(s) | CD(s):")
    UI.TextEdit(tostring(fuga.hp), function(widget, text) fuga.hp = tonumber(text) or defaults.hp end)
    UI.TextEdit(tostring(fuga.duration), function(widget, text) fuga.duration = tonumber(text) or 0 end)
    UI.TextEdit(tostring(fuga.cd), function(widget, text) fuga.cd = tonumber(text) or 30 end)
    
    local awaitBox = setupUI([[
CheckBox
  id: await]] .. index .. [[

  text: Await
]])
    awaitBox:setChecked(fuga.await or false)
    awaitBox.onCheckChange = function(widget, checked) fuga.await = checked end
end

-- Criar UI das fugas 1-4
createFugaUI(1, {hp = 20, cd = 30, spell = "", duration = 0, await = false})
UI.Separator()
createFugaUI(2, {hp = 35, cd = 30, spell = "", duration = 0, await = false})
UI.Separator()
createFugaUI(3, {hp = 50, cd = 30, spell = "", duration = 0, await = false})
UI.Separator()
createFugaUI(4, {hp = 65, cd = 30, spell = "", duration = 0, await = false})
UI.Separator()

-- Fuga 5 com multi-uso
storage.fugaSpells[5] = storage.fugaSpells[5] or {hp = 80, cd = 30, spell = "", duration = 0, multiUse = 1, multiDelay = 2, await = false}
local fuga5 = storage.fugaSpells[5]

UI.Label("Fuga 5:")
UI.TextEdit(fuga5.spell or "", function(widget, text) fuga5.spell = text end)
UI.Label("HP% | Duracao(s) | CD(s):")
UI.TextEdit(tostring(fuga5.hp), function(widget, text) fuga5.hp = tonumber(text) or 80 end)
UI.TextEdit(tostring(fuga5.duration), function(widget, text) fuga5.duration = tonumber(text) or 0 end)
UI.TextEdit(tostring(fuga5.cd), function(widget, text) fuga5.cd = tonumber(text) or 30 end)
UI.Label("Usos antes do CD | Intervalo(s):")
UI.TextEdit(tostring(fuga5.multiUse), function(widget, text) fuga5.multiUse = tonumber(text) or 1 end)
UI.TextEdit(tostring(fuga5.multiDelay), function(widget, text) fuga5.multiDelay = tonumber(text) or 2 end)

local await5 = setupUI([[
CheckBox
  id: await5
  text: Await
]])
await5:setChecked(fuga5.await or false)
await5.onCheckChange = function(widget, checked) fuga5.await = checked end

UI.Separator()