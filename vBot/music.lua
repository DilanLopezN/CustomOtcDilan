setDefaultTab("Music")

local ConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
local MUSIC_PATH = "/bot/" .. ConfigName .. "/sounds/"

storage.musicPlayer = storage.musicPlayer or {
    volume = 100,
    currentTrack = nil
}

local selectedFile = nil
local selectedWidget = nil

local function loadMusicFiles()
    local files = {}
    if g_resources.directoryExists(MUSIC_PATH) then
        local allFiles = g_resources.listDirectoryFiles(MUSIC_PATH, false, false)
        for _, file in ipairs(allFiles) do
            local ext = file:split(".")
            ext = ext[#ext]:lower()
            if ext == "ogg" or ext == "wav" then
                table.insert(files, file)
            end
        end
    end
    return files
end

local musicUI = setupUI([[
Panel
  height: 185

  Label
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text: Music Player
    text-align: center
    font: verdana-11px-rounded
    color: orange

  TextList
    id: musicList
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 80
    margin-top: 5
    vertical-scrollbar: musicScrollBar
    focusable: false

  VerticalScrollBar
    id: musicScrollBar
    anchors.top: musicList.top
    anchors.bottom: musicList.bottom
    anchors.right: musicList.right
    step: 14
    pixels-scroll: true

  Panel
    id: controls
    anchors.top: musicList.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 25
    margin-top: 8

    Button
      id: playBtn
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Play
      width: 60
      height: 20

    Button
      id: stopBtn
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      text: Stop
      width: 60
      height: 20
      margin-left: 5

    Button
      id: refreshBtn
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Refresh
      width: 60
      height: 20

  Label
    id: nowPlaying
    anchors.top: controls.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: --
    text-align: center
    font: verdana-11px-rounded
    color: white
    margin-top: 5

  Label
    id: volLabel
    anchors.top: nowPlaying.bottom
    anchors.left: parent.left
    text: Vol:
    font: verdana-11px-rounded
    color: white
    margin-top: 5
    width: 25

  HorizontalScrollBar
    id: volumeBar
    anchors.top: nowPlaying.bottom
    anchors.left: volLabel.right
    anchors.right: parent.right
    margin-top: 5
    margin-left: 3
    minimum: 0
    maximum: 100
    step: 5
]])

local function selectEntry(widget)
    if selectedWidget then
        selectedWidget:setBackgroundColor("alpha")
        selectedWidget:setColor("white")
    end
    selectedWidget = widget
    selectedFile = widget.file
    widget:setBackgroundColor("#ffffff33")
    widget:setColor("orange")
end

local function refreshMusicList()
    musicUI.musicList:destroyChildren()
    selectedFile = nil
    selectedWidget = nil
    
    local files = loadMusicFiles()
    
    if #files == 0 then
        local label = g_ui.createWidget("Label", musicUI.musicList)
        label:setText("Pasta: " .. MUSIC_PATH)
        label:setColor("gray")
        label:setFont("verdana-11px-rounded")
        return
    end
    
    for _, file in ipairs(files) do
        local label = g_ui.createWidget("Label", musicUI.musicList)
        label:setText(file)
        label:setFont("verdana-11px-rounded")
        label:setColor("white")
        label:setHeight(16)
        label:setTextOffset({x = 3, y = 0})
        label.file = file
        
        label.onMouseRelease = function(widget, mousePos, mouseButton)
            if mouseButton == MouseLeftButton then
                selectEntry(widget)
                return true
            end
        end
        
        label.onDoubleClick = function(widget)
            selectEntry(widget)
            playSound(widget.file)
            return true
        end
    end
end

function playSound(file)
    local path = MUSIC_PATH .. file
    if g_resources.fileExists(path) then
        -- Tenta diferentes métodos de tocar som
        local success = false
        
        -- Método 1: modules.client_audio
        if modules.client_audio and modules.client_audio.playSound then
            pcall(function()
                modules.client_audio.playSound(path)
                success = true
            end)
        end
        
        -- Método 2: g_sounds.playMusic
        if not success then
            pcall(function()
                g_sounds.playMusic(path, 0)
                success = true
            end)
        end
        
        -- Método 3: g_sounds diretamente
        if not success then
            pcall(function()
                g_sounds.getChannel(1):play(path, 0, storage.musicPlayer.volume / 100)
                success = true
            end)
        end

        storage.musicPlayer.currentTrack = file
        musicUI.nowPlaying:setText("Playing: " .. file)
        musicUI.nowPlaying:setColor("#00ff00")
    else
        musicUI.nowPlaying:setText("Arquivo nao encontrado")
        musicUI.nowPlaying:setColor("red")
    end
end

function stopSound()
    pcall(function() g_sounds.stopMusic() end)
    pcall(function() g_sounds.getChannel(1):stop() end)
    storage.musicPlayer.currentTrack = nil
    musicUI.nowPlaying:setText("--")
    musicUI.nowPlaying:setColor("white")
end

musicUI.controls.playBtn.onClick = function()
    if selectedFile then
        playSound(selectedFile)
    else
        musicUI.nowPlaying:setText("Selecione uma musica")
        musicUI.nowPlaying:setColor("yellow")
    end
end

musicUI.controls.stopBtn.onClick = function()
    stopSound()
end

musicUI.controls.refreshBtn.onClick = function()
    refreshMusicList()
    musicUI.nowPlaying:setText("Lista atualizada")
    musicUI.nowPlaying:setColor("yellow")
end

musicUI.volumeBar.onValueChange = function(widget, value)
    storage.musicPlayer.volume = value
end

musicUI.volumeBar:setValue(storage.musicPlayer.volume)
refreshMusicList()