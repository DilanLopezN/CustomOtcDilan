setDefaultTab("Uteis")

UI.Label("Seek and Destroyer")

--[[
  ============================================================
  ATTACK FOLLOW - Hold Target + Chase Ofensivo
  ============================================================
  Combina Hold Target com Chase Attack:
  - Mantém o target salvo (re-ataca se perder o target)
  - Persegue o inimigo de forma OFENSIVA
  - Atravessa portas, escadas, buracos (jumps) e custom IDs
  - ESC para desativar e limpar o target
  ============================================================
]]

AttackFollow = {
    targetId = nil,
    targetName = nil,
    obstaclesQueue = {},
    obstacleWalkTime = 0,
    currentTargetId = nil,
    walkDirTable = {
        [0] = {'y', -1},
        [1] = {'x', 1},
        [2] = {'y', 1},
        [3] = {'x', -1},
    },
    flags = {
        ignoreNonPathable = true,
        precision = 0,
        ignoreCreatures = true
    },
    jumpSpell = {
        up = 'jump up',
        down = 'jump down'
    },
    defaultItem = 1111,
    defaultSpell = 'skip',
    customIds = {
        { id = 1948, castSpell = false },
        { id = 595,  castSpell = false },
        { id = 1067, castSpell = false },
        { id = 1080, castSpell = false },
        {id = 13296, castSpell = false},
        { id = 386,  castSpell = true  },
    },
    walkDelay = 200
}

-- ==================== FUNÇÕES UTILITÁRIAS ====================

AttackFollow.distanceFromPlayer = function(position)
    local distx = math.abs(posx() - position.x)
    local disty = math.abs(posy() - position.y)
    return math.sqrt(distx * distx + disty * disty)
end

AttackFollow.walkToPathDir = function(path)
    if (path) then
        g_game.walk(path[1], false)
    end
end

AttackFollow.getDirection = function(playerPos, direction)
    local walkDir = AttackFollow.walkDirTable[direction]
    if (walkDir) then
        playerPos[walkDir[1]] = playerPos[walkDir[1]] + walkDir[2]
    end
    return playerPos
end

AttackFollow.checkItemOnTile = function(tile, tbl)
    if (not tile) then return nil end
    for _, item in ipairs(tile:getItems()) do
        local itemId = item:getId()
        for _, itemSelected in ipairs(tbl) do
            if (itemId == itemSelected.id) then
                return itemSelected
            end
        end
    end
    return nil
end

AttackFollow.shiftFromQueue = function()
    table.remove(AttackFollow.obstaclesQueue, 1)
end

-- ==================== DETECÇÃO DE OBSTÁCULOS ====================

-- Detecta Custom ID (buracos, teleports, etc)
AttackFollow.checkIfWentToCustomId = function(creature, newPos, oldPos, scheduleTime)
    local tile = g_map.getTile(oldPos)
    local customId = AttackFollow.checkItemOnTile(tile, AttackFollow.customIds)
    if (not customId) then return end

    if (not scheduleTime) then scheduleTime = 0 end

    schedule(scheduleTime, function()
        if (oldPos.z == posz() or #AttackFollow.obstaclesQueue > 0) then
            table.insert(AttackFollow.obstaclesQueue, {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                customId = customId,
                tile = g_map.getTile(oldPos),
                isCustom = true
            })
        end
    end)
end

-- Detecta Escada
AttackFollow.checkIfWentToStair = function(creature, newPos, oldPos, scheduleTime)
    if (g_map.getMinimapColor(oldPos) ~= 210) then return end
    local tile = g_map.getTile(oldPos)
    if (tile:isPathable()) then return end

    if (not scheduleTime) then scheduleTime = 0 end

    schedule(scheduleTime, function()
        if (oldPos.z == posz() or #AttackFollow.obstaclesQueue > 0) then
            table.insert(AttackFollow.obstaclesQueue, {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                tile = tile,
                isStair = true
            })
        end
    end)
end

-- Detecta Porta
AttackFollow.checkIfWentToDoor = function(creature, newPos, oldPos)
    if (AttackFollow.obstaclesQueue[1] and AttackFollow.distanceFromPlayer(newPos) < AttackFollow.distanceFromPlayer(oldPos)) then return end
    if (math.abs(newPos.x - oldPos.x) == 2 or math.abs(newPos.y - oldPos.y) == 2) then
        local doorPos = { z = oldPos.z }
        local directionX = oldPos.x - newPos.x
        local directionY = oldPos.y - newPos.y

        if math.abs(directionX) > math.abs(directionY) then
            if directionX > 0 then
                doorPos.x = newPos.x + 1
                doorPos.y = newPos.y
            else
                doorPos.x = newPos.x - 1
                doorPos.y = newPos.y
            end
        else
            if directionY > 0 then
                doorPos.x = newPos.x
                doorPos.y = newPos.y + 1
            else
                doorPos.x = newPos.x
                doorPos.y = newPos.y - 1
            end
        end

        local doorTile = g_map.getTile(doorPos)
        if (not doorTile:isPathable() or doorTile:isWalkable()) then return end

        table.insert(AttackFollow.obstaclesQueue, {
            newPos = newPos,
            tilePos = doorPos,
            tile = doorTile,
            isDoor = true,
        })
    end
end

-- Detecta Jump (mudança de andar sem escada)
AttackFollow.checkIfWentToJumpPos = function(creature, newPos, oldPos)
    local pos1 = { x = oldPos.x - 1, y = oldPos.y - 1 }
    local pos2 = { x = oldPos.x + 1, y = oldPos.y + 1 }

    local hasStair = nil
    for x = pos1.x, pos2.x do
        for y = pos1.y, pos2.y do
            local tilePos = { x = x, y = y, z = oldPos.z }
            if (g_map.getMinimapColor(tilePos) == 210) then
                hasStair = true
                goto continue
            end
        end
    end
    ::continue::

    if (hasStair) then return end

    local spell = newPos.z > oldPos.z and AttackFollow.jumpSpell.down or AttackFollow.jumpSpell.up
    local dir = creature:getDirection()

    table.insert(AttackFollow.obstaclesQueue, {
        oldPos = oldPos,
        oldTile = g_map.getTile(oldPos),
        spell = spell,
        dir = dir,
        isJump = true,
    })
end

-- ==================== ESC PARA DESATIVAR ====================

onKeyPress(function(keys)
    if keys == "Escape" and AttackFollow.targetId then
        AttackFollow.targetId = nil
        AttackFollow.targetName = nil
        AttackFollow.obstaclesQueue = {}
        AttackFollow.obstacleWalkTime = 0
        AttackFollow.currentTargetId = nil
    end
end)

-- ==================== MACRO PRINCIPAL ====================

-- Hold Target + Chase: salva o target e persegue
AttackFollow.mainMacro = macro(AttackFollow.walkDelay, "Attack Follow", function()
    local currentTarget = g_game.getAttackingCreature()

    -- Se atacando alguém, salva como target (ignora NPC)
    if currentTarget and currentTarget:getPosition().z == posz() and not currentTarget:isNpc() then
        if AttackFollow.targetId ~= currentTarget:getId() then
            AttackFollow.targetId = currentTarget:getId()
            AttackFollow.targetName = currentTarget:getName()
            AttackFollow.obstaclesQueue = {}
            AttackFollow.currentTargetId = currentTarget:getId()
        end
    end

    -- Sem target salvo, não faz nada
    if not AttackFollow.targetId then return end

    -- Se não está atacando, procura o target salvo e re-ataca (Hold Target)
    if not currentTarget then
        for i, spec in ipairs(getSpectators()) do
            local sameFloor = spec:getPosition().z == posz()
            local isOldTarget = spec:getId() == AttackFollow.targetId

            if sameFloor and isOldTarget then
                g_game.attack(spec)
                return
            end
        end
        -- Target não visível, não cancela (pode voltar a aparecer)
        return
    end

    -- Se tem obstáculo na fila, deixa os processadores lidarem
    if (#AttackFollow.obstaclesQueue > 0) then return end

    -- Chase: persegue o target no mesmo andar
    local targetPos = currentTarget:getPosition()
    if (not targetPos) then return end

    local myPos = pos()

    if (targetPos.z == myPos.z) then
        local path = findPath(myPos, targetPos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = true })
        if (not path) then return end

        -- Se está longe, anda até o target
        if (#path > 1 and not player:isWalking()) then
            autoWalk(targetPos, 20, { ignoreNonPathable = true, precision = 1 })
        end
    end
end)

-- ==================== ATUALIZA TARGET ID ====================

macro(1, function()
    if (AttackFollow.mainMacro.isOff()) then return end
    local currentTarget = g_game.getAttackingCreature()

    if (currentTarget and AttackFollow.currentTargetId ~= currentTarget:getId()) then
        AttackFollow.currentTargetId = currentTarget:getId()
    end
end)

-- ==================== LISTENERS DE OBSTÁCULOS ====================

-- Detecta porta (mesmo andar)
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (AttackFollow.mainMacro.isOff()) then return end
    if (not AttackFollow.targetId) then return end

    if creature:getId() == AttackFollow.targetId and newPos and oldPos and oldPos.z == newPos.z then
        AttackFollow.checkIfWentToDoor(creature, newPos, oldPos)
    end
end)

-- Detecta jump (mudou de andar, sem escada)
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (AttackFollow.mainMacro.isOff()) then return end
    if (not AttackFollow.targetId) then return end

    if creature:getId() == AttackFollow.targetId and newPos and oldPos and oldPos.z == posz() and oldPos.z ~= newPos.z then
        AttackFollow.checkIfWentToJumpPos(creature, newPos, oldPos)
    end
end)

-- Detecta escada
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (AttackFollow.mainMacro.isOff()) then return end
    if (not AttackFollow.targetId) then return end

    if creature:getId() == AttackFollow.targetId and oldPos and g_map.getMinimapColor(oldPos) == 210 then
        local scheduleTime = oldPos.z == posz() and 0 or 250
        AttackFollow.checkIfWentToStair(creature, newPos, oldPos, scheduleTime)
    end
end)

-- Detecta custom id (buracos, teleports)
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (AttackFollow.mainMacro.isOff()) then return end
    if (not AttackFollow.targetId) then return end

    if creature:getId() == AttackFollow.targetId and oldPos and oldPos.z == posz() and (not newPos or oldPos.z ~= newPos.z) then
        AttackFollow.checkIfWentToCustomId(creature, newPos, oldPos)
    end
end)

-- ==================== PROCESSADORES DE OBSTÁCULOS ====================

-- Limpa fila quando muda de andar (já processou)
macro(1, function()
    if (AttackFollow.mainMacro.isOff()) then return end

    if (AttackFollow.obstaclesQueue[1] and ((not AttackFollow.obstaclesQueue[1].isJump and AttackFollow.obstaclesQueue[1].tilePos.z ~= posz()) or (AttackFollow.obstaclesQueue[1].isJump and AttackFollow.obstaclesQueue[1].oldPos.z ~= posz()))) then
        table.remove(AttackFollow.obstaclesQueue, 1)
    end
end)

-- Processa escadas
macro(100, function()
    if (AttackFollow.mainMacro.isOff()) then return end
    if (AttackFollow.obstaclesQueue[1] and AttackFollow.obstaclesQueue[1].isStair) then
        local playerPos = pos()
        local walkingTile = AttackFollow.obstaclesQueue[1].tile
        local walkingTilePos = AttackFollow.obstaclesQueue[1].tilePos

        if (AttackFollow.distanceFromPlayer(walkingTilePos) < 2) then
            if (AttackFollow.obstacleWalkTime < now) then
                local nextFloor = g_map.getTile(walkingTilePos)
                if (nextFloor:isPathable()) then
                    AttackFollow.obstacleWalkTime = now + 250
                    use(nextFloor:getTopUseThing())
                else
                    AttackFollow.obstacleWalkTime = now + 250
                    AttackFollow.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }))
                end
                AttackFollow.shiftFromQueue()
                return
            end
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })
        if (path == nil or #path <= 1) then
            if (path == nil) then
                use(walkingTile:getTopUseThing())
            end
            return
        end

        local tileToUse = playerPos
        for i, value in ipairs(path) do
            if (i > 5) then break end
            tileToUse = AttackFollow.getDirection(tileToUse, value)
        end
        tileToUse = g_map.getTile(tileToUse)
        if (tileToUse) then
            use(tileToUse:getTopUseThing())
        end
    end
end)

-- Processa portas
macro(1, function()
    if (AttackFollow.mainMacro.isOff()) then return end

    if (AttackFollow.obstaclesQueue[1] and AttackFollow.obstaclesQueue[1].isDoor) then
        local playerPos = pos()
        local walkingTile = AttackFollow.obstaclesQueue[1].tile
        local walkingTilePos = AttackFollow.obstaclesQueue[1].tilePos

        if (table.compare(playerPos, AttackFollow.obstaclesQueue[1].newPos)) then
            AttackFollow.obstacleWalkTime = 0
            AttackFollow.shiftFromQueue()
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })
        if (path == nil or #path <= 1) then
            if (path == nil) then
                if (AttackFollow.obstacleWalkTime < now) then
                    g_game.use(walkingTile:getTopThing())
                    AttackFollow.obstacleWalkTime = now + 500
                end
            end
            return
        end
    end
end)

-- Processa jumps
macro(100, function()
    if (AttackFollow.mainMacro.isOff()) then return end

    if (AttackFollow.obstaclesQueue[1] and AttackFollow.obstaclesQueue[1].isJump) then
        local playerPos = pos()
        local walkingTilePos = AttackFollow.obstaclesQueue[1].oldPos
        local distance = AttackFollow.distanceFromPlayer(walkingTilePos)

        if (playerPos.z ~= walkingTilePos.z) then
            AttackFollow.shiftFromQueue()
            return
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })

        if (distance == 0) then
            g_game.turn(AttackFollow.obstaclesQueue[1].dir)
            schedule(50, function()
                if (AttackFollow.obstaclesQueue[1]) then
                    say(AttackFollow.obstaclesQueue[1].spell)
                end
            end)
            return
        elseif (distance < 2) then
            if (AttackFollow.obstacleWalkTime < now) then
                AttackFollow.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }))
                AttackFollow.obstacleWalkTime = now + 500
            end
            return
        elseif (distance >= 2 and distance < 5 and path) then
            use(AttackFollow.obstaclesQueue[1].oldTile:getTopUseThing())
        elseif (path) then
            local tileToUse = playerPos
            for i, value in ipairs(path) do
                if (i > 5) then break end
                tileToUse = AttackFollow.getDirection(tileToUse, value)
            end
            tileToUse = g_map.getTile(tileToUse)
            if (tileToUse) then
                use(tileToUse:getTopUseThing())
            end
        end
    end
end)

-- Processa custom IDs
macro(100, function()
    if (AttackFollow.mainMacro.isOff()) then return end

    if (AttackFollow.obstaclesQueue[1] and AttackFollow.obstaclesQueue[1].isCustom) then
        local playerPos = pos()
        local walkingTile = AttackFollow.obstaclesQueue[1].tile
        local walkingTilePos = AttackFollow.obstaclesQueue[1].tilePos
        local distance = AttackFollow.distanceFromPlayer(walkingTilePos)

        if (playerPos.z ~= walkingTilePos.z) then
            AttackFollow.shiftFromQueue()
            return
        end

        if (distance == 0) then
            if (AttackFollow.obstaclesQueue[1].customId.castSpell) then
                say(AttackFollow.defaultSpell)
                return
            end
        elseif (distance < 2) then
            local item = findItem(AttackFollow.defaultItem)
            if (AttackFollow.obstaclesQueue[1].customId.castSpell or not item) then
                if (AttackFollow.obstacleWalkTime < now) then
                    AttackFollow.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }))
                    AttackFollow.obstacleWalkTime = now + 500
                end
            elseif (item) then
                g_game.useWith(item, walkingTile)
                AttackFollow.shiftFromQueue()
            end
            return
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })
        if (path == nil or #path <= 1) then
            if (path == nil) then
                use(walkingTile:getTopUseThing())
            end
            return
        end

        local tileToUse = playerPos
        for i, value in ipairs(path) do
            if (i > 5) then break end
            tileToUse = AttackFollow.getDirection(tileToUse, value)
        end
        tileToUse = g_map.getTile(tileToUse)
        if (tileToUse) then
            use(tileToUse:getTopUseThing())
        end
    end
end)

-- ==================== ÍCONE NA TELA ====================

local atkFollowIcon = addIcon("attackFollow", { text = "ATK\nFollow", switchable = false, moveable = true }, function()
    if AttackFollow.mainMacro.isOn() then
        AttackFollow.mainMacro.setOff()
        -- Limpa tudo ao desligar
        AttackFollow.targetId = nil
        AttackFollow.targetName = nil
        AttackFollow.obstaclesQueue = {}
        AttackFollow.currentTargetId = nil
    else
        AttackFollow.mainMacro.setOn()
    end
end)
atkFollowIcon:setSize({ height = 30, width = 50 })
atkFollowIcon.text:setFont('verdana-11px-rounded')

-- Atualiza ícone com status
macro(50, function()
    if AttackFollow.mainMacro.isOn() then
        if AttackFollow.targetId then
            local name = AttackFollow.targetName or "?"
            if #name > 6 then name = name:sub(1, 6) .. ".." end
            atkFollowIcon.text:setColoredText({ "ATK\n", "white", name, "#00FF00" })
        else
            atkFollowIcon.text:setColoredText({ "ATK\n", "white", "ON", "green" })
        end
    else
        atkFollowIcon.text:setColoredText({ "ATK\n", "white", "OFF", "red" })
    end
end)


UI.Separator()
UI.Label("Treino Uteis")

local treinando = false

AntiPush = macro(100, "Treinamento", function()
  if treinando == false then
    say("!treinar")
  end
end)

onTalk(function(name, level, mode, text)
    if name ~= player:getName() then return end
    text = text:lower() 
    if text == "on!" then 
        treinando = true
    end
end)

macro(100, function()
  if AntiPush:isOff() and treinando == true then
    say("Kai")
    treinando = false
  end
end)

macro(2000, "Dance", function()
    turn(math.random(0, 3)) 
end)

macro(5000, "Powerdown", function()
    say("powerdown")
end)



UI.Separator()
UI.Label("Uteis Geral")

addTextEdit("Kunai", storage.Kunai or "7382", function(widget, text)
    storage.Kunai = text
end, scpPanel)

-- Dash Kunai SQMs configuravel
if not storage.dashKunaiSQM then storage.dashKunaiSQM = 8 end

local dashSqmPanel = setupUI([[
Panel
  height: 24
  Label
    id: lbl
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text-auto-resize: true
    color: white
    font: verdana-11px-rounded
  Button
    id: btnMinus
    anchors.right: btnPlus.left
    anchors.verticalCenter: parent.verticalCenter
    margin-right: 4
    width: 22
    height: 22
    text: -
    color: red
  Button
    id: btnPlus
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 22
    height: 22
    text: +
    color: green
]], scpPanel)

local function updateDashLabel()
  dashSqmPanel.lbl:setText("Dash SQMs: " .. storage.dashKunaiSQM)
end
updateDashLabel()

dashSqmPanel.btnMinus.onClick = function()
  if storage.dashKunaiSQM > 1 then
    storage.dashKunaiSQM = storage.dashKunaiSQM - 1
    updateDashLabel()
  end
end

dashSqmPanel.btnPlus.onClick = function()
  if storage.dashKunaiSQM < 15 then
    storage.dashKunaiSQM = storage.dashKunaiSQM + 1
    updateDashLabel()
  end
end

local superDashUseWith = macro(100, "Dash Kunai", "shift+e+0", function() end, scpPanel)

function funcSuperDashUseWith(parent)
    if not parent then
        parent = panel
    end

    onKeyPress(function(keys)
        local itemUseId = tonumber(storage.Kunai)
        local dashSQMs = storage.dashKunaiSQM or 8
        local dashSQMs2 = math.max(1, dashSQMs - 2)

        if not superDashUseWith:isOn() then
            return
        end

        local consoleModule = modules.game_console

        if (keys == "W" and not consoleModule:isChatEnabled()) or keys == "Up" then
            schedule(50, function()
                local moveToTile = g_map.getTile({x = posx(), y = posy() - dashSQMs2, z = posz()})
                if moveToTile then
                    g_game.useInventoryItemWith(itemUseId, moveToTile:getTopThing())
                end
            end)
        elseif (keys == "A" and not consoleModule:isChatEnabled()) or keys == "Left" then
            schedule(50, function()
                local moveToTile = g_map.getTile({x = posx() - dashSQMs, y = posy(), z = posz()})
                if moveToTile then
                    g_game.useInventoryItemWith(itemUseId, moveToTile:getTopThing())
                end
            end)
        elseif (keys == "S" and not consoleModule:isChatEnabled()) or keys == "Down" then
            schedule(50, function()
                local moveToTile = g_map.getTile({x = posx(), y = posy() + dashSQMs2, z = posz()})
                if moveToTile then
                    g_game.useInventoryItemWith(itemUseId, moveToTile:getTopThing())
                end
            end)
        elseif (keys == "D" and not consoleModule:isChatEnabled()) or keys == "Right" then
            schedule(50, function()
                local moveToTile = g_map.getTile({x = posx() + dashSQMs, y = posy(), z = posz()})
                if moveToTile then
                    g_game.useInventoryItemWith(itemUseId, moveToTile:getTopThing())
                end
            end)
        end
    end)
end

funcSuperDashUseWith()

Turn = {}

Turn.maxDistance = {x = 7, y = 7}
Turn.minDistance = 1
Turn.macro = macro(1, 'Turn target ', function()
    local target = g_game.getAttackingCreature()
    if target then
        local targetPos = target:getPosition()
        if targetPos then
            local pos = pos()
            local targetDistance = {x = math.abs(pos.x - targetPos.x), y = math.abs(pos.y - targetPos.y)}
            if not (targetDistance.x > Turn.minDistance and targetDistance.y > Turn.minDistance) then
                if targetDistance.x <= Turn.maxDistance.x and targetDistance.y <= Turn.maxDistance.y then
                    local playerDir = player:getDirection()
                    if targetDistance.y >= targetDistance.x then
                        if targetPos.y > pos.y then
                            return playerDir ~= 2 and turn(2)
                        else
                            return playerDir ~= 0 and turn(0)
                        end
                    else
                        if targetPos.x > pos.x then
                            return playerDir ~= 1 and turn(1)
                        else
                            return playerDir ~= 3 and turn(3)
                        end
                    end
                end
            end
        end
    end
end)


onCreatureHealthPercentChange(function(creature, hpPercent)
    if (not creature:isPlayer()) then return; end
    creature:setText(hpPercent .. '%')
end);

local configSeal = {
    spellSeal = 'explosion kunai ', -- spell de selar
    cooldownSeal = 60, -- coldown da spell, em segundos
    percentSeal = 25, -- porcentagem p selar
    possibleBijuuNames = { -- nome das bijuus pré configurada pro ultimate
        'Shukaku',
        'matatabi',
        'isobu',
        'son goku',
        'kokuou',
        'saiken',
        'choumei',
        'gyuki',
        'kurama',
    },
}




macro(100, "Selar bijuu", function()
    local findBijuu;
    local actualTarget = g_game.getAttackingCreature();
    for _, bijuuName in ipairs(configSeal.possibleBijuuNames) do
        local potentialBijuu = getCreatureByName(bijuuName:lower());
        if potentialBijuu then
            findBijuu = potentialBijuu;
            break;
        end
    end
    if not findBijuu then return; end
    if (configSeal.cooldownSpell and configSeal.cooldownSpell >= os.time()) then return; end
    if (not actualTarget or actualTarget:getName() ~= findBijuu:getName()) then
        g_game.attack(findBijuu)
    elseif actualTarget and actualTarget:getHealthPercent() <= configSeal.percentSeal then
        say(configSeal.spellSeal)
    end
end);




onTalk(function(name, level, mode, text, channelId, pos)
    if name ~= player:getName() then return; end
    text = text:lower();
    local filterSealSpell = configSeal.spellSeal:lower();
    if text == filterSealSpell then
        configSeal.cooldownSpell = os.time() + configSeal.cooldownSeal;
    end
end);

local configRegen = {
    spell = 'big regeneration',
    percentage = 99,
    cooldown = 1000, -- em milisegundos
};

if type(canCast) ~= 'function' then
    canCast = function(spell, time)
        if not spell then return; end
        time = time or now;
        if not spell or spell <= time then
            return true;
        end
        return false;
    end
end

macro(100, "Regeneration", function()
    if hppercent() <= configRegen.percentage then
        if canCast(configRegen.cooldownSpell) then
            say(configRegen.spell)
        end
    end
end);


onTalk(function(name, level, mode, text, channelId, pos)
    if name ~= player:getName() then return; end
    text = text:lower();

    toFind = configRegen.spell:lower();
    if text == toFind then
        configRegen.cooldownSpell = now + configRegen.cooldown;
    end
end);

