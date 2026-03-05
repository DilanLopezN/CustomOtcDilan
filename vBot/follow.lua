setDefaultTab("Uteis")



UI.Label("Follow Uteis:")
local followAtk = macro(100, "Auto Follow", function()
    if not g_game.isAttacking() then return end
    local target = g_game.getAttackingCreature()
    if not target then return end
    g_game.follow(target)
end)

addIcon("followAtk", {item = 12953, text = "Follow"}, followAtk)



UI.Separator()

ChaseAttack = {
    targetId = nil,
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
        {
            id = 1948,
            castSpell = false
        },
        {
            id = 595,
            castSpell = false
        },
        {
            id = 1067,
            castSpell = false
        },
        {
            id = 1080,
            castSpell = false
        },
        {
            id = 386,
            castSpell = true
        },
    },
    walkDelay = 200
};

-- Pega o target atual
ChaseAttack.getTarget = function()
    return g_game.getAttackingCreature()
end

ChaseAttack.distanceFromPlayer = function(position)
    local distx = math.abs(posx() - position.x);
    local disty = math.abs(posy() - position.y);
    return math.sqrt(distx * distx + disty * disty);
end

ChaseAttack.walkToPathDir = function(path)
    if (path) then
        g_game.walk(path[1], false);
    end
end

ChaseAttack.getDirection = function(playerPos, direction)
    local walkDir = ChaseAttack.walkDirTable[direction];
    if (walkDir) then
        playerPos[walkDir[1]] = playerPos[walkDir[1]] + walkDir[2];
    end
    return playerPos;
end

ChaseAttack.checkItemOnTile = function(tile, table)
    if (not tile) then return nil end;
    for _, item in ipairs(tile:getItems()) do
        local itemId = item:getId();
        for _, itemSelected in ipairs(table) do
            if (itemId == itemSelected.id) then
                return itemSelected;
            end
        end
    end
    return nil;
end

ChaseAttack.shiftFromQueue = function()
    table.remove(ChaseAttack.obstaclesQueue, 1);
end

ChaseAttack.checkIfWentToCustomId = function(creature, newPos, oldPos, scheduleTime)
    local tile = g_map.getTile(oldPos);
    local customId = ChaseAttack.checkItemOnTile(tile, ChaseAttack.customIds);
    if (not customId) then return; end

    if (not scheduleTime) then
        scheduleTime = 0;
    end

    schedule(scheduleTime, function()
        if (oldPos.z == posz() or #ChaseAttack.obstaclesQueue > 0) then
            table.insert(ChaseAttack.obstaclesQueue, {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                customId = customId,
                tile = g_map.getTile(oldPos),
                isCustom = true
            });
        end
    end);
end

ChaseAttack.checkIfWentToStair = function(creature, newPos, oldPos, scheduleTime)
    if (g_map.getMinimapColor(oldPos) ~= 210) then return; end
    local tile = g_map.getTile(oldPos);
    if (tile:isPathable()) then return; end

    if (not scheduleTime) then
        scheduleTime = 0;
    end

    schedule(scheduleTime, function()
        if (oldPos.z == posz() or #ChaseAttack.obstaclesQueue > 0) then
            table.insert(ChaseAttack.obstaclesQueue, {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                tile = tile,
                isStair = true
            });
        end
    end);
end

ChaseAttack.checkIfWentToDoor = function(creature, newPos, oldPos)
    if (ChaseAttack.obstaclesQueue[1] and ChaseAttack.distanceFromPlayer(newPos) < ChaseAttack.distanceFromPlayer(oldPos)) then return; end
    if (math.abs(newPos.x - oldPos.x) == 2 or math.abs(newPos.y - oldPos.y) == 2) then
        local doorPos = {
            z = oldPos.z
        }

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

        local doorTile = g_map.getTile(doorPos);
        if (not doorTile:isPathable() or doorTile:isWalkable()) then return; end

        table.insert(ChaseAttack.obstaclesQueue, {
            newPos = newPos,
            tilePos = doorPos,
            tile = doorTile,
            isDoor = true,
        });
    end
end

ChaseAttack.checkifWentToJumpPos = function(creature, newPos, oldPos)
    local pos1 = { x = oldPos.x - 1, y = oldPos.y - 1 };
    local pos2 = { x = oldPos.x + 1, y = oldPos.y + 1 };

    local hasStair = nil
    for x = pos1.x, pos2.x do
        for y = pos1.y, pos2.y do
            local tilePos = { x = x, y = y, z = oldPos.z };
            if (g_map.getMinimapColor(tilePos) == 210) then
                hasStair = true;
                goto continue;
            end
        end
    end
    ::continue::

    if (hasStair) then return; end

    local spell = newPos.z > oldPos.z and ChaseAttack.jumpSpell.down or ChaseAttack.jumpSpell.up;
    local dir = creature:getDirection();

    if (newPos.z > oldPos.z) then
        spell = ChaseAttack.jumpSpell.down;
    end

    table.insert(ChaseAttack.obstaclesQueue, {
        oldPos = oldPos,
        oldTile = g_map.getTile(oldPos),
        spell = spell,
        dir = dir,
        isJump = true,
    });
end

-- Detecta porta
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (ChaseAttack.mainMacro.isOff()) then return; end
    local target = ChaseAttack.getTarget()
    if (not target) then return; end

    if creature:getId() == target:getId() and newPos and oldPos and oldPos.z == newPos.z then
        ChaseAttack.checkIfWentToDoor(creature, newPos, oldPos);
    end
end);

-- Detecta jump
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (ChaseAttack.mainMacro.isOff()) then return; end
    local target = ChaseAttack.getTarget()
    if (not target) then return; end

    if creature:getId() == target:getId() and newPos and oldPos and oldPos.z == posz() and oldPos.z ~= newPos.z then
        ChaseAttack.checkifWentToJumpPos(creature, newPos, oldPos);
    end
end);

-- Detecta escada
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (ChaseAttack.mainMacro.isOff()) then return; end
    local target = ChaseAttack.getTarget()
    if (not target) then return; end

    if creature:getId() == target:getId() and oldPos and g_map.getMinimapColor(oldPos) == 210 then
        local scheduleTime = oldPos.z == posz() and 0 or 250;
        ChaseAttack.checkIfWentToStair(creature, newPos, oldPos, scheduleTime);
    end
end);

-- Detecta custom id
onCreaturePositionChange(function(creature, newPos, oldPos)
    if (ChaseAttack.mainMacro.isOff()) then return; end
    local target = ChaseAttack.getTarget()
    if (not target) then return; end

    if creature:getId() == target:getId() and oldPos and oldPos.z == posz() and (not newPos or oldPos.z ~= newPos.z) then
        ChaseAttack.checkIfWentToCustomId(creature, newPos, oldPos);
    end
end);

-- Limpa fila quando muda de andar
macro(1, function()
    if (ChaseAttack.mainMacro.isOff()) then return; end

    if (ChaseAttack.obstaclesQueue[1] and ((not ChaseAttack.obstaclesQueue[1].isJump and ChaseAttack.obstaclesQueue[1].tilePos.z ~= posz()) or (ChaseAttack.obstaclesQueue[1].isJump and ChaseAttack.obstaclesQueue[1].oldPos.z ~= posz()))) then
        table.remove(ChaseAttack.obstaclesQueue, 1);
    end
end);

-- Processa escadas
macro(100, function()
    if (ChaseAttack.mainMacro.isOff()) then return; end
    if (ChaseAttack.obstaclesQueue[1] and ChaseAttack.obstaclesQueue[1].isStair) then
        local start = now
        local playerPos = pos();
        local walkingTile = ChaseAttack.obstaclesQueue[1].tile;
        local walkingTilePos = ChaseAttack.obstaclesQueue[1].tilePos;

        if (ChaseAttack.distanceFromPlayer(walkingTilePos) < 2) then
            if (ChaseAttack.obstacleWalkTime < now) then
                local nextFloor = g_map.getTile(walkingTilePos);
                if (nextFloor:isPathable()) then
                    ChaseAttack.obstacleWalkTime = now + 250;
                    use(nextFloor:getTopUseThing());
                else
                    ChaseAttack.obstacleWalkTime = now + 250;
                    ChaseAttack.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
                end
                ChaseAttack.shiftFromQueue();
                return 
            end
        end
        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        if (path == nil or #path <= 1) then
            if (path == nil) then
                use(walkingTile:getTopUseThing());
            end
            return
        end
        
        local tileToUse = playerPos;
        for i, value in ipairs(path) do
            if (i > 5) then break; end
            tileToUse = ChaseAttack.getDirection(tileToUse, value);
        end
        tileToUse = g_map.getTile(tileToUse);
        if (tileToUse) then
            use(tileToUse:getTopUseThing());
        end
    end
end);

-- Processa portas
macro(1, function()
    if (ChaseAttack.mainMacro.isOff()) then return; end

    if (ChaseAttack.obstaclesQueue[1] and ChaseAttack.obstaclesQueue[1].isDoor) then
        local playerPos = pos();
        local walkingTile = ChaseAttack.obstaclesQueue[1].tile;
        local walkingTilePos = ChaseAttack.obstaclesQueue[1].tilePos;
        if (table.compare(playerPos, ChaseAttack.obstaclesQueue[1].newPos)) then
            ChaseAttack.obstacleWalkTime = 0;
            ChaseAttack.shiftFromQueue();
        end
        
        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        if (path == nil or #path <= 1) then
            if (path == nil) then
                if (ChaseAttack.obstacleWalkTime < now) then
                    g_game.use(walkingTile:getTopThing());
                    ChaseAttack.obstacleWalkTime = now + 500;
                end
            end
            return
        end
    end
end);

-- Processa jumps
macro(100, function()
    if (ChaseAttack.mainMacro.isOff()) then return; end
    
    if (ChaseAttack.obstaclesQueue[1] and ChaseAttack.obstaclesQueue[1].isJump) then
        local playerPos = pos();
        local walkingTilePos = ChaseAttack.obstaclesQueue[1].oldPos;
        local distance = ChaseAttack.distanceFromPlayer(walkingTilePos);
        if (playerPos.z ~= walkingTilePos.z) then
            ChaseAttack.shiftFromQueue();
            return;
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        
        if (distance == 0) then
            g_game.turn(ChaseAttack.obstaclesQueue[1].dir);
            schedule(50, function()
                if (ChaseAttack.obstaclesQueue[1]) then
                    say(ChaseAttack.obstaclesQueue[1].spell);
                end
            end)
            return;
        elseif (distance < 2) then
            local nextFloor = g_map.getTile(walkingTilePos);
            if (ChaseAttack.obstacleWalkTime < now) then
                ChaseAttack.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
                ChaseAttack.obstacleWalkTime = now + 500;
            end
            return 
        elseif (distance >= 2 and distance < 5 and path) then
            use(ChaseAttack.obstaclesQueue[1].oldTile:getTopUseThing());
        elseif (path) then
            local tileToUse = playerPos;
            for i, value in ipairs(path) do
                if (i > 5) then break; end
                tileToUse = ChaseAttack.getDirection(tileToUse, value);
            end
            tileToUse = g_map.getTile(tileToUse);
            if (tileToUse) then
                use(tileToUse:getTopUseThing());
            end
        end
    end
end);

-- Processa custom ids
macro(100, function()
    if (ChaseAttack.mainMacro.isOff()) then return; end
    
    if (ChaseAttack.obstaclesQueue[1] and ChaseAttack.obstaclesQueue[1].isCustom) then
        local playerPos = pos();
        local walkingTile = ChaseAttack.obstaclesQueue[1].tile;
        local walkingTilePos = ChaseAttack.obstaclesQueue[1].tilePos;
        local distance = ChaseAttack.distanceFromPlayer(walkingTilePos);
        if (playerPos.z ~= walkingTilePos.z) then
            ChaseAttack.shiftFromQueue();
            return;
        end
        
        if (distance == 0) then
            if (ChaseAttack.obstaclesQueue[1].customId.castSpell) then
                say(ChaseAttack.defaultSpell);
                return;
            end
        elseif (distance < 2) then
            local item = findItem(ChaseAttack.defaultItem)
            if (ChaseAttack.obstaclesQueue[1].customId.castSpell or not item) then
                local nextFloor = g_map.getTile(walkingTilePos);
                if (ChaseAttack.obstacleWalkTime < now) then
                    ChaseAttack.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
                    ChaseAttack.obstacleWalkTime = now + 500;
                end
            elseif (item) then
                g_game.useWith(item, walkingTile);
                ChaseAttack.shiftFromQueue();
            end
            return 
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        if (path == nil or #path <= 1) then
            if (path == nil) then
                use(walkingTile:getTopUseThing());
            end
            return
        end
        
        local tileToUse = playerPos;
        for i, value in ipairs(path) do
            if (i > 5) then break; end
            tileToUse = ChaseAttack.getDirection(tileToUse, value);
        end
        tileToUse = g_map.getTile(tileToUse);
        if (tileToUse) then
            use(tileToUse:getTopUseThing());
        end
    end
end);

-- Macro principal - SEM g_game.follow(), apenas autoWalk
ChaseAttack.mainMacro = macro(ChaseAttack.walkDelay, 'Chase Attack', function()
    local target = ChaseAttack.getTarget()
    if (not target) then return; end
    
    -- Atualiza o ID do target atual
    if (ChaseAttack.currentTargetId ~= target:getId()) then
        ChaseAttack.currentTargetId = target:getId();
        ChaseAttack.obstaclesQueue = {}; -- Limpa fila ao trocar de target
    end
    
    -- Se tem obstáculo na fila, deixa as outras macros processarem
    if (#ChaseAttack.obstaclesQueue > 0) then return; end
    
    local targetPos = target:getPosition()
    if (not targetPos) then return; end
    
    local myPos = pos()
    
    -- Se no mesmo andar, usa autoWalk para chegar perto
    if (targetPos.z == myPos.z) then
        local path = findPath(myPos, targetPos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = true })
        if (not path) then return; end
        
        -- Se está longe, anda até o target
        if (#path > 1 and not player:isWalking()) then
            autoWalk(targetPos, 20, {ignoreNonPathable = true, precision = 1})
        end
    end
end);

-- Atualiza o target ID quando muda
macro(1, function()
    if (ChaseAttack.mainMacro.isOff()) then return; end
    local target = ChaseAttack.getTarget()

    if (target and ChaseAttack.currentTargetId ~= target:getId()) then
        ChaseAttack.currentTargetId = target:getId();
    end
end);

-- Cancela walk se target sumiu ou mudou de andar
macro(1000, function()
    if (ChaseAttack.mainMacro.isOff()) then return; end
    local target = ChaseAttack.getTarget()

    if (target) then
        local targetPos = target:getPosition();

        if (not targetPos or targetPos.z ~= posz()) then
            -- Target em outro andar, não cancela o walk
            -- deixa as macros de obstáculo processarem
        end
    end
end);


-- Ícone toggle na tela
local chaseIcon = addIcon("chaseAttack", {text="Chase\nAttack", switchable=false, moveable=true}, function()
    if ChaseAttack.mainMacro.isOn() then
        ChaseAttack.mainMacro.setOff()
    else
        ChaseAttack.mainMacro.setOn()
    end
end)
chaseIcon:setSize({height=30, width=50})
chaseIcon.text:setFont('verdana-11px-rounded')

macro(50, function()
    if ChaseAttack.mainMacro.isOn() then
        chaseIcon.text:setColoredText({"Chase\n","white","ON","green"})
    else
        chaseIcon.text:setColoredText({"Chase\n","white","OFF","red"})
    end
end)



UI.Separator()

FollowPlayer = {
  targetId = nil,
  obstaclesQueue = {},
  obstacleWalkTime = 0,
  currentTargetId = nil,
  keyToClearTarget = 'Escape',
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
      {
          id = 1948,
          castSpell = false
      },
      {
          id = 595,
          castSpell = false
      },
      {
          id = 1067,
          castSpell = false
      },
      {
          id = 1080,
          castSpell = false
      },
      {
          id = 386,
          castSpell = true
      },
  },
  lastCancelFollow = 0,
  followDelay = 300
};


FollowPlayer.distanceFromPlayer = function(position)
  local distx = math.abs(posx() - position.x);
  local disty = math.abs(posy() - position.y);

  return math.sqrt(distx * distx + disty * disty);
end

FollowPlayer.walkToPathDir = function(path)
  if (path) then
      g_game.walk(path[1], false);
  end
end

FollowPlayer.getDirection = function(playerPos, direction)
  local walkDir = FollowPlayer.walkDirTable[direction];
  if (walkDir) then
      playerPos[walkDir[1]] = playerPos[walkDir[1]] + walkDir[2];
  end
  return playerPos;
end


FollowPlayer.checkItemOnTile = function(tile, table)
  if (not tile) then return nil end;
  for _, item in ipairs(tile:getItems()) do
      local itemId = item:getId();
      for _, itemSelected in ipairs(table) do
          if (itemId == itemSelected.id) then
              return itemSelected;
          end
      end
  end
  return nil;
end

FollowPlayer.shiftFromQueue = function()
  g_game.cancelFollow();
  lastCancelFollow = now + FollowPlayer.followDelay;
  table.remove(FollowPlayer.obstaclesQueue, 1);
end

FollowPlayer.checkIfWentToCustomId = function(creature, newPos, oldPos, scheduleTime)
  local tile = g_map.getTile(oldPos);

  local customId = FollowPlayer.checkItemOnTile(tile, FollowPlayer.customIds);

  if (not customId) then return; end

  if (not scheduleTime) then
      scheduleTime = 0;
  end

  schedule(scheduleTime, function()
      if (oldPos.z == posz() or #FollowPlayer.obstaclesQueue > 0) then
          table.insert(FollowPlayer.obstaclesQueue, {
              oldPos = oldPos,
              newPos = newPos,
              tilePos = oldPos,
              customId = customId,
              tile = g_map.getTile(oldPos),
              isCustom = true
          });
          g_game.cancelFollow();
          lastCancelFollow = now + FollowPlayer.followDelay;
      end
  end);
end


FollowPlayer.checkIfWentToStair = function(creature, newPos, oldPos, scheduleTime)

  if (g_map.getMinimapColor(oldPos) ~= 210) then return; end
  local tile = g_map.getTile(oldPos);

  if (tile:isPathable()) then return; end

  if (not scheduleTime) then
      scheduleTime = 0;
  end

  schedule(scheduleTime, function()
      if (oldPos.z == posz() or #FollowPlayer.obstaclesQueue > 0) then
          table.insert(FollowPlayer.obstaclesQueue, {
              oldPos = oldPos,
              newPos = newPos,
              tilePos = oldPos,
              tile = tile,
              isStair = true
          });
          g_game.cancelFollow();
          lastCancelFollow = now + FollowPlayer.followDelay;
      end
  end);
end


FollowPlayer.checkIfWentToDoor = function(creature, newPos, oldPos)
  if (FollowPlayer.obstaclesQueue[1] and FollowPlayer.distanceFromPlayer(newPos) < FollowPlayer.distanceFromPlayer(oldPos)) then return; end
  if (math.abs(newPos.x - oldPos.x) == 2 or math.abs(newPos.y - oldPos.y) == 2) then
          

      local doorPos = {
          z = oldPos.z
      }

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

      local doorTile = g_map.getTile(doorPos);

      if (not doorTile:isPathable() or doorTile:isWalkable()) then return; end

      table.insert(FollowPlayer.obstaclesQueue, {
          newPos = newPos,
          tilePos = doorPos,
          tile = doorTile,
          isDoor = true,
      });
      g_game.cancelFollow();
      lastCancelFollow = now + FollowPlayer.followDelay;
  end
end


FollowPlayer.checkifWentToJumpPos = function(creature, newPos, oldPos)
  local pos1 = { x = oldPos.x - 1, y = oldPos.y - 1 };
  local pos2 = { x = oldPos.x + 1, y = oldPos.y + 1 };

  local hasStair = nil
  for x = pos1.x, pos2.x do
      for y = pos1.y, pos2.y do
          local tilePos = { x = x, y = y, z = oldPos.z };
          if (g_map.getMinimapColor(tilePos) == 210) then
              hasStair = true;
              goto continue;
          end
      end
  end
  ::continue::

  if (hasStair) then return; end

  local spell = newPos.z > oldPos.z and FollowPlayer.jumpSpell.down or FollowPlayer.jumpSpell.up;
  local dir = creature:getDirection();

  if (newPos.z > oldPos.z) then
      spell = FollowPlayer.jumpSpell.down;
  end

  table.insert(FollowPlayer.obstaclesQueue, {
      oldPos = oldPos,
      oldTile = g_map.getTile(oldPos),
      spell = spell,
      dir = dir,
      isJump = true,
  });
  g_game.cancelFollow();
  lastCancelFollow = now + FollowPlayer.followDelay;
end


onCreaturePositionChange(function(creature, newPos, oldPos)
  if (FollowPlayer.mainMacro.isOff()) then return; end

  if creature:getId() == FollowPlayer.currentTargetId and newPos and oldPos and oldPos.z == newPos.z then
      FollowPlayer.checkIfWentToDoor(creature, newPos, oldPos);
  end
end);


onCreaturePositionChange(function(creature, newPos, oldPos)
  if (FollowPlayer.mainMacro.isOff()) then return; end

  if creature:getId() == FollowPlayer.currentTargetId and newPos and oldPos and oldPos.z == posz() and oldPos.z ~= newPos.z then
      FollowPlayer.checkifWentToJumpPos(creature, newPos, oldPos);
  end
end);


onCreaturePositionChange(function(creature, newPos, oldPos)
  if (FollowPlayer.mainMacro.isOff()) then return; end

  if creature:getId() == FollowPlayer.currentTargetId and oldPos and g_map.getMinimapColor(oldPos) == 210 then
      local scheduleTime = oldPos.z == posz() and 0 or 250;

      FollowPlayer.checkIfWentToStair(creature, newPos, oldPos, scheduleTime);
  end
end);



onCreaturePositionChange(function(creature, newPos, oldPos)
  if (FollowPlayer.mainMacro.isOff()) then return; end
  if creature:getId() == FollowPlayer.currentTargetId and oldPos and oldPos.z == posz() and (not newPos or oldPos.z ~= newPos.z) then
      FollowPlayer.checkIfWentToCustomId(creature, newPos, oldPos);
  end
end);


macro(1, function()
  if (FollowPlayer.mainMacro.isOff()) then return; end

  if (FollowPlayer.obstaclesQueue[1] and ((not FollowPlayer.obstaclesQueue[1].isJump and FollowPlayer.obstaclesQueue[1].tilePos.z ~= posz()) or (FollowPlayer.obstaclesQueue[1].isJump and FollowPlayer.obstaclesQueue[1].oldPos.z ~= posz()))) then
      table.remove(FollowPlayer.obstaclesQueue, 1);
  end
end);



macro(100, function()
  if (FollowPlayer.mainMacro.isOff()) then return; end
  if (FollowPlayer.obstaclesQueue[1] and FollowPlayer.obstaclesQueue[1].isStair) then
      local start = now
      local playerPos = pos();
      local walkingTile = FollowPlayer.obstaclesQueue[1].tile;
      local walkingTilePos = FollowPlayer.obstaclesQueue[1].tilePos;

      if (FollowPlayer.distanceFromPlayer(walkingTilePos) < 2) then
          if (FollowPlayer.obstacleWalkTime < now) then
              local nextFloor = g_map.getTile(walkingTilePos);
              if (nextFloor:isPathable()) then
                  FollowPlayer.obstacleWalkTime = now + 250;
                  use(nextFloor:getTopUseThing());
              else
                  FollowPlayer.obstacleWalkTime = now + 250;
                  FollowPlayer.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
              end
              FollowPlayer.shiftFromQueue();
              return 
          end
      end
      local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
      if (path == nil or #path <= 1) then
          if (path == nil) then
              use(walkingTile:getTopUseThing());
          end
          return
      end
      
      local tileToUse = playerPos;
      for i, value in ipairs(path) do
          if (i > 5) then break; end
          tileToUse = FollowPlayer.getDirection(tileToUse, value);
      end
      tileToUse = g_map.getTile(tileToUse);
      if (tileToUse) then
          use(tileToUse:getTopUseThing());
      end
  end
end);


macro(1, function()
  if (FollowPlayer.mainMacro.isOff()) then return; end

  if (FollowPlayer.obstaclesQueue[1] and FollowPlayer.obstaclesQueue[1].isDoor) then
      local playerPos = pos();
      local walkingTile = FollowPlayer.obstaclesQueue[1].tile;
      local walkingTilePos = FollowPlayer.obstaclesQueue[1].tilePos;
      if (table.compare(playerPos, FollowPlayer.obstaclesQueue[1].newPos)) then
          FollowPlayer.obstacleWalkTime = 0;
          FollowPlayer.shiftFromQueue();
      end
      
      local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
      if (path == nil or #path <= 1) then
          if (path == nil) then

              if (FollowPlayer.obstacleWalkTime < now) then
                  g_game.use(walkingTile:getTopThing());
                  FollowPlayer.obstacleWalkTime = now + 500;
              end
          end
          return
      end
  end
end);


macro(100, function()
  if (FollowPlayer.mainMacro.isOff()) then return; end
  
  if (FollowPlayer.obstaclesQueue[1] and FollowPlayer.obstaclesQueue[1].isJump) then
      local playerPos = pos();
      local walkingTilePos = FollowPlayer.obstaclesQueue[1].oldPos;
      local distance = FollowPlayer.distanceFromPlayer(walkingTilePos);
      if (playerPos.z ~= walkingTilePos.z) then
          FollowPlayer.shiftFromQueue();
          return;
      end

      local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
      
      if (distance == 0) then
          g_game.turn(FollowPlayer.obstaclesQueue[1].dir);
          schedule(50, function()
              if (FollowPlayer.obstaclesQueue[1]) then
                  say(FollowPlayer.obstaclesQueue[1].spell);
              end
          end)
          return;
      elseif (distance < 2) then
          local nextFloor = g_map.getTile(walkingTilePos);
          if (FollowPlayer.obstacleWalkTime < now) then
              FollowPlayer.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
              FollowPlayer.obstacleWalkTime = now + 500;
          end
          return 
      elseif (distance >= 2 and distance < 5 and path) then
          use(FollowPlayer.obstaclesQueue[1].oldTile:getTopUseThing());
      elseif (path) then
          local tileToUse = playerPos;
          for i, value in ipairs(path) do
              if (i > 5) then break; end
              tileToUse = FollowPlayer.getDirection(tileToUse, value);
          end
          tileToUse = g_map.getTile(tileToUse);
          if (tileToUse) then
              use(tileToUse:getTopUseThing());
          end
      end
  end
end);


macro(100, function()
  if (FollowPlayer.mainMacro.isOff()) then return; end
  
  if (FollowPlayer.obstaclesQueue[1] and FollowPlayer.obstaclesQueue[1].isCustom) then
      local playerPos = pos();
      local walkingTile = FollowPlayer.obstaclesQueue[1].tile;
      local walkingTilePos = FollowPlayer.obstaclesQueue[1].tilePos;
      local distance = FollowPlayer.distanceFromPlayer(walkingTilePos);
      if (playerPos.z ~= walkingTilePos.z) then
          FollowPlayer.shiftFromQueue();
          return;
      end
      
      if (distance == 0) then
          if (FollowPlayer.obstaclesQueue[1].customId.castSpell) then
              say(FollowPlayer.defaultSpell);
              return;
          end
      elseif (distance < 2) then
          local item = findItem(FollowPlayer.defaultItem)
          if (FollowPlayer.obstaclesQueue[1].customId.castSpell or not item) then
              local nextFloor = g_map.getTile(walkingTilePos);
              if (FollowPlayer.obstacleWalkTime < now) then
                  FollowPlayer.walkToPathDir(findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
                  FollowPlayer.obstacleWalkTime = now + 500;
              end
          elseif (item) then
              g_game.useWith(item, walkingTile);
              FollowPlayer.shiftFromQueue();
          end
          return 
      end

      local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
      if (path == nil or #path <= 1) then
          if (path == nil) then
              use(walkingTile:getTopUseThing());
          end
          return
      end
      
      local tileToUse = playerPos;
      for i, value in ipairs(path) do
          if (i > 5) then break; end
          tileToUse = FollowPlayer.getDirection(tileToUse, value);
      end
      tileToUse = g_map.getTile(tileToUse);
      if (tileToUse) then
          use(tileToUse:getTopUseThing());
      end
  end
end);


addTextEdit("FollowPlayer", storage.FollowPlayerName or "Nome do player", function(widget, text)
  storage.FollowPlayerName = text;
end);

FollowPlayer.mainMacro = macro(FollowPlayer.followDelay, 'Follow Player', function()
  local followingPlayer = g_game.getFollowingCreature();
  local playerToFollow = getCreatureByName(storage.FollowPlayerName);
  if (not playerToFollow) then return; end
  if (not findPath(pos(), playerToFollow:getPosition(), 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = true })) then
      if (followingPlayer and followingPlayer:getId() == playerToFollow:getId()) then
          lastCancelFollow = now + FollowPlayer.followDelay;
          return g_game.cancelFollow();
      end
  elseif (not followingPlayer and playerToFollow and playerToFollow:canShoot() and FollowPlayer.lastCancelFollow < now) then
      g_game.follow(playerToFollow);
  end
end);


macro(1, function()
  if (FollowPlayer.mainMacro.isOff()) then return; end
  local playerToFollow = getCreatureByName(storage.FollowPlayerName);

  if (playerToFollow and FollowPlayer.currentTargetId ~= playerToFollow:getId()) then
      FollowPlayer.currentTargetId = playerToFollow:getId();
  end
end);

macro(1000, function()
  if (FollowPlayer.mainMacro.isOff()) then return; end
  local target = g_game.getFollowingCreature();


  if (target) then
      local targetPos = target:getPosition();

      if (not targetPos or targetPos.z ~= posz()) then
          g_game.cancelFollow();
      end
  end
end);




UI.Separator()
-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Follow Attack: Ataca o mesmo alvo que seu parceiro está atacando
storage.followAttackNick = storage.followAttackNick or ""

local followAttackPanel = setupUI([[
Panel
  height: 20
  margin-top: 5

  Label
    text: Parceiro:
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 55
    font: verdana-11px-rounded

  BotTextEdit
    id: nickInput
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 5
]], rightPanel)

followAttackPanel.nickInput:setText(storage.followAttackNick)
followAttackPanel.nickInput.onTextChange = function(widget, text)
  storage.followAttackNick = text
end

-- Controle para desativar/reativar Follow Player automaticamente
local followPlayerWasOn = false

-- Armazena o último target do parceiro para detectar quando ele INICIA um ataque
local parceiroLastTarget = nil

local followAttackMacro = macro(200, "Follow Attack", function()
  local parceiro = storage.followAttackNick
  if parceiro == "" then return end
  
  local parceiroCreature = getCreatureByName(parceiro)
  if not parceiroCreature then return end
  
  local parceiroPos = parceiroCreature:getPosition()
  local myPos = pos()
  if not parceiroPos or parceiroPos.z ~= myPos.z then return end
  
  -- Verifica se o PARCEIRO está atacando alguém (virado para um player adjacente)
  local parceiroTarget = nil
  for _, spec in ipairs(getSpectators()) do
    if spec ~= player and spec:getName() ~= parceiro and spec:isPlayer() then
      local specPos = spec:getPosition()
      if specPos and specPos.z == parceiroPos.z then
        local dist = getDistanceBetween(parceiroPos, specPos)
        if dist <= 1 then
          -- Verifica se o parceiro está virado para essa criatura (indica ataque)
          local dir = parceiroCreature:getDirection()
          local dx = specPos.x - parceiroPos.x
          local dy = specPos.y - parceiroPos.y
          
          local isLookingAt = false
          -- Norte
          if dir == 0 and dy == -1 and math.abs(dx) <= 1 then isLookingAt = true
          -- Leste
          elseif dir == 1 and dx == 1 and math.abs(dy) <= 1 then isLookingAt = true
          -- Sul
          elseif dir == 2 and dy == 1 and math.abs(dx) <= 1 then isLookingAt = true
          -- Oeste
          elseif dir == 3 and dx == -1 and math.abs(dy) <= 1 then isLookingAt = true
          -- Nordeste
          elseif dir == 4 and dx >= 0 and dy <= 0 and dist <= 1 then isLookingAt = true
          -- Sudeste
          elseif dir == 5 and dx >= 0 and dy >= 0 and dist <= 1 then isLookingAt = true
          -- Sudoeste
          elseif dir == 6 and dx <= 0 and dy >= 0 and dist <= 1 then isLookingAt = true
          -- Noroeste
          elseif dir == 7 and dx <= 0 and dy <= 0 and dist <= 1 then isLookingAt = true
          end
          
          if isLookingAt then
            parceiroTarget = spec
            break
          end
        end
      end
    end
  end
  
  -- Se parceiro não está atacando ninguém, limpa o último target e não faz nada
  if not parceiroTarget then 
    parceiroLastTarget = nil
    return 
  end
  
  -- Só ataca se for um NOVO target (parceiro iniciou ataque)
  -- Ou se já estamos atacando o mesmo target (continua)
  local currentAttack = g_game.getAttackingCreature()
  if currentAttack and currentAttack:getId() == parceiroTarget:getId() then
    -- Já estamos atacando o mesmo, apenas segue
  elseif parceiroLastTarget ~= parceiroTarget:getId() then
    -- É um novo target, parceiro iniciou ataque em alguém novo
    parceiroLastTarget = parceiroTarget:getId()
    g_game.attack(parceiroTarget)
  else
    -- Mesmo target de antes mas não estamos atacando, inicia ataque
    if not currentAttack then
      g_game.attack(parceiroTarget)
    end
  end
  
  -- Anda até o target
  if player:isWalking() then return end
  local tpos = parceiroTarget:getPosition()
  if getDistanceBetween(myPos, tpos) > 1 then
    autoWalk(tpos, 20, {ignoreNonPathable=true, precision=1})
  end
end)

-- Macro para controlar Follow Player quando atacando
macro(100, function()
  if followAttackMacro.isOff() then return end
  
  local attacking = g_game.isAttacking()
  
  if attacking then
    -- Está atacando: desativa Follow Player se estava ligado
    if FollowPlayer.mainMacro.isOn() then
      followPlayerWasOn = true
      FollowPlayer.mainMacro.setOff()
    end
  else
    -- Não está atacando: reativa Follow Player se foi desativado automaticamente
    if followPlayerWasOn and FollowPlayer.mainMacro.isOff() then
      FollowPlayer.mainMacro.setOn()
      followPlayerWasOn = false
    end
  end
end)

addIcon("followAttackMacro", {item = 12953, text = "Follow\nATK"}, followAttackMacro)




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

