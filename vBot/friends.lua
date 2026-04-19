-- =============================================
-- FRIENDS / ENEMYS - Marcador F/E sobre o personagem
-- Depende de storage.friends_enemies e helpers definidos em main.lua
-- Carregado APOS follow.lua (que tambem usa creature:setText)
-- =============================================

if type(storage.friends_enemies) ~= "table" then
  storage.friends_enemies = { friends = {}, enemies = {} }
end

local FRIEND_PREFIX = "[F] "
local ENEMY_PREFIX  = "[E] "

local function isFriendByName(name)
  if type(feIsFriend) == "function" then return feIsFriend(name) end
  return false
end

local function isEnemyByName(name)
  if type(feIsEnemy) == "function" then return feIsEnemy(name) end
  return false
end

-- Aplica/atualiza o marcador sobre a criatura.
-- Preserva HP% ja escrito por follow.lua concatenando-o apos o prefixo.
local function applyMark(creature)
  if not creature or not creature.isPlayer then return end
  if not creature:isPlayer() then return end
  if creature:isLocalPlayer() then return end

  local name = creature:getName()
  if not name or name:len() == 0 then return end

  local current = ""
  if type(creature.getText) == "function" then
    local ok, t = pcall(function() return creature:getText() end)
    if ok and t then current = t end
  end

  -- remove prefixos antigos para nao acumular
  current = current:gsub("^%[F%] ", ""):gsub("^%[E%] ", "")

  if isFriendByName(name) then
    creature:setText(FRIEND_PREFIX .. current)
  elseif isEnemyByName(name) then
    creature:setText(ENEMY_PREFIX .. current)
  else
    -- remove marcador caso tenha sido removido da lista
    creature:setText(current)
  end
end

-- Expoe funcoes globais
function feApplyMark(creature)
  pcall(applyMark, creature)
end

function feRefreshAllMarks()
  local specs = getSpectators and getSpectators() or {}
  for _, spec in ipairs(specs) do
    pcall(applyMark, spec)
  end
end

-- Cor do outline (alem do label) ajuda a identificar visualmente
local function applyMarkAndOutline(creature)
  applyMark(creature)
  if not creature or not creature.isPlayer or not creature:isPlayer() then return end
  if creature:isLocalPlayer() then return end
  local name = creature:getName()
  if isFriendByName(name) then
    pcall(function() creature:setMarked("#00FF66") end)
  elseif isEnemyByName(name) then
    pcall(function() creature:setMarked("#FF4444") end)
  end
end

-- Hooks de eventos do jogo
if onCreatureAppear then
  onCreatureAppear(function(creature)
    pcall(applyMarkAndOutline, creature)
  end)
end

if onCreaturePositionChange then
  onCreaturePositionChange(function(creature, newPos, oldPos)
    pcall(applyMark, creature)
  end)
end

-- Reaplica apos follow.lua escrever HP% (hook registrado depois dele)
if onCreatureHealthPercentChange then
  onCreatureHealthPercentChange(function(creature, hp)
    pcall(applyMark, creature)
  end)
end

-- Refresh inicial + periodico (para pegar players que ja estavam visiveis)
schedule(500, function()
  pcall(feRefreshAllMarks)
end)

macro(3000, function()
  pcall(feRefreshAllMarks)
end)

-- =============================================
-- Filtro Battle: esconde friends e evidencia enemies
-- =============================================
schedule(1000, function()
  if not modules or not modules.game_battle then return end
  local gb = modules.game_battle

  if type(gb.doCreatureFitFilters) == "function" and not gb._feOriginalFitFilters then
    gb._feOriginalFitFilters = gb.doCreatureFitFilters
  end

  gb.doCreatureFitFilters = function(creature)
    if not creature then return false end
    if type(creature.isLocalPlayer) == "function" and creature:isLocalPlayer() then
      return false
    end
    if type(creature.getHealthPercent) == "function" and creature:getHealthPercent() <= 0 then
      return false
    end
    if type(creature.isPlayer) == "function" and creature:isPlayer() then
      local name = creature.getName and creature:getName() or nil
      if name and isFriendByName(name) then
        return false
      end
    end
    if gb._feOriginalFitFilters then
      local ok, res = pcall(gb._feOriginalFitFilters, creature)
      if ok then return res end
    end
    return true
  end
end)

-- Evidencia enemies na lista de battle (cor vermelha no label)
local function highlightBattleEnemies()
  local root = g_ui.getRootWidget()
  if not root then return end
  local panel = root:recursiveGetChildById("battlePanel")
  if not panel or type(panel.getChildren) ~= "function" then return end
  for _, btn in ipairs(panel:getChildren()) do
    local creature = btn.creature
    if creature and type(creature.isPlayer) == "function" and creature:isPlayer() then
      local name = type(creature.getName) == "function" and creature:getName() or nil
      local label = type(btn.getChildById) == "function" and btn:getChildById("label") or nil
      if name and label then
        if isEnemyByName(name) then
          label:setColor("#FF4444")
        elseif isFriendByName(name) then
          label:setColor("#00FF66")
        end
      end
    end
  end
end

macro(500, function()
  pcall(highlightBattleEnemies)
end)
