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
