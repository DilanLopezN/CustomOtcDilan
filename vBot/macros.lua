-- Criar a tab "Macros"
setDefaultTab("Macros")

UI.Separator()

addButton(200, "Equip Senju", function()
    -- Equip Senju Helmet
    schedule(0, function() 
        moveToSlot(12898, 1)  -- Senju Helmet
    end)

    -- Equip Senju Armor
    schedule(1500, function() 
        moveToSlot(12916, 4)  -- Senju Armor
    end)

    -- Equip Senju Legs
    schedule(4000, function() 
        moveToSlot(12934, 7)  -- Senju Legs
    end)

    -- Equip Senju Boots
    schedule(6000, function() 
        moveToSlot(12952, 8)  -- Senju Boots
    end)
end)


addButton(200, "Equip Kurama", function()
    -- Equip Senju Helmet
    schedule(0, function() 
        moveToSlot(13222, 1)  
    end)

    -- Equip Senju Armor
    schedule(1500, function() 
        moveToSlot(13294, 4)  
    end)

    -- Equip Senju Legs
    schedule(4000, function() 
        moveToSlot(13240, 7)  
    end)

    -- Equip Senju Boots
    schedule(6000, function() 
        moveToSlot(13258, 8)  
    end)
end)

UI.Separator()

macro(1, 'virar target', function()
  if not g_game.isAttacking() then return end
  local tt = g_game.getAttackingCreature()
  local tx = tt:getPosition().x
  local ty = tt:getPosition().y
  local dir = player:getDirection()
  local tdx = math.abs(tx - pos().x)
  local tdy = math.abs(ty - pos().y)
  if (tdy >= 2 and tdx >= 2) or tdx > 7 or tdy > 7 then return end 
  if tdy >= tdx then
    if ty > pos().y then
      if dir ~= 2 then
        return turn(2)
      end
    else
      if dir ~= 0 then
        return turn(0)
      end
    end
  else
    if tx > pos().x then
      if dir ~= 1 then
        return turn(1)
      end
    else
      if dir ~= 3 then
        return turn(3)
      end
    end
  end
end)

-- Agora todos os elementos UI/macros abaixo ficarão nessa tab
UI.Separator()

-- ==========================================
-- AUTO JUMP ISOLADO E CORRIGIDO
-- ============================================

local autoJump = {}

-- Direções
autoJump.extraJumpDirections = {
    ['W'] = {x = 0, y = -1, dir = 0},
    ['D'] = {x = 1, y = 0, dir = 1},
    ['S'] = {x = 0, y = 1, dir = 2},
    ['A'] = {x = -1, y = 0, dir = 3},
    ['Up'] = {x = 0, y = -1, dir = 0},
    ['Right'] = {x = 1, y = 0, dir = 1},
    ['Down'] = {x = 0, y = 1, dir = 2},
    ['Left'] = {x = -1, y = 0, dir = 3}
}

-- Tempo parado
autoJump.standingTime = now

onPlayerPositionChange(function(newPos, oldPos)
    autoJump.standingTime = now
end)

autoJump.standTime = function()
    return now - autoJump.standingTime
end

-- Detectar mobile
local isMobile = modules._G and modules._G.g_app and modules._G.g_app.isMobile and modules._G.g_app.isMobile() or false

-- Config mobile (só se for mobile)
if isMobile then
    local keypad = g_ui.getRootWidget():recursiveGetChildById("keypad")
    if keypad and keypad.pointer then
        autoJump.pointer = keypad.pointer
        autoJump.DIRS = {
            {highest = {x = -16, y = 29}, lowest = {x = -75, y = -30}, info = {dir = 0, x = 0, y = -1}},
            {highest = {x = 29, y = 75}, lowest = {x = -30, y = 15}, info = {dir = 1, x = 1, y = 0}},
            {highest = {x = 75, y = 29}, lowest = {x = 16, y = -30}, info = {dir = 2, x = 0, y = 1}},
            {highest = {x = 29, y = -15}, lowest = {x = -30, y = -75}, info = {dir = 3, x = -1, y = 0}}
        }
    end
end

autoJump.getPressedKeys = function()
    local wasdWalking = modules.game_walking and modules.game_walking.wsadWalking or false
    
    -- Mobile
    if isMobile and autoJump.pointer and autoJump.DIRS then
        local marginTop = autoJump.pointer:getMarginTop()
        local marginLeft = autoJump.pointer:getMarginLeft()
        for _, value in ipairs(autoJump.DIRS) do
            if (marginTop >= value.lowest.x and marginTop <= value.highest.x) and
               (marginLeft >= value.lowest.y and marginLeft <= value.highest.y) then
                return value.info
            end
        end
    else
        -- PC
        for walkKey, value in pairs(autoJump.extraJumpDirections) do
            if modules.corelib.g_keyboard.isKeyPressed(walkKey) then
                if #walkKey > 1 or wasdWalking then
                    return value
                end
            end
        end
    end
    return nil
end

-- Macro principal
autoJump.macro = macro(100, "Auto Jump", function()
    if stopCombo and stopCombo - 100 >= now then return end
    if player:isWalking() or autoJump.standTime() <= 100 then return end
    
    local values = autoJump.getPressedKeys()
    if not values then return end
    
    local currentPos = pos()
    turn(values.dir)
    currentPos.x = currentPos.x + values.x
    currentPos.y = currentPos.y + values.y
    
    local tile = g_map.getTile(currentPos)
    say(tile and tile:isFullGround() and "Jump up" or "Jump Down")
end)

-- Ícone
addIcon("autoJumpIcon", {item = 13278, text = "Jump"}, autoJump.macro)

UI.Separator()


-- ============================================
-- BUGMAP ISOLADO
-- ============================================

UI.Separator()


-- Funções auxiliares do BugMap
local function bugmapKeys(x)
    return modules.corelib.g_keyboard.isKeyPressed(x)
end

local function bugmapGetClosest(tbl)
    local closest
    if tbl and tbl[1] then
        for _, x in pairs(tbl) do
            if not closest or getDistanceBetween(closest:getPosition(), player:getPosition()) > getDistanceBetween(x:getPosition(), player:getPosition()) then
                closest = x
            end
        end
    end
    if closest then
        return getDistanceBetween(closest:getPosition(), player:getPosition())
    end
    return false
end

local function bugmapHasNonWalkable(direc)
    local tabela = {}
    for i = 1, #direc do
        local tile = g_map.getTile({
            x = player:getPosition().x + direc[i][1],
            y = player:getPosition().y + direc[i][2],
            z = player:getPosition().z
        })
        if tile and (not tile:isWalkable() or tile:getTopThing():getName():len() > 0) and tile:canShoot() then
            table.insert(tabela, tile)
        end
    end
    return tabela
end

local function bugmapGetClosestBetween(x, y)
    if x or y then
        if x and not y then return 1
        elseif y and not x then return 2
        end
    else
        return false
    end
    return x < y and 1 or 2
end

local function bugmapGetDash(dir)
    local dirs
    local tiles = {}
    if not dir then return false end
    
    if dir == 'n' then
        dirs = {{0, -1}, {0, -2}, {0, -3}, {0, -4}, {0, -5}, {0, -6}, {0, -7}, {0, -8}}
    elseif dir == 's' then
        dirs = {{0, 1}, {0, 2}, {0, 3}, {0, 4}, {0, 5}, {0, 6}, {0, 7}, {0, 8}}
    elseif dir == 'w' then
        dirs = {{-1, 0}, {-2, 0}, {-3, 0}, {-4, 0}, {-5, 0}, {-6, 0}}
    elseif dir == 'e' then
        dirs = {{1, 0}, {2, 0}, {3, 0}, {4, 0}, {5, 0}, {6, 0}}
    end
    
    for i = 1, #dirs do
        local tile = g_map.getTile({
            x = player:getPosition().x + dirs[i][1],
            y = player:getPosition().y + dirs[i][2],
            z = player:getPosition().z
        })
        if tile and tile:isWalkable() and tile:canShoot() then
            table.insert(tiles, tile)
        end
    end
    
    if not tiles[1] or bugmapGetClosestBetween(bugmapGetClosest(bugmapHasNonWalkable(dirs)), bugmapGetClosest(tiles)) == 1 then
        return false
    end
    return true
end

local function bugmapCheckPos(x, y)
    local xyz = g_game.getLocalPlayer():getPosition()
    xyz.x = xyz.x + x
    xyz.y = xyz.y + y
    local tile = g_map.getTile(xyz)
    if tile then
        return g_game.use(tile:getTopUseThing())
    end
    return false
end

-- Macro BugMap
bugmapMacro = macro(20, "BugMap", function()
    if not modules.game_walking.wsadWalking then return end
    if modules.corelib.g_keyboard.isCtrlPressed() then return end
    
    if bugmapKeys('W') then
        if bugmapGetDash('n') then
            g_game.walk(0)
        else
            bugmapCheckPos(0, -5)
        end
    elseif bugmapKeys('E') then
        bugmapCheckPos(3, -3)
    elseif bugmapKeys('D') then
        if bugmapGetDash('e') then
            g_game.walk(1)
        else
            bugmapCheckPos(5, 0)
        end
    elseif bugmapKeys('C') then
        bugmapCheckPos(3, 3)
    elseif bugmapKeys('S') then
        if bugmapGetDash('s') then
            g_game.walk(2)
        else
            bugmapCheckPos(0, 5)
        end
    elseif bugmapKeys('Z') then
        bugmapCheckPos(-3, 3)
    elseif bugmapKeys('A') then
        if bugmapGetDash('w') then
            g_game.walk(3)
        else
            bugmapCheckPos(-5, 0)
        end
    elseif bugmapKeys('Q') then
        bugmapCheckPos(-3, -3)
    end
end)

-- Ícone
addIcon("bugmapIcon", {item = 12959, text = "BugMAP"}, bugmapMacro)

UI.Separator()


macro(100, "Combo Madara", function()
    if g_game.isAttacking() then
        say("shin tengai shinsei")
        say("tengai yasaka no magatama")
        say("tengai shinsei")
        say("susano attack")
        say("mokuton mosayko no jutsu")
        say("katon endan")
        say("suiton suijinheki no jutsu")
        say("katon booru kaki")
    end
end)


UI.Separator()
--------------------------------------------------
-- =============== AUTO BUFF =====================
--------------------------------------------------
storage.buffSpells = storage.buffSpells or {
    [1] = { spell = "", enabled = true },
    [2] = { spell = "", enabled = true }
}

-- Cooldowns por buff (em segundos)
local BUFF_CDS = {
    [1] = 15,
    [2] = 18
}

local buffCooldowns = {}
local lastBuffUsed = 0

--------------------------------------------------
-- Widget
--------------------------------------------------

storage.buffWidgetPos = storage.buffWidgetPos or {x = 10, y = 200}

local buffWidget = setupUI([[
UIWidget
  background-color: black
  font: verdana-11px-rounded
  opacity: 0.70
  padding: 5 10
  draggable: true
  text-auto-resize: true
]], g_ui.getRootWidget())

buffWidget:setPosition({x = storage.buffWidgetPos.x, y = storage.buffWidgetPos.y})

buffWidget.onDragEnter = function(w, m)
    w:breakAnchors()
    w.movingReference = {x = m.x - w:getX(), y = m.y - w:getY()}
    return true
end

buffWidget.onDragMove = function(w, m)
    w:move(m.x - w.movingReference.x, m.y - w.movingReference.y)
    return true
end

buffWidget.onDragLeave = function(w, pos)
    storage.buffWidgetPos.x = w:getX()
    storage.buffWidgetPos.y = w:getY()
    return true
end

--------------------------------------------------
-- Macro principal (alterna entre buffs)
--------------------------------------------------

macro(200, "Auto Buff", function()
    if isInPz() then return end

    -- Primeiro verifica se algum buff precisa renovar (CD acabou)
    for i = 1, 2 do
        local buff = storage.buffSpells[i]
        if buff.enabled and buff.spell ~= "" then
            if now >= (buffCooldowns[i] or 0) then
                say(buff.spell)
                buffCooldowns[i] = now + (BUFF_CDS[i] * 1000)
                lastBuffUsed = i
                return
            end
        end
    end
end)

--------------------------------------------------
-- Atualização do widget
--------------------------------------------------

macro(100, function()
    local text = ""

    for i = 1, 2 do
        local buff = storage.buffSpells[i]
        if buff.spell ~= "" then
            local cd = buffCooldowns[i] or 0
            local remaining = math.max(0, math.ceil((cd - now) / 1000))
            local status = buff.enabled and "ON" or "OFF"

            text = text .. buff.spell .. ": " .. remaining .. "s [" .. status .. "]\n"
        end
    end

    if text ~= "" then
        buffWidget:setText(text:sub(1, -2))
        buffWidget:show()
    else
        buffWidget:hide()
    end
end)

--------------------------------------------------
-- UI - Buff 1
--------------------------------------------------

UI.Label("Buff 1:")
UI.TextEdit(storage.buffSpells[1].spell, function(w, t)
    storage.buffSpells[1].spell = t
end)

UI.Button("Ativar / Desativar Buff 1", function()
    storage.buffSpells[1].enabled = not storage.buffSpells[1].enabled
end)

UI.Separator()

--------------------------------------------------
-- UI - Buff 2
--------------------------------------------------

UI.Label("Buff 2:")
UI.TextEdit(storage.buffSpells[2].spell, function(w, t)
    storage.buffSpells[2].spell = t
end)

UI.Button("Ativar / Desativar Buff 2", function()
    storage.buffSpells[2].enabled = not storage.buffSpells[2].enabled
end)


UI.Separator()


macro(500, "Chakra Feet", function()
    if hppercent() >= 80 then
      if (stopCombo and stopCombo >= now) then return; end
        if not hasHaste() then
          say("concentrate chakra feet")
          delay(2500)
      end
    end
  end)


  

UI.Separator()
  -- Macro para manter o alvo travado
macro(100, "Hold Target [ESC]", nil, function()
  if g_game.isAttacking() then
    oldTarget = g_game.getAttackingCreature()
  end
  if oldTarget and oldTarget:getPosition() then
    if not g_game.isAttacking() and getDistanceBetween(pos(), oldTarget:getPosition()) <= 8 then
      if oldTarget:getPosition().z == posz() then
        g_game.attack(oldTarget)
      end
    end
  end
end)

UI.Separator()
-- Soltar o alvo ao pressionar ESC
onKeyDown(function(keys)
  if keys == "Escape" then
    oldTarget = nil
    g_game.cancelAttack()
  end
end)

local timeTrack = {
	["ntoultimate"] = 15,
	["ntolost"] = 5,
	["katon"] = 5, -- NTO SPLIT
	["dbolost"] = 2,
	["dragon ball rising"] = 5,
	["dbo galaxy"] = 5,
	["dbo infinity duel"] = 5
}

local storage = tyrBot and tyrBot.storage or storage;

local pzTime = timeTrack[g_game.getWorldName():lower()] or 15
	

os = os or modules.os

if type(storage.battleTracking) ~= "table" or storage.battleTracking[2] ~= player:getId() or (not os and storage.battleTracking[1] - now > pzTime * 60 * 1000) then
    storage.battleTracking = {0, player:getId(), {}}
end 

onTextMessage(function(mode, text)
	text = text:lower()
	if text:find("o assassinato de") or text:find("was not justified") or text:find("o assassinato do")then
		storage.battleTracking[1] = not os and now + (pzTime * 60 * 1000) or os.time() + (pzTime * 60)
		return
	end
	if not text:find("due to your") and not text:find("you deal") then return end
	local spectators = getSpecs or getSpectators;
	for _, spec in ipairs(spectators()) do
		local specName = spec:getName():lower()
		if spec:isPlayer() and text:find(specName) then
			storage.battleTracking[3][specName] = {timeBattle = not os and now + 60000 or os.time() + 60, playerId = spec:getId()}
			break
		end
	end
end)

math.mod = math.mod or function(base, modulus)
	return base % modulus
end

local function doFormatMin(v)
    v = v > 1000 and v / 1000 or v
    local mins = 00
    if v >= 60 then
        mins = string.format("%02.f", math.floor(v / 60))
    end
    local seconds = string.format("%02.f", math.abs(math.floor(math.mod(v, 60))))
    return mins .. ":" .. seconds
end




storage.widgetPos = storage.widgetPos or {}

local pkTimeWidget = setupUI([[
UIWidget
  background-color: black
  opacity: 0.8
  padding: 0 5
  focusable: true
  phantom: false
  draggable: true
]], g_ui.getRootWidget())


pkTimeWidget.onDragEnter = function(widget, mousePos)
	if not (modules.corelib.g_keyboard.isCtrlPressed()) then
		return false
	end
	widget:breakAnchors()
	widget.movingReference = {x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY()}
	return true
end

pkTimeWidget.onDragMove = function(widget, mousePos, moved)
	local parentRect = widget:getParent():getRect()
	local x = math.min(math.max(parentRect.x, mousePos.x - widget.movingReference.x), parentRect.x + parentRect.width - widget:getWidth())
	local y = math.min(math.max(parentRect.y - widget:getParent():getMarginTop(), mousePos.y - widget.movingReference.y), parentRect.y + parentRect.height - widget:getHeight())        
	widget:move(x, y)
	storage.widgetPos["pkTimeWidget"] = {x = x, y = y}
	return true
end

local name = "pkTimeWidget"
storage.widgetPos[name] = storage.widgetPos[name] or {}
pkTimeWidget:setPosition({x = storage.widgetPos[name].x or 50, y = storage.widgetPos[name].y or 50})



if g_game.getWorldName() == "Katon" then -- FIX NTO SPLIT
	function getSpecs()
		local specs = {}
		for _, tile in pairs(g_map.getTiles(posz())) do
			local creatures = tile:getCreatures();
			if (#creatures > 0) then
				for i = 1, #creatures do
					table.insert(specs, creatures[i]);
				end
			end
		end
		return specs
	end
	function getPlayerByName(name)
		name = name:lower():trim();
		for _, spec in ipairs(getSpecs()) do
			if spec:getName():lower() == name then
				return spec
			end
		end
	end
end

pkTimeMacro = macro(1, function()
	local time = os and os.time() or now
	if isInPz() then storage.battleTracking[1] = 0 end
	for specName, value in pairs(storage.battleTracking[3]) do
		if (os and value.timeBattle >= time) or (not os and value.timeBattle >= time and value.timeBattle - 60000 <= time) then
			local playerSearch = getPlayerByName(specName, true)
			if playerSearch then
				if playerSearch:getId() == value.playerId then
					if playerSearch:getHealthPercent() == 0 then
						storage.battleTracking[1] = not os and time + (pzTime * 60 * 1000) or time + (pzTime * 60)
						storage.battleTracking[3][specName] = nil
					end
				else
					storage.battleTracking[3][specName] = nil
				end
			end
		else
			storage.battleTracking[3][specName] = nil
		end
	end
	local timeWidget = pkTimeWidget
	if storage.battleTracking[1] < time then
		timeWidget:setText("PK Time is: 00:00")
		timeWidget:setColor("green")
	else
		timeWidget:setText("PK Time is: " .. doFormatMin(storage.battleTracking[1] - time))
		timeWidget:setColor("red")
	end
end)


local cIcon = addIcon("cI",{text="Cave\nBot",switchable=false,moveable=true}, function()
  if CaveBot.isOff() then 
    CaveBot.setOn()
  else 
    CaveBot.setOff()
  end
end)
cIcon:setSize({height=30,width=50})
cIcon.text:setFont('verdana-11px-rounded')

local tIcon = addIcon("tI",{text="Target\nBot",switchable=false,moveable=true}, function()
  if TargetBot.isOff() then 
    TargetBot.setOn()
  else 
    TargetBot.setOff()
  end
end)
tIcon:setSize({height=30,width=50})
tIcon.text:setFont('verdana-11px-rounded')

macro(50,function()
  if CaveBot.isOn() then
    cIcon.text:setColoredText({"CaveBot\n","white","ON","green"})
  else
    cIcon.text:setColoredText({"CaveBot\n","white","OFF","red"})
  end
  if TargetBot.isOn() then
    tIcon.text:setColoredText({"Target\n","white","ON","green"})
  else
    tIcon.text:setColoredText({"Target\n","white","OFF","red"})
  end
end)


UI.Separator()

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Auto Defesa com input
storage.autoDefesaSpell = storage.autoDefesaSpell or "mokuton jukai"

local autoDefesaPanel = setupUI([[
Panel
  height: 20
  margin-top: 5

  Label
    text: Spell:
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 40
    font: verdana-11px-rounded

  BotTextEdit
    id: spellInput
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 5
]], rightPanel)

autoDefesaPanel.spellInput:setText(storage.autoDefesaSpell)
autoDefesaPanel.spellInput.onTextChange = function(widget, text)
  storage.autoDefesaSpell = text
end

macro(5000, "Auto Defesa 5secs", function()
  local spell = storage.autoDefesaSpell
  if spell == "" then return end
  
  for _, spec in ipairs(getSpectators()) do
    if spec:isPlayer() and spec ~= player then
      local creaturePos = spec:getPosition()
      local playerPos = player:getPosition()
      if creaturePos.z == playerPos.z and getDistanceBetween(playerPos, creaturePos) <= 7 then
        say(spell)
        return
      end
    end
  end
end)

UI.Separator()

macro(7000, "Auto KAI", function()
  for _, spec in ipairs(getSpectators()) do
    if spec:isPlayer() and spec ~= player then
      local creaturePos = spec:getPosition()
      local playerPos = player:getPosition()
      if creaturePos.z == playerPos.z and getDistanceBetween(playerPos, creaturePos) <= 7 then
        say("kai")
        return
      end
    end
  end
end)

