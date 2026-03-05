setDefaultTab("Ataques")

UI.Separator()
UI.Label("Ataques por HP% do Inimigo")
UI.Separator()

-- Storage
storage.atkSpells = storage.atkSpells or {}

-- Cooldowns
local atkCooldowns = {}
storage.atkWidgetPos = storage.atkWidgetPos or {x = 10, y = 300}

local atkWidget = setupUI([[
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

atkWidget:setPosition({x = storage.atkWidgetPos.x, y = storage.atkWidgetPos.y})

atkWidget.onDragEnter = function(widget, mousePos)
    widget:breakAnchors()
    widget.movingReference = {
        x = mousePos.x - widget:getX(),
        y = mousePos.y - widget:getY()
    }
    return true
end

atkWidget.onDragMove = function(widget, mousePos)
    widget:move(
        mousePos.x - widget.movingReference.x,
        mousePos.y - widget.movingReference.y
    )
    return true
end

atkWidget.onDragLeave = function(widget, pos)
    storage.atkWidgetPos.x = widget:getX()
    storage.atkWidgetPos.y = widget:getY()
    return true
end


macro(100, function()
    local text = ""

    for i, atk in ipairs(storage.atkSpells) do
        if atk.spell and atk.spell ~= "" then
            local cdTime = atkCooldowns[i] or 0
            local remaining = math.max(0, math.ceil((cdTime - now) / 1000))

          local name = atk.name and atk.name ~= "" and atk.name or atk.spell
          text = text .. name .. ": " .. remaining .. "s\n"

        end
    end

    if text ~= "" then
        atkWidget:setText(text:sub(1, -2))
        atkWidget:show()
    else
        atkWidget:hide()
    end
end)


-- Macro principal
macro(100, "Ataque HP%", function()
    if not g_game.isAttacking() then return end
    
    local target = g_game.getAttackingCreature()
    if not target or not target:isPlayer() then return end
    
    local targetHp = target:getHealthPercent()
    
    for i, atk in ipairs(storage.atkSpells) do
        if atk.spell and atk.spell ~= "" and targetHp <= atk.hp then
            if now >= (atkCooldowns[i] or 0) then
                say(atk.spell)
                atkCooldowns[i] = now + (atk.cd * 1000)
                return
            end
        end
    end
end)

-- Ataque 1
UI.Label("Ataque 1 - Jutsu | HP% | CD(s):")
UI.TextEdit(storage.atkSpells[1] and storage.atkSpells[1].spell or "", function(w, t)
    storage.atkSpells[1] = storage.atkSpells[1] or {hp = 90, cd = 2}
    storage.atkSpells[1].spell = t
end)
UI.TextEdit(storage.atkSpells[1] and tostring(storage.atkSpells[1].hp) or "90", function(w, t)
    storage.atkSpells[1] = storage.atkSpells[1] or {spell = "", cd = 2}
    storage.atkSpells[1].hp = tonumber(t) or 90
end)
UI.TextEdit(storage.atkSpells[1] and tostring(storage.atkSpells[1].cd) or "2", function(w, t)
    storage.atkSpells[1] = storage.atkSpells[1] or {spell = "", hp = 90}
    storage.atkSpells[1].cd = tonumber(t) or 2
end)

UI.Separator()

-- Ataque 2
UI.Label("Ataque 2 - Jutsu | HP% | CD(s):")
UI.TextEdit(storage.atkSpells[2] and storage.atkSpells[2].spell or "", function(w, t)
    storage.atkSpells[2] = storage.atkSpells[2] or {hp = 70, cd = 2}
    storage.atkSpells[2].spell = t
end)
UI.TextEdit(storage.atkSpells[2] and tostring(storage.atkSpells[2].hp) or "70", function(w, t)
    storage.atkSpells[2] = storage.atkSpells[2] or {spell = "", cd = 2}
    storage.atkSpells[2].hp = tonumber(t) or 70
end)
UI.TextEdit(storage.atkSpells[2] and tostring(storage.atkSpells[2].cd) or "2", function(w, t)
    storage.atkSpells[2] = storage.atkSpells[2] or {spell = "", hp = 70}
    storage.atkSpells[2].cd = tonumber(t) or 2
end)

UI.Separator()

-- Ataque 3
UI.Label("Ataque 3 - Jutsu | HP% | CD(s):")
UI.TextEdit(storage.atkSpells[3] and storage.atkSpells[3].spell or "", function(w, t)
    storage.atkSpells[3] = storage.atkSpells[3] or {hp = 50, cd = 2}
    storage.atkSpells[3].spell = t
end)
UI.TextEdit(storage.atkSpells[3] and tostring(storage.atkSpells[3].hp) or "50", function(w, t)
    storage.atkSpells[3] = storage.atkSpells[3] or {spell = "", cd = 2}
    storage.atkSpells[3].hp = tonumber(t) or 50
end)
UI.TextEdit(storage.atkSpells[3] and tostring(storage.atkSpells[3].cd) or "2", function(w, t)
    storage.atkSpells[3] = storage.atkSpells[3] or {spell = "", hp = 50}
    storage.atkSpells[3].cd = tonumber(t) or 2
end)

UI.Separator()

-- Ataque 4
UI.Label("Ataque 4 - Jutsu | HP% | CD(s):")
UI.TextEdit(storage.atkSpells[4] and storage.atkSpells[4].spell or "", function(w, t)
    storage.atkSpells[4] = storage.atkSpells[4] or {hp = 30, cd = 2}
    storage.atkSpells[4].spell = t
end)
UI.TextEdit(storage.atkSpells[4] and tostring(storage.atkSpells[4].hp) or "30", function(w, t)
    storage.atkSpells[4] = storage.atkSpells[4] or {spell = "", cd = 2}
    storage.atkSpells[4].hp = tonumber(t) or 30
end)
UI.TextEdit(storage.atkSpells[4] and tostring(storage.atkSpells[4].cd) or "2", function(w, t)
    storage.atkSpells[4] = storage.atkSpells[4] or {spell = "", hp = 30}
    storage.atkSpells[4].cd = tonumber(t) or 2
end)

UI.Separator()

-- Ataque 5
UI.Label("Ataque 5 - Jutsu | HP% | CD(s):")
UI.TextEdit(storage.atkSpells[5] and storage.atkSpells[5].spell or "", function(w, t)
    storage.atkSpells[5] = storage.atkSpells[5] or {hp = 15, cd = 2}
    storage.atkSpells[5].spell = t
end)
UI.TextEdit(storage.atkSpells[5] and tostring(storage.atkSpells[5].hp) or "15", function(w, t)
    storage.atkSpells[5] = storage.atkSpells[5] or {spell = "", cd = 2}
    storage.atkSpells[5].hp = tonumber(t) or 15
end)
UI.TextEdit(storage.atkSpells[5] and tostring(storage.atkSpells[5].cd) or "2", function(w, t)
    storage.atkSpells[5] = storage.atkSpells[5] or {spell = "", hp = 15}
    storage.atkSpells[5].cd = tonumber(t) or 2
end)

UI.Separator()