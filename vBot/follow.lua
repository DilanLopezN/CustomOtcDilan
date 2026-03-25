setDefaultTab("Uteis")



--[[
  ╔══════════════════════════════════════════════════════════╗
  ║  CHASE & KEEP TARGET - Perseguição 100% (obitoc port)   ║
  ║  Escadas, buracos, jump up/down, portas, custom IDs     ║
  ║  ESC = desliga tudo | Sem setDefaultTab (fica na aba)   ║
  ╚══════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- CONFIG
-- ============================================================
CT = {
    targetId = nil,
    currentTargetId = nil,
    obstaclesQueue = {},
    obstacleWalkTime = 0,
    lastCancelFollow = 0,
    followDelay = 300,
    keyCancel = 'Escape',

    walkDirTable = {
        [0] = {'y', -1},
        [1] = {'x', 1},
        [2] = {'y', 1},
        [3] = {'x', -1},
    },

    jumpSpell = {
        up = 'jump up',
        down = 'jump down'
    },

    -- Item usado pra descer buraco (ex: shovel, pick, rope)
    defaultItem = 1111,
    -- Spell usada em tiles que precisam de spell
    defaultSpell = 'skip',

    -- IDs de tiles interativos (escada, buraco, etc)
    -- castSpell = true → usa defaultSpell ao invés de clicar
    customIds = {
        { id = 1948, castSpell = false },
        { id = 595,  castSpell = false },
        { id = 1067, castSpell = false },
        { id = 1080, castSpell = false },
        { id = 386,  castSpell = true  },
    },
}

-- ============================================================
-- FUNÇÕES AUXILIARES (idênticas ao obitoc)
-- ============================================================
CT.distanceFromPlayer = function(position)
    local distx = math.abs(posx() - position.x)
    local disty = math.abs(posy() - position.y)
    return math.sqrt(distx * distx + disty * disty)
end

CT.walkToPathDir = function(path)
    if path then
        g_game.walk(path[1], false)
    end
end

CT.getDirection = function(playerPos, direction)
    local walkDir = CT.walkDirTable[direction]
    if walkDir then
        playerPos[walkDir[1]] = playerPos[walkDir[1]] + walkDir[2]
    end
    return playerPos
end

CT.checkItemOnTile = function(tile, tbl)
    if not tile then return nil end
    for _, item in ipairs(tile:getItems()) do
        local itemId = item:getId()
        for _, itemSelected in ipairs(tbl) do
            if itemId == itemSelected.id then
                return itemSelected
            end
        end
    end
    return nil
end

CT.shiftFromQueue = function()
    g_game.cancelFollow()
    CT.lastCancelFollow = now + CT.followDelay
    table.remove(CT.obstaclesQueue, 1)
    -- Após cruzar obstáculo, re-ataca o alvo salvo
    if CT.targetId then
        schedule(300, function()
            local found = getCreatureById(CT.targetId)
            if found then
                g_game.attack(found)
                g_game.setChaseMode(1)
            end
        end)
    end
end

-- ============================================================
-- DETECÇÃO: Porta
-- ============================================================
CT.checkIfWentToDoor = function(creature, newPos, oldPos)
    if CT.obstaclesQueue[1] and CT.distanceFromPlayer(newPos) < CT.distanceFromPlayer(oldPos) then return end
    if math.abs(newPos.x - oldPos.x) == 2 or math.abs(newPos.y - oldPos.y) == 2 then
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
        if not doorTile then return end
        if not doorTile:isPathable() or doorTile:isWalkable() then return end

        table.insert(CT.obstaclesQueue, {
            newPos = newPos,
            tilePos = doorPos,
            tile = doorTile,
            isDoor = true,
        })
        g_game.cancelFollow()
        CT.lastCancelFollow = now + CT.followDelay
    end
end

-- ============================================================
-- DETECÇÃO: Jump (mudou de andar sem escada perto)
-- ============================================================
CT.checkifWentToJumpPos = function(creature, newPos, oldPos)
    local pos1 = { x = oldPos.x - 1, y = oldPos.y - 1 }
    local pos2 = { x = oldPos.x + 1, y = oldPos.y + 1 }

    local hasStair = nil
    for x = pos1.x, pos2.x do
        for y = pos1.y, pos2.y do
            local tilePos = { x = x, y = y, z = oldPos.z }
            if g_map.getMinimapColor(tilePos) == 210 then
                hasStair = true
                goto continue
            end
        end
    end
    ::continue::

    if hasStair then return end

    local spell = newPos.z > oldPos.z and CT.jumpSpell.down or CT.jumpSpell.up
    local dir = creature:getDirection()

    table.insert(CT.obstaclesQueue, {
        oldPos = oldPos,
        oldTile = g_map.getTile(oldPos),
        spell = spell,
        dir = dir,
        isJump = true,
    })
    g_game.cancelFollow()
    CT.lastCancelFollow = now + CT.followDelay
end

-- ============================================================
-- DETECÇÃO: Escada (minimap color 210)
-- ============================================================
CT.checkIfWentToStair = function(creature, newPos, oldPos, scheduleTime)
    if g_map.getMinimapColor(oldPos) ~= 210 then return end
    local tile = g_map.getTile(oldPos)
    if not tile then return end
    if tile:isPathable() then return end

    if not scheduleTime then scheduleTime = 0 end

    schedule(scheduleTime, function()
        if oldPos.z == posz() or #CT.obstaclesQueue > 0 then
            table.insert(CT.obstaclesQueue, {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                tile = tile,
                isStair = true
            })
            g_game.cancelFollow()
            CT.lastCancelFollow = now + CT.followDelay
        end
    end)
end

-- ============================================================
-- DETECÇÃO: Custom ID (buraco, rope, etc)
-- ============================================================
CT.checkIfWentToCustomId = function(creature, newPos, oldPos, scheduleTime)
    local tile = g_map.getTile(oldPos)
    local customId = CT.checkItemOnTile(tile, CT.customIds)
    if not customId then return end

    if not scheduleTime then scheduleTime = 0 end

    schedule(scheduleTime, function()
        if oldPos.z == posz() or #CT.obstaclesQueue > 0 then
            table.insert(CT.obstaclesQueue, {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                customId = customId,
                tile = g_map.getTile(oldPos),
                isCustom = true
            })
            g_game.cancelFollow()
            CT.lastCancelFollow = now + CT.followDelay
        end
    end)
end

-- ============================================================
-- MACRO PRINCIPAL: Attack Follow (persegue + ataca sempre)
-- ============================================================
CT.mainMacro = macro(CT.followDelay, "Attack Follow", function()
    -- ESC: desliga tudo
    if modules.corelib.g_keyboard.isKeyPressed(CT.keyCancel) then
        CT.targetId = nil
        CT.currentTargetId = nil
        CT.obstaclesQueue = {}
        g_game.setChaseMode(0)
        g_game.cancelAttack()
        g_game.cancelFollow()
        return
    end

    -- Se tem obstáculos na fila, deixa os processadores lidarem
    if #CT.obstaclesQueue > 0 then return end

    local target = g_game.getAttackingCreature()

    -- Se está atacando um player, salva o ID e persegue atacando
    if target and target:isPlayer() then
        CT.targetId = target:getId()
        g_game.setChaseMode(1)

        local targetPos = target:getPosition()
        local playerPos = pos()

        -- Mesmo andar: garante que está atacando e se aproxima
        if targetPos and targetPos.z == playerPos.z then
            local dist = CT.distanceFromPlayer(targetPos)

            -- Se está longe (não consegue bater), corre até o alvo
            if dist > 1 then
                local path = findPath(playerPos, targetPos, 50, { ignoreNonPathable = true, precision = 1, ignoreCreatures = true })
                if path then
                    CT.walkToPathDir(path)
                else
                    -- Sem path direto, tenta cancelar follow pra não ficar preso
                    local followingPlayer = g_game.getFollowingCreature()
                    if followingPlayer and followingPlayer:getId() == target:getId() then
                        CT.lastCancelFollow = now + CT.followDelay
                        g_game.cancelFollow()
                    end
                end
            end
            -- Sempre re-ataca pra garantir que não perde o ataque
            g_game.attack(target)
        end
        return
    end

    -- Perdeu o alvo: tenta re-atacar pelo ID salvo e persegue
    if CT.targetId then
        local found = getCreatureById(CT.targetId)
        if found then
            g_game.attack(found)
            g_game.setChaseMode(1)

            local targetPos = found:getPosition()
            local playerPos = pos()

            if targetPos and targetPos.z == playerPos.z then
                local dist = CT.distanceFromPlayer(targetPos)
                if dist > 1 then
                    local path = findPath(playerPos, targetPos, 50, { ignoreNonPathable = true, precision = 1, ignoreCreatures = true })
                    if path then
                        CT.walkToPathDir(path)
                    end
                end
            end
        end
        return delay(found and 300 or 100)
    end
end)
CT.mainMacro.setOff()
addIcon("ChaseTarget", {item = 14189, text = "AtkFollow"}, CT.mainMacro)

-- ============================================================
-- TRACKER: Atualiza o ID do alvo
-- ============================================================
macro(1, function()
    if CT.mainMacro.isOff() then return end
    local target = g_game.getAttackingCreature()
    if target and target:isPlayer() then
        if CT.currentTargetId ~= target:getId() then
            CT.currentTargetId = target:getId()
            CT.targetId = target:getId()
        end
    end
end)

-- Cancela follow se o alvo mudou de andar
macro(1000, function()
    if CT.mainMacro.isOff() then return end
    local target = g_game.getFollowingCreature()
    if target then
        local targetPos = target:getPosition()
        if not targetPos or targetPos.z ~= posz() then
            g_game.cancelFollow()
        end
    end
end)

-- ============================================================
-- LISTENERS: Detectam movimentação do alvo
-- ============================================================

-- Porta (mesmo andar)
onCreaturePositionChange(function(creature, newPos, oldPos)
    if CT.mainMacro.isOff() then return end
    if not CT.currentTargetId then return end
    if creature:getId() == CT.currentTargetId and newPos and oldPos and oldPos.z == newPos.z then
        CT.checkIfWentToDoor(creature, newPos, oldPos)
    end
end)

-- Jump (mudou de andar sem escada perto)
onCreaturePositionChange(function(creature, newPos, oldPos)
    if CT.mainMacro.isOff() then return end
    if not CT.currentTargetId then return end
    if creature:getId() == CT.currentTargetId and newPos and oldPos and oldPos.z == posz() and oldPos.z ~= newPos.z then
        CT.checkifWentToJumpPos(creature, newPos, oldPos)
    end
end)

-- Escada (minimap color 210)
onCreaturePositionChange(function(creature, newPos, oldPos)
    if CT.mainMacro.isOff() then return end
    if not CT.currentTargetId then return end
    if creature:getId() == CT.currentTargetId and oldPos and g_map.getMinimapColor(oldPos) == 210 then
        local scheduleTime = oldPos.z == posz() and 0 or 250
        CT.checkIfWentToStair(creature, newPos, oldPos, scheduleTime)
    end
end)

-- Custom IDs (buracos, ropes, etc)
onCreaturePositionChange(function(creature, newPos, oldPos)
    if CT.mainMacro.isOff() then return end
    if not CT.currentTargetId then return end
    if creature:getId() == CT.currentTargetId and oldPos and oldPos.z == posz() and (not newPos or oldPos.z ~= newPos.z) then
        CT.checkIfWentToCustomId(creature, newPos, oldPos)
    end
end)

-- ============================================================
-- LIMPEZA DA FILA: Remove obstáculos de andares errados
-- ============================================================
macro(1, function()
    if CT.mainMacro.isOff() then return end
    if CT.obstaclesQueue[1] and ((not CT.obstaclesQueue[1].isJump and CT.obstaclesQueue[1].tilePos.z ~= posz()) or (CT.obstaclesQueue[1].isJump and CT.obstaclesQueue[1].oldPos.z ~= posz())) then
        table.remove(CT.obstaclesQueue, 1)
    end
end)

-- ============================================================
-- PROCESSADOR: Escadas (idêntico obitoc)
-- ============================================================
macro(100, function()
    if CT.mainMacro.isOff() then return end
    if not (CT.obstaclesQueue[1] and CT.obstaclesQueue[1].isStair) then return end

    local playerPos = pos()
    local walkingTile = CT.obstaclesQueue[1].tile
    local walkingTilePos = CT.obstaclesQueue[1].tilePos

    if CT.distanceFromPlayer(walkingTilePos) < 2 then
        if CT.obstacleWalkTime < now then
            local nextFloor = g_map.getTile(walkingTilePos)
            if nextFloor and nextFloor:isPathable() then
                CT.obstacleWalkTime = now + 250
                use(nextFloor:getTopUseThing())
            else
                CT.obstacleWalkTime = now + 250
                CT.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }))
            end
            CT.shiftFromQueue()
            return
        end
    end

    local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })
    if path == nil or #path <= 1 then
        if path == nil then
            use(walkingTile:getTopUseThing())
        end
        return
    end

    local tileToUse = playerPos
    for i, value in ipairs(path) do
        if i > 5 then break end
        tileToUse = CT.getDirection(tileToUse, value)
    end
    tileToUse = g_map.getTile(tileToUse)
    if tileToUse then
        use(tileToUse:getTopUseThing())
    end
end)

-- ============================================================
-- PROCESSADOR: Portas (idêntico obitoc)
-- ============================================================
macro(1, function()
    if CT.mainMacro.isOff() then return end
    if not (CT.obstaclesQueue[1] and CT.obstaclesQueue[1].isDoor) then return end

    local playerPos = pos()
    local walkingTile = CT.obstaclesQueue[1].tile
    local walkingTilePos = CT.obstaclesQueue[1].tilePos

    if table.compare and table.compare(playerPos, CT.obstaclesQueue[1].newPos) then
        CT.obstacleWalkTime = 0
        CT.shiftFromQueue()
        return
    end

    local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })
    if path == nil or #path <= 1 then
        if path == nil then
            if CT.obstacleWalkTime < now then
                g_game.use(walkingTile:getTopThing())
                CT.obstacleWalkTime = now + 500
            end
        end
        return
    end
end)

-- ============================================================
-- PROCESSADOR: Jumps (idêntico obitoc)
-- ============================================================
macro(100, function()
    if CT.mainMacro.isOff() then return end
    if not (CT.obstaclesQueue[1] and CT.obstaclesQueue[1].isJump) then return end

    local playerPos = pos()
    local walkingTilePos = CT.obstaclesQueue[1].oldPos
    local distance = CT.distanceFromPlayer(walkingTilePos)

    if playerPos.z ~= walkingTilePos.z then
        CT.shiftFromQueue()
        return
    end

    local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })

    -- Em cima do tile: vira e fala a spell
    if distance == 0 then
        g_game.turn(CT.obstaclesQueue[1].dir)
        schedule(50, function()
            if CT.obstaclesQueue[1] then
                say(CT.obstaclesQueue[1].spell)
            end
        end)
        return
    -- Perto: anda 1 sqm até o tile
    elseif distance < 2 then
        if CT.obstacleWalkTime < now then
            CT.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }))
            CT.obstacleWalkTime = now + 500
        end
        return
    -- Médio: usa o tile diretamente
    elseif distance >= 2 and distance < 5 and path then
        use(CT.obstaclesQueue[1].oldTile:getTopUseThing())
    -- Longe: navega pelo path
    elseif path then
        local tileToUse = playerPos
        for i, value in ipairs(path) do
            if i > 5 then break end
            tileToUse = CT.getDirection(tileToUse, value)
        end
        tileToUse = g_map.getTile(tileToUse)
        if tileToUse then
            use(tileToUse:getTopUseThing())
        end
    end
end)

-- ============================================================
-- PROCESSADOR: Custom IDs (idêntico obitoc)
-- ============================================================
macro(100, function()
    if CT.mainMacro.isOff() then return end
    if not (CT.obstaclesQueue[1] and CT.obstaclesQueue[1].isCustom) then return end

    local playerPos = pos()
    local walkingTile = CT.obstaclesQueue[1].tile
    local walkingTilePos = CT.obstaclesQueue[1].tilePos
    local distance = CT.distanceFromPlayer(walkingTilePos)

    if playerPos.z ~= walkingTilePos.z then
        CT.shiftFromQueue()
        return
    end

    -- Em cima do tile
    if distance == 0 then
        if CT.obstaclesQueue[1].customId.castSpell then
            say(CT.defaultSpell)
            return
        end
    -- Perto
    elseif distance < 2 then
        local item = findItem(CT.defaultItem)
        if CT.obstaclesQueue[1].customId.castSpell or not item then
            if CT.obstacleWalkTime < now then
                CT.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }))
                CT.obstacleWalkTime = now + 500
            end
        elseif item then
            g_game.useWith(item, walkingTile)
            CT.shiftFromQueue()
        end
        return
    end

    -- Longe: navega pelo path
    local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false })
    if path == nil or #path <= 1 then
        if path == nil then
            use(walkingTile:getTopUseThing())
        end
        return
    end

    local tileToUse = playerPos
    for i, value in ipairs(path) do
        if i > 5 then break end
        tileToUse = CT.getDirection(tileToUse, value)
    end
    tileToUse = g_map.getTile(tileToUse)
    if tileToUse then
        use(tileToUse:getTopUseThing())
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

local superDashUseWith = macro(100, "Dash Kunai", "shift+e+0", function() end, scpPanel)

function funcSuperDashUseWith(parent)
    if not parent then
        parent = panel
    end

    onKeyPress(function(keys)
        local itemUseId = tonumber(storage.Kunai) -- CORREÇÃO: converter para número
        local dashSQMs = 8
        local dashSQMs2 = 6

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

funcSuperDashUseWith() -- Não esqueça de chamar a função

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

