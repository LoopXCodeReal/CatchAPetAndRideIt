--[[
    ====================================================================
    LOOPXCODE — WINDUI ONLY BUILD (single UI, no manual UI, no double UI)
    Perbaikan:
      1. Satu UI saja: WindUI. Komponen dibangun dari registry, bukan frame manual.
      2. Auto Catch pakai satu driver loop (tidak ada lagi chain dobel).
      3. Key genv.LoopXCode_HardenCfg.AntiSpeed -> AutoAntiSpeed diperbaiki.
      4. Restore snapshot toggle di-reset supaya tidak memakai data basi.
      5. FPS/Ping tampil sebagai paragraph WindUI, bukan HUD manual.
      6. Floating open button pakai drag+klik terpadu, satu jalur klik.
      7. RADIUS PASS: semua sisi radius (window, elemen, dropdown, HUD, float).
    ====================================================================
]]

getgenv().LXC_START_MARKER = os.clock()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local USE_EXTERNAL_UI = true
local genv = (type(getgenv) == "function") and getgenv() or _G
-- execute-file tidak memberi STATE, jadi pakai epoch sendiri supaya loop dari
-- run lama berhenti saat file dijalankan ulang.
genv.LoopXCode_RunEpoch = (tonumber(genv.LoopXCode_RunEpoch) or 0) + 1
local RUN_EPOCH = genv.LoopXCode_RunEpoch

-- =====================================================================
-- FONT — pakai keluarga Gotham yang bersih dan enak dibaca.
-- Display buat logo, Bold/SemiBold buat judul & ESP, Regular buat teks hub.
-- =====================================================================
local function safeFont(primary: Enum.Font, fallback: Enum.Font): Font
    local ok, result = pcall(function()
        return Font.fromEnum(primary)
    end)
    if ok and result then return result end
    return Font.fromEnum(fallback)
end

local SafeFonts = {
    Logo = safeFont(Enum.Font.FredokaOne, Enum.Font.GothamBlack),
    Display = safeFont(Enum.Font.GothamBlack, Enum.Font.GothamBold),
    Bold = safeFont(Enum.Font.GothamBold, Enum.Font.Gotham),
    SemiBold = safeFont(Enum.Font.GothamMedium, Enum.Font.Gotham),
    Regular = safeFont(Enum.Font.Gotham, Enum.Font.SourceSans),
    -- Key "Mono" sengaja tetap ada supaya config lama nggak rusak,
    -- tapi sekarang di-map ke Gotham juga (bukan RobotoMono yang jelek).
    Mono = safeFont(Enum.Font.Gotham, Enum.Font.SourceSans)
}
genv.LoopXCode_Fonts = SafeFonts

local FONT_CHOICES = { "Logo", "Display", "Bold", "SemiBold", "Regular", "Mono" }
local function fontFaceByName(name)
    return SafeFonts[tostring(name or "Regular")] or SafeFonts.Regular
end

-- =====================================================================
-- BAHASA — default English. Kunci = teks English persis yang dipakai UI.
-- =====================================================================
local LangCfg = { Language = "English" }
genv.LoopXCode_LangCfg = LangCfg

-- Config bernama: satu slot default, bisa disimpan/dimuat ulang kapan saja.
local ConfigCfg = { Name = "default" }
genv.LoopXCode_ConfigCfg = ConfigCfg
local UIHandles = {}
genv.LoopXCode_UIHandles = UIHandles
local CONFIG_BANK_ATTR = "LoopXCodeConfigBank"

local function jsonSafe(value)
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "any" end
        return value
    end
    if typeof(value) == "Color3" then
        return string.format("#%02X%02X%02X",
            math.floor(value.R * 255 + 0.5),
            math.floor(value.G * 255 + 0.5),
            math.floor(value.B * 255 + 0.5))
    end
    if type(value) == "table" then
        local out = {}
        for k, v in pairs(value) do
            if type(k) == "string" or type(k) == "number" then out[tostring(k)] = jsonSafe(v) end
        end
        return out
    end
    return value
end

local LANG_TEXT = {
    ["Welcome to my script enjoy for feature!"] = "Selamat datang di script saya, nikmati fiturnya!",

    ["Controls"] = "Kontrol", ["Target"] = "Target", ["Current Target"] = "Target Saat Ini",
    ["Activity"] = "Aktivitas", ["Performance"] = "Performa", ["Status Steal"] = "Status Tangkap",
    ["Steal Progress"] = "Progres Penangkapan", ["HUD Size"] = "Ukuran HUD",
    ["Capture"] = "Penangkapan", ["Finder"] = "Pencari", ["Pet Finder"] = "Pencari Pet",
    ["Settings"] = "Pengaturan", ["Features"] = "Fitur", ["ESP Style"] = "Gaya ESP",
    ["Misc"] = "Lainnya",

    ["HUD Width"] = "Lebar HUD", ["HUD Height"] = "Tinggi HUD",
    ["HUD Text Size"] = "Ukuran Teks HUD", ["HUD Gap"] = "Jarak HUD",
    ["HUD Shadow"] = "Bayangan HUD", ["HUD Shadow Offset"] = "Offset Bayangan HUD",
    ["HUD Font"] = "Font HUD", ["Logo Font"] = "Font Logo",
    ["Auto Catch"] = "Tangkap Otomatis", ["Catch Reel"] = "Mode Reel",
    ["Catch Rarity (tier)"] = "Rarity Tangkap (tier)", ["Catch Zone"] = "Zona Tangkap",
    ["Min Income"] = "Income Minimum", ["Auto Equip Best Speed"] = "Auto Equip Kecepatan Terbaik",
    ["Walk Speed"] = "Kecepatan Jalan", ["Walk speed used by Auto Catch in studs/sec (16-400)"] = "Kecepatan jalan Auto Catch dalam studs/detik (16-400)",
    ["Find Pet"] = "Cari Pet", ["Biome / Map"] = "Biome / Map",
    ["Refresh Finder"] = "Segarkan Pencari", ["Apply Safe Fonts"] = "Terapkan Font Aman",
    ["Menu Background"] = "Latar Menu", ["Skip Tutorial"] = "Lewati Tutorial",
    ["Pet ESP"] = "ESP Pet", ["Guardian ESP"] = "ESP Penjaga", ["Player ESP"] = "ESP Pemain",
    ["ESP Info"] = "Info ESP", ["ESP Range"] = "Jarak ESP",
    ["Save History"] = "Simpan Riwayat", ["Save UI"] = "Simpan UI", ["Save Menu"] = "Simpan Menu",
    ["Export Config"] = "Ekspor Config", ["Language"] = "Bahasa",
    ["Config Name"] = "Nama Config", ["Save Config"] = "Simpan Config",
    ["Load Config"] = "Muat Config",
    ["Save current settings under Config Name"] = "Simpan pengaturan saat ini dengan Nama Config",
    ["Load settings from Config Name"] = "Muat pengaturan dari Nama Config",

    ["Auto Claim Index"] = "Klaim Index Otomatis", ["Auto Upgrade"] = "Upgrade Otomatis",
    ["Auto Upgrade Treadmill"] = "Upgrade Treadmill Otomatis", ["Auto Treadmill"] = "Treadmill Otomatis",
    ["Anti Hit"] = "Anti Serangan", ["Auto Sell Pet"] = "Jual Pet Otomatis",
    ["Sell Rarities"] = "Rarity Dijual", ["Sell Now"] = "Jual Sekarang",
    ["Search Features"] = "Cari Fitur", ["Search all features"] = "Cari semua fitur",
    ["Auto Sell"] = "Jual Otomatis", ["Sell Interval"] = "Interval Jual",
    ["Experimen"] = "Eksperimen", ["Weak Lasso Catch"] = "Tangkap Lasso Lemah",
    ["Anti Ban"] = "Anti Ban", ["Anti AFK"] = "Anti AFK", ["God Mode"] = "Mode Dewa",
    ["Fly"] = "Terbang", ["Jump Infinity"] = "Lompat Tak Terbatas",
    ["Anti Knock Down"] = "Anti Jatuh", ["Invisible"] = "Tidak Terlihat",
    ["Anti Ragdoll"] = "Anti Ragdoll", ["Auto Anti Speed"] = "Anti Kecepatan Otomatis",

    ["Approach, lasso, reel, and secure the pet"] = "Dekati, laso, reel, dan amankan pet",
    ["ON = ride the fastest pet / OFF = dismount (auto off when Auto Treadmill is ON)"] =
        "ON = naik pet tercepat / OFF = turun dari pet (mati otomatis saat Auto Treadmill ON)",
    ["Force all hub text to Gotham (clean and readable)"] = "Paksa semua teks hub pakai Gotham (bersih & enak dibaca)",
    ["5k / 30b / 50t  (blank = any)"] = "5k / 30b / 50t  (kosong = semua)",
    ["Pet name, e.g. Bunny"] = "Nama pet, mis. Bunny",
    ["lasso too weak: "] = "lasso kurang kuat: ",
    ["strong enough"] = "cukup kuat", ["too weak"] = "kurang kuat",
    ["Failed"] = "Gagal", ["Done"] = "Selesai", ["Weak"] = "Lemah",
    ["Total pets"] = "Total pet", ["Lasso"] = "Lasso", ["Total"] = "Total",
    ["0.55  (0 = off, 1 = solid)"] = "0.55  (0 = mati, 1 = pekat)",
    ["#38BDF8  or  56,189,248"] = "#38BDF8  atau  56,189,248",
    ["Auto upgrade pen via valid 'sign' remote (off by default)"] = "Auto upgrade kandang via valid 'sign' remote (off by default)",
    ["manual steal (lasso still checked)"] = "manual steal (lasso tetap dicek)",
    ["Catch weak-lasso pets; still walks back to the safe zone"] = "Tangkap pet dengan lasso lemah; tetap kembali ke safe zone",
    ["Sell every selected rarity automatically"] = "Jual semua rarity yang dipilih otomatis",
    ["Select multiple rarities to sell"] = "Pilih beberapa rarity untuk dijual",
    ["Sell selected rarities once"] = "Jual rarity yang dipilih sekali",
    ["auto sell"] = "jual otomatis", ["pets"] = "pet",
    ["All"] = "Semua", ["English"] = "English", ["Indonesia"] = "Indonesia"
}
genv.LoopXCode_LangText = LANG_TEXT

local function translateKey(key, lang)
    key = tostring(key or "")
    if lang == "Indonesia" then return LANG_TEXT[key] or key end
    return key
end

local function tr(key)
    return translateKey(key, LangCfg.Language)
end
genv.LoopXCode_Translate = tr

local function applyFont(instance: GuiObject, fontFace: Font, textSize: number?)
    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        instance.FontFace = fontFace
        if textSize then instance.TextSize = textSize end
    end
end
genv.LoopXCode_ApplyFont = applyFont

-- Apply font ke seluruh teks hub (icon glyph satu karakter dilewati supaya
-- font icon WindUI nggak rusak).
local function applyFontTree(root)
    if not root then return end
    for _, o in ipairs(root:GetDescendants()) do
        if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
            local text = tostring(o.Text or "")
            if #text > 1 or text:match("%w") then
                pcall(function() o.FontFace = SafeFonts.Bold end)
            end
        end
    end
end
genv.LoopXCode_ApplyFontTree = applyFontTree

-- Jangan paksa StreamingEnabled=false / radius gede: itu bikin client nge-load
-- seluruh map sekaligus dan gameplay kelihatan pause. Pet jauh tetap ketemu
-- karena hub jalan ke map tujuan dulu (stageToZone), jadi streaming load
-- bagian yang dibutuhkan saja.

-- live-reload: loop lama nggak bisa dihentikan kalau cuma pakai flag bersama.
-- Instance baru pakai flag V2; flag lama dipaksa false supaya instance lama diam.
local alive = (type(STATE) == "table" and type(STATE.alive) == "function")
    and function() return STATE.alive() and genv.LoopXCode_RunEpoch == RUN_EPOCH end
    or function() return genv.LoopXCode_RunEpoch == RUN_EPOCH end
genv.LoopXCode_AutoEquipSpeed = false
genv.LoopXCode_AutoEquipV2 = true

-- Safe GUI Parent (executor gethui / CoreGui / PlayerGui)
local function GetSafeGuiParent()
    local ok, res = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if ok and res then return res end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ParentGui = GetSafeGuiParent()

-- Sisa build lama yang memakai UI manual dibersihkan.
for _, o in ipairs(ParentGui:GetChildren()) do
    if o.Name == "LoopXCodeUI" or o.Name == "LoopXCode_FloatingToggle"
        or o.Name == "LXC_ToggleGui" or o.Name == "LXC_MenuBackground"
        or o.Name == "LXC_LoadingGui" or o.Name == "LoopXCode_ESP_Holder" then
        pcall(function() o:Destroy() end)
    end
end
-- Live-reload: matikan instance harden lama yang masih menyimpan loop aktif.
pcall(function()
    local prev = genv.LoopXCode_HardenCfg
    if type(prev) == "table" then
        for _, k in ipairs({
            "AutoClaimIndex", "AutoUpgradeTraining", "AutoUpgradeTreadmill", "AutoTreadmill", "AntiBan", "AntiAFK",
            "GodMode", "Fly", "JumpInfinity", "AntiKnockDown", "Invisible",
            "AntiRagdoll", "AutoAntiSpeed", "AntiHit"
        }) do prev[k] = false end
    end
end)

-- =====================================================================
-- HELPERS
-- =====================================================================
local function AddStroke(obj, thickness, color, transparency)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1.5
    s.Color = color or Color3.fromRGB(39, 39, 42)
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function AddTextStroke(txt, thickness)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1.4
    s.Color = Color3.fromRGB(0, 0, 0)
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    s.Parent = txt
    return s
end

local function OnCleanup(fn)
    if type(STATE) == "table" and type(STATE.onCleanup) == "function" then
        STATE.onCleanup(fn)
    end
end

-- Loading screen muncul SEKETIKA script dieksekusi, sebelum require modul game
-- dan download WindUI. Ditutup setelah hub selesai dibangun; tidak pakai notifikasi.
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "LXC_LoadingGui"
LoadingGui.ResetOnSpawn = false
LoadingGui.IgnoreGuiInset = true
LoadingGui.DisplayOrder = 200
LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
LoadingGui.Parent = ParentGui

local LoadingDim = Instance.new("Frame")
LoadingDim.Size = UDim2.fromScale(1, 1)
LoadingDim.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
LoadingDim.BackgroundTransparency = 0.08
LoadingDim.BorderSizePixel = 0
LoadingDim.Parent = LoadingGui

local LoadingCard = Instance.new("Frame")
LoadingCard.Size = UDim2.fromOffset(240, 96)
LoadingCard.Position = UDim2.fromScale(0.5, 0.5)
LoadingCard.AnchorPoint = Vector2.new(0.5, 0.5)
LoadingCard.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
LoadingCard.BorderSizePixel = 0
LoadingCard.Parent = LoadingDim
Instance.new("UICorner", LoadingCard).CornerRadius = UDim.new(0, 16)
AddStroke(LoadingCard, 1.5, Color3.fromRGB(58, 58, 68), 0)

local LoadingTitle = Instance.new("TextLabel")
LoadingTitle.Name = "LoadingTitle"
LoadingTitle.Size = UDim2.new(1, 0, 0, 34)
LoadingTitle.Position = UDim2.new(0, 0, 0.12, 0)
LoadingTitle.BackgroundTransparency = 1
LoadingTitle.FontFace = SafeFonts.Logo
LoadingTitle.Text = "LOOPXCODE"
LoadingTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadingTitle.TextSize = 22
LoadingTitle.Parent = LoadingCard
AddTextStroke(LoadingTitle, 1)

local LoadingText = Instance.new("TextLabel")
LoadingText.Name = "LoadingText"
LoadingText.Size = UDim2.new(1, 0, 0, 22)
LoadingText.Position = UDim2.new(0, 0, 0.62, 0)
LoadingText.BackgroundTransparency = 1
LoadingText.FontFace = SafeFonts.Bold
LoadingText.Text = "Loading..."
LoadingText.TextColor3 = Color3.fromRGB(180, 190, 210)
LoadingText.TextSize = 13
LoadingText.Parent = LoadingCard

local LoadingBarBg = Instance.new("Frame")
LoadingBarBg.Size = UDim2.new(0, 180, 0, 4)
LoadingBarBg.Position = UDim2.new(0.5, -90, 1, -14)
LoadingBarBg.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
LoadingBarBg.BorderSizePixel = 0
LoadingBarBg.Parent = LoadingCard
Instance.new("UICorner", LoadingBarBg).CornerRadius = UDim.new(1, 0)

local LoadingBar = Instance.new("Frame")
LoadingBar.Size = UDim2.new(0, 42, 0, 4)
LoadingBar.BackgroundColor3 = Color3.fromRGB(126, 232, 255)
LoadingBar.BorderSizePixel = 0
LoadingBar.Parent = LoadingBarBg
Instance.new("UICorner", LoadingBar).CornerRadius = UDim.new(1, 0)

local loadingTween = TweenService:Create(LoadingBar, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    Position = UDim2.new(1, -42, 0, 0)
})
loadingTween:Play()
genv.LoopXCode_LoadStarted = os.clock()

-- Ambil WindUI dari jaringan SEKETIKA loading GUI sudah terlihat, parallel
-- dengan inisialisasi modul game. Tanpa ini semua nunggu HttpGet di akhir build.
local WINDUI_URL = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
local winduiSource = nil
task.spawn(function()
    local ok, src = pcall(function() return game:HttpGet(WINDUI_URL, true) end)
    if ok and type(src) == "string" and #src > 0 then winduiSource = src end
end)

local closeLoadingOverlay = function()
    pcall(function() loadingTween:Cancel() end)
    pcall(function() LoadingGui:Destroy() end)
    genv.LoopXCode_LoadFinished = os.clock()
end
OnCleanup(closeLoadingOverlay)

-- Drag + deteksi klik vs geser (dipakai floating button).
-- Lepasan mouse dipantau lewat UserInputService.InputEnded GLOBAL, bukan lewat
-- input.Changed milik InputObject: kalau mouse dilepas di luar window, Changed
-- bisa nggak pernah fire dan tombol ke-lock "dragging" → klik di mana saja
-- (termasuk di pet) jadi klik floating dan membuka menu.
local function MakeDraggable(dragHandle, targetFrame, onClickCallback, clampFn, onStopCallback)
    local dragging, dragStart, startPos, moved = false, nil, nil, 0
    local dragType = nil
    local endConn = nil

    local function stopDrag(fireClick)
        dragging = false
        if endConn then
            pcall(function() endConn:Disconnect() end)
            endConn = nil
        end
        if fireClick and moved < 6 and onClickCallback then onClickCallback() end
        if onStopCallback then onStopCallback() end
    end

    dragHandle.InputBegan:Connect(function(input)
        if dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragType = input.UserInputType
            dragStart = input.Position
            startPos = targetFrame.Position
            moved = 0

            if endConn then pcall(function() endConn:Disconnect() end) end
            endConn = UserInputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == input.UserInputType then
                    stopDrag(true)
                end
            end)
        end
    end)

    local moveConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            moved = delta.Magnitude
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            if clampFn then
                local ok, clamped = pcall(function() return clampFn(newPos) end)
                if ok and clamped then newPos = clamped end
            end
            targetFrame.Position = newPos
        end
    end)

    -- Pengaman terakhir: kalau mouse sudah dilepas tapi InputEnded nggak pernah
    -- datang (dilepas di luar window), paksa drag berhenti.
    local guardConn = RunService.Heartbeat:Connect(function()
        if dragging and dragType == Enum.UserInputType.MouseButton1
            and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            stopDrag(false)
        end
    end)

    OnCleanup(function()
        stopDrag(false)
        pcall(function() moveConn:Disconnect() end)
        pcall(function() guardConn:Disconnect() end)
    end)
end

-- =====================================================================
-- UI REGISTRY — satu-satunya sumber komponen (dibangun di WindUI)
-- =====================================================================
local UIItems = {}

local function AddToggle(name, defaultState, callback, group)
    UIItems[#UIItems + 1] = {
        Kind = "Toggle", Name = name, Default = defaultState == true,
        Callback = callback, Group = group or "Misc"
    }
end

local function AddDropdown(name, options, defaultText, callback, group)
    UIItems[#UIItems + 1] = {
        Kind = "Dropdown", Name = name, Values = options, Default = defaultText,
        Callback = callback, Group = group or "Misc"
    }
end

local function AddButton(name, callback, group)
    UIItems[#UIItems + 1] = {
        Kind = "Button", Name = name, Callback = callback, Group = group or "Misc"
    }
end

-- Set nilai handle tanpa memicu callback (dipakai mutual-exclusion & config load).
local function setUIValue(handle, value)
    if not handle then return end
    pcall(function()
        if type(handle.Set) == "function" then handle:Set(value)
        elseif type(handle.SetValue) == "function" then handle:SetValue(value)
        elseif type(handle.Select) == "function" then handle:Select(value) end
    end)
end
genv.LoopXCode_SetUIValue = setUIValue

-- =====================================================================
-- 1. AUTO STEAL ENGINE
-- =====================================================================
local RemoteFolder = ReplicatedStorage:WaitForChild("Remotes")
local ModuleFolder = ReplicatedStorage:WaitForChild("Module")
local WildFolder = Workspace:WaitForChild("WildPets")
local PC = require(ModuleFolder:WaitForChild("PetConfig"))
local CC = require(ModuleFolder:WaitForChild("CaptureConfig"))
local BC = require(ModuleFolder:WaitForChild("BiomeConfig"))

-- Nama zone/map yang dipakai game (dari BiomeConfig.GetBiomeAtZ).
local ZONE_NAMES = {
    "Grass", "Desert", "Jungle", "Snow", "Volcano", "Abyss Ocean",
    "Prehistoric", "Sakura", "Candy", "Crystal Cave", "Heaven",
    "Cosmic", "Dragon Realm", "Shadow Realm"
}
local ZONE_CENTERS = {
    Grass = -60, Desert = -275, Jungle = -525, Snow = -750,
    Volcano = -1080, ["Abyss Ocean"] = -1430, Prehistoric = -1900,
    Sakura = -2500, Candy = -3200, ["Crystal Cave"] = -4100,
    Heaven = -5300, Cosmic = -6450, ["Dragon Realm"] = -7900,
    ["Shadow Realm"] = -9500
}
genv.LoopXCode_ZoneNames = ZONE_NAMES
genv.LoopXCode_ZoneCenters = ZONE_CENTERS

-- Zona asal wild pet dibaca langsung dari BiomeConfig milik game.
local function zoneAtZ(z)
    if type(z) ~= "number" then return "Any" end
    local ok, b = pcall(function() return BC.GetBiomeAtZ(z) end)
    if ok and type(b) == "table" and b.Name ~= nil then return tostring(b.Name) end
    return "Any"
end
genv.LoopXCode_ZoneAtZ = zoneAtZ

-- Peta asli game adalah koridor lurus. Tiap map punya ZStart/ZEnd nyata dari
-- BiomeConfig. Ini dipakai supaya kalau daddy milih zone, hub NYATANYA jalan
-- ke zone itu (bukan cuma nunggu pet dari zone itu kebetulan spawn di dekat spawn).
local function zoneSpan(name)
    if type(name) ~= "string" or name == "" or name == "Any" then return nil end
    local found
    pcall(function()
        for _, b in ipairs(BC.Biomes or {}) do
            if tostring(b.Name) == name then
                found = { start = tonumber(b.ZStart), finish = tonumber(b.ZEnd) }
                break
            end
        end
    end)
    if not found or not found.start or not found.finish then return nil end
    return found.start, found.finish
end
genv.LoopXCode_ZoneSpan = zoneSpan
-- Kecepatan mount asli dihitung game lewat MountConfig.PetSpeed:
--   cfg.Speed * PetConfig.SpeedMult(size) * MutationConfig.SpeedBonus(mutation)
-- Jadi bukan sekadar cfg.Speed (itulah sebabnya auto-equip salah pilih).
local MC = require(ModuleFolder:WaitForChild("MountConfig"))
local MUT = require(ModuleFolder:WaitForChild("MutationConfig"))

local R_STEAL = {
    StartCapture = RemoteFolder:WaitForChild("StartCapture"),
    CapturePull = RemoteFolder:WaitForChild("CapturePull"),
    FinishCapture = RemoteFolder:WaitForChild("FinishCapture"),
    PenPetAction = RemoteFolder:WaitForChild("PenPetAction")
}
-- Remote secure harus tersedia SEBELUM escapeToSafeZone/secureCarry dipakai.
local R_SECURE = RemoteFolder:FindFirstChild("SecureCatch")

-- Kalau reel keputus / StartCapture gagal, sesi Capturing bisa nyangkut di
-- server. Fire cancel supaya attempt berikutnya nggak ditolak terus.
local function cancelCapture(session)
    pcall(function()
        R_STEAL.FinishCapture:FireServer(session, false, true)
    end)
end

local StealCfg = {
    Enabled = false,
    Busy = false,
    RetryDelay = 0.7,          -- jeda antar siklus, biar game nggak nge-freeze
    Rarity = "Any",             -- tier EXACT yang dipilih; nggak ada auto-turun
    Zone = "Any",               -- map/zone EXACT yang dipilih; Any = semua map
    CustomIncome = "",     -- min income: 5k / 30b / 50t / kosong = semua
    Priority = "Any",           -- tetap Any; fokus filter cuma Rarity + Min Income
    ReelMode = "Safe",
    WeakAllowed = false,      -- Experimen: boleh tangkap walau lasso kurang kuat
    WalkSpeed = 400           -- kecepatan jalan Auto Catch (default cepat, bisa diatur dari menu)
}
genv.LoopXCode_StealCfg = StealCfg

-- Auto Sell Pet: jual otomatis pet di bag yang tier-nya dipilih (multi-select).
local SellCfg = {
    Enabled = false,
    Interval = 5,
    Rarities = {}
}
genv.LoopXCode_SellCfg = SellCfg
local R_SELL = RemoteFolder:FindFirstChild("SellPets")

-- Ukuran HUD floating bisa diatur bebas dari menu Controls.
local HudCfg = { Width = 720, Height = 108, TextSize = 18, Gap = 10, Shadow = 0.55, ShadowOffset = 2, Font = "Bold", LogoFont = "Logo", X = 0, Y = 0 }
genv.LoopXCode_HudCfg = HudCfg
local applyHudLayout = function() end
genv.LoopXCode_ApplyHudLayout = function() applyHudLayout() end

local MiscCfg = { MenuBackground = true, AutoEquipBestSpeed = true }
genv.LoopXCode_MiscCfg = MiscCfg
genv.LoopXCode_SetMenuBackground = function() end

-- Live-reload bikin instance lama tetap hidup dengan StealCfg sendiri. Kalau
-- nggak dimatikan semua, loop lamanya nyelak ke reel instance baru (kabur ke
-- safe zone di tengah capture). Matikan SEMUA cfg lama, daftarin yang baru.
local allStealCfgs = genv.LoopXCode_AllStealCfgs or {}
genv.LoopXCode_AllStealCfgs = allStealCfgs
for _, old in ipairs(allStealCfgs) do
    old.Enabled = false
    old.Busy = false
end
allStealCfgs[#allStealCfgs + 1] = StealCfg

-- Status + statistik steal. Dipakai HUD atas dan panel "Status Steal".
local RuntimeStatus = {
    Mode = "idle", Detail = "any detect",
    Text = "idle | any detect"
}
genv.LoopXCode_Status = RuntimeStatus
local setStatusText = function() end
local updateHudText = function() end
local updateStealStatsText = function() end
-- Tabel baru tiap reload supaya listener CatchSecured dari instance lama
-- nggak nambahin counter instance yang baru.
local StealStats = {}
StealStats.Total = tonumber(StealStats.Total) or 0
StealStats.Done = tonumber(StealStats.Done) or 0
StealStats.Failed = tonumber(StealStats.Failed) or 0
StealStats.Weak = tonumber(StealStats.Weak) or 0
StealStats.LastWeak = tostring(StealStats.LastWeak or "")
genv.LoopXCode_StealStats = StealStats

local function setStatus(mode, detail)
    RuntimeStatus.Mode = tostring(mode or "idle")
    RuntimeStatus.Detail = tostring(detail or "any detect")
    RuntimeStatus.Text = RuntimeStatus.Mode .. " | " .. RuntimeStatus.Detail
    pcall(function() setStatusText(RuntimeStatus.Text) end)
    pcall(function() updateHudText(RuntimeStatus.Text) end)
end
genv.LoopXCode_SetStatus = setStatus

local function bumpStealStat(key, amount)
    StealStats[key] = (tonumber(StealStats[key]) or 0) + (amount or 1)
end

local function stealStatsLine()
    return string.format("%s %d | %s %d | %s %d | %s %d",
        tr("Total"), tonumber(StealStats.Total) or 0,
        tr("Done"), tonumber(StealStats.Done) or 0,
        tr("Failed"), tonumber(StealStats.Failed) or 0,
        tr("Weak"), tonumber(StealStats.Weak) or 0)
end

local function stealStatsPanel()
    local weakLine = tr("strong enough")
    if (tonumber(StealStats.Weak) or 0) > 0 then
        weakLine = tr("too weak")
        if StealStats.LastWeak ~= "" then
            weakLine = weakLine .. " — " .. tostring(StealStats.LastWeak)
        end
    end
    return string.format("%s %d\n%s %d\n%s %d\n%s: %s",
        tr("Total pets"), tonumber(StealStats.Total) or 0,
        tr("Done"), tonumber(StealStats.Done) or 0,
        tr("Failed"), tonumber(StealStats.Failed) or 0,
        tr("Lasso"), weakLine)
end

local function refreshStealStats()
    local line = stealStatsPanel()
    pcall(function() updateStealStatsText(line) end)
end
genv.LoopXCode_RefreshStealStats = refreshStealStats

pcall(function()
    RemoteFolder:WaitForChild("CatchSecured").OnClientEvent:Connect(function()
        bumpStealStat("Done")
        refreshStealStats()
    end)
end)

-- Manual STEAL dari Finder harus bisa jalan walau Auto Catch mati.
local ManualSteal = { Active = false, Name = "" }
genv.LoopXCode_ManualSteal = ManualSteal

local function readPerf()
    local fps, cpu, gpu, ping = 0, 0, 0, 0
    pcall(function() fps = math.floor(Stats.FrameRateManager.AverageFPS:GetValue()) end)
    pcall(function() cpu = Stats.PerformanceStats.CPU:GetValue() end)
    pcall(function() gpu = Stats.FrameRateManager.AverageGPU:GetValue() end)
    pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    return fps, cpu, gpu, ping
end

local STEAL_OWNER = tostring(os.clock()) .. ":" .. tostring(math.random(1, 1000000000))

-- Pace internal. Dulu tiap langkah nunggu 0.03-0.05 detik -> terlalu rapat,
-- replikasi CFrame + pull numpuk dan gameplay kelihatan pause. Sekarang ada
-- jeda nyata. Masih bisa di-tuning lewat genv.LoopXCode_Pace kalau perlu.
local Pace = {
    Walk = 0.05,        -- Safe: jeda antar langkah 6 stud
    Teleport = 0.03,    -- Fast: jeda antar teleport kecil
    Reel = 0.1,         -- game membatasi CapturePull ke 10 Hz
    Pull = 0.1,         -- Safe: 10 Hz, sama seperti klien asli game
    Settle = 0.08,      -- Safe: jeda setelah remote / sebelum siklus lanjut
    FastReel = 0.05,    -- Fast: loop reel tetap 10 Hz untuk pull
    FastPull = 0.1,     -- Fast: jangan lebih cepat dari throttle server
    FastSettle = 0.05   -- Fast: sinkronisasi minimal
}
genv.LoopXCode_Pace = Pace

-- WildPets ke-stream: yang jauh nggak masuk workspace.WildPets sampai char
-- dekat. Kalau filter nggak nemu target, hub keliling zone (urutan Z dari
-- BiomeConfig) supaya pet yang "aslinya ada" ke-load dulu. Tetap strict:
-- yang diambil cuma tier yang dipilih.
local SCAN_ZONES = {
    Vector3.new(0, 10, -80), Vector3.new(0, 10, -256), Vector3.new(0, 10, -472),
    Vector3.new(0, 10, -736), Vector3.new(0, 10, -1056), Vector3.new(0, 10, -1448),
    Vector3.new(0, 10, -1900), Vector3.new(0, 10, -2700), Vector3.new(0, 10, -3100),
    Vector3.new(0, 10, -4100), Vector3.new(0, 10, -5300), Vector3.new(0, 10, -6500),
    Vector3.new(0, 10, -7900), Vector3.new(0, 10, -9500), Vector3.new(0, 10, -10200)
}
local scanIndex = 1

local function isFastReel()
    return StealCfg.ReelMode == "Fast"
end

-- Rarity dibaca LANGSUNG dari game: spawn rarities (PetConfig.Rarities) + income tiers (PetConfig.TIERS).
local ALL_RARITIES = {}
local rarityOrder = {}
do
    local seen = {}
    local function add(n)
        n = tostring(n or "")
        if n == "" or seen[n] then return end
        seen[n] = true
        ALL_RARITIES[#ALL_RARITIES + 1] = n
    end
    -- spawn rarities dulu ( weakest -> strongest ), urutan eksplisit
    for _, n in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
        "Primordial", "Ethereal", "Transcendent", "Celestial", "Divine", "Astral",
        "Infinite", "Omega", "Eternal", "Godly", "Secret", "Exclusive" }) do add(n) end
    -- tambahkan apa pun yang ada di game tapi belum di daftar
    pcall(function() for k in pairs(PC.Rarities or {}) do add(k) end end)
    pcall(function() for _, t in ipairs(PC.TIERS or {}) do add(t) end end)
    for i, n in ipairs(ALL_RARITIES) do rarityOrder[n] = i end
end
genv.LoopXCode_AllRarities = ALL_RARITIES

local function rarityRank(name)
    if not name then return 0 end
    if rarityOrder[name] then return rarityOrder[name] end
    local lower = string.lower(name)
    for key, val in pairs(rarityOrder) do
        if string.lower(key) == lower then return val end
    end
    return 0
end

-- Parse income custom: 5k=5000, 30b=30e9, 50t=50e12, "any"/kosong = 0 (terima semua).
local function parseIncome(text)
    local raw = string.lower(tostring(text or ""))
    raw = raw:gsub("[%s,_]+", "")
    -- Ambil angka PERTAMA yang ada, bukan harus seluruh string. Jadi semua
    -- format ini tetap jalan: 5k / 30b / 50t / 5M / 5M+ / 5M or more /
    -- min 5M / 5m ke atas / 5m atau lebih. Tanpa angka = any.
    local num, suffix = raw:match("(%d+%.?%d*)([kmbtq]?)")
    if not num then return 0 end
    local mult = ({ k = 1e3, m = 1e6, b = 1e9, t = 1e12, q = 1e15 })[suffix] or 1
    return (tonumber(num) or 0) * mult
end
genv.LoopXCode_ParseIncome = parseIncome

local function petCfg(name)
    if not name then return nil end
    local ok, cfg = pcall(function() return PC.Get(name) end)
    if ok and type(cfg) == "table" then return cfg end
    return nil
end

local function petIncome(cfg)
    if not cfg then return 0 end
    local ok, v = pcall(function() return CC.GetPetIncome(cfg) end)
    if ok and type(v) == "number" then return v end
    return tonumber(cfg.Income) or 0
end

local function wildRoot(model)
    if not model then return nil end
    return model:FindFirstChild("RootPart") or model:FindFirstChildWhichIsA("BasePart", true)
end

local function wildInfo(model)
    if not model then return nil end
    local wid = model:GetAttribute("WildId")
    local part = wildRoot(model)
    if not wid or not part then return nil end
    local name = tostring(model:GetAttribute("PetName") or model.Name)
    local cfg = petCfg(name)
    local tier = tostring(cfg and cfg.Tier or "Common")
    pcall(function() if cfg then tier = tostring(PC.GetTier(cfg) or tier) end end)
    local pos = part.Position
    return {
        model = model,
        id = wid,
        name = name,
        display = tostring(model:GetAttribute("Display") or (cfg and cfg.Display) or name),
        rarity = tostring(model:GetAttribute("Rarity") or (cfg and cfg.Rarity) or "Common"),
        tier = tier,
        zone = zoneAtZ(pos.Z),
        kg = tonumber(model:GetAttribute("Kg")) or 0,
        speed = tonumber(model:GetAttribute("Speed")) or (cfg and tonumber(cfg.Speed)) or 0,
        income = petIncome(cfg),
        pos = pos
    }
end

local function normalizeText(s)
    return string.lower(tostring(s or ""):gsub("%s+", ""))
end

-- Dipakai pickTarget supaya target lemah bisa dilewati sebelum reel dicoba.
local lassoTooWeak = function() return false end

-- Filter: "Min Income" = income minimum. "Catch Rarity" = TIER EXACT.
-- Daftar tier diambil langsung dari data game (PetConfig.TIERS
-- + CaptureConfig.RARITY_NAMES). Pilih "Ethereal" => cuma tier Ethereal yang
-- diambil. Nggak ada minimum, nggak ada fallback, nggak ada auto-turun.
-- Kalau Ethereal nggak sedang spawn, hub BERHENTI / nunggu. "Any" = abaikan tier.
-- Field yang dipakai tetap `tier` (PetConfig.GetTier), BUKAN atribut `Rarity`
-- pada wild pet (itu cuma spawn weight, hampir semuanya "Common").
local function matchesFilter(info)
    if not info then return false end
    local min = parseIncome(StealCfg.CustomIncome)
    if min > 0 and info.income < min then return false end
    local want = StealCfg.EffectiveRarity or StealCfg.Rarity
    if want ~= "Any" and want ~= "" and want ~= nil then
        if tostring(info.tier or "") ~= want then return false end
    end
    local zone = StealCfg.Zone
    if zone ~= "Any" and zone ~= "" and zone ~= nil then
        if tostring(info.zone or "") ~= zone then return false end
    end
    return true
end
genv.LoopXCode_MatchesFilter = matchesFilter

-- updateStealInfo diisi ulang oleh section UI (paragraph WindUI).
local updateStealInfo = function() end
-- syncRarityUI diisi ulang setelah dropdown Catch Rarity dibuat.
local syncRarityUI = function() end

local function priorityScore(info, charRoot)
    -- Priority selalu "Any": ambil yang terdekat di antara pet yang lolos
    -- filter Rarity + Min Income. Nggak ada ranking value/rarity lagi.
    return -(info.pos - charRoot.Position).Magnitude
end

local function isUncaptured(value)
    return value == nil or value == 0 or value == "0" or value == ""
end

-- Target HARUS lolos matchesFilter (tier EXACT + min income + zone EXACT).
-- Nggak ada auto-turun, nggak ada fallback, nggak ada dropdown yang berubah
-- sendiri. Kalau tier yang dipilih nggak ada, hub berhenti.
local function pickTarget()
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local best, bestScore = nil, -math.huge
    for _, model in ipairs(WildFolder:GetChildren()) do
        local info = wildInfo(model)
        if info
            and isUncaptured(model:GetAttribute("CapturedBy"))
            and model:GetAttribute("Despawning") ~= true
            and matchesFilter(info)
            and (StealCfg.WeakAllowed or not lassoTooWeak(info)) then
            local score = priorityScore(info, rootPart)
            if score > bestScore then bestScore, best = score, info end
        end
    end
    return best
end

local function walkTowards(rootPart, targetPos, maxSteps, stopDist)
    for _ = 1, (maxSteps or 400) do
        local current = rootPart.Position
        local delta = Vector3.new(targetPos.X - current.X, 0, targetPos.Z - current.Z)
        if delta.Magnitude <= (stopDist or 8) then return true end
        rootPart.CFrame = CFrame.new(current + delta.Unit * 1.6)
        task.wait(Pace.Walk)
    end
    return false
end

local function ensureLasso()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local tool = char:FindFirstChild("Lasso")
        or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Lasso"))
    if not tool then return false end
    if tool.Parent == char and tool:IsA("Tool") then return true end
    if hum then
        -- Game suka otomatis nge-equip Tool pet (punya atribut PetId).
        -- Itu menggantikan Lasso di Character, lalu StartCapture ditolak
        -- "Equip your Lasso!". Copot dulu Tool pet sebelum equip ulang.
        for _, equipped in ipairs(char:GetChildren()) do
            if equipped:IsA("Tool") and equipped ~= tool then
                pcall(function() hum:UnequipTool(equipped) end)
            end
        end
        pcall(function() hum:EquipTool(tool) end)
    end
    for _ = 1, 20 do
        if char:FindFirstChild("Lasso") then return true end
        task.wait(0.1)
    end
    return char:FindFirstChild("Lasso") ~= nil
end
genv.LoopXCode_EnsureLasso = ensureLasso

local function configuredWalkSpeed(fallback)
    local v = tonumber(StealCfg and StealCfg.WalkSpeed)
    if not v or v < 16 then v = tonumber(fallback) or 70 end
    if v < 16 then v = 16 end
    if v > 400 then v = 400 end
    return v
end
genv.LoopXCode_ConfiguredWalkSpeed = configuredWalkSpeed

local function setWalkSpeed(char, speed)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = speed end
end

local function getWalkSpeed(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.WalkSpeed or 16
end

-- Guardian/Bos nge-LAUNCH char lewat GuardianHit: ChangeState(FallingDown)
-- + AssemblyLinearVelocity 135. Tanpa ini char melayang & kelihatan "berhenti".
-- Reset state + velocity tiap tick supaya steal tetap jalan walau kena bos.
local function recoverFromBoss(rootPart)
    local char = rootPart and rootPart.Parent
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or not rootPart then return end
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.FallingDown
        or st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.Physics then
        pcall(function()
            rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

-- Jalan pakai Humanoid:MoveTo (bukan teleport/CFrame tiap frame).
-- CFrame step bikin char glitch bolak-balik karena server narik balik posisi.
-- MoveTo bikin game yang jalanin animasi + physics sendiri, mulus dan nggak pause.
local function rushToPoint(rootPart, getPoint, stopDist, timeout, speed)
    local hum = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local oldSpeed = hum.WalkSpeed
    hum.WalkSpeed = tonumber(speed) or configuredWalkSpeed(120)
    local started = os.clock()
    local lastIssue = 0
    local ok = false
    while os.clock() - started < (timeout or 20) do
        recoverFromBoss(rootPart)
        local point = getPoint()
        if not point then break end
        local cur = rootPart.Position
        local dx, dz = point.X - cur.X, point.Z - cur.Z
        local d = math.sqrt(dx * dx + dz * dz)
        if d <= (stopDist or 6) then ok = true break end
        if os.clock() - lastIssue >= 0.2 then
            lastIssue = os.clock()
            pcall(function() hum:MoveTo(Vector3.new(point.X, cur.Y, point.Z)) end)
        end
        task.wait(0.05)
    end
    hum.WalkSpeed = oldSpeed
    return ok
end

-- Kalau daddy milih map tertentu, hub BENAR-BENAR nyamperin koridor map itu
-- pakai ZStart/ZEnd asli dari BiomeConfig. Jalan normal lewat MoveTo, bukan
-- teleport/terbang. Cuma dilakukan sekali per pergantian zone.
local lastStagedZone = nil
local function stageToZone(rootPart, zoneOverride)
    local zone = zoneOverride or StealCfg.Zone
    local startZ, finishZ = zoneSpan(zone)
    if not startZ then
        lastStagedZone = nil
        return true
    end
    if zoneAtZ(rootPart.Position.Z) == zone then
        lastStagedZone = zone
        return true
    end
    -- Habis deposit di Safe Zone char balik ke Grass. Harus NYALAH masuk lagi
    -- ke map yang dipilih, kalau nggak pet di map itu nggak pernah keload.

    local targetZ = (startZ + finishZ) / 2
    rushToPoint(rootPart, function()
        return Vector3.new(0, rootPart.Position.Y, targetZ)
    end, 6, 90, configuredWalkSpeed(120))

    lastStagedZone = zone
    return true
end
genv.LoopXCode_StageToZone = stageToZone

local function approachTarget(rootPart, targetInfo, maxSteps, stopDist)
    -- Filter (tier + zone + income) diputuskan dari DATA dulu. Begitu target ketemu,
    -- char JALAN normal ke sisi pet pakai Humanoid:MoveTo (game yang pegang
    -- animasi/physics). Nggak terbang, nggak CFrame step, nggak glitch bolak-balik.
    local first = wildRoot(targetInfo.model)
    if not (first and rootPart) then return false end
    recoverFromBoss(rootPart)
    local keep = math.max(1.5, (tonumber(CC.Reel and CC.Reel.STOP_DIST) or 4) - 1)

    rushToPoint(rootPart, function()
        local live = wildRoot(targetInfo.model)
        if not live then return nil end
        targetInfo.pos = live.Position
        return live.Position
    end, keep, 12, 90)

    local done = wildRoot(targetInfo.model)
    if not done then return false end
    targetInfo.pos = done.Position
    local rest = Vector3.new(
        rootPart.Position.X - done.Position.X, 0,
        rootPart.Position.Z - done.Position.Z
    ).Magnitude
    if rest > keep + 8 then return false end
    if isFastReel() then task.wait(Pace.FastSettle) else task.wait(0.05) end
    return true
end

-- Lasso terlalu lemah kalau power yang dibutuhkan pet > power player.
lassoTooWeak = function(targetInfo)
    if not targetInfo then return false end
    local required = 0
    pcall(function()
        required = tonumber(CC.RequiredLassoPower(petCfg(targetInfo.name))) or 0
    end)
    local power = tonumber(LocalPlayer:GetAttribute("LassoPower")) or 0
    return required > power
end

-- Nempelkan karakter ke pet supaya CapturePull tetap bisa menarik walau lasso lemah.
local function stickToPet(rootPart, targetInfo)
    if not (rootPart and targetInfo) then return end
    local live = wildRoot(targetInfo.model)
    if not live then return end
    targetInfo.pos = live.Position
    local delta = Vector3.new(live.Position.X - rootPart.Position.X, 0, live.Position.Z - rootPart.Position.Z)
    local range = tonumber(CC.Reel and CC.Reel.STOP_DIST) or 4
    local keep = math.max(1.5, range - 1)
    if delta.Magnitude > keep then
        rootPart.CFrame = CFrame.new(Vector3.new(
            live.Position.X + delta.Unit.X * keep,
            rootPart.Position.Y,
            live.Position.Z + delta.Unit.Z * keep))
    end
end

local function captureAllowed()
    return StealCfg.Enabled == true or ManualSteal.Active == true
end

-- Forward declarations: reel butuh state carry + safe zone tanpa dependency loop.
local isCarrying = function() return false end
local escapeToSafeZone = function() return false end

local function reelDuration(difficulty)
    -- Durasi dari system lama yang sudah tested: Fast 1.05s, Safe 4s.
    -- Fast di atas ReelMinTime (~0.76s), jadi server tetap nerima reel penuh.
    if isFastReel() then return 1.05 end
    return 4
end

local function reelCapture(session, targetInfo, difficulty)
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    local duration = reelDuration(difficulty)
    local weak = lassoTooWeak(targetInfo)
    local started = os.clock()
    local lastFire = 0
    local lastFollow = 0
    local active = true
    local pullEvery = isFastReel() and Pace.FastPull or Pace.Pull
    local reelWait = isFastReel() and Pace.FastReel or Pace.Reel
    local followEvery = isFastReel() and 0.1 or 0.18

    while os.clock() - started < duration do
        if not captureAllowed() then active = false break end
        if rootPart then recoverFromBoss(rootPart) end
        -- Ikut pelan-pelan kalau pet jalan, tapi jangan teleport tiap tick.
        -- Ini yang bikin durasi reel tetap stabil tanpa pet "escaped".
        if targetInfo and rootPart and os.clock() - lastFollow >= followEvery then
            lastFollow = os.clock()
            local live = wildRoot(targetInfo.model)
            if live then
                local dx, dz = live.Position.X - rootPart.Position.X, live.Position.Z - rootPart.Position.Z
                local d = math.sqrt(dx * dx + dz * dz)
                local maxDist = weak and math.max(2, (tonumber(CC.Reel and CC.Reel.STOP_DIST) or 4) - 1) or 8
                if d > maxDist and d > 0.01 then
                    local s = math.min(weak and 6 or 5, d - maxDist)
                    pcall(function()
                        rootPart.CFrame = CFrame.new(
                            rootPart.Position.X + (dx / d) * s,
                            rootPart.Position.Y,
                            rootPart.Position.Z + (dz / d) * s
                        )
                    end)
                end
            end
        end
        local progress = 0.2 + 0.8 * math.min(1, (os.clock() - started) / duration)
        if os.clock() - lastFire >= pullEvery then
            lastFire = os.clock()
            pcall(function() R_STEAL.CapturePull:FireServer(session, math.min(1, progress)) end)
        end
        task.wait(reelWait)
    end

    if active then
        pcall(function() R_STEAL.CapturePull:FireServer(session, 1) end)
        task.wait(0.05)
        pcall(function() R_STEAL.FinishCapture:FireServer(session, true, false) end)
        -- Carrying attribute server datang SESUDAH FinishCapture. Tunggu
        -- sebentar di sini supaya tryCaptureOnce nggak salah hitung "Failed"
        -- padahal pet sudah benar-benar kepegang.
        for _ = 1, 20 do
            if isCarrying() then break end
            task.wait(0.05)
        end
    else
        -- Auto Catch dimatikan di tengah reel: batalkan, jangan tinggalkan
        -- Capturing=true di server (nanti StartCapture selalu ditolak).
        cancelCapture(session)
    end
    return active
end

isCarrying = function()
    -- Capturing = reel masih jalan, BUKAN pet sudah di tangan. Kalau ini ikut
    -- dihitung, stealStep bisa kabur ke safe zone di tengah reel dan gagal.
    local carrying = LocalPlayer:GetAttribute("Carrying")
    return (carrying ~= nil and carrying ~= "")
end

-- Safe zone mulai sekitar Z = 0 (entry point game: Z = 3.34).
-- Pulangnya JALAN pakai MoveTo, bukan teleport: server harus nerima posisi
-- character + carried pet sebelum SecureCatch diproses. Teleport client bikin
-- server lihat char masih di map -> carry dibuang tanpa masuk bag.
local SAFE_FRONT = Vector3.new(4, 0, -10)
local SAFE_PULL = Vector3.new(4, 0, 10)
local function inSafeZone(pos)
    return pos.Z >= 0 and math.abs(pos.X) < 200
end

-- Satu carry cuma boleh dihitung sekali. Game sendiri fire SecureCatch dari
-- SafeZoneFX begitu Carrying ada dan char masuk zone; hub nggak nembak remote
-- manual (doble fire bikin carry dianggap invalid).
local lastSecuredCarry = nil
local function carryToken()
    local name = tostring(LocalPlayer:GetAttribute("Carrying") or "")
    if name == "" then return nil end
    return name .. "|" .. tostring(LocalPlayer:GetAttribute("CaptureTarget") or "")
end

-- Diam di safe zone sampai server menghapus Carrying. Nggak ada pin pet,
-- nggak ada CFrame step: server yang pegang posisi carried pet.
local function secureCarry(rootPart)
    local token = carryToken()
    if not token then return false end
    if token == lastSecuredCarry then return false end
    lastSecuredCarry = token

    for _ = 1, 80 do
        if not isCarrying() then
            lastSecuredCarry = nil
            return true
        end
        recoverFromBoss(rootPart)
        task.wait(0.1)
    end
    return false
end

local escapeRunning = false
local function doEscapeToSafeZone()
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    if not inSafeZone(rootPart.Position) then
        -- Jalan cepat ke depan safe zone dulu (Z -10), lalu masuk ke Z 10.
        -- Pet ngikutin char lewat lasso/server, jadi posisinya ikut valid.
        -- System lama: kecepatan escape ditetapkan tinggi (220/140/220),
        -- bukan WalkSpeed biasa. WalkSpeed dipakai buat jalan ke zone/target;
        -- pulang bawa pet harus cepat kalau nggak pet ke-drop guardian.
        rushToPoint(rootPart, function()
            return Vector3.new(SAFE_FRONT.X, rootPart.Position.Y, SAFE_FRONT.Z)
        end, 6, 90, 220)

        rushToPoint(rootPart, function()
            return Vector3.new(SAFE_PULL.X, rootPart.Position.Y, SAFE_PULL.Z)
        end, 5, 30, 140)

        -- Kalau masih kehalang, coba sekali lagi dengan kecepatan lebih tinggi.
        if not inSafeZone(rootPart.Position) then
            rushToPoint(rootPart, function()
                return Vector3.new(SAFE_PULL.X, rootPart.Position.Y, SAFE_PULL.Z)
            end, 5, 40, 220)
        end
    end

    -- Kasih waktu sinkron sebelum game fire / sebelum siklus berikutnya.
    task.wait(0.3)
    if isCarrying() then secureCarry(rootPart) end
    return not isCarrying()
end

-- Satu deposit saja. Double trigger (dari reel + dari stealStep) sebelumnya
-- bisa bikin dua jalur safe-zone jalan bareng dan bikin Fast terasa macet.
escapeToSafeZone = function()
    if escapeRunning then return false end
    escapeRunning = true
    local ok = false
    pcall(function() ok = doEscapeToSafeZone() end)
    escapeRunning = false
    return ok
end

-- Pindah ke zone berikutnya untuk memicu streaming WildPets. Sekali per siklus,
-- jadi nggak nge-freeze. Pet tetap ke-ride (cuma rootPart yang digeser).
local function roamToNextZone(rootPart)
    if not rootPart or #SCAN_ZONES == 0 then return end
    local dest = SCAN_ZONES[scanIndex]
    scanIndex = scanIndex % #SCAN_ZONES + 1
    if not dest then return end
    recoverFromBoss(rootPart)
    pcall(function()
        rootPart.CFrame = CFrame.new(Vector3.new(dest.X, dest.Y, dest.Z))
    end)
    task.wait(0.6) -- kasih waktu client stream-in pet di zone itu
end
genv.LoopXCode_RoamZone = roamToNextZone

local function bagCount()
    -- Baca atribut player (GRATIS), jangan InvokeServer "list" tiap siklus (bikin ngeframe).
    local n = LocalPlayer:GetAttribute("BagPets")
    if type(n) == "number" then return math.floor(n) end
    local ok, result = pcall(function() return R_STEAL.PenPetAction:InvokeServer("list") end)
    if ok and type(result) == "table" then return #(result.bag or {}) end
    return -1
end

-- Satu percobaan capture. Return true kalau pet benar-benar ada di tangan.
local function tryCaptureOnce(rootPart, target)
    setStatus("on system", target and target.name or "any detect")
    bumpStealStat("Total")
    refreshStealStats()

    if not approachTarget(rootPart, target, 400, 7) then
        bumpStealStat("Failed")
        refreshStealStats()
        return false
    end

    local live = wildRoot(target.model)
    if not live then
        bumpStealStat("Failed")
        refreshStealStats()
        return false
    end
    local liveDist = Vector3.new(
        live.Position.X - rootPart.Position.X, 0,
        live.Position.Z - rootPart.Position.Z
    ).Magnitude
    if liveDist > 17 then
        bumpStealStat("Failed")
        refreshStealStats()
        return false
    end

    -- Deteksi lasso lemah TETAP jalan, tapi tidak menghentikan attempt.
    local weak = lassoTooWeak(target)
    if weak then
        bumpStealStat("Weak")
        StealStats.LastWeak = tostring(target.name or "?")
        setStatus("on system", tr("lasso too weak: ") .. tostring(target.name or "?"))
        refreshStealStats()
        -- Nudge kecil cuma untuk reel; navigasi tetap MoveTo.
        stickToPet(rootPart, target)
    end
    -- FAST: settle minimal supaya server menerima posisi hasil nudge.
    if isFastReel() then task.wait(Pace.FastSettle) else task.wait(Pace.Settle) end

    -- Game bisa mengganti Lasso dengan Tool pet saat kamera/stream berubah.
    -- Pastikan Lasso benar-benar dipegang tepat sebelum StartCapture.
    if not ensureLasso() then
        bumpStealStat("Failed")
        refreshStealStats()
        return false
    end

    local okStart, startResult = pcall(function()
        return R_STEAL.StartCapture:InvokeServer(target.id)
    end)
    if not (okStart and type(startResult) == "table" and startResult.session
        and startResult.ok ~= false) then
        bumpStealStat("Failed")
        refreshStealStats()
        return false
    end

    local active = reelCapture(startResult.session, target, startResult.difficulty)
    if not active then return false end
    task.wait(isFastReel() and 0.08 or 0.25)
    if not isCarrying() then
        bumpStealStat("Failed")
        refreshStealStats()
        return false
    end
    refreshStealStats()
    return true
end

-- Satu siklus penuh. System lama: sekali ON, terus cari/capture di zone.
-- Gagal = lanjut cari target lain (nggak balik safe, nggak nunggu lama).
-- Sukses = pet masih di tangan, lanjut cari lagi sampai bag full / di-off.
-- Safe zone HANYA dipakai kalau ada carry sisa dari sesi sebelumnya.
local function stealStep()
    -- Carry sisa (misal dari ReelMode/Fast yang keputus) dibersihkan dulu.
    if isCarrying() then
        escapeToSafeZone()
        return true
    end

    -- Capturing adalah attribute server. Kalau masih true (sisa sesi yang
    -- keputus), StartCapture pasti ditolak. Tunggu sebentar, paksa cancel.
    for i = 1, 20 do
        if LocalPlayer:GetAttribute("Capturing") ~= true then break end
        if i == 10 then cancelCapture(nil) end
        task.wait(0.05)
    end
    if LocalPlayer:GetAttribute("Capturing") == true then return false end
    if not ensureLasso() then return false end

    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    -- Kalau daddy pilih map tertentu, ke map itu dulu (data Z asli BiomeConfig),
    -- baru cari pet di situ. "Any" = diam di tempat, cari dari data yang ada.
    stageToZone(rootPart)

    while StealCfg.Enabled do
        local target = pickTarget()
        updateStealInfo(target)
        if not target then
            -- Nggak ada pet yang lolos filter -> diam di zone, jangan kabur.
            setStatus("any detect", "waiting for filtered pet")
            return false
        end
        setStatus("any detect", tostring(target.name or "?"))

        local ok = tryCaptureOnce(rootPart, target)

        -- Kasih server waktu bersihin Capturing. Kalaupun nyangkut, jangan
        -- nunggu 4 detik: cancel cepat lalu lanjut target berikutnya.
        if LocalPlayer:GetAttribute("Capturing") == true then
            task.wait(0.15)
            if LocalPlayer:GetAttribute("Capturing") == true then cancelCapture(nil) end
        end

        -- Setelah sukses tetap lanjut; setelah gagal juga tetap lanjut.
        -- Tidak ada escapeToSafeZone di sini. Boss/dekat guardian diabaikan:
        -- recoverFromBoss sudah jalan di rushToPoint/reelCapture.
        if ok then
            task.wait(isFastReel() and 0.08 or 0.15)
        else
            task.wait(isFastReel() and 0.08 or 0.12)
        end
        if isCarrying() then
            -- Carry baru saja selesai = persist ke bag sekarang. Setelah itu
            -- loop berikutnya mulai lagi dari zone yang sama.
            escapeToSafeZone()
            return true
        end
        if not StealCfg.Enabled then return false end
    end
    return false
end

local function stealLoop()
    -- Satu pemilik global. Instance lama yang masih nyoba start loop kalah.
    if genv.LoopXCode_StealOwner == STEAL_OWNER then return end
    genv.LoopXCode_StealOwner = STEAL_OWNER
    task.spawn(function()
        while StealCfg.Enabled and not ManualSteal.Active
            and genv.LoopXCode_StealOwner == STEAL_OWNER do
            StealCfg.Busy = true
            pcall(stealStep)
            StealCfg.Busy = false
            -- Jeda kecil antar siklus supaya game nggak freeze. Bukan RetryDelay
            -- (0.7s) yang bikin Fast kerasa macet tiap selesai satu catch.
            if StealCfg.Enabled then task.wait(isFastReel() and 0.08 or 0.15) end
        end
        StealCfg.Busy = false
        -- Loop selesai: lepas owner supaya toggle ON lagi bisa jalan.
        if genv.LoopXCode_StealOwner == STEAL_OWNER then
            genv.LoopXCode_StealOwner = nil
        end
        updateStealInfo(nil)
        if not ManualSteal.Active then setStatus("idle", "any detect") end
    end)
end

-- Manual STEAL dari Finder: cari wild pet berdasarkan nama (abaikan filter
-- Auto Catch), cek lasso tetap dilaporkan, lalu Tetap jalan ke pet itu.
local function findWildPetByName(name, rootPart)
    local wanted = normalizeText(name)
    local best, bestDist = nil, math.huge
    for _, model in ipairs(WildFolder:GetChildren()) do
        if isUncaptured(model:GetAttribute("CapturedBy"))
            and model:GetAttribute("Despawning") ~= true then
            local info = wildInfo(model)
            if info and normalizeText(info.name) == wanted then
                local dist = rootPart and (info.pos - rootPart.Position).Magnitude or 0
                if dist < bestDist then best, bestDist = info, dist end
            end
        end
    end
    return best
end

local function startManualSteal(petName)
    if ManualSteal.Active then return false end
    petName = tostring(petName or "")
    if petName == "" then return false end
    ManualSteal.Active = true
    ManualSteal.Name = petName
    task.spawn(function()
        setStatus("on system", "manual " .. petName)
        local okRun, err = pcall(function()
            local char = LocalPlayer.Character
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            if not rootPart then error("no character") end
            if not ensureLasso() then error("no lasso") end

            local target = findWildPetByName(petName, rootPart)
            if not target then
                bumpStealStat("Failed")
                setStatus("any detect", "pet not loaded: " .. petName)
                refreshStealStats()
                return
            end

            updateStealInfo(target)
            stageToZone(rootPart, target.zone)
            local weak = lassoTooWeak(target)
            if weak then
                bumpStealStat("Weak")
                StealStats.LastWeak = tostring(target.name or "?")
                setStatus("on system", tr("lasso too weak: ") .. tostring(target.name or "?"))
                refreshStealStats()
            end

            local got = tryCaptureOnce(rootPart, target)
            if got and isCarrying() then
                escapeToSafeZone()
            end
            -- tryCaptureOnce sudah menghitung Failed bila attempt gagal.
        end)
        if not okRun then
            bumpStealStat("Failed")
            setStatus("any detect", "manual steal error")
            refreshStealStats()
        end
        updateStealInfo(nil)
        ManualSteal.Active = false
        ManualSteal.Name = ""
        if not StealCfg.Enabled then setStatus("idle", "any detect") end
    end)
    return true
end
genv.LoopXCode_StartManualSteal = startManualSteal
genv.LoopXCode_FindWildPetByName = findWildPetByName

-- applyAutoSteal dipindah ke bawah (butuh dismountPet/equipBestSpeed)
genv.LoopXCode_ApplyAutoSteal = function() end

local R_MOUNT = RemoteFolder:FindFirstChild("Mount")

-- Auto Equip Best Speed: samakan persis alur tombol "Ride" manual game:
--   1) equipmount(id)  -> nandain MountPet (hewan disiapin)
--   2) Mount(id, true) -> hewan BENERAN dipakai (Mount / MountId keisi)
-- Cek pakai MountId (bukan MountPet) karena MountPet bisa keisi tapi hewan
-- tetap nggak dipakai kalau remote Mount nggak dipanggil.
local function equipBestSpeed()
    -- Server kadang balasin list kosong right setelah mount/dismount. Coba lagi
    -- sampai ada isinya, kalau nggak bakal salah pilih / nggak nge-equip.
    local list
    for _ = 1, 4 do
        local ok, res = pcall(function() return R_STEAL.PenPetAction:InvokeServer("list") end)
        local penN, bagN = 0, 0
        if ok and type(res) == "table" then
            if type(res.pen) == "table" then penN = #res.pen end
            if type(res.bag) == "table" then bagN = #res.bag end
            if penN + bagN > 0 then list = res break end
        end
        task.wait(0.25)
    end
    if not list then return end
    local best, bestSpeed = nil, -1
    local function consider(pet)
        if type(pet) ~= "table" or not pet.id then return end
        local cfg = petCfg(pet.name)
        if not cfg then return end
        local size = tonumber(pet.size) or 1
        local mutation = pet.mutation
        local speed = 0
        -- Sama persis dengan perhitungan UI game (MountClient / PetTags).
        pcall(function()
            speed = tonumber(MC.PetSpeed(cfg, size, mutation)) or 0
        end)
        if speed <= 0 then speed = tonumber(cfg.Speed) or 0 end
        if speed > bestSpeed then
            bestSpeed = speed
            best = pet
        elseif speed == bestSpeed and best and petIncome(cfg) > petIncome(petCfg(best.name)) then
            -- tie-break: kalau speed sama, pilih yang income lebih tinggi
            best = pet
        end
    end
    for _, pet in ipairs(list.pen or {}) do consider(pet) end
    for _, pet in ipairs(list.bag or {}) do consider(pet) end
    if not best then return end

    local currentId = LocalPlayer:GetAttribute("MountId")
    if currentId == best.id and (LocalPlayer:GetAttribute("Mount") or "") ~= "" then return end

    -- langkah 1: siapkan hewan (skip kalau sudah ke-prep)
    if (LocalPlayer:GetAttribute("MountPet") or "") ~= best.id then
        pcall(function() R_STEAL.PenPetAction:InvokeServer("equipmount", best.id) end)
        task.wait(0.12)
    end
    -- langkah 2: benaran pakai / kendarai hewan (ini yang bikin gerak)
    if R_MOUNT then
        pcall(function() R_MOUNT:InvokeServer(best.id, true) end)
    else
        pcall(function() R_STEAL.PenPetAction:InvokeServer("equipbestmount") end)
    end
end
genv.LoopXCode_EquipBestSpeed = equipBestSpeed

-- Turun dari pet: samakan tombol Ride game saat hewan sedang dipakai.
local function dismountPet()
    if R_MOUNT then
        pcall(function() R_MOUNT:InvokeServer("", true) end)
    end
end
genv.LoopXCode_DismountPet = dismountPet

-- Auto Equip Best Speed: event perubahan Mount/MountId + jaga-jaga tiap 3 detik,
-- supaya kalau hewan dilepas / diganti manual, langsung balik ke yang tercepat.
genv.LoopXCode_AutoEquipV2 = true
pcall(function()
    local function reEquip()
        if genv.LoopXCode_AutoEquipV2 then
            task.spawn(function() task.wait(0.2) pcall(equipBestSpeed) end)
        end
    end
    LocalPlayer:GetAttributeChangedSignal("MountId"):Connect(reEquip)
    LocalPlayer:GetAttributeChangedSignal("Mount"):Connect(reEquip)
end)
task.spawn(function()
    while alive() do
        -- Pet TETAP dipakai selama auto steal (daddy minta hewan tetap ke-ride).
        if genv.LoopXCode_AutoEquipV2 then pcall(equipBestSpeed) end
        task.wait(3)
    end
end)

-- Auto Steal ON  -> pet TETAP ke-ride. Gerak pakai step 6 bertahap (server nerima)
--                  dan pulih dari launch Guardian tiap tick.
-- Auto Steal OFF -> auto-equip tetap jalan, nggak ada yang di-dismount.
local function applyAutoSteal(v)
    StealCfg.Enabled = (v == true)
    if StealCfg.Enabled and genv.LoopXCode_HardenCfg.AutoTreadmill then
        pcall(function() genv.LoopXCode_HardenToggle("AutoTreadmill", false) end)
    end
    if StealCfg.Enabled then
        -- pastikan hewan ke-ride sebelum jalan (tanpa turun dari pet)
        if genv.LoopXCode_AutoEquipV2 then task.spawn(equipBestSpeed) end
        setStatus("on system", "any detect")
        stealLoop()
    else
        StealCfg.Busy = false
        updateStealInfo(nil)
        if not ManualSteal.Active then setStatus("idle", "any detect") end
    end
end
genv.LoopXCode_ApplyAutoSteal = applyAutoSteal

-- =====================================================================
-- 2. SKIP TUTORIAL
-- =====================================================================
local TutorialRemote = RemoteFolder:WaitForChild("Tutorial")
local TutorialSteps = require(ModuleFolder:WaitForChild("TutorialSteps"))

local function serverAccepted(value)
    if type(value) ~= "table" then return value == true end
    if value.ok ~= nil then return value.ok == true end
    if value.success ~= nil then return value.success == true end
    return true
end

local SkipTutorial = {}
function SkipTutorial.Run()
    local step = LocalPlayer:GetAttribute("TutorialStep") or 0
    local id = "DONE"
    if step > 0 then
        local entry = TutorialSteps.List[step]
        id = entry and entry.id or "?"
    end

    local ok, result = pcall(function() return TutorialRemote:InvokeServer("skip") end)
    if (not ok or not serverAccepted(result)) and step > 0 then
        pcall(function() return TutorialRemote:InvokeServer("uidone", id) end)
    end
end
genv.LoopXCode_SkipTutorial = SkipTutorial

-- =====================================================================
-- 3. ESP
-- =====================================================================
local Camera = Workspace.CurrentCamera
local ESPConfig = {
    Enabled = true,
    MaxDistance = 1500,
    FixedSize = true,
    ShowInfo = true,
    -- RenderStepped tetap dipakai buat timing, tapi kerja berat ESP cuma
    -- jalan tiap interval ini. Naikkan kalau masih lag, turunkan kalau mau halus.
    UpdateInterval = 0.12,
    ScanInterval = 0.75,
    ESPPlayers = true,
    ESPGuards = false,
    ESPPets = true,
    PlayerSize = 14,
    GuardSize = 13,
    PetSize = 13,
    PlayerColor = Color3.fromRGB(255, 92, 40),
    GuardColor = Color3.fromRGB(251, 191, 36),
    PetColor = Color3.fromRGB(56, 189, 248),
    TargetFolders = { "WildPets", "PetsGame", "Guardians", "Pets", "Guards", "NPCs", "Enemies", "Mobs" },
    -- Style ESP per kategori. "Any" dipakai shortcut buat set semua sekaligus.
    Styles = {
        Any = { Size = 13, Shadow = 0.55, ShadowOffset = 2, Font = "Bold", Color = "#8AD7FF" },
        Player = { Size = 14, Shadow = 0.55, ShadowOffset = 2, Font = "Bold", Color = "#FF5C28" },
        Pet = { Size = 13, Shadow = 0.55, ShadowOffset = 2, Font = "Bold", Color = "#38BDF8" },
        Guard = { Size = 13, Shadow = 0.55, ShadowOffset = 2, Font = "Bold", Color = "#FBBF24" }
    }
}
genv.LoopXCode_ESPConfig = ESPConfig

local function colorFromInput(value, fallback: Color3): Color3
    local s = tostring(value or "")
    local hex = s:match("^%s*#?(%x%x%x%x%x%x)%s*$")
    if hex then
        return Color3.fromRGB(
            tonumber(hex:sub(1, 2), 16) or fallback.R * 255,
            tonumber(hex:sub(3, 4), 16) or fallback.G * 255,
            tonumber(hex:sub(5, 6), 16) or fallback.B * 255)
    end
    local r, g, b = s:match("^%s*(%d+)%s*[%,%s]%s*(%d+)%s*[%,%s]%s*(%d+)%s*$")
    if r and g and b then
        return Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
    end
    return fallback
end
genv.LoopXCode_ColorFromInput = colorFromInput

local function setEspStyle(category, key, value)
    local targets = (category == "Any") and { "Player", "Pet", "Guard" } or { category }
    for _, cat in ipairs(targets) do
        local style = ESPConfig.Styles[cat]
        if style then style[key] = value end
    end
end
genv.LoopXCode_SetEspStyle = setEspStyle

local function addEspStyleInputs(section, category, label)
    section:Input({
        Title = label .. " ESP Size",
        Value = tostring(ESPConfig.Styles[category].Size),
        Placeholder = "13",
        Callback = function(v)
            setEspStyle(category, "Size", math.max(1, math.floor(tonumber(v) or 13)))
        end
    })
    section:Input({
        Title = label .. " ESP Color",
        Value = tostring(ESPConfig.Styles[category].Color),
        Placeholder = "#38BDF8  or  56,189,248",
        Callback = function(v)
            setEspStyle(category, "Color", tostring(v))
        end
    })
    section:Input({
        Title = label .. " ESP Shadow",
        Value = tostring(ESPConfig.Styles[category].Shadow),
        Placeholder = "0.55  (0 = off, 1 = solid)",
        Callback = function(v)
            setEspStyle(category, "Shadow", math.clamp(tonumber(v) or 0.55, 0, 1))
        end
    })
    section:Input({
        Title = label .. " ESP Shadow Offset",
        Value = tostring(ESPConfig.Styles[category].ShadowOffset),
        Placeholder = "2",
        Callback = function(v)
            setEspStyle(category, "ShadowOffset", math.clamp(math.floor(tonumber(v) or 2), 0, 12))
        end
    })
    section:Dropdown({
        Title = label .. " ESP Font",
        Values = FONT_CHOICES,
        Value = tostring(ESPConfig.Styles[category].Font or "Regular"),
        Callback = function(v)
            setEspStyle(category, "Font", tostring(v or "Regular"))
        end
    })
end

local BillboardHolder = Instance.new("Folder")
BillboardHolder.Name = "LoopXCode_ESP_Holder"
BillboardHolder.Parent = ParentGui

local ESPCache = {}
local TrackedEntities = {}

local function GetAnchorPart(model)
    if not model or not model.Parent then return nil end
    if model:IsA("BasePart") then return model end
    return model:FindFirstChild("RootPart")
        or model:FindFirstChild("Head")
        or model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function ClassifyEntity(model)
    if not model or not model:IsA("Model") then return nil end
    if Players:GetPlayerFromCharacter(model) then return "Player" end
    if model:GetAttribute("Guardian") == true or model:GetAttribute("Boss") then return "Guard" end
    -- Pet asli game selalu punya atribut PetName (wild maupun di pen).
    if model:GetAttribute("PetName") then return "Pet" end

    local lowerName = string.lower(model.Name)
    local parentName = model.Parent and string.lower(model.Parent.Name) or ""

    if parentName == "wildpets" or parentName == "penpets" or parentName == "pets" then
        return "Pet"
    end
    if string.find(lowerName, "guard") or string.find(parentName, "guard")
        or string.find(lowerName, "enemy") or string.find(parentName, "enemy")
        or string.find(parentName, "guardians") then
        return "Guard"
    end
    return nil
end

task.spawn(function()
    while BillboardHolder.Parent do
        local found = {}
        for _, folderName in ipairs(ESPConfig.TargetFolders) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, desc in ipairs(folder:GetDescendants()) do
                    local cat = ClassifyEntity(desc)
                    if cat then found[desc] = cat end
                end
            end
        end
        for _, child in ipairs(Workspace:GetChildren()) do
            local cat = ClassifyEntity(child)
            if cat then found[child] = cat end
        end
        TrackedEntities = found
        task.wait(math.max(0.25, tonumber(ESPConfig.ScanInterval) or 0.75))
    end
end)

local function EnsureBillboard(model, category)
    local anchor = GetAnchorPart(model)
    if not anchor then return nil end

    local entry = ESPCache[model]
    if not entry then
        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_" .. model.Name
        bb.AlwaysOnTop = true
        bb.ResetOnSpawn = false
        bb.StudsOffset = Vector3.new(0, 2.4, 0)
        bb.Adornee = anchor
        bb.Parent = BillboardHolder

        -- Shadow duplikat hitam di belakang teks (bukan outline/garis).
        local sh = Instance.new("TextLabel")
        sh.Name = "Shadow"
        sh.Size = UDim2.fromScale(1, 1)
        sh.BackgroundTransparency = 1
        sh.Font = Enum.Font.GothamBold
        sh.TextColor3 = Color3.fromRGB(0, 0, 0)
        sh.TextStrokeTransparency = 1
        sh.TextXAlignment = Enum.TextXAlignment.Center
        sh.TextYAlignment = Enum.TextYAlignment.Center
        sh.TextWrapped = false
        sh.Active = false
        sh.Parent = bb

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 1
        lbl.TextWrapped = false
        lbl.Parent = bb

        entry = { Gui = bb, Label = lbl, Shadow = sh, Category = category }
        ESPCache[model] = entry
    elseif entry.Gui.Adornee ~= anchor then
        entry.Gui.Adornee = anchor
    end

    return entry
end

local function PruneESPCache()
    for model, entry in pairs(ESPCache) do
        local validModel = model and model.Parent ~= nil
        local validAdornee = entry.Gui and entry.Gui.Adornee and entry.Gui.Adornee.Parent ~= nil
        if not validModel or not validAdornee then
            if entry.Gui then pcall(function() entry.Gui:Destroy() end) end
            ESPCache[model] = nil
        end
    end
end

local function ApplyTextSize(entry, sizePx)
    if ESPConfig.FixedSize then
        entry.Gui.Size = UDim2.new(0, 340, 0, sizePx + 12)
        entry.Label.TextScaled = false
        entry.Label.TextSize = sizePx
    else
        entry.Gui.Size = UDim2.new(0, 240, 0, 44)
        entry.Label.TextScaled = true
    end
end

local function applyEspStyle(entry, category)
    local style = ESPConfig.Styles[category] or ESPConfig.Styles.Any
    local size = math.max(1, math.floor(tonumber(style.Size) or 13))
    local sh = math.clamp(tonumber(style.Shadow) or 0.55, 0, 1)
    local so = math.clamp(math.floor(tonumber(style.ShadowOffset) or 2), 0, 12)
    local face = fontFaceByName(style.Font)
    local fallbackColor = (category == "Player" and ESPConfig.PlayerColor)
        or (category == "Guard" and ESPConfig.GuardColor)
        or ESPConfig.PetColor
    local color = colorFromInput(style.Color, fallbackColor)
    ApplyTextSize(entry, size)
    pcall(function()
        applyFont(entry.Label, face)
        entry.Label.TextColor3 = color
        if entry.Shadow then
            applyFont(entry.Shadow, face)
            entry.Shadow.TextSize = size
            entry.Shadow.TextScaled = entry.Label.TextScaled
            entry.Shadow.TextTransparency = 1 - sh
            entry.Shadow.Visible = sh > 0
            entry.Shadow.Position = UDim2.new(0, so, 0, so)
        end
    end)
end

-- Style cuma dipakai ulang kalau nilai menu-nya berubah. Ini yang bikin
-- RenderStepped nggak nulis FontFace/Color3/UDim2 tiap frame buat tiap ESP.
local StyleSigCache = {}
local function espStyleSignature(category)
    local style = ESPConfig.Styles[category] or ESPConfig.Styles.Any
    local sig = table.concat({
        tostring(style.Size), tostring(style.Shadow), tostring(style.ShadowOffset),
        tostring(style.Font), tostring(style.Color), tostring(ESPConfig.FixedSize),
        tostring(ESPConfig.ShowInfo)
    }, "|")
    StyleSigCache[category] = sig
    return sig
end

local function setEntryText(entry, text)
    if entry.LastText == text then return end
    entry.LastText = text
    entry.Label.Text = text
    if entry.Shadow then entry.Shadow.Text = text end
end

local function refreshEntryStyle(entry, category)
    local sig = espStyleSignature(category)
    if entry.StyleSig ~= sig then
        applyEspStyle(entry, category)
        entry.StyleSig = sig
        entry.LastText = nil
    end
end

local function joinInfo(parts)
    local out = {}
    for _, value in ipairs(parts) do
        if value ~= nil and tostring(value) ~= "" then
            table.insert(out, tostring(value))
        end
    end
    return table.concat(out, " • ")
end

local function EntityText(model, category, dist)
    if category == "Player" then
        local plr = Players:GetPlayerFromCharacter(model)
        local name = plr and ((plr.DisplayName ~= plr.Name)
            and (plr.DisplayName .. " (@" .. plr.Name .. ")")
            or plr.Name) or model.Name
        local hum = model:FindFirstChildOfClass("Humanoid")
        local hp = hum and math.floor(hum.Health) or 0
        if ESPConfig.ShowInfo then
            return string.format("[%dm] %s • %d HP", math.floor(dist), name, hp)
        end
        return name
    end

    local isGuard = category == "Guard"
    local display = model:GetAttribute("Display") or model.Name
    local detail = isGuard
        and joinInfo({ model:GetAttribute("GState"), model:GetAttribute("Biome") })
        or joinInfo({ model:GetAttribute("Rarity"), model:GetAttribute("Biome") })

    if ESPConfig.ShowInfo then
        return string.format("[%dm] %s • %s%s",
            math.floor(dist), isGuard and "GUARD" or "PET", display,
            detail ~= "" and (" • " .. detail) or "")
    end
    return display
end

local RenderConn
local lastEspUpdate = 0
RenderConn = RunService.RenderStepped:Connect(function()
    if not BillboardHolder.Parent then
        RenderConn:Disconnect()
        return
    end

    -- BillboardGui.Adornee sudah bikin label ngikutin pet tiap frame.
    -- Kerja berat (scan + hitung teks + tulis style) cuma tiap UpdateInterval.
    local now = os.clock()
    if now - lastEspUpdate < math.max(0.05, tonumber(ESPConfig.UpdateInterval) or 0.12) then return end
    lastEspUpdate = now

    PruneESPCache()

    local myRoot = LocalPlayer.Character and GetAnchorPart(LocalPlayer.Character)
    local origin = myRoot and myRoot.Position or Camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and ESPConfig.ESPPlayers then
            local char = plr.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local anchor = GetAnchorPart(char)
            if anchor and hum and hum.Health > 0 then
                local entry = EnsureBillboard(char, "Player")
                if entry then
                    local dist = (anchor.Position - origin).Magnitude
                    local show = ESPConfig.Enabled and dist <= ESPConfig.MaxDistance
                    entry.Gui.Enabled = show
                    if show then
                        refreshEntryStyle(entry, "Player")
                        setEntryText(entry, EntityText(char, "Player", dist))
                    end
                end
            end
        end
    end

    for model, category in pairs(TrackedEntities) do
        -- Player sudah digambar di loop Players; jangan dimatikan loop ini.
        if category ~= "Player" and model and model.Parent then
            local anchor = GetAnchorPart(model)
            local hum = model:FindFirstChildOfClass("Humanoid")
            if anchor and (not hum or hum.Health > 0) then
                local entry = EnsureBillboard(model, category)
                if entry then
                    local dist = (anchor.Position - origin).Magnitude
                    local catEnabled = (category == "Guard" and ESPConfig.ESPGuards)
                        or (category == "Pet" and ESPConfig.ESPPets)
                    local show = ESPConfig.Enabled and catEnabled and dist <= ESPConfig.MaxDistance
                    entry.Gui.Enabled = show
                    if show then
                        refreshEntryStyle(entry, category)
                        setEntryText(entry, EntityText(model, category, dist))
                    end
                end
            end
        end
    end
end)

local function stopESP()
    if RenderConn then
        pcall(function() RenderConn:Disconnect() end)
        RenderConn = nil
    end
    for model, entry in pairs(ESPCache) do
        if entry.Gui then pcall(function() entry.Gui:Destroy() end) end
        ESPCache[model] = nil
    end
    TrackedEntities = {}
    pcall(function() BillboardHolder:Destroy() end)
end
OnCleanup(stopESP)

-- =====================================================================
-- 4. EXTENDED HACKS — remote tervalidasi, efek hanya untuk LocalPlayer
-- =====================================================================
-- Scope terpisah supaya ratusan lokal di engine ini tidak memakan register
-- chunk utama. State penting diekspor lewat genv untuk dipakai registry/UI.
local function buildHarden()
genv.LoopXCode_HardenCfg = {
    SaveHistory = true, SaveUI = true, SaveMenu = true,
    AutoClaimIndex = true, AutoUpgradeTraining = false, AutoUpgradeTreadmill = false, AutoTreadmill = false,
    AntiBan = true, GodMode = false, Fly = false, JumpInfinity = false,
    AntiKnockDown = true, Invisible = false, AntiRagdoll = true, AutoAntiSpeed = false,
    AntiAFK = true, AntiHit = false
}
if genv.LoopXCode_HardenCfg.AntiAFK == nil then genv.LoopXCode_HardenCfg.AntiAFK = true end
-- config exported above; no local alias needed
genv.LoopXCode_HardenEpoch = (tonumber(genv.LoopXCode_HardenEpoch) or 0) + 1
local HARDEN_EPOCH = genv.LoopXCode_HardenEpoch

-- Anti AFK: pakai Idled + VirtualUser klik kanan. Nggak menyentuh HRD,
-- Humanoid, mount, atau remote capture, jadi aman kalau Auto Catch jalan.
local okVU, VirtualUser = pcall(function() return game:GetService("VirtualUser") end)
if not okVU then VirtualUser = nil end
local AntiAFKConn = nil
local function setAntiAFK(enabled)
    enabled = (enabled == true)
    if not enabled or not VirtualUser then
        if AntiAFKConn then
            pcall(function() AntiAFKConn:Disconnect() end)
            AntiAFKConn = nil
        end
        return
    end
    if AntiAFKConn then return end
    AntiAFKConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            pcall(function() VirtualUser:CaptureController() end)
            if type(VirtualUser.ClickButton2) == "function" then
                VirtualUser:ClickButton2(Vector2.new())
            else
                local cam = Workspace.CurrentCamera
                VirtualUser:Button2Down(Vector2.new(), cam and cam.CFrame or CFrame.new())
                task.wait(0.1)
                VirtualUser:Button2Up(Vector2.new(), cam and cam.CFrame or CFrame.new())
            end
        end)
    end)
end
genv.LoopXCode_SetAntiAFK = setAntiAFK
OnCleanup(function() setAntiAFK(false) end)
setAntiAFK(genv.LoopXCode_HardenCfg.AntiAFK)

local HardenHistory = {}
genv.LoopXCode_HardenAlive = function()
    return not STATE or type(STATE.alive) ~= "function" or STATE.alive()
end
genv.LoopXCode_HardenAlive = function()
    return HARDEN_EPOCH == genv.LoopXCode_HardenEpoch
        and (not STATE or type(STATE.alive) ~= "function" or STATE.alive())
end
-- alive checker exported above

-- Anti Hit: guardian target diubah ke id bukan milik LocalPlayer supaya
-- guardian/poseidon tidak masuk mode wake dan tidak mengejar. Set_Shake juga
-- dimatikan supaya efek hit dari server tidak mengguncang layar.
genv.LoopXCode_AntiHitState = { shakeOriginal = nil, cache = {}, hitConnections = nil }
genv.LoopXCode_PacifyGuardian = function(model)
    if not model or not model.Parent then return end
    local mine = LocalPlayer.UserId
    local function isMine(v)
        return v == mine or v == tostring(mine)
    end
    if isMine(model:GetAttribute("GTarget")) then
        pcall(function()
            model:SetAttribute("GTarget", 0)
            model:SetAttribute("GState", "sleep")
        end)
    end
    for _, key in ipairs({ "TargetUserId", "PetTarget", "AttackTarget", "ChaseTarget" }) do
        if isMine(model:GetAttribute(key)) then
            pcall(function() model:SetAttribute(key, 0) end)
        end
    end
end

genv.LoopXCode_CollectGuardians = function()
    local found = {}
    pcall(function()
        for _, g in ipairs(CollectionService:GetTagged("Guardian")) do found[g] = true end
    end)
    for _, folderName in ipairs({ "Guardians", "PetsGame", "Pets", "Guards" }) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, o in ipairs(folder:GetDescendants()) do
                local lower = string.lower(o.Name)
                if string.find(lower, "guard", 1, true)
                    or string.find(lower, "boss", 1, true)
                    or o:GetAttribute("GTarget") ~= nil then
                    found[o] = true
                end
            end
        end
    end
    return found
end

-- GuardianHit dikirim server, jadi client nggak bisa mengubah keputusan chase.
-- Yang BISA dilakukan: putuskan listener efek hit di client supaya char nggak
-- di-launch/flash, lalu pasangkan kembali kalau Anti Hit dimatikan.
local function suppressGuardianHit()
    local state = genv.LoopXCode_AntiHitState
    if state.hitConnections then return end
    local remote = RemoteFolder and RemoteFolder:FindFirstChild("GuardianHit")
    if not remote or type(getconnections) ~= "function" then return end
    local saved = {}
    pcall(function()
        for _, c in ipairs(getconnections(remote.OnClientEvent)) do
            local fn = c.Function
            if type(fn) == "function" then
                saved[#saved + 1] = { signal = remote.OnClientEvent, fn = fn, conn = c }
                pcall(function() c:Disconnect() end)
            end
        end
    end)
    state.hitConnections = saved
end

local function restoreGuardianHit()
    local state = genv.LoopXCode_AntiHitState
    local saved = state.hitConnections
    if not saved then return end
    for _, e in ipairs(saved) do
        pcall(function() e.signal:Connect(e.fn) end)
    end
    state.hitConnections = nil
end

task.spawn(function()
    local nextScan = 0
    while genv.LoopXCode_HardenAlive() do
        if genv.LoopXCode_HardenCfg.AntiHit then
            pcall(function() LocalPlayer:SetAttribute("Set_Shake", false) end)
            local now = os.clock()
            if now >= nextScan then
                nextScan = now + 0.65
                genv.LoopXCode_AntiHitState.cache = genv.LoopXCode_CollectGuardians()
            end
            for guardian in pairs(genv.LoopXCode_AntiHitState.cache) do
                genv.LoopXCode_PacifyGuardian(guardian)
            end
        end
        task.wait(0.12)
    end
end)

pcall(function()
    CollectionService:GetInstanceAddedSignal("Guardian"):Connect(function(g)
        if genv.LoopXCode_HardenCfg.AntiHit then
            task.spawn(function() task.wait(0.05) genv.LoopXCode_PacifyGuardian(g) end)
        end
    end)
end)

OnCleanup(function()
    local state = genv.LoopXCode_AntiHitState
    pcall(restoreGuardianHit)
    if state.shakeOriginal ~= nil then
        pcall(function() LocalPlayer:SetAttribute("Set_Shake", state.shakeOriginal) end)
    end
end)

local R_INDEX = RemoteFolder:FindFirstChild("IndexAction")
local R_FREE = RemoteFolder:FindFirstChild("FreeReward")
local R_OFFLINE = RemoteFolder:FindFirstChild("OfflineEarnings")
local R_TRAIN = RemoteFolder:FindFirstChild("TrainTap")
local R_UP_DUMMY = RemoteFolder:FindFirstChild("UpgradeDummy")
local R_UP_PEN = RemoteFolder:FindFirstChild("UpgradePen")

local function hInvoke(remote, ...)
    if not remote or not remote:IsA("RemoteFunction") then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
    if ok then return res end
    return nil
end

local function hFire(remote, ...)
    if not remote or not remote:IsA("RemoteEvent") then return end
    local args = table.pack(...)
    pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
end

do
    -- Auto Sell Pet: jual semua pet yang tier-nya dicentang. Remote yang dipakai
    -- persis sama dengan tombol SELL di game: SellPets("list") lalu ("sell", ids).
    genv.LoopXCode_NormalizeSellRarities = function(value)
        local out = {}
        if type(value) == "table" then
            for _, v in pairs(value) do
                local name = (type(v) == "table" and (v.Title or v.Value or v.Name)) or v
                if name ~= nil and tostring(name) ~= "" then out[tostring(name)] = true end
            end
        elseif value ~= nil and tostring(value) ~= "" then
            out[tostring(value)] = true
        end
        return out
    end

    local function petSellTier(pet)
        local cfg = petCfg(pet and pet.Name)
        local tier = nil
        pcall(function() if cfg then tier = PC.GetTier(cfg) end end)
        return tostring(tier or (pet and pet.Tier) or (pet and pet.Rarity) or "Common")
    end

    genv.LoopXCode_SellPetsNow = function()
        if not R_SELL or SellCfg.Busy then return 0 end
        local selected = genv.LoopXCode_NormalizeSellRarities(SellCfg.Rarities)
        if not next(selected) then return 0 end

        local okList, list = pcall(function() return R_SELL:InvokeServer("list") end)
        if not okList or type(list) ~= "table" then return 0 end

        local ids = {}
        for _, pet in ipairs(list) do
            local tier = petSellTier(pet)
            if selected[tier]
                or selected[tostring(pet.Tier)]
                or selected[tostring(pet.Rarity)] then
                ids[#ids + 1] = pet.Id
            end
        end
        if #ids == 0 then return 0 end

        SellCfg.Busy = true
        local okSell, result = pcall(function() return R_SELL:InvokeServer("sell", ids) end)
        SellCfg.Busy = false
        if okSell and type(result) == "table" and result.ok then
            setStatus(tr("auto sell"), tostring(#ids) .. " " .. tr("pets"))
            return #ids
        end
        return 0
    end

    task.spawn(function()
        while alive() do
            if SellCfg.Enabled then pcall(function() genv.LoopXCode_SellPetsNow() end) end
            task.wait(math.max(1, tonumber(SellCfg.Interval) or 5))
        end
    end)
end

genv.LoopXCode_HardenSave = function()
    local ok, str = pcall(function()
        return HttpService:JSONEncode({
            AutoClaimIndex = genv.LoopXCode_HardenCfg.AutoClaimIndex,
            AutoUpgradeTraining = genv.LoopXCode_HardenCfg.AutoUpgradeTraining,
            AutoUpgradeTreadmill = genv.LoopXCode_HardenCfg.AutoUpgradeTreadmill,
            AutoTreadmill = genv.LoopXCode_HardenCfg.AutoTreadmill,
            AntiBan = genv.LoopXCode_HardenCfg.AntiBan, GodMode = genv.LoopXCode_HardenCfg.GodMode,
            Fly = genv.LoopXCode_HardenCfg.Fly, JumpInfinity = genv.LoopXCode_HardenCfg.JumpInfinity,
            AntiKnockDown = genv.LoopXCode_HardenCfg.AntiKnockDown, Invisible = genv.LoopXCode_HardenCfg.Invisible,
            AntiRagdoll = genv.LoopXCode_HardenCfg.AntiRagdoll, AutoAntiSpeed = genv.LoopXCode_HardenCfg.AutoAntiSpeed,
            AntiAFK = genv.LoopXCode_HardenCfg.AntiAFK, AntiHit = genv.LoopXCode_HardenCfg.AntiHit
        })
    end)
    if genv.LoopXCode_HardenCfg.SaveHistory and ok and type(str) == "string" then
        HardenHistory[#HardenHistory + 1] = string.format("%s %s", os.date("%Y-%m-%d %H:%M:%S"), str)
        if #HardenHistory > 20 then table.remove(HardenHistory, 1) end
        pcall(function() ReplicatedStorage:SetAttribute("LoopXCodeExtendedCfg", str) end)
    end
end
-- settings save exported above

-- Auto Claim Index: tombol "CLAIM ALL" tetap dilacak di PlayerGui supaya
-- hub tahu kalau UI Index tersedia, lalu jalur yang dipakai tombol itu
-- (IndexAction("claimall")) yang dipanggil langsung. Tidak pakai firesignal /
-- Connection:Fire karena di executor ini keduanya no-op.
local function findIndexClaimAllButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local exact = pg:FindFirstChild("GuiMid")
    exact = exact and exact:FindFirstChild("Index")
    exact = exact and exact:FindFirstChild("IndexFrame")
    exact = exact and exact:FindFirstChild("TOP")
    exact = exact and exact:FindFirstChild("ClaimAll")
    if exact and exact:IsA("GuiButton") then return exact end

    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = string.upper(string.gsub(tostring(obj.Text or ""), "%s+", " "))
            if string.find(text, "CLAIM ALL", 1, true) then
                local node = obj
                while node and node ~= pg do
                    if node:IsA("GuiButton") then return node end
                    node = node.Parent
                end
            end
        end
    end
    return nil
end

local lastIndexClaim = 0
local lastMiniClaim = 0
local HardenClaimIndex = function()
    if not genv.LoopXCode_HardenCfg.AutoClaimIndex then return end
    local now = os.clock()

    if now - lastIndexClaim >= 1.5 then
        lastIndexClaim = now

        -- Pastikan tombol CLAIM ALL masih bisa ditemukan (path/teks berubah?).
        -- Tetap panggil remote aslinya: ini yang benar-benar memberi reward.
        findIndexClaimAllButton()
        local res = hInvoke(R_INDEX, "claimall")
        local state = type(res) == "table" and res.state or nil
        if type(state) ~= "table" then
            local fresh = hInvoke(R_INDEX, "get")
            state = type(fresh) == "table" and fresh.state or nil
        end
        if type(state) == "table" then
            local claimed, discovered = {}, {}
            for _, name in ipairs(state.Claims or {}) do claimed[name] = true end
            for _, name in ipairs(state.Discovered or {}) do discovered[name] = true end
            for name in pairs(discovered) do
                if not claimed[name] then
                    hInvoke(R_INDEX, "claim", name)
                    claimed[name] = true
                    task.wait(0.05)
                end
            end
            for _, section in ipairs(state.Sections or {}) do
                hInvoke(R_INDEX, "claimsection", section)
            end
        end
    end

    if now - lastMiniClaim >= 6 then
        lastMiniClaim = now
        if LocalPlayer:GetAttribute("FreeRewardClaimed") ~= true then
            hInvoke(R_FREE, "joined")
            hInvoke(R_FREE, "claim")
        end
        hInvoke(R_OFFLINE)
    end
end

-- Auto Treadmill: teleport ke TrainPad dulu (server baru set Training=true
-- kalau character benar-benar di pad), lalu tekan TAP! memakai jalur persis
-- seperti tombol aslinya: TrainTap:FireServer(TrainTapId) sekali per gelembung.
local function getTrainPadDeck()
    local ok, deck = pcall(function()
        local bases = workspace:FindFirstChild("PetsGame")
            and workspace.PetsGame:FindFirstChild("Bases")
        if not bases then return nil end
        local myBase = nil
        for _, b in ipairs(bases:GetChildren()) do
            if tostring(b:GetAttribute("Owner")) == tostring(LocalPlayer.UserId) then
                myBase = b
                break
            end
        end
        myBase = myBase
            or bases:FindFirstChild("Base" .. tostring(LocalPlayer:GetAttribute("BaseId")))
        local station = myBase and myBase:FindFirstChild("TrainingStation")
        local pad = station and station:FindFirstChild("TrainPad")
        return pad and pad:FindFirstChild("Deck") or pad
    end)
    return ok and deck or nil
end

local function teleportToTreadmill()
    if not genv.LoopXCode_HardenCfg.AutoTreadmill then return false end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local deck = getTrainPadDeck()
    if not hrp or not deck then return false end
    local target = deck:IsA("BasePart") and deck.CFrame + Vector3.new(0, 3.5, 0)
        or deck:GetPivot() + Vector3.new(0, 3.5, 0)
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = target
    end)
    return true
end

local function getTapButton()
    local ok, btn = pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local tt = pg and pg:FindFirstChild("TrainTap")
        local root = tt and tt:FindFirstChild("Root")
        return root and root:FindFirstChild("Button")
    end)
    return ok and btn or nil
end

-- Klik tombol TAP! asli lewat koneksi Activated-nya. Ini yang dipakai mouse
-- daddy: handler-nya menyembunyikan gelembung (biar nggak jadi MISS) dan
-- mengirim TrainTap:FireServer(id) + efek combo. Connection:Fire bekerja di
-- executor ini (sudah diuji: Visible langsung false setelah fire).
local function pressTapButton()
    local btn = getTapButton()
    if not btn then return false end
    local ok, vis = pcall(function() return btn.Visible end)
    if not ok or not vis then return false end
    local okC, conns = pcall(function() return getconnections(btn.Activated) end)
    if not okC or type(conns) ~= "table" then return false end
    local fired = 0
    for _, conn in ipairs(conns) do
        if conn.Enabled ~= false and pcall(function() conn:Fire() end) then
            fired += 1
        end
    end
    return fired > 0
end

local lastTapId = nil
local pendingTapId = nil
local pendingTapAt = 0
local lastPadTry = 0

-- Klik instan: pantau atribut TrainTapId + Heartbeat supaya gelembung yang
-- muncul di antara tick polling tetap kena di frame yang sama.
local tapListenerConn = nil
local function stopTapListener()
    if tapListenerConn then
        pcall(function() tapListenerConn:Disconnect() end)
        tapListenerConn = nil
    end
end
local function startTapListener()
    stopTapListener()
    tapListenerConn = RunService.Heartbeat:Connect(function()
        if not genv.LoopXCode_HardenAlive() or not genv.LoopXCode_HardenCfg.AutoTreadmill then return end
        if LocalPlayer:GetAttribute("Training") ~= true then return end
        if (tonumber(LocalPlayer:GetAttribute("TutorialStep") or 0) or 0) ~= 0 then return end
        local id = LocalPlayer:GetAttribute("TrainTapId")
        local untilTime = tonumber(LocalPlayer:GetAttribute("TrainTapUntil") or 0) or 0
        if id == nil or id == lastTapId or workspace:GetServerTimeNow() >= untilTime then return end
        if pressTapButton() then
            lastTapId = id
            pendingTapId = nil
        end
    end)
end

local HardenAutoTap = function()
    if not genv.LoopXCode_HardenCfg.AutoTreadmill or not R_TRAIN then
        lastTapId, pendingTapId = nil, nil
        return
    end
    if (tonumber(LocalPlayer:GetAttribute("TutorialStep") or 0) or 0) ~= 0 then
        lastTapId, pendingTapId = nil, nil
        return
    end
    if LocalPlayer:GetAttribute("Training") ~= true then
        lastTapId, pendingTapId = nil, nil
        local nowT = os.clock()
        if nowT - lastPadTry >= 1.5 then
            lastPadTry = nowT
            task.spawn(teleportToTreadmill)
        end
        return
    end
    local id = LocalPlayer:GetAttribute("TrainTapId")
    local untilTime = tonumber(LocalPlayer:GetAttribute("TrainTapUntil") or 0) or 0
    local now = workspace:GetServerTimeNow()
    if id == nil or now >= untilTime then
        lastTapId, pendingTapId = nil, nil
        return
    end
    if id == lastTapId then return end
    if id ~= pendingTapId then
        pendingTapId = id
        pendingTapAt = os.clock()
    end
    if pressTapButton() then
        lastTapId = id
        pendingTapId = nil
        return
    end
    -- Tombol belum kelihatan / koneksi nggak ada. Kalau jendela hampir habis,
    -- kirim remote langsung biar tap tetap tercatat.
    if os.clock() - pendingTapAt > 0.35 then
        lastTapId = id
        pendingTapId = nil
        hFire(R_TRAIN, id)
    end
end

do
    -- Auto Upgrade / Auto Upgrade Treadmill: default OFF; kalau ON pakai argumen
    -- "sign" yang dipakai BaseSigns/PetPanel game (bukan fireclickdetector buta).
    local lastUpgradePen = 0
    local lastUpgradeDummy = 0
    local function HardenUpgradeTraining()
        local now = os.clock()
        local did = false
        if genv.LoopXCode_HardenCfg.AutoUpgradeTraining and now - lastUpgradePen >= 1.5 then
            lastUpgradePen = now
            hInvoke(R_UP_PEN, "sign")
            did = true
        end
        if genv.LoopXCode_HardenCfg.AutoUpgradeTreadmill and now - lastUpgradeDummy >= 1.5 then
            lastUpgradeDummy = now
            hInvoke(R_UP_DUMMY, "sign")
            did = true
        end
        if did then setStatus("auto upgrade", "sign") end
    end

    task.spawn(function()
        while genv.LoopXCode_HardenAlive() do
            HardenClaimIndex()
            HardenAutoTap()
            HardenUpgradeTraining()
            task.wait(0.12 + math.random() * 0.06)
        end
    end)
end

-- ---------- snapshot / restore (hanya LocalPlayer) ----------
local HardenRestore = {}
local jumpLevel = 0

local function currentHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local HardenCaptureStats = function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local visual = {}
    if char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                visual[obj] = { kind = "transparency", value = obj.Transparency, anchored = obj.Anchored }
            elseif obj:IsA("Highlight") or obj:IsA("BillboardGui") or obj:IsA("ParticleEmitter") then
                visual[obj] = { kind = "enabled", value = obj.Enabled }
            end
        end
    end
    return {
        jump = hum and hum.JumpPower, height = hum and hum.JumpHeight,
        walk = hum and hum.WalkSpeed, max = hum and hum.MaxHealth,
        health = hum and hum.Health, platform = hum and hum.PlatformStand,
        visual = visual
    }
end

local statesDisabled = false
local function setHumanoidStates(enabled)
    local hum = currentHumanoid()
    if not hum then return end
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, enabled)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, enabled)
        hum:SetStateEnabled(Enum.HumanoidStateType.GetUp, enabled)
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, enabled)
    end)
    statesDisabled = not enabled
end

local HardenRestoreStats = function(key, stats)
    if not stats then return end
    local hum = currentHumanoid()
    if hum then
        pcall(function()
            if stats.jump then hum.JumpPower = stats.jump end
            if stats.height then hum.JumpHeight = stats.height end
            if stats.walk then hum.WalkSpeed = stats.walk end
            if stats.max then hum.MaxHealth = stats.max end
            if stats.health then hum.Health = stats.health end
            if stats.platform ~= nil then hum.PlatformStand = stats.platform end
        end)
    end
    if key == "Invisible" then
        for obj, saved in pairs(stats.visual or {}) do
            if obj.Parent then
                pcall(function()
                    if saved.kind == "transparency" then
                        obj.Transparency = saved.value
                        obj.Anchored = saved.anchored
                    elseif saved.kind == "enabled" then
                        obj.Enabled = saved.value
                    end
                end)
            end
        end
    end
    if key == "AntiRagdoll" or key == "AntiKnockDown" then
        if not genv.LoopXCode_HardenCfg.AntiRagdoll and not genv.LoopXCode_HardenCfg.AntiKnockDown and statesDisabled then
            setHumanoidStates(true)
        end
    end
    if key == "JumpInfinity" then jumpLevel = 0 end
end

genv.LoopXCode_HardenToggle = function(key, v)
    if genv.LoopXCode_HardenCfg[key] == nil then return end
    if key == "AntiHit" then
        local enabled = (v == true)
        local state = genv.LoopXCode_AntiHitState
        if enabled and state.shakeOriginal == nil then
            state.shakeOriginal = LocalPlayer:GetAttribute("Set_Shake")
        end
        genv.LoopXCode_HardenCfg.AntiHit = enabled
        if enabled then
            pcall(function() LocalPlayer:SetAttribute("Set_Shake", false) end)
            pcall(suppressGuardianHit)
            for guardian in pairs(state.cache) do genv.LoopXCode_PacifyGuardian(guardian) end
        else
            pcall(restoreGuardianHit)
            if state.shakeOriginal ~= nil then
                pcall(function() LocalPlayer:SetAttribute("Set_Shake", state.shakeOriginal) end)
                state.shakeOriginal = nil
            end
        end
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if key == "AntiAFK" then
        genv.LoopXCode_HardenCfg[key] = (v == true)
        setAntiAFK(genv.LoopXCode_HardenCfg[key])
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if key == "AutoUpgradeTraining" or key == "AutoUpgradeTreadmill" then
        genv.LoopXCode_HardenCfg[key] = (v == true)
        if genv.LoopXCode_HardenCfg[key] then
            setStatus("auto upgrade", "sign")
        elseif not StealCfg.Enabled and not ManualSteal.Active then
            setStatus("idle", "any detect")
        end
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if v and not HardenRestore[key] then
        HardenRestore[key] = HardenCaptureStats()
    end
    genv.LoopXCode_HardenCfg[key] = v
    if not v and HardenRestore[key] then
        HardenRestoreStats(key, HardenRestore[key])
        HardenRestore[key] = nil
    end
    pcall(genv.LoopXCode_HardenSave)

    -- Auto Treadmill dan auto naik pet saling eksklusif.
    if key == "AutoTreadmill" then
        if v and (StealCfg.Enabled or ManualSteal.Active) then
            -- Auto Treadmill kalah kalau Auto Catch/Steal nyala.
            genv.LoopXCode_HardenCfg.AutoTreadmill = false
            setUIValue(UIHandles["Auto Treadmill"], false)
            pcall(genv.LoopXCode_HardenSave)
            return
        end
        if v then
            if genv.LoopXCode_AutoEquipBeforeTreadmill == nil then
                genv.LoopXCode_AutoEquipBeforeTreadmill = (genv.LoopXCode_AutoEquipV2 == true)
            end
            genv.LoopXCode_AutoEquipV2 = false
            genv.LoopXCode_AutoEquipSpeed = false
            pcall(function() genv.LoopXCode_SetAutoEquip(false, false) end)
            task.spawn(function()
                dismountPet()
                task.wait(0.2)
                teleportToTreadmill()
            end)
            startTapListener()
        else
            stopTapListener()
            local restore = genv.LoopXCode_AutoEquipBeforeTreadmill
            if restore ~= nil then
                genv.LoopXCode_AutoEquipBeforeTreadmill = nil
                genv.LoopXCode_AutoEquipV2 = restore
                genv.LoopXCode_AutoEquipSpeed = false
                pcall(function() genv.LoopXCode_SetAutoEquip(restore, false) end)
                if restore then task.spawn(equipBestSpeed) end
            end
        end
    end
end

-- ---------- Fly: arah dari kamera, W/A/S/D + Space/Shift ----------
local flyConn = nil
local function stopFly()
    if not flyConn then return end
    pcall(function() flyConn:Disconnect() end)
    flyConn = nil
    local hum = currentHumanoid()
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

local function startFly()
    if flyConn then return end
    flyConn = RunService.Heartbeat:Connect(function()
        if not genv.LoopXCode_HardenAlive() or not genv.LoopXCode_HardenCfg.Fly then
            stopFly()
            return
        end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        local cam = Workspace.CurrentCamera
        local dir = Vector3.new(0, 0, 0)
        if cam then
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then flat = flat.Unit end
            local right = cam.CFrame.RightVector
            local flatRight = Vector3.new(right.X, 0, right.Z)
            if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += flat end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= flat end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= flatRight end
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
            dir -= Vector3.new(0, 1, 0)
        end
        if dir.Magnitude > 0 then dir = dir.Unit end
        pcall(function()
            hum.PlatformStand = true
            root.AssemblyLinearVelocity = dir * 95
        end)
    end)
end

-- ---------- Jump infinity: tiap tekan Space makin tinggi ----------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not genv.LoopXCode_HardenAlive() or gameProcessed then return end
    if input.KeyCode ~= Enum.KeyCode.Space then return end
    if not genv.LoopXCode_HardenCfg.JumpInfinity or genv.LoopXCode_HardenCfg.Fly then return end
    local hum = currentHumanoid()
    if not hum then return end
    jumpLevel += 1
    pcall(function()
        hum.JumpPower = math.min(50 + jumpLevel * 30, 900)
        hum.JumpHeight = math.min(7.2 + jumpLevel * 4, 120)
        hum:Jump()
    end)
end)

-- ---------- loop efek perk frame ----------
task.spawn(function()
    while genv.LoopXCode_HardenAlive() do
        task.wait(0.08)

        if genv.LoopXCode_HardenCfg.Fly then startFly() else stopFly() end

        local hum = currentHumanoid()
        local char = LocalPlayer.Character

        -- God Mode: hanya LocalPlayer, health dijaga tetap penuh.
        if genv.LoopXCode_HardenCfg.GodMode and hum then
            pcall(function()
                hum.MaxHealth = 1e6
                if hum.Health < 1e6 then hum.Health = 1e6 end
                if hum:GetState() == Enum.HumanoidStateType.Dead then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end

        -- Anti Knock Down + Anti Ragdoll: matikan state jatuh/ragdoll,
        -- batalkan launch GuardianHit, JANGAN anchor bagian tubuh.
        if genv.LoopXCode_HardenCfg.AntiKnockDown or genv.LoopXCode_HardenCfg.AntiRagdoll then
            if hum and not statesDisabled then setHumanoidStates(false) end
            if hum then
                pcall(function()
                    local st = hum:GetState()
                    if st == Enum.HumanoidStateType.FallingDown
                        or st == Enum.HumanoidStateType.Ragdoll
                        or st == Enum.HumanoidStateType.GetUp then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                    hum.PlatformStand = false
                end)
            end
            if genv.LoopXCode_HardenCfg.AntiKnockDown and char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local v = root.AssemblyLinearVelocity
                    if v.Y > 40 then
                        pcall(function()
                            root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
                        end)
                    end
                end
            end
            if genv.LoopXCode_HardenCfg.AntiRagdoll and char and not genv.LoopXCode_HardenCfg.Fly then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Anchored then
                        pcall(function() part.Anchored = false end)
                    end
                end
            end
        elseif statesDisabled then
            setHumanoidStates(true)
        end

        -- Invisible: sempart, aksesoris, highlight dan billboard ikut hilang.
        if genv.LoopXCode_HardenCfg.Invisible and char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if obj.Transparency < 1 then obj.Transparency = 1 end
                elseif obj:IsA("Highlight") or obj:IsA("BillboardGui") or obj:IsA("ParticleEmitter") then
                    if obj.Enabled then obj.Enabled = false end
                end
            end
        end

        -- Anti Ban: jangan kirim remote cacat, jangan pakai math.huge, dan
        -- jaga status offline tetap wajar. Remote hygiene ada di hInvoke/hFire.
        if genv.LoopXCode_HardenCfg.AntiBan then
            if LocalPlayer:GetAttribute("OfflineBoosted") ~= true then
                pcall(function() LocalPlayer:SetAttribute("OfflineBoosted", true) end)
            end
            if hum then
                pcall(function()
                    if hum.WalkSpeed > 300 then hum.WalkSpeed = 300 end
                    if hum.JumpPower > 900 then hum.JumpPower = 900 end
                end)
            end
        else
            if LocalPlayer:GetAttribute("OfflineBoosted") == true then
                pcall(function() LocalPlayer:SetAttribute("OfflineBoosted", false) end)
            end
        end

        -- Auto Anti Speed: reset ke kecepatan normal (bukan math.huge).
        if genv.LoopXCode_HardenCfg.AutoAntiSpeed and hum and not genv.LoopXCode_HardenCfg.Fly then
            pcall(function()
                local saved = HardenRestore.AutoAntiSpeed
                hum.WalkSpeed = saved and saved.walk or 16
            end)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if not genv.LoopXCode_HardenAlive() then return end
    task.wait(0.4)
    for key in pairs(HardenRestore) do
        HardenRestore[key] = HardenCaptureStats()
    end
    jumpLevel = 0
end)
end
buildHarden()

-- =====================================================================
-- 5. DAFTARKAN SEMUA KOMPONEN KE REGISTRY
-- =====================================================================
AddButton("Skip Tutorial", function()
    task.spawn(SkipTutorial.Run)
end, "Misc")

AddToggle("Pet ESP", true, function(v) ESPConfig.ESPPets = v end, "ESP")
AddToggle("Guardian ESP", false, function(v) ESPConfig.ESPGuards = v end, "ESP")
AddToggle("Player ESP", true, function(v) ESPConfig.ESPPlayers = v end, "ESP")
AddToggle("ESP Info", true, function(v) ESPConfig.ShowInfo = v end, "ESP")
AddDropdown("ESP Range", { "All", "300 studs", "800 studs", "1500 studs" }, "All", function(v)
    if v == "All" then
        ESPConfig.MaxDistance = math.huge
    else
        ESPConfig.MaxDistance = tonumber(string.match(v, "%d+")) or 1500
    end
end, "ESP")

do
    local keys = {
        "AutoClaimIndex", "AutoUpgradeTraining", "AutoUpgradeTreadmill", "AutoTreadmill",
        "AntiBan", "AntiAFK", "GodMode", "Fly", "JumpInfinity", "AntiKnockDown",
        "Invisible", "AntiRagdoll", "AutoAntiSpeed", "AntiHit"
    }
    genv.LoopXCode_HardenFeatureKeys = keys
    local labels = {
        AutoClaimIndex = "Auto Claim Index", AutoUpgradeTraining = "Auto Upgrade",
        AutoUpgradeTreadmill = "Auto Upgrade Treadmill", AutoTreadmill = "Auto Treadmill",
        AntiBan = "Anti Ban", AntiAFK = "Anti AFK", GodMode = "God Mode",
        Fly = "Fly", JumpInfinity = "Jump Infinity", AntiKnockDown = "Anti Knock Down",
        Invisible = "Invisible", AntiRagdoll = "Anti Ragdoll", AutoAntiSpeed = "Auto Anti Speed",
        AntiHit = "Anti Hit"
    }
    genv.LoopXCode_HardenFeatureLabels = labels
    for _, key in ipairs(keys) do
        AddToggle(labels[key], genv.LoopXCode_HardenCfg[key] ~= false, function(v)
            genv.LoopXCode_HardenToggle(key, v)
        end, "Features")
    end
end

AddToggle("Save History", genv.LoopXCode_HardenCfg.SaveHistory ~= false, function(v)
    genv.LoopXCode_HardenCfg.SaveHistory = v
end, "Misc")
AddToggle("Save UI", true, function(v) genv.LoopXCode_HardenCfg.SaveUI = v end, "Misc")
AddToggle("Save Menu", true, function(v) genv.LoopXCode_HardenCfg.SaveMenu = v end, "Misc")
AddButton("Export Config", function()
    pcall(genv.LoopXCode_HardenSave)
    local ok, enc = pcall(function()
        return HttpService:JSONEncode({ StealCfg = StealCfg, HardenCfg = genv.LoopXCode_HardenCfg, ESPConfig = ESPConfig })
    end)
    if ok then pcall(function() setclipboard(enc) end) end
end, "Misc")

-- ---------------------------------------------------------------------
-- CONFIG BERNAMA — disimpan di satu attribute ReplicatedStorage.
-- Nama slot diambil dari input "Config Name" (default: default).
-- ---------------------------------------------------------------------
local function readConfigBank()
    local bank = {}
    pcall(function()
        local raw = ReplicatedStorage:GetAttribute(CONFIG_BANK_ATTR)
        if type(raw) == "string" and raw ~= "" then
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then bank = decoded end
        end
    end)
    return bank
end

local function saveNamedConfig(name)
    name = tostring(name or "")
    if name == "" then name = "default" end
    local harden = {}
    for _, key in ipairs(genv.LoopXCode_HardenFeatureKeys) do harden[key] = genv.LoopXCode_HardenCfg[key] end
    harden.SaveHistory = genv.LoopXCode_HardenCfg.SaveHistory
    harden.SaveUI = genv.LoopXCode_HardenCfg.SaveUI
    harden.SaveMenu = genv.LoopXCode_HardenCfg.SaveMenu

    local payload = {
        StealCfg = {
            Enabled = StealCfg.Enabled, RetryDelay = StealCfg.RetryDelay,
            Rarity = StealCfg.Rarity, Zone = StealCfg.Zone,
            CustomIncome = StealCfg.CustomIncome, Priority = StealCfg.Priority,
            ReelMode = StealCfg.ReelMode, WeakAllowed = StealCfg.WeakAllowed,
            WalkSpeed = StealCfg.WalkSpeed
        },
        SellCfg = {
            Enabled = SellCfg.Enabled, Interval = SellCfg.Interval,
            Rarities = jsonSafe(SellCfg.Rarities)
        },
        MiscCfg = jsonSafe(MiscCfg),
        HudCfg = jsonSafe(HudCfg),
        ESPConfig = jsonSafe(ESPConfig),
        HardenCfg = harden,
        LangCfg = { Language = LangCfg.Language },
        ConfigName = name
    }
    pcall(function()
        local ui = genv.LoopXCode_UIWindow
        if ui and ui.UIElements and ui.UIElements.Main then
            payload.UI = { Width = ui.UIElements.Main.AbsoluteSize.X, Height = ui.UIElements.Main.AbsoluteSize.Y }
        end
    end)

    local bank = readConfigBank()
    bank[name] = payload
    local ok = pcall(function()
        ReplicatedStorage:SetAttribute(CONFIG_BANK_ATTR, HttpService:JSONEncode(bank))
    end)
    pcall(genv.LoopXCode_HardenSave)
    return ok
end
genv.LoopXCode_SaveConfig = saveNamedConfig

local function setHandleValue(handle, value)
    setUIValue(handle, value)
end

local function loadNamedConfig(name)
    name = tostring(name or "")
    if name == "" then name = "default" end
    local bank = readConfigBank()
    local data = bank[name]
    if type(data) ~= "table" then return false end
    ConfigCfg.Name = tostring(data.ConfigName or name)
    setHandleValue(UIHandles["Config Name"], ConfigCfg.Name)

    local s = type(data.StealCfg) == "table" and data.StealCfg or {}
    for _, key in ipairs({ "Rarity", "Zone", "CustomIncome", "Priority", "ReelMode" }) do
        if s[key] ~= nil then StealCfg[key] = tostring(s[key]) end
    end
    if tonumber(s.RetryDelay) then StealCfg.RetryDelay = tonumber(s.RetryDelay) end
    if tonumber(s.WalkSpeed) then StealCfg.WalkSpeed = math.max(16, math.min(400, tonumber(s.WalkSpeed))) end
    StealCfg.Enabled = s.Enabled == true
    StealCfg.WeakAllowed = s.WeakAllowed == true
    StealCfg.Busy = false

    local sell = type(data.SellCfg) == "table" and data.SellCfg or {}
    SellCfg.Enabled = sell.Enabled == true
    if tonumber(sell.Interval) then SellCfg.Interval = math.max(1, tonumber(sell.Interval)) end
    SellCfg.Rarities = {}
    for r in pairs(genv.LoopXCode_NormalizeSellRarities(sell.Rarities)) do
        if type(r) == "string" then SellCfg.Rarities[#SellCfg.Rarities + 1] = r end
    end
    table.sort(SellCfg.Rarities)
    pcall(function() setHandleValue(UIHandles["Sell Rarities"], SellCfg.Rarities) end)

    local misc = type(data.MiscCfg) == "table" and data.MiscCfg or {}
    MiscCfg.MenuBackground = misc.MenuBackground ~= false
    MiscCfg.AutoEquipBestSpeed = misc.AutoEquipBestSpeed ~= false
    pcall(function() genv.LoopXCode_SetMenuBackground(MiscCfg.MenuBackground) end)
    pcall(function() genv.LoopXCode_SetAutoEquip(MiscCfg.AutoEquipBestSpeed, false) end)

    local h = type(data.HudCfg) == "table" and data.HudCfg or {}
    for _, key in ipairs({ "Width", "Height", "TextSize", "Gap", "Shadow", "ShadowOffset", "Font", "LogoFont", "X", "Y" }) do
        if h[key] ~= nil then HudCfg[key] = h[key] end
    end

    local e = type(data.ESPConfig) == "table" and data.ESPConfig or {}
    for _, key in ipairs({ "ESPPets", "ESPGuards", "ESPPlayers", "ShowInfo", "UpdateInterval", "ScanInterval" }) do
        if e[key] ~= nil then ESPConfig[key] = e[key] end
    end
    if e.MaxDistance ~= nil then
        ESPConfig.MaxDistance = (e.MaxDistance == "any") and math.huge or (tonumber(e.MaxDistance) or ESPConfig.MaxDistance)
    end
    if type(e.Styles) == "table" then
        for _, cat in ipairs({ "Any", "Player", "Pet", "Guard" }) do
            local src = e.Styles[cat]
            local dst = ESPConfig.Styles[cat]
            if type(src) == "table" and dst then
                for _, key in ipairs({ "Size", "Shadow", "ShadowOffset", "Font", "Color" }) do
                    if src[key] ~= nil then dst[key] = src[key] end
                end
            end
        end
    end
    local hd = type(data.HardenCfg) == "table" and data.HardenCfg or {}
    for _, key in ipairs(genv.LoopXCode_HardenFeatureKeys) do
        if hd[key] ~= nil then
            genv.LoopXCode_HardenCfg[key] = hd[key] == true
            pcall(function() genv.LoopXCode_HardenToggle(key, genv.LoopXCode_HardenCfg[key]) end)
            setHandleValue(UIHandles["Harden:" .. key], genv.LoopXCode_HardenCfg[key])
        end
    end
    for _, key in ipairs({ "SaveHistory", "SaveUI", "SaveMenu" }) do
        if hd[key] ~= nil then genv.LoopXCode_HardenCfg[key] = hd[key] == true end
    end
    if type(data.LangCfg) == "table" and data.LangCfg.Language then
        LangCfg.Language = (tostring(data.LangCfg.Language) == "Indonesia") and "Indonesia" or "English"
        setHandleValue(UIHandles["Language"], LangCfg.Language)
    end
    setHandleValue(UIHandles["Auto Catch"], StealCfg.Enabled)
    setHandleValue(UIHandles["Catch Reel"], StealCfg.ReelMode)
    setHandleValue(UIHandles["Catch Rarity (tier)"], StealCfg.Rarity)
    setHandleValue(UIHandles["Catch Zone"], StealCfg.Zone)
    setHandleValue(UIHandles["Min Income"], StealCfg.CustomIncome)
    setHandleValue(UIHandles["Walk Speed"], tostring(StealCfg.WalkSpeed))
    setHandleValue(UIHandles["Weak Lasso Catch"], StealCfg.WeakAllowed)
    setHandleValue(UIHandles["Auto Equip Best Speed"], MiscCfg.AutoEquipBestSpeed)
    setHandleValue(UIHandles["Auto Sell Pet"], SellCfg.Enabled)
    setHandleValue(UIHandles["Sell Interval"], tostring(SellCfg.Interval))
    setHandleValue(UIHandles["Menu Background"], MiscCfg.MenuBackground)
    setHandleValue(UIHandles["HUD Width"], tostring(HudCfg.Width))
    setHandleValue(UIHandles["HUD Height"], tostring(HudCfg.Height))
    setHandleValue(UIHandles["HUD Text Size"], tostring(HudCfg.TextSize))
    setHandleValue(UIHandles["HUD Gap"], tostring(HudCfg.Gap))
    setHandleValue(UIHandles["HUD Shadow"], tostring(HudCfg.Shadow))
    setHandleValue(UIHandles["HUD Shadow Offset"], tostring(HudCfg.ShadowOffset))
    setHandleValue(UIHandles["HUD Font"], tostring(HudCfg.Font))
    setHandleValue(UIHandles["Logo Font"], tostring(HudCfg.LogoFont))
    setHandleValue(UIHandles["ESP Range"], ESPConfig.MaxDistance == math.huge and "All" or tostring(ESPConfig.MaxDistance))
    for _, item in ipairs({
        { "Pet ESP", ESPConfig.ESPPets }, { "Guardian ESP", ESPConfig.ESPGuards },
        { "Player ESP", ESPConfig.ESPPlayers }, { "ESP Info", ESPConfig.ShowInfo },
        { "Save History", genv.LoopXCode_HardenCfg.SaveHistory }, { "Save UI", genv.LoopXCode_HardenCfg.SaveUI },
        { "Save Menu", genv.LoopXCode_HardenCfg.SaveMenu }
    }) do setHandleValue(UIHandles[item[1]], item[2]) end
    pcall(function() genv.LoopXCode_ApplyAutoSteal(StealCfg.Enabled) end)
    pcall(function() genv.LoopXCode_ApplyHudLayout() end)
    pcall(function() genv.LoopXCode_ApplyLanguage() end)
    pcall(function() genv.LoopXCode_ReapplyFonts() end)
    task.spawn(function() pcall(function() genv.LoopXCode_RefreshFinder() end) end)
    pcall(genv.LoopXCode_HardenSave)
    return true
end
genv.LoopXCode_LoadConfig = loadNamedConfig

-- =====================================================================
-- 6. WINDUI — library dimuat SEKALI, window dibuat SEKALI
-- =====================================================================
-- Fungsi terpisah bukan sekadar `do`: memberi scope lokal baru supaya jumlah
-- lokal di chunk utama nggak menembus batas register Luau (200).
local function buildWindUI()
    -- Buang semua ScreenGui WindUI sisa run lama SEBELUM load, supaya
    -- save-state tidak menempel ke ScreenGui mati dan CreateWindow tidak error.
    for _, o in ipairs(ParentGui:GetChildren()) do
        local n = tostring(o.Name or ""):lower()
        if o:IsA("ScreenGui") and (n == "windui" or n:find("windui/", 1, true)) then
            pcall(function() o:Destroy() end)
        end
    end

    local okLib, lib = pcall(function()
        local src = winduiSource
        if type(src) ~= "string" or src == "" then
            src = game:HttpGet(WINDUI_URL, true)
        end
        return loadstring(src)()
    end)

    if not (okLib and type(lib) == "table" and type(lib.CreateWindow) == "function") then
        closeLoadingOverlay()
        return
    end

    local UIWindow = lib:CreateWindow({
        Title = "LoopXCode",
        Icon = "crosshair",
        Author = "Welcome to my script enjoy for feature!",
        Size = UDim2.fromOffset(540, 480),
        MinSize = Vector2.new(540, 480),
        MaxSize = Vector2.new(700, 760),
        ToggleKey = Enum.KeyCode.RightShift,
        Transparent = true,
        Theme = "Dark",
        ShadowTransparency = 1,
        Resizable = true,
        SideBarWidth = 170,
        HideSearchBar = true,
        ScrollBarEnabled = false
    })

    -- WindUI Dark theme ngasih tiap toggle/dropdown/section bayangan kotak
    -- hitam (LabelBackgroundTransparency = 0.83). Sekarang kotaknya dipakai
    -- lagi tapi tipis, dan semua sudutnya di-radius lewat theme + RADIUS PASS
    -- di bawah, jadi elemen kelihatan seperti kartu rounded, bukan kotak.
    pcall(function()
        local themes = lib.Themes
        local dark = type(themes) == "table" and themes.Dark or nil
        if type(dark) == "table" then
            -- Latar elemen pakai warna card gelap, BUKAN hitam pekat.
            dark.LabelBackground = Color3.fromRGB(24, 28, 42)
            dark.LabelBackgroundTransparency = 0.5
            dark.CornerRadius = UDim.new(0, 12)
            dark.ElementCornerRadius = UDim.new(0, 10)
            dark.WindowCornerRadius = UDim.new(0, 14)
        end
        if type(lib.SetTheme) == "function" then lib:SetTheme("Dark") end
    end)

    UIWindow.Visible = true
    UIWindow.Closed = false
    if type(UIWindow.Open) == "function" then pcall(function() UIWindow:Open() end) end
    genv.LoopXCode_UIWindow = UIWindow

    local uiScreen
    pcall(function()
        if type(UIWindow.GetScreenGui) == "function" then uiScreen = UIWindow:GetScreenGui() end
    end)

    OnCleanup(function()
        StealCfg.Enabled = false
        StealCfg.Busy = false
        pcall(function()
            if type(UIWindow.Destroy) == "function" then UIWindow:Destroy() end
        end)
        pcall(function() if uiScreen then uiScreen:Destroy() end end)
        genv.LoopXCode_UIWindow = nil
    end)

    local function findWindRoot()
        if uiScreen and uiScreen.Parent then return uiScreen end
        return ParentGui:FindFirstChild("WindUI", true)
    end

    -- Logo kiri topbar: ganti icon crosshair bawaan WindUI dengan tulisan LXC.
    local function applyHeaderMark()
        pcall(function()
            local main = UIWindow.UIElements and UIWindow.UIElements.Main
            local left = main and main:FindFirstChild("Main")
                and main.Main:FindFirstChild("Topbar")
                and main.Main.Topbar:FindFirstChild("Left")
            if not left then return end
            local holder
            for _, o in ipairs(left:GetChildren()) do
                if o:IsA("Frame") and o.Name ~= "Title" then holder = o; break end
            end
            if not holder then return end
            for _, o in ipairs(holder:GetDescendants()) do
                if o:IsA("GuiObject") and o.Name ~= "LXCBrand" then o.Visible = false end
            end
            local mark = holder:FindFirstChild("LXCBrand")
            if not mark then
                mark = Instance.new("TextLabel")
                mark.Name = "LXCBrand"
                mark.BackgroundTransparency = 1
                mark.Size = UDim2.fromScale(1, 1)
                mark.TextXAlignment = Enum.TextXAlignment.Center
                mark.TextYAlignment = Enum.TextYAlignment.Center
                mark.TextColor3 = Color3.fromRGB(255, 255, 255)
                mark.Text = "LXC"
                mark.Active = false
                mark.Parent = holder
            end
            mark.Visible = true
            mark.FontFace = SafeFonts.Logo
            mark.TextSize = 10
        end)
    end

    local function applyLanguage()
        local root = findWindRoot()
        if not root then return end
        for _, o in ipairs(root:GetDescendants()) do
            if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
                local key = o:GetAttribute("LXC_LangKey")
                if not key then
                    local text = tostring(o.Text or "")
                    if LANG_TEXT[text] then
                        key = text
                        o:SetAttribute("LXC_LangKey", key)
                    end
                end
                if key then
                    pcall(function() o.Text = translateKey(key, LangCfg.Language) end)
                end
            end
        end
    end
    genv.LoopXCode_ApplyLanguage = applyLanguage

    -- WindUI bisa mengubah FontFace saat tab/option dipilih (misal selected
    -- jadi Medium). Pengawas ini mengembalikan semua teks menu ke Bold
    -- SEKETIKA FontFace berubah, termasuk elemen yang dibuat belakangan.
    local fontConns = {}
    local function sameFontFace(a, b)
        if not a or not b then return false end
        local ok, same = pcall(function()
            return a.Family == b.Family and a.Style == b.Style and a.Weight == b.Weight
        end)
        return ok and same == true
    end
    local function enforceBold(o)
        if not o then return end
        if not (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then return end
        if o.Name == "LXCBrand" then return end
        local text = tostring(o.Text or "")
        if not (#text > 1 or text:match("%w")) then return end
        local ok, face = pcall(function() return o.FontFace end)
        if ok and face and not sameFontFace(face, SafeFonts.Bold) then
            pcall(function() o.FontFace = SafeFonts.Bold end)
        end
    end
    local function watchBold(o)
        if not (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then return end
        enforceBold(o)
        fontConns[#fontConns + 1] = o:GetPropertyChangedSignal("FontFace"):Connect(function()
            enforceBold(o)
        end)
    end
    local function installFontGuard()
        local root = findWindRoot()
        if not root then return end
        for _, o in ipairs(root:GetDescendants()) do watchBold(o) end
        fontConns[#fontConns + 1] = root.DescendantAdded:Connect(function(o)
            task.spawn(function() watchBold(o) end)
        end)
    end
    OnCleanup(function()
        for _, c in ipairs(fontConns) do pcall(function() c:Disconnect() end) end
    end)

    -- WindUI nama ScreenGui-nya nggak selalu "WindUI", jadi pakai referensi
    -- langsung dari UIWindow bila ada. Bisa dipanggil ulang kapan saja.
    local function reapplyFonts()
        pcall(function()
            local root = findWindRoot()
            if root then applyFontTree(root) end
        end)
        applyHeaderMark()
    end
    genv.LoopXCode_ReapplyFonts = reapplyFonts
    reapplyFonts()

    -- WindUI dropdown default hitam. Samakan dengan wallpaper menu dan batasi
    -- tinggi list (terutama di phone) supaya 18 rarity nggak keluar layar.
    local function styleDropdown(dropdown)
        local ui = (type(dropdown) == "table") and dropdown.UIElements or nil
        if type(ui) ~= "table" then return end
        local cap = UserInputService.TouchEnabled and 220 or 300
        pcall(function()
            if typeof(ui.Menu) == "Instance" then
                ui.Menu.ImageColor3 = Color3.fromRGB(18, 22, 34)
                ui.Menu.ImageTransparency = 0.02
                local c = ui.Menu:FindFirstChildOfClass("UICorner")
                if c then
                    c.CornerRadius = UDim.new(0, 12)
                else
                    Instance.new("UICorner", ui.Menu).CornerRadius = UDim.new(0, 12)
                end
            end
            if typeof(ui.MenuCanvas) == "Instance" then
                for _, o in ipairs(ui.MenuCanvas:GetDescendants()) do
                    if o:IsA("UISizeConstraint") then
                        o.MaxSize = Vector2.new(math.huge, cap)
                    elseif o:IsA("ScrollingFrame") then
                        o.BackgroundTransparency = 1
                    elseif o:IsA("ImageButton") then
                        o.ImageColor3 = Color3.fromRGB(30, 34, 50)
                        if not o:FindFirstChildOfClass("UICorner") then
                            Instance.new("UICorner", o).CornerRadius = UDim.new(0, 8)
                        end
                    end
                end
            end
        end)
    end
    genv.LoopXCode_StyleDropdown = styleDropdown
    local function styleAllDropdowns()
        for _, handle in pairs(UIHandles) do
            if type(handle) == "table" and handle.__type == "Dropdown" then
                styleDropdown(handle)
            end
        end
    end
    genv.LoopXCode_StyleAllDropdowns = styleAllDropdowns

    -- ---------- Menu wallpaper: gradient + pattern, NO external asset ----------
    -- Wallpaper dipasang langsung di Background milik WindUI supaya ikut
    -- clip/tween window, termasuk saat fullscreen. Nggak pakai ScreenGui
    -- terpisah lagi (versi lama bikin wallpaper keluar dari frame).
    local menuBgController = nil
    local function installMenuBackground(windowObj)
        local windowMain = windowObj and windowObj.UIElements and windowObj.UIElements.Main or nil
        if not windowMain then return nil end
        local holder = windowMain:FindFirstChild("Background")
        if not holder then
            holder = Instance.new("Frame")
            holder.Name = "Background"
            holder.Size = UDim2.fromScale(1, 1)
            holder.BackgroundTransparency = 1
            holder.BorderSizePixel = 0
            holder.ZIndex = 0
            holder.Parent = windowMain
        end

        local old = holder:FindFirstChild("LXC_MenuBackground")
        if old then pcall(function() old:Destroy() end) end

        local frame = Instance.new("Frame")
        frame.Name = "LXC_MenuBackground"
        frame.Size = UDim2.fromScale(1, 1)
        frame.BorderSizePixel = 0
        -- Frame induk harus benar-benar transparan. Kalau ada warna + corner
        -- di sini, wallpaper kelihatan seperti kotak panel di dalam menu.
        frame.BackgroundTransparency = 1
        frame.ClipsDescendants = false
        frame.ZIndex = 0
        frame.Parent = holder

        local function fullLayer(name, color, z)
            local f = Instance.new("Frame")
            f.Name = name
            f.Size = UDim2.fromScale(1, 1)
            f.BorderSizePixel = 0
            f.BackgroundColor3 = color
            f.ZIndex = z or 0
            f.Parent = frame
            return f
        end

        -- Layer 1: gradient utama. Rotasi/dark-stop dibuang supaya nggak
        -- bikin bayangan di sudut kiri/kanan/bawah. Warna merata lembut.
        local base = fullLayer("Gradient", Color3.fromRGB(255, 255, 255), 0)
        local baseGrad = Instance.new("UIGradient")
        baseGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 24, 46)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(22, 18, 42)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 22, 40))
        })
        baseGrad.Rotation = 0
        baseGrad.Parent = base
        base.BackgroundTransparency = 0.28

        -- Layer 2: pattern garis diagonal + vertikal (faint, murah).
        local function addStripes(name, rotation, segments, opacity, z)
            local f = fullLayer(name, Color3.fromRGB(255, 255, 255), z)
            local pts = {}
            for i = 0, segments do
                local faint = (i % 2 == 0) and (1 - opacity) or 1
                pts[#pts + 1] = NumberSequenceKeypoint.new(i / segments, faint)
            end
            local g = Instance.new("UIGradient")
            g.Rotation = rotation
            g.Transparency = NumberSequence.new(pts)
            g.Parent = f
        end
        addStripes("PatternDiagonal", 45, 4, 0.045, 1)
        addStripes("PatternVertical", 0, 4, 0.025, 1)

        local controller = { Enabled = true, Busy = false }
        local alive = true

        local function sync()
            if not alive then return end
            frame.Visible = controller.Enabled and not controller.Busy
        end

        function controller:SetEnabled(value)
            controller.Enabled = value == true
            sync()
        end

        function controller:SetBusy(value)
            controller.Busy = value == true
            sync()
        end

        function controller:Destroy()
            alive = false
            pcall(function() frame:Destroy() end)
        end

        OnCleanup(function() controller:Destroy() end)
        sync()
        return controller
    end

    menuBgController = installMenuBackground(UIWindow)
    genv.LoopXCode_MenuBackground = menuBgController
    genv.LoopXCode_SetMenuBackground = function(v)
        if menuBgController then pcall(function() menuBgController:SetEnabled(v == true) end) end
        MiscCfg.MenuBackground = (v == true)
    end

    -- WindUI animasi fullscreen 0.45 detik. Matikan layer pattern selama
    -- tween supaya animasinya ringan, lalu hidupkan lagi setelah diam.
    pcall(function()
        local originalToggle = UIWindow.ToggleFullscreen
        if type(originalToggle) ~= "function" then return end
        UIWindow.ToggleFullscreen = function(...)
            if menuBgController then pcall(function() menuBgController:SetBusy(true) end) end
            local results = table.pack(originalToggle(...))
            task.delay(0.5, function()
                if menuBgController then pcall(function() menuBgController:SetBusy(false) end) end
            end)
            return table.unpack(results, 1, results.n)
        end
    end)

    AddToggle("Menu Background", MiscCfg.MenuBackground, function(v)
        MiscCfg.MenuBackground = (v == true)
        if menuBgController then pcall(function() menuBgController:SetEnabled(v) end) end
    end, "Misc")

    -- ---------- Tab: Controls ----------
    local Tab = UIWindow:Tab({ Title = "Controls", Icon = "sliders-horizontal" })

    -- Search semua fitur: menyembunyikan element menu yang tidak cocok.
    -- WindUI search bawaan cuma menyaring tab, jadi ini yang dipakai.
    local featureSearchText = ""
    local SEARCH_SECTIONS = {}
    local function trackSection(title, section)
        if section then SEARCH_SECTIONS[#SEARCH_SECTIONS + 1] = { Title = title, Handle = section } end
        return section
    end
    local function featureHay(title, name)
        local realName = tostring(name or ""):gsub("^Harden:", "")
        local cleanTitle = tostring(title or realName)
        return string.lower(cleanTitle .. " " .. realName .. " "
            .. tostring(translateKey(realName, "Indonesia")) .. " "
            .. tostring(translateKey(cleanTitle, "Indonesia")))
    end
    local function applyFeatureSearch()
        local q = string.lower(featureSearchText or "")
        for name, handle in pairs(UIHandles) do
            local realName = name:gsub("^Harden:", "")
            if not name:find("^Harden:") then
                local frame = nil
                pcall(function() frame = handle and handle.ElementFrame end)
                if typeof(frame) == "Instance" then
                    local title = tostring((type(handle) == "table" and handle.Title) or realName)
                    local hay = featureHay(title, realName)
                    pcall(function() frame.Visible = (q == "" or hay:find(q, 1, true) ~= nil) end)
                end
            end
        end
        -- Section header ikut tersaring. Kalau section nggak punya teks yang
        -- cocok, seluruh section disembunyikan biar hasil search kelihatan bersih.
        for _, entry in ipairs(SEARCH_SECTIONS) do
            local frame = nil
            pcall(function() frame = entry.Handle and entry.Handle.ElementFrame end)
            if typeof(frame) == "Instance" then
                local show = (q == "" or entry.Title == "Search Features")
                if not show and q ~= "" then
                    if featureHay(entry.Title, entry.Title):find(q, 1, true) then
                        show = true
                    else
                        pcall(function()
                            for _, o in ipairs(frame:GetDescendants()) do
                                if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
                                    local t = string.lower(tostring(o.Text or ""))
                                    if t ~= "" and t:find(q, 1, true) then show = true break end
                                end
                            end
                        end)
                    end
                end
                pcall(function() frame.Visible = show end)
            end
        end
    end
    genv.LoopXCode_ApplyFeatureSearch = applyFeatureSearch

    local SearchSection = trackSection("Search Features", Tab:Section({ Title = "Search Features", Opened = true }))
    SearchSection:Input({
        Title = "Search Features",
        Value = "",
        Placeholder = "Search all features",
        Callback = function(v)
            featureSearchText = tostring(v or "")
            applyFeatureSearch()
        end
    })
    pcall(function()
        local box = nil
        for _, o in ipairs(ParentGui:GetDescendants()) do
            if o:IsA("TextBox") and tostring(o.PlaceholderText) == "Search all features" then
                box = o
                break
            end
        end
        if box then
            box:GetPropertyChangedSignal("Text"):Connect(function()
                featureSearchText = tostring(box.Text or "")
                applyFeatureSearch()
            end)
        end
    end)

    local TargetSection = trackSection("Target", Tab:Section({ Title = "Target", Opened = true }))
    local TargetParagraph = TargetSection:Paragraph({ Title = "Current Target", Desc = "Target: none" })
    local StatusParagraph = TargetSection:Paragraph({ Title = "Activity", Desc = RuntimeStatus.Text })
    local StatsParagraph = TargetSection:Paragraph({
        Title = "Performance", Desc = "FPS: --  |  CPU: --%  |  GPU: -- ms  |  Ping: -- ms"
    })

    updateStealInfo = function(info)
        if not info then
            pcall(function() TargetParagraph:SetDesc("Target: none") end)
            return
        end
        local pet = tostring(info.name or "?")
        if info.display and info.display ~= "" and info.display ~= info.name then
            pet = string.format("%s (%s)", tostring(info.display), pet)
        end
        pcall(function()
            TargetParagraph:SetDesc(string.format(
                "Rarity: %s\nZone: %s\nPet: %s\nIncome: +%.1f/s\nWeight: %.1f kg",
                tostring(info.tier or info.rarity or "?"), tostring(info.zone or "?"),
                pet, tonumber(info.income) or 0, tonumber(info.kg) or 0
            ))
        end)
    end
    genv.LoopXCode_SetTargetText = updateStealInfo
    setStatusText = function(text)
        pcall(function() StatusParagraph:SetDesc(tostring(text)) end)
    end
    setStatus(RuntimeStatus.Mode, RuntimeStatus.Detail)

    local StealStatusSection = trackSection("Status Steal", Tab:Section({ Title = "Status Steal", Opened = true }))
    local StealStatusParagraph = StealStatusSection:Paragraph({
        Title = "Steal Progress", Desc = stealStatsPanel()
    })
    updateStealStatsText = function(line)
        pcall(function() StealStatusParagraph:SetDesc(tostring(line)) end)
    end
    refreshStealStats()

    -- FPS/CPU/GPU/Ping + status sekarang di dalam WindUI dan HUD atas.
    task.spawn(function()
        local frames, last = 0, os.clock()
        while StatsParagraph do
            frames += 1
            if os.clock() - last >= 0.5 then
                local fps = math.floor(frames / (os.clock() - last))
                frames, last = 0, os.clock()
                local _, cpu, gpu, ping = readPerf()
                pcall(function()
                    StatsParagraph:SetDesc(string.format(
                        "FPS: %d  |  CPU: %.0f%%  |  GPU: %.1f ms  |  Ping: %d ms",
                        fps, cpu, gpu, ping))
                end)
            end
            RunService.RenderStepped:Wait()
        end
    end)

    -- Section HUD Size (satu saja, jangan dobel).
    local HudSection = Tab:Section({ Title = "HUD Size", Opened = true })
    HudSection:Input({
        Title = "HUD Width",
        Value = tostring(HudCfg.Width),
        Placeholder = "720",
        Callback = function(v)
            HudCfg.Width = tonumber(v) or HudCfg.Width
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    HudSection:Input({
        Title = "HUD Height",
        Value = tostring(HudCfg.Height),
        Placeholder = "108",
        Callback = function(v)
            HudCfg.Height = tonumber(v) or HudCfg.Height
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    HudSection:Input({
        Title = "HUD Text Size",
        Value = tostring(HudCfg.TextSize),
        Placeholder = "18",
        Callback = function(v)
            HudCfg.TextSize = tonumber(v) or HudCfg.TextSize
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    HudSection:Input({
        Title = "HUD Gap",
        Value = tostring(HudCfg.Gap),
        Placeholder = "10",
        Callback = function(v)
            HudCfg.Gap = tonumber(v) or HudCfg.Gap
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    HudSection:Input({
        Title = "HUD Shadow",
        Value = tostring(HudCfg.Shadow),
        Placeholder = "0.55  (0 = off, 1 = solid)",
        Callback = function(v)
            HudCfg.Shadow = tonumber(v) or HudCfg.Shadow
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    HudSection:Input({
        Title = "HUD Shadow Offset",
        Value = tostring(HudCfg.ShadowOffset),
        Placeholder = "2",
        Callback = function(v)
            HudCfg.ShadowOffset = tonumber(v) or HudCfg.ShadowOffset
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    local hudFontDropdown = HudSection:Dropdown({
        Title = "HUD Font",
        Values = FONT_CHOICES,
        Value = tostring(HudCfg.Font or "Mono"),
        Callback = function(v)
            HudCfg.Font = tostring(v or "Mono")
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    UIHandles["HUD Font"] = hudFontDropdown
    local logoFontDropdown = HudSection:Dropdown({
        Title = "Logo Font",
        Values = FONT_CHOICES,
        Value = tostring(HudCfg.LogoFont or "Display"),
        Callback = function(v)
            HudCfg.LogoFont = tostring(v or "Display")
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    UIHandles["Logo Font"] = logoFontDropdown

    local CaptureSection = trackSection("Capture", Tab:Section({ Title = "Capture", Opened = true }))
    local autoCatchToggle = CaptureSection:Toggle({
        Title = "Auto Catch",
        Desc = "Approach, lasso, reel, and secure the pet",
        Value = StealCfg.Enabled,
        Callback = applyAutoSteal
    })
    UIHandles["Auto Catch"] = autoCatchToggle
    local catchReelDropdown = CaptureSection:Dropdown({
        Title = "Catch Reel",
        Values = { "Safe", "Fast" },
        Value = StealCfg.ReelMode,
        Callback = function(v) StealCfg.ReelMode = v end
    })
    UIHandles["Catch Reel"] = catchReelDropdown
    local rarityValues = { "Any" }
    for _, r in ipairs(ALL_RARITIES) do rarityValues[#rarityValues + 1] = r end
    local rarityDropdown = CaptureSection:Dropdown({
        Title = "Catch Rarity (tier)",
        Values = rarityValues,
        Value = StealCfg.Rarity,
        Callback = function(v) StealCfg.Rarity = tostring(v or "Any") end
    })
    UIHandles["Catch Rarity (tier)"] = rarityDropdown
    local zoneValues = { "Any" }
    for _, z in ipairs(ZONE_NAMES) do zoneValues[#zoneValues + 1] = z end
    local zoneDropdown = CaptureSection:Dropdown({
        Title = "Catch Zone",
        Values = zoneValues,
        Value = StealCfg.Zone,
        Callback = function(v) StealCfg.Zone = tostring(v or "Any") end
    })
    UIHandles["Catch Zone"] = zoneDropdown
    local incomeInput = CaptureSection:Input({
        Title = "Min Income",
        Value = StealCfg.CustomIncome,
        Placeholder = "5k / 30b / 50t  (blank = any)",
        Callback = function(v) StealCfg.CustomIncome = tostring(v or "") end
    })
    UIHandles["Min Income"] = incomeInput
    local walkSpeedInput = CaptureSection:Input({
        Title = "Walk Speed",
        Value = tostring(StealCfg.WalkSpeed),
        Placeholder = "400",
        Desc = "Walk speed used by Auto Catch in studs/sec (16-400)",
        Callback = function(v)
            local n = tonumber(v)
            if not n then n = configuredWalkSpeed(400) end
            n = math.max(16, math.min(400, n))
            StealCfg.WalkSpeed = n
        end
    })
    UIHandles["Walk Speed"] = walkSpeedInput
    -- WindUI Input cuma fire callback pas Enter/FocusLost. Pasang listener langsung
    -- di TextBox supaya filter ngefek seketika pas daddy ngetik.
    pcall(function()
        local box = nil
        for _, o in ipairs(gethui():GetDescendants()) do
            if o:IsA("TextBox") and tostring(o.PlaceholderText):find("5k", 1, true) then
                box = o
                break
            end
        end
        if box then
            box:GetPropertyChangedSignal("Text"):Connect(function()
                StealCfg.CustomIncome = tostring(box.Text or "")
            end)
        end
        local speedBox = nil
        for _, o in ipairs(gethui():GetDescendants()) do
            if o:IsA("TextBox") and (tostring(o.PlaceholderText) == "400" or tostring(o.Text) == tostring(StealCfg.WalkSpeed)) then
                local okTitle, title = pcall(function()
                    local p = o.Parent
                    for _ = 1, 6 do
                        if not p then break end
                        for _, t in ipairs(p:GetChildren()) do
                            if t:IsA("TextLabel") and tostring(t.Text):find("Walk Speed", 1, true) then return true end
                        end
                        p = p.Parent
                    end
                    return false
                end)
                if okTitle and title then speedBox = o break end
            end
        end
        if speedBox then
            speedBox:GetPropertyChangedSignal("Text"):Connect(function()
                local n = tonumber(speedBox.Text)
                if not n then return end
                n = math.max(16, math.min(400, n))
                StealCfg.WalkSpeed = n
            end)
        end
    end)
    local function applyAutoEquip(v, spawnAction)
        v = (v == true)
        -- Kalau auto treadmill hidup, auto naik pet harus mati. Nyalain manual
        -- Auto Equip akan mematikan Auto Treadmill dulu.
        if v and genv.LoopXCode_HardenCfg.AutoTreadmill then
            pcall(function() genv.LoopXCode_HardenToggle("AutoTreadmill", false) end)
            return
        end
        genv.LoopXCode_AutoEquipV2 = v
        genv.LoopXCode_AutoEquipSpeed = false -- jangan bangunkan instance lama
        if spawnAction ~= false then
            if v then task.spawn(equipBestSpeed) else task.spawn(dismountPet) end
        end
    end

    local autoEquipToggle = CaptureSection:Toggle({
        Title = "Auto Equip Best Speed",
        Desc = "ON = ride the fastest pet / OFF = dismount (auto off when Auto Treadmill is ON)",
        Value = true,
        Callback = function(v) applyAutoEquip(v, true) end
    })
    genv.LoopXCode_AutoEquipToggle = autoEquipToggle
    genv.LoopXCode_SetAutoEquip = function(v, spawnAction)
        v = (v == true)
        local didSet = false
        pcall(function()
            if autoEquipToggle and type(autoEquipToggle.Set) == "function" then
                autoEquipToggle:Set(v)
                didSet = true
            elseif autoEquipToggle and type(autoEquipToggle.SetValue) == "function" then
                autoEquipToggle:SetValue(v)
                didSet = true
            end
        end)
        if not didSet then applyAutoEquip(v, spawnAction) end
    end
    task.spawn(equipBestSpeed)

    -- ---------- Experimen: paksa tangkap walau lasso lemah ----------
    local ExperimentSection = trackSection("Experimen", Tab:Section({ Title = "Experimen", Opened = true }))
    local weakCatchToggle = ExperimentSection:Toggle({
        Title = "Weak Lasso Catch",
        Desc = "Catch weak-lasso pets; still walks back to the safe zone",
        Value = StealCfg.WeakAllowed,
        Callback = function(v) StealCfg.WeakAllowed = (v == true) end
    })
    UIHandles["Weak Lasso Catch"] = weakCatchToggle

    -- ---------- Auto Sell Pet ----------
    local SellSection = trackSection("Auto Sell", Tab:Section({ Title = "Auto Sell", Opened = true }))
    local autoSellToggle = SellSection:Toggle({
        Title = "Auto Sell Pet",
        Desc = "Sell every selected rarity automatically",
        Value = SellCfg.Enabled,
        Callback = function(v) SellCfg.Enabled = (v == true) end
    })
    UIHandles["Auto Sell Pet"] = autoSellToggle
    local sellIntervalInput = SellSection:Input({
        Title = "Sell Interval",
        Value = tostring(SellCfg.Interval),
        Placeholder = "5",
        Callback = function(v)
            SellCfg.Interval = math.max(1, tonumber(v) or SellCfg.Interval)
        end
    })
    UIHandles["Sell Interval"] = sellIntervalInput
    local sellRarityDropdown = SellSection:Dropdown({
        Title = "Sell Rarities",
        Desc = "Select multiple rarities to sell",
        Values = ALL_RARITIES,
        Value = SellCfg.Rarities,
        Multi = true,
        Callback = function(v)
            local selected = genv.LoopXCode_NormalizeSellRarities(v)
            table.clear(SellCfg.Rarities)
            for r in pairs(selected) do
                if type(r) == "string" then SellCfg.Rarities[#SellCfg.Rarities + 1] = r end
            end
            table.sort(SellCfg.Rarities)
        end
    })
    UIHandles["Sell Rarities"] = sellRarityDropdown
    SellSection:Button({
        Title = "Sell Now",
        Desc = "Sell selected rarities once",
        Callback = function() task.spawn(function() genv.LoopXCode_SellPetsNow() end) end
    })

    -- ---------- Tab: Finder Pet ----------
    -- Menampilkan semua pet dari game: nama, income, rarity/tier, biome (dimap mana), dan gambar pet.
    local FinderTab = UIWindow:Tab({ Title = "Finder", Icon = "search" })
    local FinderSection = trackSection("Pet Finder", FinderTab:Section({ Title = "Pet Finder", Opened = true }))

    local FinderState = { Query = "", Biome = "All", Limit = math.huge }
    genv.LoopXCode_FinderState = FinderState

    local function buildBiomeList()
        local list = { "All" }
        local seen = { All = true }
        pcall(function()
            for _, pet in ipairs(PC.Pets or {}) do
                local b = tostring(pet and pet.Biome or "")
                if b ~= "" and not seen[b] then seen[b] = true list[#list + 1] = b end
            end
        end)
        table.sort(list, function(a, b)
            if a == "All" then return true end
            if b == "All" then return false end
            return a < b
        end)
        return list
    end

    FinderSection:Input({
        Title = "Find Pet",
        Value = "",
        Placeholder = "Pet name, e.g. Bunny",
        Callback = function(v) FinderState.Query = tostring(v or "") end
    })
    FinderSection:Dropdown({
        Title = "Biome / Map",
        Values = buildBiomeList(),
        Value = "All",
        Callback = function(v) FinderState.Biome = tostring(v or "All") end
    })

    local function fmtIncome(n)
        n = tonumber(n) or 0
        if n >= 1e12 then return string.format("%.2ft", n / 1e12) end
        if n >= 1e9 then return string.format("%.2fb", n / 1e9) end
        if n >= 1e6 then return string.format("%.2fm", n / 1e6) end
        if n >= 1e3 then return string.format("%.2fk", n / 1e3) end
        return string.format("%.1f", n)
    end

    local function humanize(name)
        return (tostring(name or ""):gsub("([a-z])([A-Z])", "%1 %2"))
    end

    local finderParagraphs = {}
    local function clearFinder()
        for _, p in ipairs(finderParagraphs) do pcall(function() p:Destroy() end) end
        table.clear(finderParagraphs)
    end

    local function refreshFinder()
        clearFinder()
        local q = string.lower(FinderState.Query or "")
        local biome = FinderState.Biome or "All"
        local shown = 0
        local PI = nil
        pcall(function() PI = require(ModuleFolder:WaitForChild("PetIcons")) end)
        for _, pet in ipairs(PC.Pets or {}) do
            if shown >= (FinderState.Limit or 70) then break end
            if type(pet) == "table" and pet.Name then
                local name = tostring(pet.Name)
                local display = tostring(pet.Display or humanize(name))
                local petBiome = tostring(pet.Biome or "?")
                local matchQ = (q == "" or string.lower(name):find(q, 1, true) ~= nil
                    or string.lower(display):find(q, 1, true) ~= nil)
                if (biome == "All" or petBiome == biome) and matchQ then
                    local cfg = petCfg(name)
                    local income = petIncome(cfg)
                    local tier = tostring(pet.Tier or (cfg and cfg.Tier) or "Common")
                    local rarity = tostring(pet.Rarity or "Common")
                    local icon = nil
                    pcall(function()
                        if PI then icon = (type(PI.Get) == "function" and PI.Get(name)) or PI[name] end
                    end)
                    local para = FinderSection:Paragraph({
                        Title = string.format("%s  |  %s/s", display, fmtIncome(income)),
                        Desc = string.format("Rarity: %s  |  Tier: %s  |  Map/Biome: %s  |  Speed: %s",
                            rarity, tier, petBiome, tostring(pet.Speed or (cfg and cfg.Speed) or "-")),
                        Image = icon
                    })
                    if para then
                        finderParagraphs[#finderParagraphs + 1] = para
                        pcall(function()
                            if icon and type(para.SetImage) == "function" then para:SetImage(icon) end
                        end)
                    end
                    local stealBtn = FinderSection:Button({
                        Title = "STEAL | " .. display,
                        Desc = string.format("Tier %s  |  %s  |  manual steal (lasso still checked)",
                            tier, petBiome),
                        Callback = function()
                            task.spawn(function() startManualSteal(name) end)
                        end
                    })
                    if stealBtn then finderParagraphs[#finderParagraphs + 1] = stealBtn end
                    shown += 1
                end
            end
        end
        reapplyFonts()
    end
    FinderSection:Button({
        Title = "Refresh Finder",
        Callback = function() task.spawn(refreshFinder) end
    })
    genv.LoopXCode_RefreshFinder = refreshFinder
    refreshFinder()

    -- ---------- Tab: Settings ----------
    local SettingsTab = UIWindow:Tab({ Title = "Settings", Icon = "settings-2" })
    local Sections = {
        Features = trackSection("Features", SettingsTab:Section({ Title = "Features", Opened = true })),
        ESP = trackSection("ESP", SettingsTab:Section({ Title = "ESP", Opened = true })),
        ESPStyle = trackSection("ESP Style", SettingsTab:Section({ Title = "ESP Style", Opened = true })),
        Misc = trackSection("Misc", SettingsTab:Section({ Title = "Misc", Opened = true }))
    }
    Sections.Misc:Button({
        Title = "Apply Safe Fonts",
        Desc = "Force all hub text to Gotham (clean and readable)",
        Callback = function() reapplyFonts() end
    })
    local languageDropdown = Sections.Misc:Dropdown({
        Title = "Language",
        Values = { "English", "Indonesia" },
        Value = LangCfg.Language,
        Callback = function(v)
            LangCfg.Language = (tostring(v) == "Indonesia") and "Indonesia" or "English"
            applyLanguage()
            reapplyFonts()
        end
    })
    UIHandles["Language"] = languageDropdown

    local configNameInput = Sections.Misc:Input({
        Title = "Config Name",
        Value = ConfigCfg.Name,
        Placeholder = "default",
        Callback = function(v)
            local n = tostring(v or "")
            ConfigCfg.Name = (n == "") and "default" or n
        end
    })
    UIHandles["Config Name"] = configNameInput
    Sections.Misc:Button({
        Title = "Save Config",
        Desc = "Save current settings under Config Name",
        Callback = function() saveNamedConfig(ConfigCfg.Name) end
    })
    Sections.Misc:Button({
        Title = "Load Config",
        Desc = "Load settings from Config Name",
        Callback = function() loadNamedConfig(ConfigCfg.Name) end
    })

    for _, item in ipairs(UIItems) do
        local target = Sections[item.Group] or Sections.Misc
        local handle = nil
        if item.Kind == "Toggle" then
            handle = target:Toggle({ Title = item.Name, Value = item.Default, Callback = item.Callback })
        elseif item.Kind == "Dropdown" then
            handle = target:Dropdown({ Title = item.Name, Values = item.Values, Value = item.Default, Callback = item.Callback })
        elseif item.Kind == "Button" then
            handle = target:Button({ Title = item.Name, Callback = item.Callback })
        end
        if handle then UIHandles[item.Name] = handle end
    end
    for _, key in ipairs(genv.LoopXCode_HardenFeatureKeys) do
        UIHandles["Harden:" .. key] = UIHandles[genv.LoopXCode_HardenFeatureLabels[key]]
    end

    -- ESP style: size + warna + shadow + font diatur sendiri-sendiri per kategori.
    -- "Any" = shortcut set Player, Pet, dan Guard sekaligus.
    addEspStyleInputs(Sections.ESPStyle, "Any", "Any")
    addEspStyleInputs(Sections.ESPStyle, "Player", "Player")
    addEspStyleInputs(Sections.ESPStyle, "Pet", "Pet")
    addEspStyleInputs(Sections.ESPStyle, "Guard", "Guard")

    -- Semua teks WindUI ikut font helper (logo/HUD diatur sendiri di bawah).
    reapplyFonts()

    -- ---------- Floating ICONLXC-style logo + HUD (SATU button saja) ----------
    -- Template ICONLXC: kotak #0e0e12, corner 14, stroke #3a3a44, accent pill.
    -- Logo tetap solid seperti template; yang transparan dan diperbesar adalah
    -- HUD FPS/CPU/GPU/status. Logo pakai FredokaOne + outline hitam seperti template.
    -- Fungsi terpisah supaya register lokal WindUI induk nggak jebol.
    local function buildFloatingLogo()
    local FloatGui = Instance.new("ScreenGui")
    FloatGui.Name = "LXC_ToggleGui"
    FloatGui.ResetOnSpawn = false
    FloatGui.DisplayOrder = 50
    FloatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    FloatGui.Enabled = true
    FloatGui.Parent = ParentGui

    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Name = "LOOPXCODE_FloatingToggle"
    FloatBtn.Size = UDim2.new(0, 56, 0, 56)
    FloatBtn.Position = UDim2.new(0, 24, 0.5, -28)
    FloatBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    FloatBtn.BackgroundTransparency = 0
    FloatBtn.AutoButtonColor = false
    FloatBtn.Text = ""
    FloatBtn.ClipsDescendants = false
    FloatBtn.Parent = FloatGui

    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(0, 16)
    FloatCorner.Parent = FloatBtn

    local FloatStroke = AddStroke(FloatBtn, 1.5, Color3.fromRGB(58, 58, 68), 0)

    -- Teks utama persis template ICONLXC: kotak 56x56, FredokaOne, outline hitam.
    local LogoLabel = Instance.new("TextLabel")
    LogoLabel.Name = "LogoLabel"
    LogoLabel.Size = UDim2.new(1, 0, 0, 22)
    LogoLabel.Position = UDim2.new(0, 0, 0.5, -13)
    LogoLabel.BackgroundTransparency = 1
    LogoLabel.Font = Enum.Font.FredokaOne
    LogoLabel.TextSize = 15
    LogoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    LogoLabel.Text = "LXC"
    LogoLabel.Active = false
    LogoLabel.Parent = FloatBtn
    AddTextStroke(LogoLabel, 1.2)

    local AccentPill = Instance.new("Frame")
    AccentPill.Name = "AccentPill"
    AccentPill.Size = UDim2.new(0, 20, 0, 3)
    AccentPill.Position = UDim2.new(0.5, -10, 0.5, 11)
    AccentPill.BackgroundColor3 = Color3.fromRGB(82, 82, 91)
    AccentPill.BorderSizePixel = 0
    AccentPill.Active = false
    AccentPill.Parent = FloatBtn
    Instance.new("UICorner", AccentPill).CornerRadius = UDim.new(1, 0)

    local lastPerf = { fps = 0, cpu = 0, gpu = 0, ping = 0 }
    local function hudRichText()
        return string.format(
            '<font color="#7EE8FF">%s</font>\n' ..
            '<font color="#5CFF8D">FPS %d</font>  |  ' ..
            '<font color="#FFD15C">CPU %.0f%%</font>  |  ' ..
            '<font color="#C08CFF">GPU %.1f ms</font>  |  ' ..
            '<font color="#6FB6FF">Ping %d ms</font>\n' ..
            '<font color="#D6D6E0">%s</font>',
            tostring(RuntimeStatus.Text), lastPerf.fps, lastPerf.cpu,
            lastPerf.gpu, lastPerf.ping, stealStatsLine())
    end

    -- Shadow = duplicate polos hitam di belakang teks warna (RichText nggak
    -- bisa di-stroke warna hitam tanpa merusak warna per bagian).
    local function hudPlainText()
        return string.format("%s\nFPS %d  |  CPU %.0f%%  |  GPU %.1f ms  |  Ping %d ms\n%s",
            tostring(RuntimeStatus.Text), lastPerf.fps, lastPerf.cpu,
            lastPerf.gpu, lastPerf.ping, stealStatsLine())
    end

    local HudShadow = Instance.new("TextLabel")
    HudShadow.Name = "HUDShadow"
    HudShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    HudShadow.BackgroundTransparency = 0.55
    HudShadow.Font = Enum.Font.GothamBold
    HudShadow.TextColor3 = Color3.fromRGB(0, 0, 0)
    HudShadow.TextXAlignment = Enum.TextXAlignment.Center
    HudShadow.TextYAlignment = Enum.TextYAlignment.Center
    HudShadow.Text = hudPlainText()
    HudShadow.Active = false
    HudShadow.Parent = FloatGui
    Instance.new("UICorner", HudShadow).CornerRadius = UDim.new(0, 14)

    local FloatStatus = Instance.new("TextLabel")
    FloatStatus.Name = "HUD"
    FloatStatus.Size = UDim2.new(0, HudCfg.Width, 0, HudCfg.Height)
    FloatStatus.Position = UDim2.new(0.5, -HudCfg.Width / 2, 0, HudCfg.Gap)
    FloatStatus.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    FloatStatus.BackgroundTransparency = 0.72
    FloatStatus.Font = Enum.Font.GothamBold
    FloatStatus.TextSize = HudCfg.TextSize
    FloatStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatStatus.TextXAlignment = Enum.TextXAlignment.Center
    FloatStatus.TextYAlignment = Enum.TextYAlignment.Center
    FloatStatus.RichText = true
    FloatStatus.Text = hudRichText()
    FloatStatus.Active = true
    FloatStatus.Parent = FloatGui
    Instance.new("UICorner", FloatStatus).CornerRadius = UDim.new(0, 14)

    local function clampHudPos(pos)
        local w = math.max(1, math.floor(tonumber(HudCfg.Width) or 720))
        local h = math.max(1, math.floor(tonumber(HudCfg.Height) or 108))
        local gap = math.max(0, math.floor(tonumber(HudCfg.Gap) or 10))
        local sx, sy = FloatGui.AbsoluteSize.X, FloatGui.AbsoluteSize.Y
        if sx <= 0 or sy <= 0 then return pos end
        local left = math.clamp(pos.X.Offset + pos.X.Scale * sx, 0, math.max(0, sx - w))
        local top = math.clamp(pos.Y.Offset + pos.Y.Scale * sy, 0, math.max(0, sy - h))
        HudCfg.X = left - sx / 2 + w / 2
        HudCfg.Y = top - gap
        local finalPos = UDim2.new(0.5, left - sx / 2, 0, top)
        -- Shadow ikut HUD saat drag, bukan cuma saat applyHudLayout dipanggil.
        if HudShadow then
            local so = math.clamp(math.floor(tonumber(HudCfg.ShadowOffset) or 2), 0, 12)
            pcall(function()
                HudShadow.Position = UDim2.new(finalPos.X.Scale, finalPos.X.Offset + so, finalPos.Y.Scale, finalPos.Y.Offset + so)
            end)
        end
        return finalPos
    end

    applyHudLayout = function()
        -- "any": bebas angka berapa pun; dibulatkan dan dijaga tetap positif.
        local w = math.max(1, math.floor(tonumber(HudCfg.Width) or 720))
        local h = math.max(1, math.floor(tonumber(HudCfg.Height) or 108))
        local ts = math.max(1, math.floor(tonumber(HudCfg.TextSize) or 18))
        local gap = math.max(0, math.floor(tonumber(HudCfg.Gap) or 10))
        local sh = math.clamp(tonumber(HudCfg.Shadow) or 0.55, 0, 1)
        local so = math.clamp(math.floor(tonumber(HudCfg.ShadowOffset) or 2), 0, 12)
        HudCfg.Width, HudCfg.Height, HudCfg.TextSize, HudCfg.Gap = w, h, ts, gap
        HudCfg.Shadow, HudCfg.ShadowOffset = sh, so
        HudCfg.X, HudCfg.Y = tonumber(HudCfg.X) or 0, tonumber(HudCfg.Y) or 0
        pcall(function()
            local hudFace = fontFaceByName(HudCfg.Font)
            local logoFace = fontFaceByName(HudCfg.LogoFont)
            applyFont(FloatStatus, hudFace)
            applyFont(HudShadow, hudFace)
            applyFont(LogoLabel, logoFace)
            local pos = clampHudPos(UDim2.new(0.5, -w / 2 + HudCfg.X, 0, gap + HudCfg.Y))
            FloatStatus.Size = UDim2.new(0, w, 0, h)
            FloatStatus.Position = pos
            FloatStatus.TextSize = ts
            HudShadow.Size = UDim2.new(0, w, 0, h)
            HudShadow.Position = UDim2.new(pos.X.Scale, pos.X.Offset + so, pos.Y.Scale, pos.Y.Offset + so)
            HudShadow.TextSize = ts
            HudShadow.TextTransparency = 1 - sh
            HudShadow.Visible = sh > 0
        end)
    end
    applyHudLayout()

    updateHudText = function()
        pcall(function()
            FloatStatus.Text = hudRichText()
            HudShadow.Text = hudPlainText()
        end)
    end
    setStatus(RuntimeStatus.Mode, RuntimeStatus.Detail)

    local function pulseAccent()
        pcall(function()
            TweenService:Create(AccentPill, TweenInfo.new(0.14), {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            }):Play()
            TweenService:Create(FloatStroke, TweenInfo.new(0.14), {
                Color = Color3.fromRGB(255, 255, 255)
            }):Play()
            task.delay(0.2, function()
                pcall(function()
                    TweenService:Create(AccentPill, TweenInfo.new(0.2), {
                        BackgroundColor3 = Color3.fromRGB(82, 82, 91)
                    }):Play()
                    TweenService:Create(FloatStroke, TweenInfo.new(0.2), {
                        Color = Color3.fromRGB(58, 58, 68)
                    }):Play()
                end)
            end)
        end)
    end

    local function openWindow()
        pulseAccent()
        pcall(function()
            if UIWindow.Closed then UIWindow:Open() end
        end)
    end
    MakeDraggable(FloatBtn, FloatBtn, openWindow)
    -- HUD transparan bisa digeser, tapi selalu dijaga di dalam layar.
    MakeDraggable(FloatStatus, FloatStatus, nil, clampHudPos, function()
        pcall(genv.LoopXCode_HardenSave)
    end)

    task.spawn(function()
        local frames, last = 0, os.clock()
        while FloatStatus and FloatStatus.Parent and genv.LoopXCode_HardenAlive() do
            frames += 1
            if os.clock() - last >= 0.5 then
                local fps = math.floor(frames / (os.clock() - last))
                frames, last = 0, os.clock()
                local _, cpu, gpu, ping = readPerf()
                lastPerf.fps = fps
                lastPerf.cpu = cpu
                lastPerf.gpu = gpu
                lastPerf.ping = ping
                pcall(function()
                    FloatStatus.Text = hudRichText()
                    HudShadow.Text = hudPlainText()
                end)
            end
            RunService.RenderStepped:Wait()
        end
    end)

    OnCleanup(function() pcall(function() FloatGui:Destroy() end) end)
    end
    -- WindUI bisa menutup window saat state lama dipulihkan. Buka lagi di akhir
    -- setelah semua tab jadi, lalu paksa font + wallpaper sinkron.
    pcall(function()
        UIWindow.Closed = false
        if type(UIWindow.Open) == "function" then UIWindow:Open() end
    end)
    local okTail, tailErr = pcall(function()
        reapplyFonts()
        applyLanguage()
        installFontGuard()
        styleAllDropdowns()
        applyFeatureSearch()
        if menuBgController then pcall(function() menuBgController:SetEnabled(true) end) end
        buildFloatingLogo()
        closeLoadingOverlay()
    end)
    if not okTail then genv.LoopXCode_TailError = tostring(tailErr) end
end
buildWindUI()
-- =====================================================================
-- 7. RADIUS PASS — radius semua sisi, bayangan kotak hitam dihapus
-- =====================================================================
-- WindUI menaruh frame bayangan kotak hitam ("Shadow") di belakang tiap
-- elemen. Radius di elemen jadi nggak ada artinya karena sudut bayangannya
-- tetap kotak dan nyembul keluar. Pass ini: (a) mematikan semua objek bayangan,
-- (b) memberi UICorner ke semua container/elemen/menu, (c) mengganti kedalaman
-- visual dengan latar card gelap + garis tepi tipis yang ikut radius.
do
    local RADIUS_WINDOW = UDim.new(0, 16)
    local RADIUS_PANEL = UDim.new(0, 12)
    local RADIUS_ELEMENT = UDim.new(0, 10)
    local RADIUS_PILL = UDim.new(1, 0)
    local CARD_COLOR = Color3.fromRGB(24, 28, 42)
    local CARD_ALPHA = 0.5
    local STROKE_COLOR = Color3.fromRGB(46, 52, 72)
    local STROKE_ALPHA = 0.45

    local function ensureCorner(obj, radius)
        if not obj or not obj:IsA("GuiObject") then return nil end
        local existing = obj:FindFirstChildOfClass("UICorner")
        if existing then
            pcall(function() existing.CornerRadius = radius end)
            return existing
        end
        local ok, corner = pcall(function()
            local c = Instance.new("UICorner")
            c.CornerRadius = radius
            c.Parent = obj
            return c
        end)
        if ok then return corner end
        return nil
    end

    local function radiusFor(obj)
        local name = string.lower(tostring(obj.Name or ""))
        if name:find("scrollbar", 1, true) or name:find("pill", 1, true)
            or name == "bar" or name == "thumb" then
            return RADIUS_PILL
        end
        local h = obj.AbsoluteSize.Y
        if h >= 120 then return RADIUS_WINDOW end
        if h >= 44 then return RADIUS_PANEL end
        return RADIUS_ELEMENT
    end

    local function isNearBlack(c)
        return c.R < 0.14 and c.G < 0.14 and c.B < 0.14
    end

    -- Bayangan kotak WindUI dimatikan total: Visible = false + latar transparan.
    -- Nama apa pun yang mengandung "shadow" kena, termasuk DropShadow/ElementShadow.
    local function killShadow(obj)
        if not obj:IsA("GuiObject") then return false end
        if string.lower(tostring(obj.Name or "")):find("shadow", 1, true) then
            pcall(function()
                obj.Visible = false
                obj.BackgroundTransparency = 1
            end)
            return true
        end
        return false
    end

    local function polish(obj)
        if not obj or not obj:IsA("GuiObject") then return end
        if obj.Name == "HUD" or obj.Name == "HUDShadow" then return end -- diurus terpisah
        if killShadow(obj) then return end

        if obj:IsA("ScrollingFrame") then
            ensureCorner(obj, RADIUS_PANEL)
            return
        end

        local isBox = obj:IsA("Frame") or obj:IsA("TextButton")
            or obj:IsA("ImageLabel") or obj:IsA("ImageButton")
        local isText = obj:IsA("TextLabel") or obj:IsA("TextBox")
        if not (isBox or isText) then return end

        ensureCorner(obj, radiusFor(obj))

        -- Hanya baris elemen yang dikasih latar + tepi. TextLabel dibiarkan
        -- transparan supaya nggak muncul kotak ganda di dalam baris.
        if not isBox then return end
        local size = obj.AbsoluteSize
        if size.Y < 22 or size.Y > 60 or size.X < 90 then return end

        if obj.BackgroundTransparency > 0.95 then
            pcall(function()
                obj.BackgroundColor3 = CARD_COLOR
                obj.BackgroundTransparency = CARD_ALPHA
            end)
        elseif isNearBlack(obj.BackgroundColor3) then
            -- Hitam pekat diganti slate gelap, jadi nggak kelihatan kotak hitam.
            pcall(function() obj.BackgroundColor3 = CARD_COLOR end)
        end

        -- Pengganti bayangan: garis tepi tipis yang ikut radius.
        if not obj:FindFirstChildOfClass("UIStroke") then
            pcall(function()
                local s = Instance.new("UIStroke")
                s.Thickness = 1
                s.Color = STROKE_COLOR
                s.Transparency = STROKE_ALPHA
                s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                s.Parent = obj
            end)
        end
    end

    local root = nil
    pcall(function()
        local win = genv.LoopXCode_UIWindow
        root = win and win.UIElements and win.UIElements.Main or nil
    end)
    if root then
        ensureCorner(root, RADIUS_WINDOW)
        for _, o in ipairs(root:GetDescendants()) do polish(o) end
        -- Element baru (hasil refresh finder, dropdown dibuka, config load)
        -- langsung diproses juga, jadi nggak ada yang balik kotak/hitam.
        pcall(function()
            root.DescendantAdded:Connect(function(o)
                task.spawn(function() polish(o) end)
            end)
        end)
    end

    -- Floating logo + HUD: bayangan kotak diganti latar tipis beradius.
    pcall(function()
        local floatGui = ParentGui:FindFirstChild("LXC_ToggleGui")
        if not floatGui then return end
        for _, o in ipairs(floatGui:GetDescendants()) do
            if o:IsA("GuiObject") and string.lower(tostring(o.Name or "")):find("shadow", 1, true) then
                pcall(function() o.Visible = false end)
            end
        end
        local btn = floatGui:FindFirstChild("LOOPXCODE_FloatingToggle")
        if btn then ensureCorner(btn, RADIUS_WINDOW) end
        local hud = floatGui:FindFirstChild("HUD")
        if hud then
            ensureCorner(hud, UDim.new(0, 14))
            pcall(function()
                hud.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
                hud.BackgroundTransparency = 0.62
            end)
        end
        local shadow = floatGui:FindFirstChild("HUDShadow")
        if shadow then
            ensureCorner(shadow, UDim.new(0, 14))
            pcall(function()
                shadow.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
                shadow.BackgroundTransparency = 0.72
                shadow.Visible = true -- ini bukan bayangan kotak, cuma cadangan teks
            end)
        end
    end)

    -- Kartu loading: sudut radius, tanpa bayangan kotak.
    pcall(function()
        local lg = ParentGui:FindFirstChild("LXC_LoadingGui")
        local dim = lg and lg:FindFirstChildWhichIsA("Frame")
        local card = dim and dim:FindFirstChildWhichIsA("Frame")
        if card then
            ensureCorner(card, UDim.new(0, 18))
            for _, o in ipairs(card:GetDescendants()) do
                if o:IsA("GuiObject") and string.lower(tostring(o.Name or "")):find("shadow", 1, true) then
                    pcall(function() o.Visible = false end)
                end
            end
        end
    end)
end
