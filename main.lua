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
      7. RADIUS PASS selektif: cuma container/baris/menu yang dibulatkan.
      8. HUD floating transparan total (tanpa latar kotak).
    ====================================================================
]]

getgenv().LXC_START_MARKER = os.clock()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
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

-- First run: toggle yang diminta daddy nyala otomatis; sisanya OFF.
-- Config tersimpan tidak auto-load; hanya dipakai saat tombol Load Config.
local FIRST_RUN_OFF = true
local HARDEN_DEFAULT_ON = {
    AutoClaimIndex = true, AntiBan = true, AntiAFK = true,
    AntiKnockDown = true, AntiRagdoll = true
}
local function defaultToggle(state, alwaysOn)
    if alwaysOn == true then return true end
    if FIRST_RUN_OFF then return false end
    return state == true
end

-- Shadow disimpan sebagai persen (0-100). Nilai lama 0-1 tetap diterima.
local function shadowAmount(value, fallback)
    local n = tonumber(value)
    if not n then n = tonumber(fallback) or 0 end
    if n > 1 then n = n / 100 end
    return math.clamp(n, 0, 1)
end
genv.LoopXCode_ShadowAmount = shadowAmount

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
    ["Event"] = "Event", ["HUD"] = "HUD", ["Misc"] = "Lainnya", ["Sell"] = "Jual",

    ["HUD Width"] = "Lebar HUD", ["HUD Height"] = "Tinggi HUD",
    ["HUD Text Size"] = "Ukuran Teks HUD", ["HUD Gap"] = "Jarak HUD",
    ["HUD Shadow"] = "Bayangan HUD", ["HUD Shadow Offset"] = "Offset Bayangan HUD",
    ["HUD Font"] = "Font HUD", ["Logo Font"] = "Font Logo",
    ["Auto Catch"] = "Tangkap Otomatis", ["Catch Reel"] = "Mode Reel",
    ["Catch Rarity (tier)"] = "Rarity Tangkap (tier)", ["Catch Zone"] = "Zona Tangkap",
    ["Min Income"] = "Income Minimum", ["Auto Equip Best Speed"] = "Auto Equip Kecepatan Terbaik",
    ["Auto Equip Best Pen"] = "Auto Equip Pen Terbaik",
    ["Walk Speed"] = "Kecepatan Jalan", ["Walk speed used by Auto Catch in studs/sec (16-50000)"] = "Kecepatan jalan Auto Catch dalam studs/detik (16-50000)",
    ["Speed Boost"] = "Tambah Kecepatan", ["Boost on-foot and mounted movement to this speed (16-50000)"] = "Percepat jalan kaki dan naik pet sampai kecepatan ini (16-50000)",
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

    ["Auto Claim Index"] = "Klaim Index Otomatis", ["Auto Upgrade Pen"] = "Upgrade Pen Otomatis",
    ["Auto Upgrade Treadmill"] = "Upgrade Treadmill Otomatis", ["Auto Treadmill"] = "Treadmill Otomatis",
    ["Admin Event"] = "Event Admin", ["Auto Treadmill Admin Event"] = "Treadmill Event Admin",
    ["Auto tap TAP! saat event treadmill admin aktif"] = "Tekan TAP! otomatis saat event treadmill admin aktif",
    ["Auto farm"] = "Peternakan Otomatis", ["Event Scan"] = "Scan Event",
    ["All Map"] = "Semua Map", ["Refresh Event Scan"] = "Segarkan Scan Event",
    ["Scan Event Pets"] = "Scan Pet Event", ["Event Data"] = "Data Event",
    ["Farm Maps"] = "Map Farm", ["Select multiple maps for Auto farm"] = "Pilih beberapa map untuk Peternakan Otomatis",
    ["No lasso-safe turkey found"] = "Tidak ada turkey yang sesuai lasso",
    ["Farm: waiting for turkey"] = "Farm: menunggu turkey",
    ["Turkey Coins"] = "Koin Turkey", ["Coins gained"] = "Koin didapat",
    ["No Clip / Tembus Tembok"] = "Tembus Tembok", ["Tembus Tembok"] = "Tembus Tembok",
    ["Pass through walls without triggering SpawnSafety"] = "Tembus tembok tanpa memicu SpawnSafety",
    ["Auto Sell Pet"] = "Jual Pet Otomatis",
    ["Unlock FPS"] = "Buka FPS", ["FPS Cap"] = "Batas FPS",
    ["Custom FPS cap used by Unlock FPS / Auto Low"] = "Batas FPS kustom untuk Buka FPS / Auto Low",
    ["1-1000  (dipakai Unlock FPS / Auto Low)"] = "1-1000  (dipakai Buka FPS / Auto Low)",
    ["Unlock FPS 240"] = "Buka FPS", ["Auto Low / Performance"] = "Auto Low / Performa",
    ["Hide Your Pet in Pen"] = "Sembunyikan Pet di Pen", ["Respawn"] = "Respawn", ["Hide HUD"] = "Sembunyikan HUD",
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
    ["Automatically keep the best pets in the pen"] = "Otomatis memasukkan pet terbaik ke pen",
    ["Force all hub text to Gotham (clean and readable)"] = "Paksa semua teks hub pakai Gotham (bersih & enak dibaca)",
    ["1S 20M 30K 50B 1T  (blank = any)"] = "1S 20M 30K 50B 1T  (kosong = semua)",
    ["Pet name, e.g. Bunny"] = "Nama pet, mis. Bunny",
    ["lasso too weak: "] = "lasso kurang kuat: ",
    ["strong enough"] = "cukup kuat", ["too weak"] = "kurang kuat",
    ["Failed"] = "Gagal", ["Done"] = "Selesai", ["Weak"] = "Lemah",
    ["Total pets"] = "Total pet", ["Lasso"] = "Lasso", ["Total"] = "Total",
    ["0.55  (0 = off, 1 = solid)"] = "0.55  (0 = mati, 1 = pekat)",
    ["#38BDF8  or  56,189,248"] = "#38BDF8  atau  56,189,248",
    ["Auto upgrade pen via valid 'sign' remote (off by default)"] = "Auto upgrade kandang via valid 'sign' remote (off by default)",
    ["manual steal (lasso still checked)"] = "manual steal (lasso tetap dicek)",
    ["Catch red (too-strong) pets; on fail keep hunting green/orange"] = "Tangkap pet merah (lasso kurang kuat); gagal tetap cari yang hijau/orange",
    ["Sell every selected rarity automatically"] = "Jual semua rarity yang dipilih otomatis",
    ["Select multiple rarities to sell"] = "Pilih beberapa rarity untuk dijual",
    ["Sell selected rarities once"] = "Jual rarity yang dipilih sekali",
    ["Auto farm ON"] = "Peternakan otomatis aktif", ["Auto farm OFF"] = "Peternakan otomatis mati",
    ["Auto Sell ON"] = "Jual otomatis aktif", ["Auto Sell OFF"] = "Jual otomatis mati",
    ["Sell Now: %d pets"] = "Jual Sekarang: %d pet", ["Sell Now: no pets"] = "Jual Sekarang: tidak ada pet",
    ["Event scan: %d turkeys"] = "Scan event: %d turkey",
    ["Event deposit: %d turkeys"] = "Setor event: %d turkey",
    ["Auto farm event turkeys; auto deposit after Safe Zone"] = "Auto farm turkey event; otomatis disetor setelah Safe Zone",
    ["Scan turkey data from all loaded maps"] = "Scan data turkey dari semua map yang ter-load",
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
genv.LoopXCode_AutoEquipV2 = false

-- Safe GUI Parent (executor gethui / CoreGui / PlayerGui)
local function GetSafeGuiParent()
    local ok, res = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if ok and res then return res end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ParentGui = GetSafeGuiParent()

-- Sisa build lama yang memakai UI manual dibersihkan. Setelah round change,
-- gethui() bisa berpindah (CoreGui -> PlayerGui), jadi sapu semua root yang
-- mungkin dipakai run sebelumnya supaya nggak ada logo/loading dobel.
local cleanupRoots = { ParentGui }
pcall(function() if CoreGui and CoreGui ~= ParentGui then table.insert(cleanupRoots, CoreGui) end end)
pcall(function()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg and pg ~= ParentGui then table.insert(cleanupRoots, pg) end
end)
local seenCleanupRoot = {}
for _, root in ipairs(cleanupRoots) do
    if root and not seenCleanupRoot[root] then
        seenCleanupRoot[root] = true
        for _, o in ipairs(root:GetDescendants()) do
            local n = tostring(o.Name or "")
            local ln = n:lower()
            if n == "LoopXCodeUI" or n == "LoopXCode_FloatingToggle"
                or n == "LXC_ToggleGui" or n == "LXC_HudGui" or n == "LXC_MenuBackground"
                or n == "LXC_LoadingGui" or n == "LoopXCode_ESP_Holder"
                or ln == "windui" or ln:find("windui/", 1, true) then
                pcall(function() o:Destroy() end)
            end
        end
    end
end
-- Live-reload: matikan instance harden lama yang masih menyimpan loop aktif.
pcall(function()
    local prev = genv.LoopXCode_HardenCfg
    if type(prev) == "table" then
        for _, k in ipairs({
            "AutoClaimIndex", "AutoUpgradeTraining", "AutoUpgradeTreadmill", "AutoTreadmill", "AdminEventTreadmill", "AntiBan", "AntiAFK",
            "GodMode", "Fly", "JumpInfinity", "AntiKnockDown", "Invisible",
            "AntiRagdoll", "AutoAntiSpeed", "AntiHit", "SpeedBoost",
            "UnlockFPS", "AutoLow", "HidePetPen"
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
LoadingText.Text = "LoopXCode AntiBan"
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
local winduiSource = genv.LoopXCode_WindUISrc
if type(winduiSource) ~= "string" or winduiSource == "" then
    task.spawn(function()
        local ok, src = pcall(function() return game:HttpGet(WINDUI_URL, true) end)
        if ok and type(src) == "string" and #src > 0 then
            winduiSource = src
            genv.LoopXCode_WindUISrc = src
        end
    end)
end

local closeLoadingOverlay = function()
    pcall(function() loadingTween:Cancel() end)
    pcall(function() LoadingGui:Destroy() end)
    genv.LoopXCode_LoadFinished = os.clock()
end
OnCleanup(closeLoadingOverlay)
-- Watchdog: kalau require/download/build tersendat, loading screen tetap hilang.
task.delay(8, function()
    if LoadingGui and LoadingGui.Parent then closeLoadingOverlay() end
end)

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

local function AddToggle(name, defaultState, callback, group, alwaysOn)
    UIItems[#UIItems + 1] = {
        Kind = "Toggle", Name = name, Default = defaultToggle(defaultState, alwaysOn),
        Callback = callback, Group = group or "Misc"
    }
end

local function AddDropdown(name, options, defaultText, callback, group)
    UIItems[#UIItems + 1] = {
        Kind = "Dropdown", Name = name, Values = options, Default = defaultText,
        Callback = callback, Group = group or "Misc"
    }
end

local function AddInput(name, value, placeholder, callback, group)
    UIItems[#UIItems + 1] = {
        Kind = "Input", Name = name, Default = value, Placeholder = placeholder,
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

-- Anti Ban: semua argumen remote yang dikirim hub dibersihkan dulu. Server
-- menolak angka NaN/infinite, string terlalu panjang, dan tabel bersarang yang
-- cacat; wrapper ini mencegah remote cacat itu pernah keluar dari client.
local AntiBanState = { cleaned = 0, blocked = 0 }
genv.LoopXCode_AntiBanState = function()
    return {
        enabled = type(genv.LoopXCode_HardenCfg) == "table"
            and genv.LoopXCode_HardenCfg.AntiBan == true,
        cleaned = AntiBanState.cleaned,
        blocked = AntiBanState.blocked
    }
end
local function antiBanClean(value, depth)
    depth = depth or 0
    local robloxType = typeof and typeof(value) or nil
    if robloxType and robloxType ~= "userdata" then return value end
    local kind = type(value)
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge
            or math.abs(value) > 1e15 then
            AntiBanState.blocked += 1
            return 0
        end
        AntiBanState.cleaned += 1
        return value
    elseif kind == "string" then
        if #value > 4096 then
            AntiBanState.blocked += 1
            return value:sub(1, 4096)
        end
        AntiBanState.cleaned += 1
        return value
    elseif kind == "table" then
        if depth >= 6 then
            AntiBanState.blocked += 1
            return nil
        end
        local out, count = {}, 0
        for k, v in pairs(value) do
            count += 1
            if count > 1000 then AntiBanState.blocked += 1 break end
            local ck = antiBanClean(k, depth + 1)
            local cv = antiBanClean(v, depth + 1)
            if ck ~= nil and cv ~= nil then out[ck] = cv end
        end
        return out
    elseif kind == "function" or kind == "thread" or kind == "userdata" then
        AntiBanState.blocked += 1
        return nil
    end
    return value
end
local function safeArgs(...)
    local cfg = genv.LoopXCode_HardenCfg
    if type(cfg) == "table" and cfg.AntiBan == false then return ... end
    local packed = table.pack(...)
    for i = 1, packed.n do packed[i] = antiBanClean(packed[i], 0) end
    return table.unpack(packed, 1, packed.n)
end
genv.LoopXCode_SafeRemoteArgs = safeArgs
local function banSafeInvoke(remote, ...)
    if not remote or not remote:IsA("RemoteFunction") then return nil end
    local args = table.pack(safeArgs(...))
    local ok, result = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
    if ok then return result end
    return nil
end
local function banSafeFire(remote, ...)
    if not remote or not remote:IsA("RemoteEvent") then return false end
    local args = table.pack(safeArgs(...))
    return pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
end
genv.LoopXCode_BanSafeInvoke = banSafeInvoke
genv.LoopXCode_BanSafeFire = banSafeFire
local PC = require(ModuleFolder:WaitForChild("PetConfig"))
local CC = require(ModuleFolder:WaitForChild("CaptureConfig"))
local PTC = require(ModuleFolder:WaitForChild("PetTagConfig"))
local BC = require(ModuleFolder:WaitForChild("BiomeConfig"))
local THC = nil
pcall(function() THC = require(ModuleFolder:WaitForChild("Turkey" .. "HuntConfig")) end)
-- Notifikasi memakai sistem notifikasi milik game, jadi nggak bikin root UI tambahan.
local Notify = nil
pcall(function() Notify = require(ModuleFolder:WaitForChild("Notify")) end)
local function hubNotify(text, kind)
    if genv.LoopXCode_SuppressNotify then return end
    kind = kind or "Info"
    text = tostring(text)
    pcall(function()
        if type(Notify) ~= "table" then return end
        local fn = (kind == "Success" and Notify.Success)
            or (kind == "Error" and Notify.Error)
            or (kind == "Info" and Notify.Info)
            or nil
        if type(fn) == "function" then
            fn(text)
        elseif type(Notify.Show) == "function" then
            Notify.Show(text, kind)
        end
    end)
end
genv.LoopXCode_Notify = hubNotify
local MapArea = nil
pcall(function()
    local module = ModuleFolder:FindFirstChild("MapArea")
    if module then MapArea = require(module) end
end)

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

-- Auto farm: farm turkey event dengan pilihan map ganda. Engine-nya memakai
-- Manual Steal yang sudah tested, jadi lasso tetap dicek dan pet merah
-- (ratio < MIN_RATIO) dilewati dulu ke yang hijau/orange.
genv.LoopXCode_FarmCfg = {
    Enabled = true,
    Maps = (function()
        local list = { "Any" }
        for _, z in ipairs(ZONE_NAMES) do list[#list + 1] = z end
        return list
    end)(),
    ScanIndex = 0,
    ScanLine = "Event scan: 0 turkeys",
    LastTarget = "none",
    LastData = "Event Data",
    LastPoints = 0,
    LastLevel = 0,
    LastGain = 0,
    LastCoins = 0,
    CoinStart = 0,
    CoinsGained = 0,
    Deposits = 0,
    LastDepositAt = 0
}

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
local SC = require(ModuleFolder:WaitForChild("ShopConfig"))

local R_STEAL = {
    StartCapture = RemoteFolder:WaitForChild("StartCapture"),
    CapturePull = RemoteFolder:WaitForChild("CapturePull"),
    FinishCapture = RemoteFolder:WaitForChild("FinishCapture"),
    DropCarry = RemoteFolder:FindFirstChild("DropCarry")
        or RemoteFolder:WaitForChild("DropCarry", 5),
    PenPetAction = RemoteFolder:WaitForChild("PenPetAction")
}
-- Remote secure harus tersedia SEBELUM escapeToSafeZone/secureCarry dipakai.
local R_SECURE = RemoteFolder:FindFirstChild("SecureCatch")

-- Kalau reel keputus / StartCapture gagal, sesi Capturing bisa nyangkut di
-- server. Fire cancel supaya attempt berikutnya nggak ditolak terus.
local function cancelCapture(session)
    pcall(function()
        banSafeFire(R_STEAL.FinishCapture, session, false, true)
    end)
end

-- Guardian / gagal reel kadang meninggalkan attribute Carrying walaupun pet
-- tidak benar-benar didapat. Game menolak StartCapture berikutnya dengan
-- "Bring your pet back to the Safe Zone first!". Drop carry palsu ini lewat
-- remote yang sama dengan tombol DROP di CaptureClient, supaya hub tidak
-- perlu pulang ke safe zone dan tidak mengira gagal = pet sukses.
local function dropStaleCarry(reason)
    local name = LocalPlayer:GetAttribute("Carrying")
    if type(name) ~= "string" or name == "" then return false end
    genv.LoopXCode_LastDroppedCarryAt = os.clock()
    genv.LoopXCode_LastDroppedCarryReason = tostring(reason or "stale")
    pcall(function()
        if R_STEAL.DropCarry then banSafeFire(R_STEAL.DropCarry) end
    end)
    return true
end
genv.LoopXCode_DropStaleCarry = dropStaleCarry

local StealCfg = {
    Enabled = true,
    Busy = false,
    RetryDelay = 0.7,          -- jeda antar siklus, biar game nggak nge-freeze
    Rarity = "Any",             -- tier EXACT yang dipilih; nggak ada auto-turun
    Zone = "Any",               -- map/zone EXACT yang dipilih; Any = semua map
    CustomIncome = "",     -- min income: 5k / 30b / 50t / kosong = semua
    Priority = "Any",           -- tetap Any; fokus filter cuma Rarity + Min Income
    ReelMode = "Fast", -- Catch Reel sekarang FAST-only; mode Safe dihapus.
    WeakAllowed = false,      -- Experimen: boleh tangkap walau lasso kurang kuat
    WalkSpeed = 60            -- kecepatan jalan Auto Catch (default mulus, bisa diatur dari menu)
}
genv.LoopXCode_StealCfg = StealCfg

-- Speed Boost: input menu tetap bisa sampai 50000 (disimpan apa adanya supaya
-- config dan UI nggak berubah), tapi kecepatan yang dipakai game dibatasi ke
-- nilai yang terbukti mulus. 50000 WalkSpeed bikin char macet/aneh karena
-- langkah physics per frame terlalu besar dan server menarik balik posisi.
local SpeedCfg = { Enabled = false, Value = 60 }
genv.LoopXCode_SpeedCfg = SpeedCfg
local function speedTarget()
    local v = tonumber(SpeedCfg.Value) or 60
    if v < 16 then v = 16 end
    if v > 50000 then v = 50000 end
    return v
end
genv.LoopXCode_SpeedTarget = speedTarget

-- Uji live terbaru: 50 dan 60 studs/s mulus tanpa snap-back. 75 sudah kena
-- rubber-band ~42 studs, 100/400 makin parah. Jadi angka besar di input
-- diterjemahkan ke plafon ini, bukan dipaksakan ke Humanoid.WalkSpeed.
local MAX_EFFECTIVE_WALK = 60
local function mountedNow()
    local mount = LocalPlayer:GetAttribute("Mount")
    return type(mount) == "string" and mount ~= ""
end
local function safeWalkSpeed(value)
    local n = tonumber(value) or MAX_EFFECTIVE_WALK
    if n < 16 then n = 16 end
    if n > MAX_EFFECTIVE_WALK then n = MAX_EFFECTIVE_WALK end
    return n
end
genv.LoopXCode_SafeWalkSpeed = safeWalkSpeed
genv.LoopXCode_MaxEffectiveWalkSpeed = MAX_EFFECTIVE_WALK

-- Jangan pernah menyuruh Humanoid:MoveTo ke luar koridor map. Kalau target di
-- luar, game menabrakkan char ke dinding lalu posisinya kelihatan bolak-balik.
-- Pakai MapArea milik game (sumber kebenaran yang sama dengan SafeZoneFX).
local function insideMap(pos)
    if not MapArea then return true end
    local ok, result = pcall(function() return MapArea.Inside(pos) end)
    return ok and result ~= false
end
local function clampToMap(fromPos, targetPos)
    if not targetPos then return nil end
    if not MapArea or insideMap(targetPos) then return targetPos end
    local origin = fromPos or targetPos
    if not insideMap(origin) then return targetPos end
    local lo, hi = 0, 1
    for _ = 1, 14 do
        local mid = (lo + hi) * 0.5
        local test = origin:Lerp(targetPos, mid)
        test = Vector3.new(test.X, origin.Y, test.Z)
        if insideMap(test) then lo = mid else hi = mid end
    end
    local result = origin:Lerp(targetPos, math.max(0, lo - 0.02))
    return Vector3.new(result.X, origin.Y, result.Z)
end
genv.LoopXCode_InsideMap = insideMap
genv.LoopXCode_ClampToMap = clampToMap

-- Auto Sell Pet: jual otomatis pet di bag yang tier-nya dipilih (multi-select).
local SellCfg = {
    Enabled = true,
    Interval = 5,
    Rarities = {}
}
genv.LoopXCode_SellCfg = SellCfg
local R_SELL = RemoteFolder:FindFirstChild("SellPets")

-- Ukuran HUD floating bisa diatur bebas dari menu Controls.
local HudCfg = { Width = 720, Height = 108, TextSize = 18, Gap = 10, Shadow = 50, ShadowOffset = 1, Font = "Bold", LogoFont = "Logo", X = 0, Y = 0, Hidden = false }
genv.LoopXCode_HudCfg = HudCfg
local applyHudLayout = function() end
genv.LoopXCode_ApplyHudLayout = function() applyHudLayout() end
genv.LoopXCode_SetHudHidden = function() end

local MiscCfg = { MenuBackground = false, AutoEquipBestSpeed = defaultToggle(true), AutoEquipBestPen = false }
genv.LoopXCode_MiscCfg = MiscCfg
genv.LoopXCode_SetMenuBackground = function() end
genv.LoopXCode_SetAutoEquipBestPen = function() end

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
    FastReel = 0.03,    -- Fast: loop reel responsif tanpa membanjiri server
    FastPull = 0.1,     -- Fast: jangan lebih cepat dari throttle server
    FastSettle = 0.03   -- Fast: sinkronisasi minimal supaya catch terasa cepat
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

-- Parse income compact: 1S / 20M / 30K / 50B / 1T / 10B, juga format bebas
-- seperti "5M or more", "min 5m", "50K+". Blank/any/all = 0 (terima semua).
-- Angka yang dihasilkan dibandingkan dengan income TAMPILAN game (sudah
-- termasuk bonus size, mutation, dan MoneyMult).
local INCOME_SUFFIXES = {
    { "sp", 1e24 }, { "sx", 1e21 }, { "s", 1e21 },
    { "qn", 1e18 }, { "qd", 1e15 }, { "q", 1e15 },
    { "t", 1e12 }, { "b", 1e9 }, { "m", 1e6 }, { "k", 1e3 }
}
local function parseIncome(text)
    local raw = string.lower(tostring(text or ""))
    raw = raw:gsub("[%s,_]+", "")
    if raw == "" or raw == "any" or raw == "all" or raw == "none"
        or raw == "off" or raw == "-" or raw == "0" then
        return 0
    end
    local num, letters = raw:match("(%d+%.?%d*)(%a*)")
    if not num then return 0 end
    local mult = 1
    letters = letters or ""
    for _, entry in ipairs(INCOME_SUFFIXES) do
        if letters:sub(1, #entry[1]) == entry[1] then
            mult = entry[2]
            break
        end
    end
    return (tonumber(num) or 0) * mult
end
genv.LoopXCode_ParseIncome = parseIncome

local function petCfg(name)
    if not name then return nil end
    local ok, cfg = pcall(function() return PC.Get(name) end)
    if ok and type(cfg) == "table" then return cfg end
    return nil
end

-- Income yang dipakai filter harus SAMA dengan angka yang dilihat daddy di UI
-- game: GetPetIncome * bonus size * bonus mutation * MoneyMult. Kalau cukup
-- pakai base GetPetIncome, angka "10B" nggak bakal pernah cocok karena UI game
-- menampilkan angka yang sudah dikali bonus.
local function petIncome(cfg, model)
    if not cfg then return 0 end
    local moneyMult = 1
    pcall(function() moneyMult = tonumber(SC.MoneyMult(LocalPlayer)) or 1 end)

    local direct = nil
    if model then
        pcall(function() direct = tonumber(model:GetAttribute("Income")) end)
    end
    if direct then return direct * moneyMult end

    local base = tonumber(cfg.Income) or 0
    pcall(function()
        local v = CC.GetPetIncome(cfg)
        if type(v) == "number" then base = v end
    end)

    local sizeBonus, mutationBonus = 1, 1
    if model then
        local size = tonumber(model:GetAttribute("Size")) or 1
        pcall(function() sizeBonus = tonumber(PC.IncomeBonus(size)) or 1 end)
        local mutation = model:GetAttribute("Mutation")
        if mutation and mutation ~= "" then
            pcall(function()
                local m = MUT.Get(tostring(mutation))
                mutationBonus = tonumber(m and m.Bonus) or 1
            end)
        end
    end
    return base * sizeBonus * mutationBonus * moneyMult
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
        -- Size dari game berupa ANGKA skala (mis. 3.24). Jangan di-tostring:
        -- RequiredLassoPower menghitung requirement berbeda untuk angka vs teks.
        size = (function()
            local s = model:GetAttribute("Size")
            if s == nil then s = cfg and cfg.Size or "Normal" end
            return s
        end)(),
        mutation = tostring(model:GetAttribute("Mutation") or ""),
        income = petIncome(cfg, model),
        pos = pos
    }
end

-- Sumber kebenaran warna requirement = tag yang asli dipakai game
-- (PetTagsClient: WildInfo -> Requirement.TextColor3). Game menghitungnya dari
-- PetTagConfig.RequirementColor(GetPlayerDifficulty(...).ratio, Reel.MIN_RATIO).
-- Kalau tag tersedia, pakai warnanya langsung. Kalau belum ke-render (pet baru
-- stream-in), fallback ke hitungan ratio yang SAMA dengan game.
local function requirementTagColor(model)
    if not model then return nil end
    local root = wildRoot(model)
    if not root then return nil end
    local gui = root:FindFirstChild("WildInfo")
    if not gui then return nil end
    local label = gui:FindFirstChild("Requirement", true)
    if not label or not label:IsA("TextLabel") then return nil end
    return label.TextColor3
end

local function isImpossibleTagColor(color)
    if typeof(color) ~= "Color3" then return nil end
    local ref = PTC.REQUIREMENT_IMPOSSIBLE
    local diff = math.abs(color.R - ref.R)
        + math.abs(color.G - ref.G)
        + math.abs(color.B - ref.B)
    return diff <= 0.04
end

local function tagSaysImpossible(model)
    return isImpossibleTagColor(requirementTagColor(model))
end
genv.LoopXCode_RequirementTagColor = requirementTagColor
genv.LoopXCode_TagSaysImpossible = tagSaysImpossible

local function normalizeText(s)
    return string.lower(tostring(s or ""):gsub("%s+", ""))
end

-- Dipakai pickTarget supaya target yang tak bisa ditangkap bisa dilewati.
local lassoTooWeak = function() return false end
-- Target yang sudah terbukti terlalu kuat dilewati sementara, supaya loop
-- nggak ngejar pet yang sama berulang kali saat Weak Lasso Catch aktif.
genv.LoopXCode_WeakSkip = genv.LoopXCode_WeakSkip or {}
skipWeakTarget = function(info, seconds)
    if not info or not info.id then return end
    genv.LoopXCode_WeakSkip[info.id] = os.clock() + (seconds or 25)
end
isWeakSkipped = function(info)
    if not info or not info.id then return false end
    local untilTime = genv.LoopXCode_WeakSkip[info.id]
    if not untilTime then return false end
    if os.clock() >= untilTime then genv.LoopXCode_WeakSkip[info.id] = nil return false end
    return true
end
-- Dipakai kalau beberapa attempt berturut-turut gagal: semua skip dilepas supaya
-- loop mau coba lagi pet yang sama setelah pindah zone.
genv.LoopXCode_ClearWeakSkips = function()
    for id in pairs(genv.LoopXCode_WeakSkip) do genv.LoopXCode_WeakSkip[id] = nil end
end

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

-- Lock target Auto Catch: sekali pet dipilih, hub tetap mengejar pet itu sampai
-- tertangkap / hilang / dua kali gagal. Ini menghentikan bolak-balik antar pet
-- yang jaraknya hampir sama tiap kali loop scan dijalankan.
local CatchLock = { model = nil, id = nil, fails = 0, deadline = 0, score = 0 }
genv.LoopXCode_CatchLock = CatchLock
local function clearCatchLock()
    CatchLock.model, CatchLock.id, CatchLock.fails, CatchLock.deadline, CatchLock.score =
        nil, nil, 0, 0, 0
end
local function lockedCatchTarget()
    local model = CatchLock.model
    if not model or model.Parent ~= WildFolder then clearCatchLock() return nil end
    if os.clock() > (tonumber(CatchLock.deadline) or 0) then clearCatchLock() return nil end
    if model:GetAttribute("CapturedBy") ~= 0 and model:GetAttribute("CapturedBy") ~= nil
        or model:GetAttribute("Despawning") == true then
        clearCatchLock()
        return nil
    end
    local info = wildInfo(model)
    if not info or not matchesFilter(info)
        or (genv.LoopXCode_IsFarmTurkey and genv.LoopXCode_IsFarmTurkey(info.name)) then
        clearCatchLock()
        return nil
    end
    -- Jangan pertahankan lock pada pet yang sudah terbukti merah / sedang di-skip.
    -- Ini bikin Auto Catch pindah target SEGERA, bukan ngejar pet yang mustahil.
    if isWeakSkipped(info) or (lassoTooWeak(info) and not StealCfg.WeakAllowed) then
        clearCatchLock()
        return nil
    end
    return info
end
local function lockCatchTarget(info, score)
    if not info or not info.model then return end
    CatchLock.model = info.model
    CatchLock.id = info.id
    CatchLock.fails = 0
    CatchLock.score = tonumber(score) or 0
    CatchLock.deadline = os.clock() + 18
end
local function failCatchLock(info, reason)
    if not info then clearCatchLock() return end
    if CatchLock.model ~= info.model and CatchLock.id ~= info.id then return end
    reason = string.lower(tostring(reason or "capture-failed"))
    -- Kegagalan navigasi / pet hilang bukan salah target. Lepas lock sekarang
    -- supaya siklus berikutnya langsung memilih pet yang benar-benar dekat.
    if string.find(reason, "approach", 1, true)
        or string.find(reason, "lost", 1, true)
        or string.find(reason, "far", 1, true)
        or string.find(reason, "lasso", 1, true)
        or string.find(reason, "stopped", 1, true) then
        clearCatchLock()
        return
    end
    CatchLock.fails += 1
    if CatchLock.fails >= 2 then clearCatchLock() end
end
genv.LoopXCode_ClearCatchLock = clearCatchLock
genv.LoopXCode_FailCatchLock = failCatchLock

-- Target HARUS lolos matchesFilter (tier EXACT + min income + zone EXACT).
-- Nggak ada auto-turun, nggak ada fallback, nggak ada dropdown yang berubah
-- sendiri. Kalau tier yang dipilih nggak ada, hub berhenti.
local function pickTarget()
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local locked = lockedCatchTarget()
    local lockedScore = -math.huge
    if locked then
        local liveLocked = wildRoot(locked.model)
        if liveLocked then locked.pos = liveLocked.Position end
        lockedScore = priorityScore(locked, rootPart)
    end

    local best, bestScore = nil, -math.huge
    local fallback, fallbackScore = nil, -math.huge
    -- Pet yang lagi di-skip karena GAGAL (bukan merah) jangan dibuang begitu
    -- saja: kalau tidak ada kandidat lain, tetap dicoba lagi supaya Auto Catch
    -- nggak berhenti / diam setelah satu attempt gagal.
    local retry, retryScore = nil, -math.huge
    for _, model in ipairs(WildFolder:GetChildren()) do
        local info = wildInfo(model)
        if info
            and isUncaptured(model:GetAttribute("CapturedBy"))
            and model:GetAttribute("Despawning") ~= true
            and matchesFilter(info)
            and not (genv.LoopXCode_IsFarmTurkey and genv.LoopXCode_IsFarmTurkey(info.name)) then
            local score = priorityScore(info, rootPart)
            local red = lassoTooWeak(info)
            if isWeakSkipped(info) then
                if not red and score > retryScore then retryScore, retry = score, info end
            elseif not red then
                if score > bestScore then bestScore, best = score, info end
            elseif StealCfg.WeakAllowed and score > fallbackScore then
                fallbackScore, fallback = score, info
            end
        end
    end
    -- Yang benar-benar bisa ditangkap selalu diprioritaskan. Weak Lasso Catch
    -- cuma cadangan. Retry dipakai terakhir supaya loop tetap jalan.
    local chosen = best or fallback or retry
    if not chosen then
        clearCatchLock()
        return nil
    end

    -- Histeresis: target yang sedang dikejar dipertahankan kalau kandidat baru
    -- cuma "mungkin lebih dekat" (selisih < 45 stud). Ini menghentikan bolak-balik
    -- tiap scan. Tapi kalau pet lain jauh lebih dekat, pindah SEKARANG.
    local chosenScore = chosen == best and bestScore
        or chosen == fallback and fallbackScore
        or retryScore
    if locked and CatchLock.fails < 2 and chosenScore <= lockedScore + 45 then
        CatchLock.score = lockedScore
        return locked
    end

    lockCatchTarget(chosen, chosenScore)
    return chosen
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
    return safeWalkSpeed(v)
end
genv.LoopXCode_ConfiguredWalkSpeed = configuredWalkSpeed

local function setWalkSpeed(char, speed)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = safeWalkSpeed(speed) end
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
local function rushToPoint(rootPart, getPoint, stopDist, timeout, speed, shouldStop)
    local hum = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local oldSpeed = hum.WalkSpeed
    -- NAik pet: jangan pernah paksa 60 di sini. MountConfig.PetSpeed yang
    -- ngatur kecepatan hewan (bisa 200+). Memaksa 60 bikin Auto Catch pelan
    -- banget kalau daddy nyangkut di pet, padahal tanpa pet kenceng.
    local mounted = mountedNow()
    if not mounted then
        hum.WalkSpeed = safeWalkSpeed(tonumber(speed) or configuredWalkSpeed(120))
    end
    local started = os.clock()
    local lastIssue = 0
    local ok = false
    while os.clock() - started < (timeout or 20) do
        recoverFromBoss(rootPart)
        if shouldStop and shouldStop() then break end
        local rawPoint = getPoint()
        if not rawPoint then break end
        local cur = rootPart.Position
        local point = clampToMap(cur, rawPoint)
        local dx, dz = point.X - cur.X, point.Z - cur.Z
        local d = math.sqrt(dx * dx + dz * dz)
        if d <= (stopDist or 6) then ok = true break end
        if os.clock() - lastIssue >= 0.2 then
            lastIssue = os.clock()
            pcall(function() hum:MoveTo(Vector3.new(point.X, cur.Y, point.Z)) end)
        end
        task.wait(0.05)
    end
    if not mounted then hum.WalkSpeed = oldSpeed end
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
    local approachTimeout = math.clamp(
        (first.Position - rootPart.Position).Magnitude / 20 + 6, 7, 18)

    rushToPoint(rootPart, function()
        local live = wildRoot(targetInfo.model)
        if not live then return nil end
        targetInfo.pos = live.Position
        return live.Position
    end, keep, approachTimeout, 90)

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

-- Warna requirement di atas kepala pet dihitung game lewat:
--   PetTagConfig.RequirementColor(
--       CaptureConfig.GetPlayerDifficulty(cfg, LocalPlayer, stunned, size).ratio,
--       CaptureConfig.Reel.MIN_RATIO)
-- ratio = EffectiveLassoPower(player) / PetLassoPower(cfg, size).
-- MERAH  : ratio < 0.6  -> lasso benar-benar tak cukup, pet dilewati.
-- ORANGE : 0.6 - 0.8    -> susah tapi MASIH BISA ditangkap.
-- KUNING : 0.8 - 1.0    -> bisa.
-- HIJAU  : >= 1.0       -> mudah.
-- Pakai ambang yang SAMA dengan warna game, bukan "required > power" yang dulu
-- salah membuang pet orange/kuning yang sebenarnya masih bisa ditangkap.
local function lassoRatio(targetInfo)
    if not targetInfo then return 0 end
    local ratio = 0
    pcall(function()
        local cfg = petCfg(targetInfo.name)
        if not cfg then return end
        -- PetTagsClient memakai status STUNNED dari atribut game, bukan false.
        -- Pet yang sedang stunned punya requirement lebih rendah (warna naik).
        local stunned = false
        pcall(function()
            local untilTime = tonumber(targetInfo.model and targetInfo.model:GetAttribute("StunnedUntil")) or 0
            stunned = workspace:GetServerTimeNow() < untilTime
        end)
        local diff = CC.GetPlayerDifficulty(cfg, LocalPlayer, stunned, targetInfo.size)
        ratio = tonumber(diff and diff.ratio) or 0
    end)
    return ratio
end
genv.LoopXCode_LassoRatio = lassoRatio

lassoTooWeak = function(targetInfo)
    if not targetInfo then return false end
    -- Kalau tag requirement sudah ke-render, warnanya adalah keputusan final
    -- game: merah = skip, orange/kuning/hijau = boleh ditangkap.
    local byTag = tagSaysImpossible(targetInfo.model)
    if byTag ~= nil then return byTag end
    local minRatio = tonumber(CC.Reel and CC.Reel.MIN_RATIO) or 0.6
    return lassoRatio(targetInfo) < minRatio
end
genv.LoopXCode_LassoTooWeak = function(info) return lassoTooWeak(info) end

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
    -- Catch Reel sekarang FAST-only. 0.82s masih di atas batas server yang
    -- sudah teruji (~0.76s), tapi jauh lebih cepat dari reel lama 1.05s/4s.
    if isFastReel() then return 0.82 end
    return 0.82
end

local function reelCapture(session, targetInfo, difficulty)
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    local duration = reelDuration(difficulty)
    -- Merah sudah difilter pickTarget. Orange/kuning (ratio < 1) reel-nya
    -- lebih sulit -> ikuti lebih dekat supaya pet nggak escape.
    local hardFollow = lassoRatio(targetInfo) < 1
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
                local maxDist = hardFollow and math.max(2, (tonumber(CC.Reel and CC.Reel.STOP_DIST) or 4) - 1) or 8
                if d > maxDist and d > 0.01 then
                    local s = math.min(hardFollow and 6 or 5, d - maxDist)
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
            pcall(banSafeFire, R_STEAL.CapturePull, session, math.min(1, progress))
        end
        task.wait(reelWait)
    end

    if active then
        pcall(banSafeFire, R_STEAL.CapturePull, session, 1)
        task.wait(0.05)
        pcall(banSafeFire, R_STEAL.FinishCapture, session, true, false)
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
-- Carrying yang nyangkut setelah catch gagal/kena guard bukan carry asli.
-- Dipakai supaya stealStep tidak mengira itu hasil tangkapan dan pulang.
genv.LoopXCode_LastFailedCarryAt = 0
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
        -- Berhenti SEBETIKAN server menghapus Carrying. Kalau tidak, char
        -- tetap jalan sampai Z +10 walaupun pet sudah masuk bag.
        local deposited = function() return not isCarrying() end
        rushToPoint(rootPart, function()
            return Vector3.new(SAFE_FRONT.X, rootPart.Position.Y, SAFE_FRONT.Z)
        end, 6, 90, 220, deposited)
        if isCarrying() then
            rushToPoint(rootPart, function()
                return Vector3.new(SAFE_PULL.X, rootPart.Position.Y, SAFE_PULL.Z)
            end, 5, 30, 140, deposited)
        end

        -- Kalau masih kehalang, coba sekali lagi dengan kecepatan lebih tinggi.
        if isCarrying() and not inSafeZone(rootPart.Position) then
            rushToPoint(rootPart, function()
                return Vector3.new(SAFE_PULL.X, rootPart.Position.Y, SAFE_PULL.Z)
            end, 5, 40, 220, deposited)
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
-- jadi nggak nge-freeze. JALAN pakai MoveTo seperti stageToZone: CFrame step
-- bikin server narik char balik dan kelihatan seperti pulang safe zone.
local function roamToNextZone(rootPart)
    if not rootPart then return end
    local dest
    if StealCfg.Zone ~= "Any" then
        -- Kalau daddy pilih map tertentu, keliling DI DALAM map itu. Jangan
        -- pakai daftar global yang ujung-ujungnya jalan kembali ke safe zone.
        local s, e = zoneSpan(StealCfg.Zone)
        if s and e then
            local center = (s + e) / 2
            local len = math.abs(e - s)
            local offsets = { -0.25, 0.25, 0, -0.12, 0.12 }
            local off = offsets[scanIndex % #offsets + 1]
            dest = Vector3.new(0, 10, center + len * off)
        end
    end
    if not dest then
        if #SCAN_ZONES == 0 then return end
        dest = SCAN_ZONES[scanIndex]
    end
    scanIndex = scanIndex % math.max(1, #SCAN_ZONES) + 1
    recoverFromBoss(rootPart)
    local dx = dest.X - rootPart.Position.X
    local dz = dest.Z - rootPart.Position.Z
    local dist = math.sqrt(dx * dx + dz * dz)
    local walk = configuredWalkSpeed(120)
    local timeout = math.clamp(dist / math.max(16, walk) + 12, 15, 240)
    rushToPoint(rootPart, function()
        return dest
    end, 10, timeout, walk)
    task.wait(0.3) -- kasih waktu client stream-in pet di zone itu
end
genv.LoopXCode_RoamZone = roamToNextZone

local function bagCount()
    -- Baca atribut player (GRATIS), jangan InvokeServer "list" tiap siklus (bikin ngeframe).
    local n = LocalPlayer:GetAttribute("BagPets")
    if type(n) == "number" then return math.floor(n) end
    local ok, result = pcall(banSafeInvoke, R_STEAL.PenPetAction, "list")
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
        return false, "approach"
    end

    local live = wildRoot(target.model)
    if not live then
        bumpStealStat("Failed")
        refreshStealStats()
        return false, "lost"
    end
    local liveDist = Vector3.new(
        live.Position.X - rootPart.Position.X, 0,
        live.Position.Z - rootPart.Position.Z
    ).Magnitude
    if liveDist > 17 then
        bumpStealStat("Failed")
        refreshStealStats()
        return false, "far"
    end

    -- Deteksi lasso lemah TETAP jalan, tapi tidak menghentikan attempt.
    local weak = lassoTooWeak(target)
    if weak then
        bumpStealStat("Weak")
        StealStats.LastWeak = tostring(target.name or "?")
        setStatus("on system", tr("lasso too weak: ") .. tostring(target.name or "?"))
        refreshStealStats()
        -- Pet ini sudah terbukti di luar kemampuan lasso. Jangan dipilih lagi
        -- dalam beberapa detik; loop langsung cari yang benar-benar bisa.
        skipWeakTarget(target, 25)
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
        return false, "lasso"
    end

    local okStart, startResult = pcall(banSafeInvoke, R_STEAL.StartCapture, target.id)
    if not (okStart and type(startResult) == "table" and startResult.session
        and startResult.ok ~= false) then
        local reason = ""
        if type(startResult) == "table" then
            reason = tostring(startResult.reason or startResult.msg or startResult.error or "")
        end
        local hardFail = reason:lower():find("strong", 1, true)
            or reason:lower():find("lasso", 1, true)
            or reason:lower():find("power", 1, true)
        if hardFail then skipWeakTarget(target, 25) end
        bumpStealStat("Failed")
        refreshStealStats()
        return false, hardFail and "weak" or "start"
    end

    local active = reelCapture(startResult.session, target, startResult.difficulty)
    if not active then return false, "stopped" end
    task.wait(isFastReel() and 0.08 or 0.25)
    if not isCarrying() then
        bumpStealStat("Failed")
        refreshStealStats()
        return false, "no-carry"
    end
    refreshStealStats()
    return true, "ok"
end

-- Satu siklus penuh. System lama: sekali ON, terus cari/capture di zone.
-- Gagal = lanjut cari target lain (nggak balik safe, nggak nunggu lama).
-- Sukses = pet masih di tangan, lanjut cari lagi sampai bag full / di-off.
-- Safe zone HANYA dipakai kalau ada carry sisa dari sesi sebelumnya.
local consecCatchFails = 0
local function catchFailed(rootPart, target, reason)
    reason = string.lower(tostring(reason or "capture-failed"))
    consecCatchFails += 1
    genv.LoopXCode_LastCatchFailAt = os.clock()
    genv.LoopXCode_LastCatchFailReason = reason
    if LocalPlayer:GetAttribute("Capturing") == true then cancelCapture(nil) end
    -- Carrying nyangkut pasca guard hit BUKAN hasil tangkapan. Tandai supaya
    -- stealLoop tidak mengira ini pet sukses dan pulang ke safe zone.
    if isCarrying() then
        genv.LoopXCode_LastFailedCarryAt = os.clock()
        -- Carry hasil gagal/GuardianHit bukan pet asli. Buang sekarang supaya
        -- siklus berikutnya tidak ditolah game dan tidak kabur ke safe zone.
        dropStaleCarry(reason)
    end
    if target then
        pcall(function() genv.LoopXCode_FailCatchLock(target, reason) end)
        local hardFail = string.find(reason, "weak", 1, true) ~= nil
        local softFail = string.find(reason, "approach", 1, true)
            or string.find(reason, "lost", 1, true)
            or string.find(reason, "far", 1, true)
            or string.find(reason, "lasso", 1, true)
        local skipTime = hardFail and 25 or softFail and 4 or 8
        skipWeakTarget(target, skipTime)
    end
    -- 3 gagal berturut = pet di zone ini habis / semua kena guard. Pindah zone
    -- dan hapus skip dulu, jangan diam di "any detect" selamanya.
    if consecCatchFails >= 3 then
        consecCatchFails = 0
        pcall(genv.LoopXCode_ClearWeakSkips)
        setStatus("on system", "no catchable pet - roam")
        pcall(roamToNextZone, rootPart)
    end
    task.wait(isFastReel() and 0.08 or 0.12)
end

local function stealStep()
    -- Carry sisa dari sesi sebelumnya ditangani SEKALI di stealLoop, bukan di
    -- sini. Kalau masih dicek tiap siklus, Carrying nyangkut pasca guard hit
    -- bikin hub bolak-balik ke safe zone dan berhenti mencari.

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
            -- Nggak ada pet lolos filter -> jangan kabur ke safe zone. Hitung
            -- sebagai gagal supaya setelah beberapa siklus hub pindah zone.
            setStatus("any detect", "waiting for filtered pet")
            local charNow = LocalPlayer.Character
            pcall(catchFailed, charNow and charNow:FindFirstChild("HumanoidRootPart"), nil, "no-target")
            return false
        end
        setStatus("any detect", tostring(target.name or "?"))

        local ok, failReason = tryCaptureOnce(rootPart, target)

        -- Kasih server waktu bersihin Capturing. Kalaupun nyangkut, jangan
        -- nunggu 4 detik: cancel cepat lalu lanjut target berikutnya.
        if LocalPlayer:GetAttribute("Capturing") == true then
            task.wait(0.15)
            if LocalPlayer:GetAttribute("Capturing") == true then cancelCapture(nil) end
        end

        -- CATCH GAGAL / KENA GUARD = JANGAN PERNAH BALIK KE SAFE ZONE.
        -- Guard bisa menyela reel dan meninggalkan attribute Carrying yang
        -- nyangkut walau pet tak benar-benar didapat. Escape hanya boleh
        -- dipicu oleh catch yang memang SUKSES (ok == true), bukan sekadar
        -- isCarrying(). Setelah gagal: skip pet itu, cari yang lain di zone ini.
        if ok then
            consecCatchFails = 0
            pcall(function() genv.LoopXCode_ClearCatchLock() end)
            if isCarrying() then
                -- Carry asli hasil catch sukses -> persist sekarang, lalu
                -- loop berikutnya mulai lagi dari zone yang sama.
                escapeToSafeZone()
                return true
            end
            task.wait(isFastReel() and 0.08 or 0.15)
        else
            -- Gagal / guard menyela: skip pet ini sebentar, lanjut cari yang
            -- hijau/orange. Setelah 3 gagal, pindah zone tanpa balik safe.
            pcall(catchFailed, rootPart, target, failReason or "capture-failed")
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
        -- Deposit carry asli dari sesi sebelumnya cukup SEKALI di awal. Jangan
        -- diulang tiap siklus: Carrying yang nyangkut setelah catch gagal/kena
        -- guard bukan hasil tangkapan dan bikin hub kabur ke safe zone.
        if isCarrying() then
            local failedAt = tonumber(genv.LoopXCode_LastFailedCarryAt) or 0
            local age = os.clock() - failedAt
            if failedAt > 0 and age < 15 then
                -- Masih terlalu dekat dengan kegagalan/guard hit: ini carry
                -- nyangkut, bukan hasil tangkapan. DROP, jangan pulang.
                pcall(dropStaleCarry, "stale-after-fail")
            else
                pcall(escapeToSafeZone)
            end
        end
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
local function findWildPetByName(name, rootPart, zoneOverride)
    local wanted = normalizeText(name)
    local best, bestDist = nil, math.huge
    for _, model in ipairs(WildFolder:GetChildren()) do
        if isUncaptured(model:GetAttribute("CapturedBy"))
            and model:GetAttribute("Despawning") ~= true then
            local info = wildInfo(model)
            if info and normalizeText(info.name) == wanted
                and (not zoneOverride or zoneOverride == "Any" or info.zone == zoneOverride) then
                local dist = rootPart and (info.pos - rootPart.Position).Magnitude or 0
                if dist < bestDist then best, bestDist = info, dist end
            end
        end
    end
    return best
end

local function startManualSteal(petName, zoneOverride)
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

            local target = findWildPetByName(petName, rootPart, zoneOverride)
            if not target then
                bumpStealStat("Failed")
                setStatus("any detect", "pet not loaded: " .. petName)
                refreshStealStats()
                return
            end

            updateStealInfo(target)
            stageToZone(rootPart, zoneOverride or target.zone)
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

-- Saat Auto Catch menyala, kecepatan mount perlu lebih tinggi dari guardian
-- fastest (Shadow Realm 260) setelah catch-up 1.3x (~338). Carry slow ~0.85,
-- jadi target mount-nya ~1.7x natural supaya tetap menang walau bawa pet.
local MOUNT_CATCH_MULT = 1.7
local MOUNT_CATCH_CAP = 480
local function mountedSpeedTarget()
    local FarmCfg = genv.LoopXCode_FarmCfg
    local natural = tonumber(genv.LoopXCode_BestMountSpeed) or 0
    if natural <= 0 then return 0 end
    local hunting = StealCfg.Enabled or ManualSteal.Active or FarmCfg.Enabled
    if not (hunting and mountedNow()) then return natural end
    local boosted = natural * MOUNT_CATCH_MULT
    if boosted > MOUNT_CATCH_CAP then boosted = MOUNT_CATCH_CAP end
    if boosted < natural then boosted = natural end
    return boosted
end
genv.LoopXCode_MountedSpeedTarget = mountedSpeedTarget
genv.LoopXCode_MountCatchMultiplier = MOUNT_CATCH_MULT

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
        local ok, res = pcall(banSafeInvoke, R_STEAL.PenPetAction, "list")
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
    genv.LoopXCode_BestMountSpeed = bestSpeed
    local targetSpeed = mountedSpeedTarget()

    local currentId = LocalPlayer:GetAttribute("MountId")
    if currentId == best.id and (LocalPlayer:GetAttribute("Mount") or "") ~= "" then
        -- Sudah naik pet yang benar, tapi WalkSpeed bisa saja masih 60 dari
        -- SpeedBoost jalan kaki. Paksa ke kecepatan pet sekarang juga.
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = targetSpeed end
        end)
        return
    end

    -- langkah 1: siapkan hewan (skip kalau sudah ke-prep)
    if (LocalPlayer:GetAttribute("MountPet") or "") ~= best.id then
        pcall(banSafeInvoke, R_STEAL.PenPetAction, "equipmount", best.id)
        task.wait(0.12)
    end
    -- langkah 2: benaran pakai / kendarai hewan (ini yang bikin gerak)
    if R_MOUNT then
        pcall(banSafeInvoke, R_MOUNT, best.id, true)
    else
        pcall(banSafeInvoke, R_STEAL.PenPetAction, "equipbestmount")
    end
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = targetSpeed end
    end)
end
genv.LoopXCode_EquipBestSpeed = equipBestSpeed

-- Watchdog kecepatan pet: selama Auto Catch menyala, WalkSpeed HARUS mengikuti
-- MountConfig.PetSpeed, bukan SpeedBoost/StealCfg.WalkSpeed (60) untuk jalan.
local function ensureMountedSpeed()
    if not mountedNow() then return false end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local target = mountedSpeedTarget()
    if hum and target > 0 then
        pcall(function()
            if math.abs(hum.WalkSpeed - target) > 0.5 then hum.WalkSpeed = target end
        end)
        return true
    end
    task.spawn(equipBestSpeed)
    return false
end
genv.LoopXCode_EnsureMountedSpeed = ensureMountedSpeed

-- Turun dari pet: samakan tombol Ride game saat hewan sedang dipakai.
local function dismountPet()
    if R_MOUNT then
        pcall(banSafeInvoke, R_MOUNT, "", true)
    end
end
genv.LoopXCode_DismountPet = dismountPet

-- Auto Equip Best Pen: tombol "EquipBest" di PetPanel game (bukan
-- EquipBestMount yang cuma mengendarai pet). Ini yang mengisi 14 slot pen
-- dengan pet terbaik dari bag, persis seperti tombol "Equip Best".
local function equipBestPen()
    local remote = R_STEAL and R_STEAL.PenPetAction
    if not remote then return false end
    local ok, res = pcall(banSafeInvoke, remote, "equipbest")
    return ok and type(res) == "table" and res.ok == true
end
genv.LoopXCode_EquipBestPen = equipBestPen

-- Cukup jalan saat jumlah pet di bag berubah, plus sekali saat toggle aktif.
do
    local lastPenBagCount = nil
    local function syncBestPen()
        if not MiscCfg.AutoEquipBestPen then return false end
        local bag = tonumber(LocalPlayer:GetAttribute("BagPets")) or 0
        if lastPenBagCount ~= nil and bag == lastPenBagCount then return false end
        lastPenBagCount = bag
        return equipBestPen()
    end
    pcall(function()
        LocalPlayer:GetAttributeChangedSignal("BagPets"):Connect(function()
            task.spawn(syncBestPen)
        end)
    end)
    task.spawn(function()
        while alive() do
            pcall(syncBestPen)
            task.wait(2.5)
        end
    end)
end

-- Auto Equip Best Speed: event perubahan Mount/MountId + jaga-jaga tiap 3 detik,
-- supaya kalau hewan dilepas / diganti manual, langsung balik ke yang tercepat.
-- Default ikut first-run OFF; Load Config / toggle yang menghidupkan.
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
        -- Auto Catch menyalakan ini walaupun toggle Auto Equip Best Speed OFF,
        -- supaya kecepatan datang dari pet, bukan SpeedBoost jalan kaki.
        if genv.LoopXCode_AutoEquipV2 or StealCfg.Enabled then
            pcall(equipBestSpeed)
            pcall(ensureMountedSpeed)
        end
        task.wait(3)
    end
end)

-- Auto Steal ON  -> pet TETAP ke-ride. Gerak pakai step 6 bertahap (server nerima)
--                  dan pulih dari launch Guardian tiap tick.
-- Auto Steal OFF -> auto-equip tetap jalan, nggak ada yang di-dismount.
-- Anti Hit dinyalakan sementara selama Auto Catch supaya guardian tidak mengejar
-- / melaunch char di map jauh, lalu dikembalikan ke pilihan daddy saat OFF.
-- =====================================================================
-- AUTO FARM EVENT — turkey event, multi map, lasso AMAN saja
-- =====================================================================
do
local FarmCfg = genv.LoopXCode_FarmCfg
local FARM_OWNER = tostring(os.clock()) .. ":" .. tostring(math.random(1, 1000000000))
local R_TURKEY_DEPOSIT = RemoteFolder:FindFirstChild("TurkeyDeposit")
    or RemoteFolder:FindFirstChild("TurkeyDeposit", 5)

local function normalizeFarmMaps(v)
    local list = {}
    local function add(x)
        x = tostring(x or "")
        if x == "" then return end
        for _, old in ipairs(list) do if old == x then return end end
        list[#list + 1] = x
    end
    if type(v) == "table" then
        if v[1] ~= nil then
            for _, x in ipairs(v) do add(x) end
        else
            -- Config bank JSON-encode mengubah array jadi object dengan key
            -- "1","2", jadi baca nilai, bukan key-nya. Set-style {Map=true}
            -- tetap dibaca dari key.
            for k, x in pairs(v) do
                if tonumber(k) ~= nil and type(x) == "string" then
                    add(x)
                elseif type(x) == "boolean" and x then
                    add(k)
                elseif type(x) == "string" then
                    add(x)
                else
                    add(k)
                end
            end
        end
    else
        add(v)
    end
    for _, x in ipairs(list) do
        if x == "Any" or x == "All" or x == "All Map" or x == "Semua Map" then
            return { "Any" }
        end
    end
    for _, x in ipairs(list) do
        local valid = false
        for _, z in ipairs(ZONE_NAMES) do
            if z == x then
                valid = true
                break
            end
        end
        if valid then
            local exists = false
            for _, kept in ipairs(list) do
                if kept == x then
                    exists = true
                    break
                end
            end
            if not exists then list[#list + 1] = x end
        end
    end
    if #list == 0 then return { "Any" } end
    return list
end
genv.LoopXCode_NormalizeFarmMaps = normalizeFarmMaps

local function farmMapAllowed(zone)
    if #FarmCfg.Maps == 0 then return true end
    for _, m in ipairs(FarmCfg.Maps) do
        if m == "Any" or m == "All" or m == "All Map" or m == zone then return true end
    end
    return false
end
genv.LoopXCode_FarmMapAllowed = farmMapAllowed

local function isFarmTurkey(name)
    if type(name) ~= "string" or name == "" then return false end
    if THC and type(THC.TURKEYS) == "table" and THC.TURKEYS[name] then return true end
    local ok, event = pcall(function() return PC.IsEventPet(name) end)
    if ok and event and (name:find("Turkey", 1, true) or name == "GoldenGobbler") then
        return true
    end
    return false
end
genv.LoopXCode_IsFarmTurkey = isFarmTurkey

local function farmHuntFolder()
    local petsGame = workspace:FindFirstChild("PetsGame")
    return petsGame and petsGame:FindFirstChild("TurkeyHunt") or nil
end
local function farmRoundActive()
    local folder = farmHuntFolder()
    return folder ~= nil and folder:GetAttribute("RoundActive") == true
end
local function farmPoints()
    local folder = farmHuntFolder()
    return tonumber(folder and folder:GetAttribute("FeastPoints")) or 0
end
local function farmLevel()
    local folder = farmHuntFolder()
    return tonumber(folder and folder:GetAttribute("FeastLevel")) or 0
end
genv.LoopXCode_FarmRoundActive = farmRoundActive
genv.LoopXCode_FarmPoints = farmPoints
genv.LoopXCode_FarmLevel = farmLevel

local function farmCoins()
    local lp = game:GetService("Players").LocalPlayer
    return tonumber(lp:GetAttribute("TurkeyCoins")) or 0
end
genv.LoopXCode_FarmCoins = farmCoins

local function farmPointsLive()
    local pg = workspace:FindFirstChild("PetsGame")
    local th = pg and pg:FindFirstChild("TurkeyHunt")
    return tonumber(th and th:GetAttribute("FeastPoints")) or 0
end
local function farmLevelLive()
    local pg = workspace:FindFirstChild("PetsGame")
    local th = pg and pg:FindFirstChild("TurkeyHunt")
    return tonumber(th and th:GetAttribute("FeastLevel")) or 0
end

local function refreshFarmCoinUI()
    if typeof(genv.LoopXCode_FarmCoinLabel) ~= "Instance" then return end
    local label = genv.LoopXCode_FarmCoinLabel
    label.Text = string.format("Koin Turkey: %d | Feast: %d | Level: %d",
        farmCoins(), farmPointsLive(), farmLevelLive())
end
genv.LoopXCode_RefreshFarmCoinUI = refreshFarmCoinUI

local function updateFarmCoinText()
    local current = farmCoins()
    FarmCfg.LastCoins = current
    local gained = math.max(0, current - (tonumber(FarmCfg.CoinStart) or current))
    FarmCfg.CoinsGained = gained
    pcall(function()
        if type(genv.LoopXCode_FarmSetCoins) == "function" then
            genv.LoopXCode_FarmSetCoins(string.format("%s: %d | %s: %d",
                tr("Turkey Coins"), current, tr("Coins gained"), gained))
        end
    end)
end
genv.LoopXCode_UpdateFarmCoins = updateFarmCoinText

local function holdingFarmTurkeys()
    local char = LocalPlayer.Character
    if not char then return 0 end
    local count = 0
    local carried = char:FindFirstChild("CarriedPet")
    if carried and isFarmTurkey(carried:GetAttribute("PetName")) then count += 1 end
    for _, container in ipairs({ char, LocalPlayer:FindFirstChildOfClass("Backpack") }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("Turkey") then count += 1 end
            end
        end
    end
    return count
end
genv.LoopXCode_HoldingFarmTurkeys = holdingFarmTurkeys

local function setFarmText(text)
    FarmCfg.LastData = tostring(text or FarmCfg.LastData or "Event Data")
    pcall(function()
        if type(genv.LoopXCode_FarmSetDesc) == "function" then
            genv.LoopXCode_FarmSetDesc(FarmCfg.LastData)
        end
    end)
end

-- Farm target lock disimpan di genv supaya tidak menambah local di chunk utama
-- (Luau membatasi 200 local register per function).
genv.LoopXCode_FarmLock = { model = nil, name = nil, zone = nil, fails = 0, deadline = 0 }
genv.LoopXCode_FarmSkip = genv.LoopXCode_FarmSkip or {}
genv.LoopXCode_ClearFarmLock = function()
    local lock = genv.LoopXCode_FarmLock
    lock.model, lock.name, lock.zone, lock.fails, lock.deadline = nil, nil, nil, 0, 0
end
genv.LoopXCode_FailFarmLock = function(entry)
    local lock = genv.LoopXCode_FarmLock
    if entry and entry.model and lock.model ~= entry.model then return end
    lock.fails += 1
    if lock.fails >= 2 then
        local model = lock.model
        if model then
            local id = tostring(model:GetAttribute("WildId") or model.Name)
            genv.LoopXCode_FarmSkip[id] = os.clock() + 20
        end
        genv.LoopXCode_ClearFarmLock()
    end
end
genv.LoopXCode_FarmLockedEntry = function()
    local lock = genv.LoopXCode_FarmLock
    local model = lock.model
    if not model or model.Parent ~= WildFolder then genv.LoopXCode_ClearFarmLock() return nil end
    if os.clock() > (tonumber(lock.deadline) or 0) then genv.LoopXCode_ClearFarmLock() return nil end
    local skip = genv.LoopXCode_FarmSkip[tostring(model:GetAttribute("WildId") or model.Name)]
    if skip and os.clock() < skip then genv.LoopXCode_ClearFarmLock() return nil end
    if isUncaptured(model:GetAttribute("CapturedBy")) ~= true
        or model:GetAttribute("Despawning") == true then genv.LoopXCode_ClearFarmLock() return nil end
    local info = wildInfo(model)
    if not info or not isFarmTurkey(info.name) or not farmMapAllowed(info.zone)
        or lassoTooWeak(info) then genv.LoopXCode_ClearFarmLock() return nil end
    local coins = 0
    pcall(function()
        local cfg = THC and THC.TURKEYS and THC.TURKEYS[info.name]
        coins = tonumber(cfg and (cfg.Coins or cfg.coins)) or 0
    end)
    return { name = info.name, zone = info.zone, ratio = lassoRatio(info),
        coins = coins, dist = 0, score = 1000 + coins * 2, model = model }
end
genv.LoopXCode_LockFarmTarget = function(entry)
    if not entry or not entry.model then return end
    local lock = genv.LoopXCode_FarmLock
    lock.model, lock.name, lock.zone, lock.fails = entry.model, entry.name, entry.zone, 0
    lock.deadline = os.clock() + 60
end

local function scanFarmTarget(rootPart)
    local locked = genv.LoopXCode_FarmLockedEntry()
    if locked then return locked end
    local entries, byMap = {}, {}
    for _, model in ipairs(WildFolder:GetChildren()) do
        if isUncaptured(model:GetAttribute("CapturedBy"))
            and model:GetAttribute("Despawning") ~= true then
            local info = wildInfo(model)
            if info and isFarmTurkey(info.name) and farmMapAllowed(info.zone)
                and not ((genv.LoopXCode_FarmSkip[tostring(model:GetAttribute("WildId") or model.Name)] or 0) > os.clock()) then
                -- Merah = lasso benar-benar kurang. Skip dan cari yang
                -- hijau/orange memakai ambang warna yang sama dengan game.
                if not lassoTooWeak(info) then
                    local ratio = lassoRatio(info)
                    local coins = 0
                    pcall(function()
                        local cfg = THC and THC.TURKEYS and THC.TURKEYS[info.name]
                        coins = tonumber(cfg and (cfg.Coins or cfg.coins)) or 0
                    end)
                    local dist = rootPart and (info.pos - rootPart.Position).Magnitude or 0
                    local score = (ratio >= 1 and 200 or 100) + coins * 2
                        + math.max(0, 1000 - dist)
                    entries[#entries + 1] = {
                        name = info.name, zone = info.zone, ratio = ratio,
                        coins = coins, dist = dist, score = score, model = model
                    }
                    byMap[info.zone] = (byMap[info.zone] or 0) + 1
                end
            end
        end
    end
    table.sort(entries, function(a, b) return a.score > b.score end)
    local keys = {}
    for zone in pairs(byMap) do keys[#keys + 1] = zone end
    table.sort(keys)
    local parts = {}
    for _, zone in ipairs(keys) do parts[#parts + 1] = zone .. ":" .. byMap[zone] end
    FarmCfg.ScanLine = string.format("Event scan: %d turkeys%s", #entries,
        #parts > 0 and (" | " .. table.concat(parts, ", ")) or "")
    if #entries == 0 then
        setFarmText(tr("No lasso-safe turkey found") .. " | " .. FarmCfg.ScanLine)
    else
        setFarmText(FarmCfg.ScanLine)
    end
    return entries[1]
end
genv.LoopXCode_FarmScan = scanFarmTarget

local function farmRoam(rootPart, zoneHint)
    if not rootPart then return end
    local maps = FarmCfg.Maps
    if #maps == 0 or maps[1] == "Any" then
        -- Kalau target turkey baru saja gagal, tetap di map-nya dulu. Jangan
        -- keliling global yang bikin farm bolak-balik lintas biome.
        if zoneHint and zoneHint ~= "Any" then
            pcall(stageToZone, rootPart, zoneHint)
            task.wait(0.2)
            return
        end
        pcall(roamToNextZone, rootPart)
        return
    end
    FarmCfg.ScanIndex = FarmCfg.ScanIndex % #maps + 1
    local zone = maps[FarmCfg.ScanIndex]
    local startZ, finishZ = zoneSpan(zone)
    if not startZ then return end
    local center = (startZ + finishZ) / 2
    local len = math.abs(finishZ - startZ)
    local offsets = { -0.25, 0.25, 0, -0.12, 0.12 }
    local off = offsets[FarmCfg.ScanIndex % #offsets + 1]
    local dest = Vector3.new(0, rootPart.Position.Y, center + len * off)
    rushToPoint(rootPart, function() return dest end, 10,
        math.clamp(len / 60 + 30, 20, 240), configuredWalkSpeed(120))
end

local function farmDeposit()
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false, "no character" end
    if os.clock() - (tonumber(FarmCfg.LastDepositAt) or 0) < 2 then
        return false, "cooldown"
    end
    local count = holdingFarmTurkeys()
    if count <= 0 then return false, "no turkey" end
    if not farmRoundActive() then return false, "round inactive" end

    -- Carrying sudah dilepas game di Safe Zone. Sekarang jalan ke Pig Chef
    -- (atau ChefSpot saat round aktif) supaya remote deposit diterima server.
    local folder = farmHuntFolder()
    local spot = folder and (folder:FindFirstChild("ChefSpot") or folder:FindFirstChild("PigChef"))
    local chefPos = nil
    pcall(function()
        if spot then
            chefPos = spot:IsA("BasePart") and spot.Position or spot:GetPivot().Position
        end
    end)
    if chefPos then
        rushToPoint(rootPart, function() return chefPos end, 12, 45, configuredWalkSpeed(120))
    end

    count = holdingFarmTurkeys()
    if count <= 0 then
        setFarmText(string.format("Event deposit: %d turkeys | Feast +0 | Points %d | Level %d",
            0, farmPoints(), farmLevel()))
        return false, "lost before deposit"
    end

    FarmCfg.LastDepositAt = os.clock()
    local before = farmPoints()
    local coinsBefore = farmCoins()
    local fired = pcall(banSafeFire, R_TURKEY_DEPOSIT)
    if not fired then return false, "deposit remote error" end
    local after = before
    for _ = 1, 30 do
        task.wait(0.1)
        after = farmPoints()
        if after > before or holdingFarmTurkeys() == 0 then break end
    end
    for _ = 1, 20 do
        if farmCoins() > coinsBefore or not farmRoundActive() then break end
        task.wait(0.1)
    end
    local gain = math.max(0, after - before)
    local coinGain = math.max(0, farmCoins() - coinsBefore)
    FarmCfg.LastPoints = after
    FarmCfg.LastLevel = farmLevel()
    FarmCfg.LastGain = gain
    if gain > 0 then FarmCfg.Deposits += 1 end
    updateFarmCoinText()
    local data = string.format("Event deposit: %d turkeys | Feast +%d | Points %d | Level %d | Coins +%d",
        count, gain, after, FarmCfg.LastLevel, coinGain)
    setFarmText(data)
    hubNotify(string.format(tr("Event deposit: %d turkeys"), count),
        gain > 0 and "Success" or "Info")
    return gain > 0, data
end
genv.LoopXCode_FarmDeposit = farmDeposit

local function farmLoop()
    if genv.LoopXCode_FarmOwner == FARM_OWNER then return end
    genv.LoopXCode_FarmOwner = FARM_OWNER
    task.spawn(function()
        while FarmCfg.Enabled do
            updateFarmCoinText()
            -- Auto Catch diprioritaskan. Toggle Auto Farm tetap ON di UI, tapi
            -- loop-nya standby supaya dua driver nggak berebut MoveTo.
            if StealCfg.Enabled then
                FarmCfg.LastTarget = "standby: Auto Catch"
                task.wait(0.5)
                continue
            end
            -- Event belum ada / round belum aktif: diam, jangan scan, jangan
            -- jalan-jalan, jangan kirim notifikasi. Cuma tunggu sampai aktif.
            if farmRoundActive() then
                pcall(equipBestSpeed)
                pcall(ensureMountedSpeed)
                local char = LocalPlayer.Character
                local rootPart = char and char:FindFirstChild("HumanoidRootPart")
                if rootPart and not ManualSteal.Active and not StealCfg.Busy then
                    local target = scanFarmTarget(rootPart)
                    if target then
                        genv.LoopXCode_LockFarmTarget(target)
                        FarmCfg.LastTarget = target.name .. " (" .. tostring(target.zone) .. ")"
                        pcall(startManualSteal, target.name, target.zone)
                        local deadline = os.clock() + 45
                        while FarmCfg.Enabled and ManualSteal.Active and os.clock() < deadline do
                            task.wait(0.2)
                        end
                        if FarmCfg.Enabled then
                            if holdingFarmTurkeys() > 0 then
                                pcall(farmDeposit)
                                pcall(genv.LoopXCode_ClearFarmLock)
                                FarmCfg.FailStreak = 0
                            else
                                pcall(genv.LoopXCode_FailFarmLock, target)
                                FarmCfg.FailStreak = (FarmCfg.FailStreak or 0) + 1
                                if FarmCfg.FailStreak >= 3 then
                                    for id in pairs(genv.LoopXCode_FarmSkip) do
                                        genv.LoopXCode_FarmSkip[id] = nil
                                    end
                                    FarmCfg.FailStreak = 0
                                end
                                pcall(farmRoam, rootPart, target.zone)
                            end
                        end
                    else
                        FarmCfg.LastTarget = "none"
                        pcall(farmRoam, rootPart)
                        task.wait(0.8)
                    end
                end
                task.wait(0.4)
            else
                task.wait(1)
            end
        end
        if genv.LoopXCode_FarmOwner == FARM_OWNER then genv.LoopXCode_FarmOwner = nil end
    end)
end

local farmAntiHitPrev = nil
local function applyAutoFarm(v)
    v = (v == true)
    if v then
        -- Matikan NoClip sementara. Toggle UI No Clip tetap ON di config;
        -- setelah farm selesai otomatis nyala lagi.
        farmAntiHitPrev = genv.LoopXCode_HardenCfg.AntiHit == true
            and genv.LoopXCode_NoClipState.active == true
        if farmAntiHitPrev then pcall(function() genv.LoopXCode_StopNoClip() end) end
        -- Auto Catch dan Auto Farm boleh sama-sama ON. farmLoop yang standby
        -- saat catch aktif; jangan matikan toggle Catch dari sini.
        if genv.LoopXCode_HardenCfg.AutoTreadmill then
            pcall(function() genv.LoopXCode_HardenToggle("AutoTreadmill", false) end)
            setUIValue(UIHandles["Auto Treadmill"], false)
        end
        if genv.LoopXCode_HardenCfg.AdminEventTreadmill then
            pcall(function() genv.LoopXCode_HardenToggle("AdminEventTreadmill", false) end)
            setUIValue(UIHandles["Auto Treadmill Admin Event"], false)
        end
        FarmCfg.Enabled = true
        FarmCfg.CoinStart = farmCoins()
        FarmCfg.LastCoins = FarmCfg.CoinStart
        FarmCfg.CoinsGained = 0
        updateFarmCoinText()
        task.spawn(equipBestSpeed)
        task.spawn(function()
            task.wait(0.25)
            pcall(ensureMountedSpeed)
        end)
        setStatus("on system", tr("Auto farm ON"))
        hubNotify(tr("Auto farm ON"), "Success")
        farmLoop()
    else
        FarmCfg.Enabled = false
        if farmAntiHitPrev and not StealCfg.Enabled and not ManualSteal.Active then
            pcall(function() genv.LoopXCode_StartNoClip() end)
            farmAntiHitPrev = nil
        end
        if not StealCfg.Enabled and not ManualSteal.Active then setStatus("idle", "any detect") end
        hubNotify(tr("Auto farm OFF"), "Info")
    end
    updateFarmCoinText()
    setFarmText(FarmCfg.LastData)
end
genv.LoopXCode_ApplyAutoFarm = applyAutoFarm
end

local autoStealAntiHitPrev = nil
local function applyAutoSteal(v)
    local FarmCfg = genv.LoopXCode_FarmCfg
    StealCfg.Enabled = (v == true)
    -- Auto Farm tetap ON di UI; farmLoop akan standby selama catch aktif.
    if StealCfg.Enabled and genv.LoopXCode_HardenCfg.AutoTreadmill then
        pcall(function() genv.LoopXCode_HardenToggle("AutoTreadmill", false) end)
    end
    if StealCfg.Enabled and genv.LoopXCode_HardenCfg.AdminEventTreadmill then
        -- Auto Catch butuh jalan-jalan; event treadmill butuh diam di tap.
        pcall(function() genv.LoopXCode_HardenToggle("AdminEventTreadmill", false) end)
        setUIValue(UIHandles["Auto Treadmill Admin Event"], false)
    end
    if StealCfg.Enabled then
        -- NoClip bikin char mengambang & MoveTo gagal. Suspended selama hunting,
        -- lalu dinyalakan lagi begitu Auto Catch / Farm / Manual selesai.
        autoStealAntiHitPrev = genv.LoopXCode_HardenCfg.AntiHit == true
            and genv.LoopXCode_NoClipState.active == true
        if autoStealAntiHitPrev then pcall(function() genv.LoopXCode_StopNoClip() end) end
        local huntChar = LocalPlayer.Character
        local huntRoot = huntChar and huntChar:FindFirstChild("HumanoidRootPart")
        local huntHum = huntChar and huntChar:FindFirstChildOfClass("Humanoid")
        if huntRoot and huntHum and (huntRoot.Position.Y > 120
            or huntHum:GetState() == Enum.HumanoidStateType.Freefall) then
            pcall(function() genv.LoopXCode_Respawn() end)
        end
        -- pastikan hewan ke-ride sebelum jalan (tanpa turun dari pet).
        -- Selalu dipanggil saat Auto Catch ON, terlepas dari toggle Auto Equip.
        task.spawn(equipBestSpeed)
        task.spawn(function()
            task.wait(0.25)
            pcall(ensureMountedSpeed)
        end)
        setStatus("on system", "any detect")
        stealLoop()
    else
        StealCfg.Busy = false
        updateStealInfo(nil)
        if autoStealAntiHitPrev and not FarmCfg.Enabled and not ManualSteal.Active then
            pcall(function() genv.LoopXCode_StartNoClip() end)
            autoStealAntiHitPrev = nil
        end
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

    local ok, result = pcall(banSafeInvoke, TutorialRemote, "skip")
    if (not ok or not serverAccepted(result)) and step > 0 then
        pcall(banSafeInvoke, TutorialRemote, "uidone", id)
    end
end
genv.LoopXCode_SkipTutorial = SkipTutorial

-- =====================================================================
-- 3. ESP
-- =====================================================================
local Camera = Workspace.CurrentCamera
local ESPConfig = {
    Enabled = defaultToggle(true),
    ToggleKey = Enum.KeyCode.Q,
    MaxDistance = 1500,
    FixedSize = true,
    ShowInfo = defaultToggle(true),

    -- Player ESP
    ESPPlayers = defaultToggle(true),
    TeamCheck = false,
    PlayerSize = 14,
    PlayerColor = Color3.fromRGB(255, 92, 40),

    -- Pet / Guard ESP
    ESPGuards = defaultToggle(true),
    ESPPets = defaultToggle(true),
    GuardSize = 13,
    PetSize = 13,
    GuardColor = Color3.fromRGB(251, 191, 36),
    PetColor = Color3.fromRGB(56, 189, 248),

    -- Scan entity tiap 1.5 detik; renderBillboard tiap frame.
    ScanInterval = 1.5,
    TargetFolders = { "Guards", "Pets", "NPCs", "Enemies", "Mobs", "WildPets", "PetsGame", "Guardians" },

    -- Style lama tetap disimpan supaya input ESP Style tidak putus. Warna &
    -- ukuran dipetakan ke field di atas; shadow/font jadi kompatibilitas UI.
    Styles = {
        Any = { Size = 13, Shadow = 50, ShadowOffset = 1, Font = "Bold", Color = "#8AD7FF" },
        Player = { Size = 14, Shadow = 50, ShadowOffset = 1, Font = "Bold", Color = "#FF5C28" },
        Pet = { Size = 13, Shadow = 50, ShadowOffset = 1, Font = "Bold", Color = "#38BDF8" },
        Guard = { Size = 13, Shadow = 50, ShadowOffset = 1, Font = "Bold", Color = "#FBBF24" }
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
        if key == "Size" then
            ESPConfig[cat .. "Size"] = math.clamp(math.floor(tonumber(value) or 13), 10, 28)
        elseif key == "Color" then
            local fallback = cat == "Player" and ESPConfig.PlayerColor
                or cat == "Guard" and ESPConfig.GuardColor
                or ESPConfig.PetColor
            ESPConfig[cat .. "Color"] = colorFromInput(value, fallback)
        end
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
        Placeholder = "50  (0 = off, 100 = solid)",
        Callback = function(v)
            setEspStyle(category, "Shadow", math.clamp(tonumber(v) or 50, 0, 100))
        end
    })
    section:Input({
        Title = label .. " ESP Shadow Offset",
        Value = tostring(ESPConfig.Styles[category].ShadowOffset),
        Placeholder = "1",
        Callback = function(v)
            setEspStyle(category, "ShadowOffset", math.clamp(math.floor(tonumber(v) or 1), 0, 12))
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

-- Renderer ESP mengikuti ContohESP.luau: BillboardGui + TextLabel di
-- ScreenGui, scan tiap 1.5 detik, update tiap frame. Dipisah di scope sendiri
-- supaya lokal-nya tidak memakan register chunk utama.
local function buildESP()
local GuiParent = GetSafeGuiParent()
for _, root in ipairs(cleanupRoots) do
    pcall(function()
        local old = root:FindFirstChild("ChilliStyleESP_UI")
        if old then old:Destroy() end
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChilliStyleESP_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GuiParent

local BillboardHolder = Instance.new("Folder")
BillboardHolder.Name = "ESP_Holder"
BillboardHolder.Parent = ScreenGui

local ESPCache = {}
local TrackedEntities = {}
local espAlive = true
local RenderConn, FocusConn, FocusReleaseConn, InputConn
local IsTyping = false

genv.LoopXCode_ESPGui = ScreenGui

local function GetAnchorPart(model)
    if not model or not model.Parent then return nil end
    if model:IsA("BasePart") then return model end
    return model:FindFirstChild("Head")
        or model:FindFirstChild("RootPart")
        or model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function ClassifyEntity(model)
    if not model or not model:IsA("Model") then return nil end
    if Players:GetPlayerFromCharacter(model) then return nil end

    local lowerName = string.lower(model.Name)
    local parentName = model.Parent and string.lower(model.Parent.Name) or ""
    local hum = model:FindFirstChildOfClass("Humanoid")

    if model:GetAttribute("Guardian") == true or model:GetAttribute("Boss") then
        return "Guard"
    end
    if model:GetAttribute("PetName") then
        return "Pet"
    end
    if string.find(lowerName, "guard") or string.find(parentName, "guard")
        or string.find(lowerName, "enemy") or string.find(parentName, "enemy") then
        return "Guard"
    end
    if string.find(lowerName, "pet") or string.find(parentName, "pet")
        or parentName == "wildpets" or parentName == "penpets" then
        return "Pet"
    end
    if hum and hum.Health > 0 then
        return "Guard"
    end
    return nil
end

task.spawn(function()
    while espAlive and ScreenGui.Parent do
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
        local tracked = 0
        for _ in pairs(found) do tracked += 1 end
        genv.LoopXCode_ESPTracked = tracked
        task.wait(math.max(0.5, tonumber(ESPConfig.ScanInterval) or 1.5))
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

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 0.2
        lbl.TextStrokeColor3 = Color3.fromRGB(12, 12, 16)
        lbl.TextWrapped = false
        lbl.Parent = bb

        entry = { Gui = bb, Label = lbl, Category = category }
        ESPCache[model] = entry
    elseif entry.Gui.Adornee ~= anchor then
        entry.Gui.Adornee = anchor
    end
    return entry
end

local function PruneESPCache()
    for model, entry in pairs(ESPCache) do
        local validModel = model and model.Parent ~= nil
        local adornee = entry.Gui and entry.Gui.Adornee or nil
        local validAdornee = adornee and adornee.Parent ~= nil
        if not validModel or not validAdornee then
            if entry.Gui then pcall(function() entry.Gui:Destroy() end) end
            ESPCache[model] = nil
        end
    end
end

local function ApplyTextSize(entry, sizePx)
    local sig = tostring(ESPConfig.FixedSize) .. "|" .. tostring(sizePx)
    if entry.SizeSig == sig then return end
    entry.SizeSig = sig
    if ESPConfig.FixedSize then
        entry.Gui.Size = UDim2.new(0, 280, 0, sizePx + 12)
        entry.Label.TextScaled = false
        entry.Label.TextSize = sizePx
    else
        entry.Gui.Size = UDim2.new(0, 200, 0, 44)
        entry.Label.TextScaled = true
    end
end
local lastEspRender = 0
RenderConn = RunService.RenderStepped:Connect(function()
    if not espAlive or not ScreenGui.Parent then return end
    local now = os.clock()
    if now - lastEspRender < 0.05 then return end
    lastEspRender = now
    PruneESPCache()

    local myChar = LocalPlayer.Character
    local myRoot = myChar and GetAnchorPart(myChar)
    local origin = myRoot and myRoot.Position or Camera.CFrame.Position
    local shown = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local anchor = GetAnchorPart(char)
            if anchor and hum and hum.Health > 0 then
                local dist = (anchor.Position - origin).Magnitude
                local teamPass = (not ESPConfig.TeamCheck) or (plr.Team ~= LocalPlayer.Team)
                local show = ESPConfig.Enabled and ESPConfig.ESPPlayers
                    and teamPass and dist <= ESPConfig.MaxDistance
                local entry = show and EnsureBillboard(char, "Player") or ESPCache[char]
                if entry then
                    entry.Gui.Enabled = show
                    if show then
                        shown += 1
                        ApplyTextSize(entry, ESPConfig.PlayerSize)
                        entry.Label.TextColor3 = ESPConfig.PlayerColor
                        local nameStr = (plr.DisplayName ~= plr.Name)
                            and (plr.DisplayName .. " (@" .. plr.Name .. ")")
                            or plr.Name
                        local text = ESPConfig.ShowInfo
                            and string.format("[%dm] %s • %d HP",
                                math.floor(dist), nameStr, math.floor(hum.Health))
                            or nameStr
                        if entry.LastText ~= text then
                            entry.LastText = text
                            entry.Label.Text = text
                        end
                    end
                end
            end
        end
    end

    for model, category in pairs(TrackedEntities) do
        if model and model.Parent then
            local anchor = GetAnchorPart(model)
            local hum = model:FindFirstChildOfClass("Humanoid")
            if anchor and (not hum or hum.Health > 0) then
                local dist = (anchor.Position - origin).Magnitude
                local catEnabled = (category == "Guard" and ESPConfig.ESPGuards)
                    or (category == "Pet" and ESPConfig.ESPPets)
                local show = ESPConfig.Enabled and catEnabled and dist <= ESPConfig.MaxDistance
                local entry = show and EnsureBillboard(model, category) or ESPCache[model]
                if entry then
                    entry.Gui.Enabled = show
                    if show then
                        shown += 1
                        local isGuard = category == "Guard"
                        local sizePx = isGuard and ESPConfig.GuardSize or ESPConfig.PetSize
                        local colorVal = isGuard and ESPConfig.GuardColor or ESPConfig.PetColor
                        ApplyTextSize(entry, sizePx)
                        entry.Label.TextColor3 = colorVal
                        local tag = isGuard and "GUARD" or "PET"
                        local hpPart = (hum and ESPConfig.ShowInfo)
                            and string.format(" • %d HP", math.floor(hum.Health)) or ""
                        local distPart = ESPConfig.ShowInfo
                            and string.format("[%dm] ", math.floor(dist)) or ""
                        local text = string.format("%s[%s] %s%s", distPart, tag, model.Name, hpPart)
                        if entry.LastText ~= text then
                            entry.LastText = text
                            entry.Label.Text = text
                        end
                    end
                end
            end
        end
    end

    local cached = 0
    for _ in pairs(ESPCache) do cached += 1 end
    genv.LoopXCode_ESPStats = {
        drawn = shown, cached = cached,
        tracked = genv.LoopXCode_ESPTracked or 0, ui = true
    }
end)

FocusConn = UserInputService.TextBoxFocused:Connect(function() IsTyping = true end)
FocusReleaseConn = UserInputService.TextBoxFocusReleased:Connect(function() IsTyping = false end)
pcall(function()
    InputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and not IsTyping and input.KeyCode == ESPConfig.ToggleKey then
            ESPConfig.Enabled = not ESPConfig.Enabled
        end
    end)
end)

OnCleanup(function()
    espAlive = false
    if RenderConn then pcall(function() RenderConn:Disconnect() end) end
    if FocusConn then pcall(function() FocusConn:Disconnect() end) end
    if FocusReleaseConn then pcall(function() FocusReleaseConn:Disconnect() end) end
    if InputConn then pcall(function() InputConn:Disconnect() end) end
    for _, entry in pairs(ESPCache) do
        if entry.Gui then pcall(function() entry.Gui:Destroy() end) end
    end
    pcall(function() ScreenGui:Destroy() end)
    ESPCache, TrackedEntities = {}, {}
    genv.LoopXCode_ESPStats = { drawn = 0, cached = 0, tracked = 0, ui = false }
end)

genv.LoopXCode_ESPStats = { drawn = 0, cached = 0, tracked = 0, ui = true }
end
buildESP()

-- =====================================================================
-- 4. EXTENDED HACKS — remote tervalidasi, efek hanya untuk LocalPlayer
-- =====================================================================
-- Scope terpisah supaya ratusan lokal di engine ini tidak memakan register
-- chunk utama. State penting diekspor lewat genv untuk dipakai registry/UI.
local function buildHarden()
genv.LoopXCode_HardenCfg = {
    SaveHistory = true, SaveUI = true, SaveMenu = true,
    AutoClaimIndex = true, AutoUpgradeTraining = false, AutoUpgradeTreadmill = false, AutoTreadmill = false,
    AdminEventTreadmill = false,
    AntiBan = true, GodMode = false, Fly = false, JumpInfinity = false,
    AntiKnockDown = true, Invisible = false, AntiRagdoll = true, AutoAntiSpeed = false,
    AntiAFK = true, AntiHit = false, SpeedBoost = false,
    UnlockFPS = false, UnlockFPSValue = 240, AutoLow = false, HidePetPen = false
}
genv.LoopXCode_HardenEpoch = (tonumber(genv.LoopXCode_HardenEpoch) or 0) + 1
local HARDEN_EPOCH = genv.LoopXCode_HardenEpoch

-- Anti AFK: game mengirim Analytics("Idle", ...) lewat LocalPlayer.Idled.
-- Reporter game diputus saat aktif, engine tetap dijaga pakai VirtualUser.
local okVU, VirtualUser = pcall(function() return game:GetService("VirtualUser") end)
if not okVU then VirtualUser = nil end
local AFK = genv.LoopXCode_AFKState
if type(AFK) ~= "table" then
    AFK = { owner = nil, enabled = false, idleConn = nil, blocked = false,
        restoreIdle = nil, restoreInputs = {} }
    genv.LoopXCode_AFKState = AFK
end
AFK.restoreInputs = AFK.restoreInputs or {}

local function analyticsIdleConnection(conn)
    local fn = type(conn.Function) == "function" and conn.Function or nil
    if not fn then return false end
    local src = ""
    pcall(function()
        local env = getfenv and getfenv(fn) or nil
        src = env and env.script and env.script:GetFullName() or ""
    end)
    if string.find(src, "AnalyticsClient", 1, true) then return true end
    pcall(function()
        local info = debug.getinfo(fn)
        local short = info and info.short_src or ""
        if string.find(short, "AnalyticsClient", 1, true) then src = short end
    end)
    return string.find(src, "AnalyticsClient", 1, true) ~= nil
end

local function pokeEngineActive()
    if not VirtualUser then return end
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
end

local function disconnectRestoreReporter()
    if AFK.restoreIdle then
        pcall(function() AFK.restoreIdle:Disconnect() end)
        AFK.restoreIdle = nil
    end
    for i, conn in ipairs(AFK.restoreInputs) do
        pcall(function() conn:Disconnect() end)
        AFK.restoreInputs[i] = nil
    end
end

local function blockGameIdleReporter()
    local removed = 0
    pcall(function()
        for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
            if analyticsIdleConnection(conn) then
                pcall(function() conn:Disconnect() end)
                removed += 1
            end
        end
    end)
    if removed > 0 then AFK.blocked = true end
    return removed
end

local function restoreGameIdleReporter()
    local gameReporter = false
    pcall(function()
        for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
            if analyticsIdleConnection(conn) then gameReporter = true end
        end
    end)
    if gameReporter then
        AFK.blocked = false
        return
    end
    if AFK.restoreIdle then return end
    disconnectRestoreReporter()
    local remote = RemoteFolder:FindFirstChild("Analytics")
    if not remote then return end
    pcall(function()
        local pending = false
        AFK.restoreIdle = LocalPlayer.Idled:Connect(function(seconds)
            pending = true
            banSafeFire(remote, "Idle", seconds)
        end)
        local function active()
            if pending then
                pending = false
                banSafeFire(remote, "Active")
            end
        end
        AFK.restoreInputs[1] = UserInputService.InputBegan:Connect(active)
        AFK.restoreInputs[2] = UserInputService.InputChanged:Connect(active)
        AFK.blocked = false
    end)
end

local function setAntiAFK(enabled)
    enabled = enabled == true
    if AFK.owner ~= HARDEN_EPOCH then
        local wasEnabled = AFK.enabled
        if AFK.idleConn then
            pcall(function() AFK.idleConn:Disconnect() end)
            AFK.idleConn = nil
        end
        AFK.owner = HARDEN_EPOCH
        if wasEnabled then restoreGameIdleReporter() end
    end
    if enabled then
        blockGameIdleReporter()
        if not AFK.idleConn then
            AFK.idleConn = RunService.Heartbeat:Connect(function()
                if AFK.enabled and HARDEN_EPOCH == genv.LoopXCode_HardenEpoch then pokeEngineActive() end
            end)
        end
        AFK.enabled = true
        pcall(genv.LoopXCode_PauseStart)
        task.spawn(pokeEngineActive)
    else
        if AFK.idleConn then
            pcall(function() AFK.idleConn:Disconnect() end)
            AFK.idleConn = nil
        end
        AFK.enabled = false
        restoreGameIdleReporter()
    end
end
genv.LoopXCode_SetAntiAFK = setAntiAFK
genv.LoopXCode_AntiAFKState = function()
    local idle, analytics = 0, 0
    pcall(function()
        for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
            idle += 1
            if analyticsIdleConnection(conn) then analytics += 1 end
        end
    end)
    return {
        enabled = AFK.enabled, blocked = AFK.blocked,
        watcher = AFK.idleConn ~= nil, replacement = AFK.restoreIdle ~= nil,
        idleConnections = idle, analyticsConnections = analytics, owner = AFK.owner
    }
end
OnCleanup(function()
    if HARDEN_EPOCH == genv.LoopXCode_HardenEpoch then setAntiAFK(false) end
end)
setAntiAFK(genv.LoopXCode_HardenCfg.AntiAFK)

local HardenHistory = {}
genv.LoopXCode_HardenAlive = function()
    return not STATE or type(STATE.alive) ~= "function" or STATE.alive()
end
genv.LoopXCode_HardenAlive = function()
    return HARDEN_EPOCH == genv.LoopXCode_HardenEpoch
        and (not STATE or type(STATE.alive) ~= "function" or STATE.alive())
end

-- No Clip: tembus semua tembok tanpa membekukan guardian / tanpa freeze parts.
-- Kollisi character dimatikan, ketinggian hover dijaga, dan velocity jatuh
-- dinetralisir. Ringan: hanya sink part 2x/detik + koreksi Y di Heartbeat.
local NoClip = {
    active = false, parts = {}, groups = {}, hoverY = nil, lastXZ = nil,
    conn = nil, nextSync = 0, cache = {}, shakeOriginal = nil,
    changeStateInstalled = false, capturingPrev = nil, capturingOwned = false,
    groupReady = false
}
genv.LoopXCode_AntiHitState = NoClip
genv.LoopXCode_NoClipState = NoClip

-- SpawnSafety milik game melewati watchdog kalau atribut Capturing/Training true,
-- dan semua raycast/overlap-nya memakai CollisionGroup HumanoidRootPart.
-- Dua kunci itu dipakai bersama supaya keluar dari tembok nggak di-teleport
-- balik ke safe spot. Tidak ada part guardian yang dibekukan.
local NOCLIP_GROUP = "LXC_NoClip"
local PhysicsService = game:GetService("PhysicsService")
pcall(function()
    pcall(function() PhysicsService:CreateCollisionGroup(NOCLIP_GROUP) end)
    PhysicsService:SetCollisionGroupPairEnabled(NOCLIP_GROUP, "Default", false)
    NoClip.groupReady = true
end)

local function setSafetyCapture(enabled)
    if enabled then
        if not NoClip.capturingOwned then
            NoClip.capturingPrev = LocalPlayer:GetAttribute("Capturing")
            NoClip.capturingOwned = true
        end
        if LocalPlayer:GetAttribute("Capturing") ~= true then
            pcall(function() LocalPlayer:SetAttribute("Capturing", true) end)
        end
    elseif NoClip.capturingOwned then
        local prev = NoClip.capturingPrev
        if prev ~= true and LocalPlayer:GetAttribute("Capturing") == true then
            pcall(function() LocalPlayer:SetAttribute("Capturing", prev) end)
        end
        NoClip.capturingPrev = nil
        NoClip.capturingOwned = false
    end
end
genv.LoopXCode_NoClipSafetyCapture = setSafetyCapture

local function applyNoClipParts(char, enabled)
    if not char then return end
    pcall(function()
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                if enabled then
                    if NoClip.parts[obj] == nil then NoClip.parts[obj] = obj.CanCollide end
                    if NoClip.groups[obj] == nil then NoClip.groups[obj] = obj.CollisionGroup end
                    if obj.CanCollide then obj.CanCollide = false end
                    if NoClip.groupReady and obj.CollisionGroup ~= NOCLIP_GROUP then
                        pcall(function() obj.CollisionGroup = NOCLIP_GROUP end)
                    end
                else
                    if NoClip.parts[obj] ~= nil then
                        if obj.Parent then obj.CanCollide = NoClip.parts[obj] end
                        NoClip.parts[obj] = nil
                    end
                    if NoClip.groups[obj] ~= nil then
                        if obj.Parent then pcall(function() obj.CollisionGroup = NoClip.groups[obj] end) end
                        NoClip.groups[obj] = nil
                    end
                end
            end
        end
    end)
end
genv.LoopXCode_ApplyNoClipParts = applyNoClipParts

local function stopNoClip()
    if not NoClip.active and not NoClip.conn then return end
    NoClip.active = false
    genv.LoopXCode_AntiHitActive = false
    setSafetyCapture(false)
    if NoClip.conn then
        pcall(function() NoClip.conn:Disconnect() end)
        NoClip.conn = nil
    end
    applyNoClipParts(LocalPlayer.Character, false)
    NoClip.hoverY, NoClip.lastXZ = nil, nil
end
genv.LoopXCode_StopNoClip = stopNoClip

local function startNoClip()
    if NoClip.active then return true end
    -- NoClip dan Auto Catch/Auto Farm tidak boleh jalan bareng: hover melawan
    -- MoveTo bikin char nyangkut di udara (Freefall) dan capture gagal semua.
    local farmState = genv.LoopXCode_FarmCfg
    if StealCfg.Enabled or ManualSteal.Active or (farmState and farmState.Enabled) then
        return false
    end
    NoClip.active = true
    genv.LoopXCode_AntiHitActive = true
    pcall(setSafetyCapture, true)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    NoClip.hoverY = root and root.Position.Y or nil
    NoClip.lastXZ = root and Vector2.new(root.Position.X, root.Position.Z) or nil
    applyNoClipParts(char, true)
    if NoClip.conn then pcall(function() NoClip.conn:Disconnect() end) end
    NoClip.conn = RunService.Heartbeat:Connect(function()
        if not NoClip.active or HARDEN_EPOCH ~= genv.LoopXCode_HardenEpoch then return end
        local ch = LocalPlayer.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local now = os.clock()
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if now >= NoClip.nextSync then
            applyNoClipParts(ch, true)
            pcall(setSafetyCapture, true)
            NoClip.nextSync = now + 0.5
            -- Guardian bisa melempar char ke Freefall/Ragdoll. Kembalikan ke
            -- Running supaya MoveTo Auto Catch tetap bekerja.
            if hum then
                local st = hum:GetState()
                if st == Enum.HumanoidStateType.Freefall
                    or st == Enum.HumanoidStateType.FallingDown
                    or st == Enum.HumanoidStateType.Ragdoll
                    or st == Enum.HumanoidStateType.Physics then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                end
            end
        end
        local xz = Vector2.new(hrp.Position.X, hrp.Position.Z)
        -- hoverY mengikuti ketinggian normal, TAPI tidak pernah naik karena
        -- lemparan guardian. Kalau char terlempar, tarik balik ke hover asli.
        if not NoClip.hoverY then
            NoClip.hoverY = hrp.Position.Y
        elseif hrp.Position.Y > NoClip.hoverY + 4 then
            local st = hum and hum:GetState() or nil
            if st ~= Enum.HumanoidStateType.Freefall
                and st ~= Enum.HumanoidStateType.FallingDown
                and st ~= Enum.HumanoidStateType.Ragdoll
                and st ~= Enum.HumanoidStateType.Physics then
                NoClip.hoverY = hrp.Position.Y
            end
        end
        NoClip.lastXZ = xz
        local v = hrp.AssemblyLinearVelocity
        if math.abs(v.Y) > 0.01 then
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        end
        if NoClip.hoverY and math.abs(hrp.Position.Y - NoClip.hoverY) > 1 then
            local cf = hrp.CFrame
            hrp.CFrame = CFrame.new(cf.Position.X, NoClip.hoverY, cf.Position.Z)
                * (cf - cf.Position)
        end
    end)
    return true
end
genv.LoopXCode_StartNoClip = startNoClip
OnCleanup(stopNoClip)

local R_INDEX = RemoteFolder:FindFirstChild("IndexAction")
local R_FREE = RemoteFolder:FindFirstChild("FreeReward")
local R_OFFLINE = RemoteFolder:FindFirstChild("OfflineEarnings")
local R_TRAIN = RemoteFolder:FindFirstChild("TrainTap")
local R_UP_DUMMY = RemoteFolder:FindFirstChild("UpgradeDummy")
local R_UP_PEN = RemoteFolder:FindFirstChild("UpgradePen")

local function hInvoke(remote, ...)
    return banSafeInvoke(remote, ...)
end

local function hFire(remote, ...)
    return banSafeFire(remote, ...)
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

        local okList, list = pcall(banSafeInvoke, R_SELL, "list")
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
        local okSell, result = pcall(banSafeInvoke, R_SELL, "sell", ids)
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
            AdminEventTreadmill = genv.LoopXCode_HardenCfg.AdminEventTreadmill,
            AntiBan = genv.LoopXCode_HardenCfg.AntiBan, GodMode = genv.LoopXCode_HardenCfg.GodMode,
            Fly = genv.LoopXCode_HardenCfg.Fly, JumpInfinity = genv.LoopXCode_HardenCfg.JumpInfinity,
            AntiKnockDown = genv.LoopXCode_HardenCfg.AntiKnockDown, Invisible = genv.LoopXCode_HardenCfg.Invisible,
            AntiRagdoll = genv.LoopXCode_HardenCfg.AntiRagdoll, AutoAntiSpeed = genv.LoopXCode_HardenCfg.AutoAntiSpeed,
            AntiAFK = genv.LoopXCode_HardenCfg.AntiAFK, AntiHit = genv.LoopXCode_HardenCfg.AntiHit,
            SpeedBoost = genv.LoopXCode_HardenCfg.SpeedBoost, SpeedValue = SpeedCfg.Value,
            UnlockFPS = genv.LoopXCode_HardenCfg.UnlockFPS,
            UnlockFPSValue = genv.LoopXCode_HardenCfg.UnlockFPSValue,
            AutoLow = genv.LoopXCode_HardenCfg.AutoLow,
            HidePetPen = genv.LoopXCode_HardenCfg.HidePetPen
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

-- Event treadmill admin ditandai dua bentuk dari data game:
-- 1) LocalPlayer.TrainAdmin = true (server lama / saat player sudah di event)
-- 2) workspace.PetsGame.AdminDummy + AdminDummyEnd masih aktif ( event aktif,
--    tapi TrainAdmin belum diset sampai player masuk ke area dummy ).
-- Keduanya harus diterima, kalau tidak hub diam padahal eventnya jalan.
local function adminEventActive()
    local ok, active = pcall(function()
        if LocalPlayer:GetAttribute("TrainAdmin") == true then return true end
        local pets = workspace:FindFirstChild("PetsGame")
        local admin = pets and pets:FindFirstChild("AdminDummy")
        if not admin then return false end
        local now = workspace:GetServerTimeNow()
        local endTime = tonumber(workspace:GetAttribute("AdminDummyEnd")
            or pets:GetAttribute("AdminDummyEnd")
            or admin:GetAttribute("AdminDummyEnd") or 0) or 0
        if endTime > 0 and now < endTime then return true end
        local mult = tonumber(workspace:GetAttribute("AdminDummy")
            or pets:GetAttribute("AdminDummy")
            or admin:GetAttribute("AdminDummy")
            or admin:GetAttribute("Tier") or 0) or 0
        return mult > 0
    end)
    return ok and active == true
end
genv.LoopXCode_AdminEventActive = adminEventActive

-- Admin Event punya treadmill sendiri: workspace.PetsGame.AdminDummy (model
-- dengan atribut Center/Radius), BUKAN TrainingStation.TrainPad di base.
-- Pad biasa dipakai hanya oleh Auto Treadmill normal.
local function getAdminEventDeck()
    local ok, target = pcall(function()
        local pets = workspace:FindFirstChild("PetsGame")
        local admin = pets and pets:FindFirstChild("AdminDummy")
        if not admin then return nil end
        local center = admin:GetAttribute("Center")
        if typeof(center) ~= "Vector3" then
            local dummy = admin:FindFirstChild("Dummy")
            local root = dummy and dummy.PrimaryPart
            center = root and root.Position or admin:GetPivot().Position
        end
        -- Center atribut game adalah XZ treadmill event. Tambah sedikit Y supaya
        -- character tidak masuk ke lantai; jangan pakai TrainPad base di sini.
        return center + Vector3.new(0, 3.3, 0)
    end)
    return ok and target or nil
end

local function teleportToTreadmill()
    local cfg = genv.LoopXCode_HardenCfg
    if not cfg.AutoTreadmill and not cfg.AdminEventTreadmill then return false end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local target = nil
    if cfg.AdminEventTreadmill and adminEventActive() then
        target = getAdminEventDeck()
    end
    if not target then
        local deck = getTrainPadDeck()
        if not deck then return false end
        target = deck:IsA("BasePart") and deck.CFrame + Vector3.new(0, 3.5, 0)
            or deck:GetPivot() + Vector3.new(0, 3.5, 0)
    elseif typeof(target) == "Vector3" then
        target = CFrame.new(target)
    end
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

-- Admin Event treadmill: game menandai event lewat TrainAdmin / AdminDummy,
-- lalu memunculkan tombol TrainTap.Root.Button (label "TAP!") tiap 3-5 detik.
-- Deteksi ini memakai atribut yang sama dengan game, bukan menebak berdasarkan UI.
local adminTapLastId = nil
local adminTapSeenId = nil
local adminTapSeenAt = 0
local adminTapConn = nil
local adminTapCount = 0
local adminPadTryAt = 0
local adminEventPrevActive = false
local ADMIN_TAP_WINDOW = 2.2
pcall(function()
    local TC = ModuleFolder:FindFirstChild("TrainingConfig")
    if TC then
        local tap = require(TC).TAP
        if tap and tonumber(tap.WINDOW) then ADMIN_TAP_WINDOW = tonumber(tap.WINDOW) end
    end
end)

local function adminTreadmillActive()
    local ok, active = pcall(function()
        return adminEventActive() and LocalPlayer:GetAttribute("Training") == true
    end)
    return ok and active == true
end
genv.LoopXCode_AdminTreadmillActive = adminTreadmillActive

local function stopAdminEventTapListener()
    if adminTapConn then
        pcall(function() adminTapConn:Disconnect() end)
        adminTapConn = nil
    end
    adminTapLastId = nil
    adminTapSeenId, adminTapSeenAt = nil, 0
    adminEventPrevActive = false
end

local function sendToAdminPad(reason)
    local t = tick()
    if t - adminPadTryAt < 1.5 then return end
    adminPadTryAt = t
    task.spawn(function()
        if mountedNow() then pcall(dismountPet) end
        task.wait(0.15)
        pcall(teleportToTreadmill)
    end)
    setStatus(reason, "tap")
end

local function startAdminEventTapListener()
    stopAdminEventTapListener()
    local listenerEpoch = RUN_EPOCH
    adminTapConn = RunService.Heartbeat:Connect(function()
        if genv.LoopXCode_RunEpoch ~= listenerEpoch then
            pcall(function()
                if adminTapConn then adminTapConn:Disconnect() end
            end)
            adminTapConn = nil
            return
        end
        local cfg = genv.LoopXCode_HardenCfg
        if not cfg.AdminEventTreadmill then
            if adminEventPrevActive then
                adminEventPrevActive = false
                adminTapLastId = nil
            end
            return
        end
        if not adminEventActive() then
            if adminEventPrevActive then
                adminEventPrevActive = false
                adminTapLastId = nil
                adminTapSeenId, adminTapSeenAt = nil, 0
            end
            return
        end
        if not adminEventPrevActive then
            adminEventPrevActive = true
            adminTapLastId = nil
            sendToAdminPad("admin event")
        end
        -- Saat event baru aktif, server kadang belum menyetel Training=true walau
        -- TrainTapId/Until sudah jalan. Tetap coba tap bila ada bubble, sambil
        -- terus menempel di area AdminDummy.
        if LocalPlayer:GetAttribute("Training") ~= true then
            sendToAdminPad("admin event pad")
        end
        if (tonumber(LocalPlayer:GetAttribute("TutorialStep") or 0) or 0) ~= 0 then return end
        local id = LocalPlayer:GetAttribute("TrainTapId")
        local untilTime = tonumber(LocalPlayer:GetAttribute("TrainTapUntil") or 0) or 0
        local now = workspace:GetServerTimeNow()
        if id == nil or now >= untilTime then return end
        if id == adminTapLastId then return end
        if id ~= adminTapSeenId then
            adminTapSeenId, adminTapSeenAt = id, now
        end
        local window = ADMIN_TAP_WINDOW
        local remaining = untilTime - now
        local age = now - adminTapSeenAt
        -- Tekan di akhir jendela biar dapat PERFECT, tapi jangan sampai MISS.
        if remaining > math.min(0.45, window * 0.4)
            and age < math.max(window * 0.55, 1.1) then return end
        if pressTapButton() then
            adminTapLastId = id
            adminTapSeenId = nil
            adminTapCount += 1
            genv.LoopXCode_AdminEventTapCount = adminTapCount
            setStatus("admin event tap", "tap")
            return
        end
        -- Tombol belum ke-render / koneksi Activated belum ada: jalur cadangan
        -- tetap memanggil remote yang sama persis seperti handler tombol asli.
        if age > 1.0 then
            adminTapLastId = id
            adminTapSeenId = nil
            adminTapCount += 1
            genv.LoopXCode_AdminEventTapCount = adminTapCount
            hFire(R_TRAIN, id)
            setStatus("admin event tap", "tap")
        end
    end)
end
genv.LoopXCode_StartAdminEventTap = startAdminEventTapListener
genv.LoopXCode_StopAdminEventTap = stopAdminEventTapListener
OnCleanup(function() stopAdminEventTapListener() end)

-- Watchdog mandiri: kalau listener mati / koneksinya putus saat event aktif,
-- nyalakan lagi otomatis. Ini satu-satunya jalur yang restart listener, jadi
-- tidak bisa menumpuk dobel TAP!.
;(function()
    local watchdogEpoch = RUN_EPOCH
    local seenCount = genv.LoopXCode_AdminEventTapCount or 0
    local changedAt = os.clock()
    task.spawn(function()
        while alive() and genv.LoopXCode_RunEpoch == watchdogEpoch do
            task.wait(1)
            local cfg = genv.LoopXCode_HardenCfg
            if cfg.AdminEventTreadmill and adminEventActive() then
                local count = genv.LoopXCode_AdminEventTapCount or 0
                if count ~= seenCount then
                    seenCount, changedAt = count, os.clock()
                end
                if not adminTapConn then
                    startAdminEventTapListener()
                    adminPadTryAt = os.clock()
                elseif os.clock() - math.max(changedAt, adminPadTryAt) > 10 then
                    startAdminEventTapListener()
                    adminPadTryAt = os.clock()
                    changedAt = os.clock()
                    genv.LoopXCode_AdminEventRestartCount = (genv.LoopXCode_AdminEventRestartCount or 0) + 1
                end
            end
        end
    end)
end)()

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
        if genv.LoopXCode_HardenCfg.AdminEventTreadmill then return end
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
    if genv.LoopXCode_HardenCfg.AdminEventTreadmill then
        lastTapId, pendingTapId = nil, nil
        return
    end
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
        if did then setStatus("auto upgrade pen", "sign") end
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
local HARDEN_STATE_LIST = {
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.GettingUp,
    Enum.HumanoidStateType.Dead,
}
local function setHumanoidStates(enabled)
    local hum = currentHumanoid()
    if not hum then return end
    pcall(function()
        for _, st in ipairs(HARDEN_STATE_LIST) do
            hum:SetStateEnabled(st, enabled)
        end
    end)
    statesDisabled = not enabled
end

-- Run lama bisa meninggalkan FallingDown/Ragdoll/Dead dalam kondisi mati setelah
-- reload. Karena flag lokal reset, loop lupa mengembalikannya dan char jadi
-- macet/nggak bisa respawn. Paksa enable kalau opsi ragdoll/knockdown mati.
local function ensureHumanoidStatesEnabled()
    local hum = currentHumanoid()
    if not hum then return end
    pcall(function()
        for _, st in ipairs(HARDEN_STATE_LIST) do
            local ok, enabled = pcall(function() return hum:GetStateEnabled(st) end)
            if not ok or enabled ~= true then
                hum:SetStateEnabled(st, true)
            end
        end
    end)
end

local HardenRestoreStats = function(key, stats)
    if not stats then return end
    local hum = currentHumanoid()
    if hum then
        pcall(function()
            if stats.jump then hum.JumpPower = stats.jump end
            if stats.height then hum.JumpHeight = stats.height end
            -- Jangan kembalikan WalkSpeed lama saat naik pet: itu angka
            -- SpeedBoost jalan kaki (60) yang bikin mount kerasa lambat.
            if stats.walk and not mountedNow() then hum.WalkSpeed = stats.walk end
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
        if not genv.LoopXCode_HardenCfg.AntiRagdoll and not genv.LoopXCode_HardenCfg.AntiKnockDown then
            statesDisabled = false
            ensureHumanoidStatesEnabled()
        end
    end
    if key == "JumpInfinity" then jumpLevel = 0 end
end

-- FPS / grafis rendah / sembunyikan pet di pen: state dipakai HardenToggle.
local LowGfxState = { active = false, savedLight = {}, savedEffect = {}, savedVisual = {} }
genv.LoopXCode_LowGfxState = LowGfxState
local LIGHT_KEYS = { "Ambient", "Brightness", "OutdoorAmbient", "FogColor",
    "FogDensity", "FogStart", "FogEnd", "ExposureCompensation", "ClockTime" }
local function fpsCapValue()
    local n = tonumber(genv.LoopXCode_HardenCfg.UnlockFPSValue)
    if not n then n = 240 end
    if n < 1 or n > 1000 then n = 240 end
    return math.floor(n)
end
genv.LoopXCode_GetFpsCap = fpsCapValue

local function setFpsCap(value)
    local n = tonumber(value) or fpsCapValue()
    if n < 1 or n > 1000 then n = fpsCapValue() end
    n = math.floor(n)
    pcall(function()
        if type(setfpscap) == "function" then setfpscap(n)
        elseif type(set_fps_cap) == "function" then set_fps_cap(n) end
    end)
end
genv.LoopXCode_SetFpsCap = setFpsCap

local function activeFpsCap()
    return genv.LoopXCode_HardenCfg.UnlockFPS == true and fpsCapValue() or 60
end

local function setFpsCapValue(v)
    local n = tonumber(v)
    if not n or n < 1 or n > 1000 then n = 240 end
    n = math.floor(n)
    genv.LoopXCode_HardenCfg.UnlockFPSValue = n
    if genv.LoopXCode_HardenCfg.UnlockFPS then setFpsCap(n) end
    pcall(function() genv.LoopXCode_HardenSave() end)
    return n
end
genv.LoopXCode_SetFpsCapValue = setFpsCapValue

local function applyLowGraphics(enabled)
    enabled = enabled == true
    if enabled then
        if not LowGfxState.active then
            LowGfxState.savedLight, LowGfxState.savedEffect = {}, {}
            for _, key in ipairs(LIGHT_KEYS) do
                pcall(function() LowGfxState.savedLight[key] = Lighting[key] end)
            end
            pcall(function()
                for _, obj in ipairs(Lighting:GetDescendants()) do
                    if obj:IsA("PostEffect") and obj.Enabled then
                        LowGfxState.savedEffect[obj] = true
                        obj.Enabled = false
                    end
                end
            end)
        end
        pcall(function()
            Lighting.Ambient = Color3.new(1, 1, 1)
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            Lighting.Brightness = 2
            Lighting.FogColor = Color3.new(1, 1, 1)
            Lighting.FogDensity = 0
            Lighting.FogStart = 0
            Lighting.FogEnd = 1000000
            Lighting.ExposureCompensation = 0
            Lighting.ClockTime = 12
        end)
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterColor = Color3.new(1, 1, 1)
                terrain.WaterTransparency = 1
                terrain.WaterReflectance = 0
            end
        end)
        -- Mode putih: hapus material tekstur/efek visual sekali jalan, simpan
        -- nilai aslinya supaya bisa dikembalikan kalau toggle dimatikan.
        if not next(LowGfxState.savedVisual) then
            pcall(function()
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    pcall(function()
                        if obj:IsA("BasePart") and obj.ClassName ~= "Terrain" then
                            LowGfxState.savedVisual[obj] = {
                                kind = "part", color = obj.Color, material = obj.Material
                            }
                            obj.Color = Color3.new(1, 1, 1)
                            obj.Material = Enum.Material.Plastic
                        elseif obj:IsA("Decal") or obj:IsA("Texture") then
                            LowGfxState.savedVisual[obj] = { kind = "visible", value = obj.Visible }
                            obj.Visible = false
                        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
                            or obj:IsA("Highlight") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                            LowGfxState.savedVisual[obj] = { kind = "enabled", value = obj.Enabled }
                            obj.Enabled = false
                        end
                    end)
                end
            end)
        end
        LowGfxState.active = true
        setFpsCap(activeFpsCap())
    else
        if LowGfxState.active then
            for key, value in pairs(LowGfxState.savedLight) do
                pcall(function() Lighting[key] = value end)
            end
            for obj in pairs(LowGfxState.savedEffect) do
                if obj.Parent then pcall(function() obj.Enabled = true end) end
            end
            for obj, saved in pairs(LowGfxState.savedVisual) do
                if obj.Parent then
                    pcall(function()
                        if saved.kind == "part" then
                            obj.Color = saved.color
                            obj.Material = saved.material
                        elseif saved.kind == "visible" then
                            obj.Visible = saved.value
                        elseif saved.kind == "enabled" then
                            obj.Enabled = saved.value
                        end
                    end)
                end
            end
        end
        LowGfxState.savedLight, LowGfxState.savedEffect, LowGfxState.savedVisual = {}, {}, {}
        LowGfxState.active = false
        setFpsCap(activeFpsCap())
    end
end
genv.LoopXCode_ApplyLowGraphics = applyLowGraphics

local HidePetPenState = { active = false, saved = {}, thread = nil }
genv.LoopXCode_HidePetPenState = HidePetPenState
local function restoreHidePetPen()
    for obj, saved in pairs(HidePetPenState.saved) do
        if obj.Parent then
            pcall(function()
                if saved.kind == "transparency" then obj.Transparency = saved.value
                elseif saved.kind == "enabled" then obj.Enabled = saved.value end
            end)
        end
    end
    HidePetPenState.saved = {}
end
local function applyHidePetPen()
    pcall(function()
        local cs = game:GetService("CollectionService")
        for _, model in ipairs(cs:GetTagged("PenPet")) do
            if model:IsA("Model")
                and tostring(model:GetAttribute("Owner")) == tostring(LocalPlayer.UserId) then
                for _, obj in ipairs(model:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        if HidePetPenState.saved[obj] == nil then
                            HidePetPenState.saved[obj] = { kind = "transparency", value = obj.Transparency }
                        end
                        if obj.Transparency < 1 then obj.Transparency = 1 end
                    elseif obj:IsA("BillboardGui") or obj:IsA("Highlight")
                        or obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                        if HidePetPenState.saved[obj] == nil then
                            HidePetPenState.saved[obj] = { kind = "enabled", value = obj.Enabled }
                        end
                        if obj.Enabled then obj.Enabled = false end
                    end
                end
            end
        end
    end)
end
genv.LoopXCode_ApplyHidePetPen = applyHidePetPen

genv.LoopXCode_HardenToggle = function(key, v)
    local FarmCfg = genv.LoopXCode_FarmCfg
    if genv.LoopXCode_HardenCfg[key] == nil then return end
    if key == "SpeedBoost" then
        local enabled = (v == true)
        genv.LoopXCode_HardenCfg.SpeedBoost = enabled
        SpeedCfg.Enabled = enabled
        pcall(function()
            local hum = currentHumanoid()
            -- Saat naik pet, biarkan MountConfig yang mengatur WalkSpeed;
            -- memaksa 60 di sini bikin mount kerasa lambat.
            if hum and not mountedNow() then hum.WalkSpeed = enabled and safeWalkSpeed(speedTarget()) or (HardenRestore.AutoAntiSpeed and HardenRestore.AutoAntiSpeed.walk or 26) end
        end)
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if key == "AntiHit" then
        local enabled = (v == true)
        genv.LoopXCode_HardenCfg.AntiHit = enabled
        if enabled then pcall(startNoClip) else pcall(stopNoClip) end
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if key == "UnlockFPS" then
        local enabled = (v == true)
        genv.LoopXCode_HardenCfg.UnlockFPS = enabled
        if enabled then setFpsCap(fpsCapValue()) else setFpsCap(60) end
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if key == "AutoLow" then
        local enabled = (v == true)
        genv.LoopXCode_HardenCfg.AutoLow = enabled
        pcall(applyLowGraphics, enabled)
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if key == "HidePetPen" then
        local enabled = (v == true)
        genv.LoopXCode_HardenCfg.HidePetPen = enabled
        if HidePetPenState.thread then pcall(task.cancel, HidePetPenState.thread) end
        if enabled then
            applyHidePetPen()
            HidePetPenState.active = true
            HidePetPenState.thread = task.spawn(function()
                while HidePetPenState.active and genv.LoopXCode_HardenAlive() do
                    task.wait(1.5)
                    applyHidePetPen()
                end
            end)
        else
            HidePetPenState.active = false
            restoreHidePetPen()
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
    if key == "AdminEventTreadmill" then
        local enabled = (v == true)
        genv.LoopXCode_HardenCfg[key] = enabled
        if enabled then
            -- Satu jalur tap saja: Auto Treadmill biasa, Auto Catch, dan Auto
            -- Farm dimatikan supaya karakter tetap di event dan TAP! tidak dobel.
            if FarmCfg.Enabled then
                pcall(function() genv.LoopXCode_ApplyAutoFarm(false) end)
                setUIValue(UIHandles["Auto farm"], false)
            end
            if genv.LoopXCode_HardenCfg.AutoTreadmill then
                pcall(function() genv.LoopXCode_HardenToggle("AutoTreadmill", false) end)
            end
            if StealCfg.Enabled then
                applyAutoSteal(false)
                setUIValue(UIHandles["Auto Catch"], false)
            end
            if genv.LoopXCode_AutoEquipBeforeAdminEvent == nil then
                genv.LoopXCode_AutoEquipBeforeAdminEvent = (genv.LoopXCode_AutoEquipV2 == true)
            end
            genv.LoopXCode_AutoEquipV2 = false
            genv.LoopXCode_AutoEquipSpeed = false
            pcall(function() genv.LoopXCode_SetAutoEquip(false, false) end)
            -- Jangan turun dari pet / teleport kalau event treadmill admin belum
            -- aktif. Toggle boleh standby dulu; listener yang akan bawa ke pad
            -- begitu TrainAdmin=true dari data game.
            startAdminEventTapListener()
            if adminEventActive() then
                sendToAdminPad("admin event")
            else
                setStatus("admin event standby", "tap")
            end
        else
            stopAdminEventTapListener()
            local restore = genv.LoopXCode_AutoEquipBeforeAdminEvent
            if restore ~= nil then
                genv.LoopXCode_AutoEquipBeforeAdminEvent = nil
                genv.LoopXCode_AutoEquipV2 = restore
                genv.LoopXCode_AutoEquipSpeed = false
                pcall(function() genv.LoopXCode_SetAutoEquip(restore, false) end)
                if restore then task.spawn(equipBestSpeed) end
            end
            if not StealCfg.Enabled and not ManualSteal.Active then setStatus("idle", "any detect") end
        end
        setUIValue(UIHandles["Harden:" .. key], genv.LoopXCode_HardenCfg[key])
        pcall(genv.LoopXCode_HardenSave)
        return
    end
    if key == "AutoUpgradeTraining" or key == "AutoUpgradeTreadmill" then
        genv.LoopXCode_HardenCfg[key] = (v == true)
        if genv.LoopXCode_HardenCfg[key] then
            setStatus("auto upgrade pen", "sign")
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
        if v and FarmCfg.Enabled then
            genv.LoopXCode_HardenCfg.AutoTreadmill = false
            setUIValue(UIHandles["Auto Treadmill"], false)
            pcall(genv.LoopXCode_HardenSave)
            return
        end
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
    -- Kalau masih naik pet, game memaksa state Seated dan WASD nggak sampai ke
    -- fly loop. Turun dulu supaya kontrol kamera/WASD benar-benar dipakai.
    if LocalPlayer:GetAttribute("Mount") then pcall(dismountPet) end
    flyConn = RunService.Heartbeat:Connect(function(dt)
        if not genv.LoopXCode_HardenAlive() or not genv.LoopXCode_HardenCfg.Fly then
            stopFly()
            return
        end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        if UserInputService:GetFocusedTextBox() then return end

        local cam = Workspace.CurrentCamera
        local dir = Vector3.new(0, 0, 0)
        if cam then
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.01 then flat = flat.Unit end
            local right = cam.CFrame.RightVector
            local flatRight = Vector3.new(right.X, 0, right.Z)
            if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end
            if UserInputService:IsKeyDown(Enum.KeyCode.W)
                or UserInputService:IsKeyDown(Enum.KeyCode.Up) then dir += flat end
            if UserInputService:IsKeyDown(Enum.KeyCode.S)
                or UserInputService:IsKeyDown(Enum.KeyCode.Down) then dir -= flat end
            if UserInputService:IsKeyDown(Enum.KeyCode.D)
                or UserInputService:IsKeyDown(Enum.KeyCode.Right) then dir += flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.A)
                or UserInputService:IsKeyDown(Enum.KeyCode.Left) then dir -= flatRight end
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
            dir -= Vector3.new(0, 1, 0)
        end
        if dir.Magnitude > 0 then dir = dir.Unit end

        local speed = math.max(60, math.min(50000, speedTarget()))
        pcall(function()
            -- Jangan PlatformStand: state itu bikin char kaku/T-pose. Pakai
            -- velocity + Humanoid:Move supaya animasi jalan/fall tetap hidup.
            hum.PlatformStand = false
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            if flatDir.Magnitude > 0 then flatDir = flatDir.Unit end
            hum:Move(flatDir, false)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            root.AssemblyLinearVelocity = dir * speed
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
                        or st == Enum.HumanoidStateType.GettingUp then
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
        else
            if statesDisabled then
                setHumanoidStates(true)
            else
                ensureHumanoidStatesEnabled()
            end
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
                    -- Jangan cap WalkSpeed saat naik pet: kecepatan mount
                    -- dihitung game (MountConfig.PetSpeed) dan jauh di atas 60.
                    if not mountedNow() then
                        local cap = safeWalkSpeed((SpeedCfg.Enabled and speedTarget() > 300) and speedTarget() or 300)
                        if hum.WalkSpeed > cap then hum.WalkSpeed = cap end
                    end
                    if hum.JumpPower > 900 then hum.JumpPower = 900 end
                end)
            end
        else
            if LocalPlayer:GetAttribute("OfflineBoosted") == true then
                pcall(function() LocalPlayer:SetAttribute("OfflineBoosted", false) end)
            end
        end

        -- Speed Boost jangan dipaksakan saat naik pet: biar MountConfig yang
        -- pegang kecepatan hewan (dipaksa 60 = mount jadi lambat).
        if SpeedCfg.Enabled and hum and not mountedNow() and not genv.LoopXCode_HardenCfg.Fly then
            pcall(function()
                local target = safeWalkSpeed(speedTarget())
                if math.abs(hum.WalkSpeed - target) > 1 then hum.WalkSpeed = target end
            end)
        end

        -- Auto Anti Speed: reset ke kecepatan normal (bukan math.huge).
        -- Skip saat naik pet supaya mount tetap pakai kecepatan aslinya.
        if genv.LoopXCode_HardenCfg.AutoAntiSpeed and hum and not mountedNow() and not SpeedCfg.Enabled and not genv.LoopXCode_HardenCfg.Fly then
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
    if genv.LoopXCode_HardenCfg.AntiHit then pcall(startNoClip) end
    if genv.LoopXCode_HardenCfg.HidePetPen then pcall(applyHidePetPen) end
end)
end

-- Anti Pause: Roblox membuka menu pause saat window kehilangan focus dan game
-- ikut berhenti. GuiService:SetMenuIsOpen(false) menutup menu engine itu supaya
-- Auto Catch tetap jalan walaupun window tidak sedang difokuskan.
-- Didefinisikan sebagai function scope tersendiri, di luar buildHarden(),
-- supaya local-nya tidak ikut memakan register chunk utama.
;(function()
    local P = genv.LoopXCode_PauseState
    if type(P) ~= "table" then
        P = { owner = nil, conns = {}, thread = nil, closed = 0 }
        genv.LoopXCode_PauseState = P
    end
    P.conns = P.conns or {}

    P.close = function()
        if P.owner ~= genv.LoopXCode_HardenEpoch then return false end
        local closed = false
        pcall(function()
            local gs = game:GetService("GuiService")
            if gs.MenuIsOpen and type(gs.SetMenuIsOpen) == "function" then
                gs:SetMenuIsOpen(false)
                closed = true
            end
        end)
        if closed then P.closed += 1 end
        return closed
    end

    P.stop = function()
        for i, conn in ipairs(P.conns) do
            pcall(function() conn:Disconnect() end)
            P.conns[i] = nil
        end
        if P.thread then
            pcall(task.cancel, P.thread)
            P.thread = nil
        end
    end

    P.start = function()
        local epoch = tonumber(genv.LoopXCode_HardenEpoch) or 0
        if P.owner == epoch and P.thread then return end
        P.stop()
        P.owner = epoch
        pcall(function()
            local gs = game:GetService("GuiService")
            P.conns[#P.conns + 1] = gs.MenuOpened:Connect(P.close)
            P.conns[#P.conns + 1] = UserInputService.WindowFocusReleased:Connect(P.close)
        end)
        pcall(P.close)
        P.thread = task.spawn(function()
            while P.owner == epoch do
                P.close()
                task.wait(0.5)
            end
        end)
    end

    genv.LoopXCode_CloseGamePause = P.close
    genv.LoopXCode_PauseStop = P.stop
    genv.LoopXCode_PauseStart = P.start
end)()

buildHarden()

-- Anti Pause aktif setiap load, terlepas dari konfigurasi Anti AFK.
pcall(genv.LoopXCode_PauseStart)
OnCleanup(function() pcall(genv.LoopXCode_PauseStop) end)

-- Tes funktion Anti Hit: simulasikan efek GuardianHit (FallingDown + launch),
-- lalu cek apakah state dan velocity sudah dinetralisir dalam 0.8 detik.
genv.LoopXCode_TestAntiHit = function()
    local prev = genv.LoopXCode_HardenCfg.AntiHit
    pcall(function() genv.LoopXCode_HardenToggle("AntiHit", true) end)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return { passed = false, reason = "no character" } end
    task.wait(0.4)
    local colliding = 0
    pcall(function()
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and obj.CanCollide then colliding += 1 end
        end
    end)
    local result = {
        passed = colliding == 0 and genv.LoopXCode_AntiHitActive == true
            and LocalPlayer:GetAttribute("Capturing") == true,
        collidingParts = colliding, hoverY = genv.LoopXCode_NoClipState.hoverY,
        active = genv.LoopXCode_AntiHitActive,
        safetyCapture = LocalPlayer:GetAttribute("Capturing") == true,
        collisionGroupReady = genv.LoopXCode_NoClipState.groupReady
    }
    pcall(function() genv.LoopXCode_HardenToggle("AntiHit", prev) end)
    return result
end

-- =====================================================================
-- 5. DAFTARKAN SEMUA KOMPONEN KE REGISTRY
-- =====================================================================
genv.LoopXCode_Respawn = function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local spawn = nil
    pcall(function()
        local bases = Workspace:FindFirstChild("PetsGame")
            and Workspace.PetsGame:FindFirstChild("Bases")
        if bases then
            for _, base in ipairs(bases:GetChildren()) do
                if tostring(base:GetAttribute("Owner")) == tostring(LocalPlayer.UserId) then
                    spawn = base:FindFirstChild("BaseSpawn")
                    if spawn then break end
                end
            end
        end
        spawn = spawn or Workspace:FindFirstChild("SpawnLocation")
        local safe = Workspace:FindFirstChild("PetsGame")
            and Workspace.PetsGame:FindFirstChild("SafeZone")
        spawn = spawn or (safe and safe:FindFirstChild("SafeZoneArea"))
    end)
    if hum then pcall(function() hum.Health = hum.MaxHealth end) end
    if root and spawn then
        pcall(function()
            local cf = spawn.CFrame
            root.CFrame = CFrame.new(cf.Position.X, cf.Position.Y + 3.5, cf.Position.Z)
                * (cf - cf.Position)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if hum then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        pcall(function() hum.Sit = false end)
    end
    -- Respawn harus mengembalikan ketinggian hover No Clip ke spawn, kalau tidak
    -- karakter tetap mengambang di tinggi lama setelah teleport jauh.
    if root and genv.LoopXCode_NoClipState and genv.LoopXCode_NoClipState.active then
        pcall(function()
            genv.LoopXCode_NoClipState.hoverY = root.Position.Y
            genv.LoopXCode_NoClipState.lastXZ = Vector2.new(root.Position.X, root.Position.Z)
            genv.LoopXCode_ApplyNoClipParts(char, true)
        end)
    end
    return { ok = spawn ~= nil, spawn = spawn and spawn:GetFullName() or nil }
end

AddButton("Skip Tutorial", function()
    task.spawn(SkipTutorial.Run)
end, "Misc")
AddButton("Respawn", function()
    pcall(function() genv.LoopXCode_Respawn() end)
end, "Controls")

AddToggle("Pet ESP", ESPConfig.ESPPets, function(v) ESPConfig.ESPPets = v end, "ESP")
AddToggle("Guardian ESP", ESPConfig.ESPGuards, function(v) ESPConfig.ESPGuards = v end, "ESP")
AddToggle("Player ESP", ESPConfig.ESPPlayers, function(v) ESPConfig.ESPPlayers = v end, "ESP")
AddToggle("ESP Info", ESPConfig.ShowInfo, function(v) ESPConfig.ShowInfo = v end, "ESP")
AddToggle("Fixed Size", ESPConfig.FixedSize, function(v) ESPConfig.FixedSize = v end, "ESP")
AddToggle("Team Check", ESPConfig.TeamCheck, function(v) ESPConfig.TeamCheck = v end, "ESP")
AddDropdown("ESP Range", { "300 studs", "800 studs", "1500 studs", "All" }, "1500 studs", function(v)
    if v == "All" then
        ESPConfig.MaxDistance = math.huge
    else
        ESPConfig.MaxDistance = tonumber(string.match(v, "%d+")) or 1500
    end
end, "ESP")

do
    local keys = {
        "AutoClaimIndex", "AutoUpgradeTraining", "AutoUpgradeTreadmill", "AutoTreadmill",
        "AdminEventTreadmill",
        "AntiBan", "AntiAFK", "GodMode", "Fly", "JumpInfinity", "AntiKnockDown",
        "Invisible", "AntiRagdoll", "AutoAntiSpeed", "AntiHit", "SpeedBoost",
        "UnlockFPS", "AutoLow", "HidePetPen"
    }
    genv.LoopXCode_HardenFeatureKeys = keys
    local labels = {
        AutoClaimIndex = "Auto Claim Index", AutoUpgradeTraining = "Auto Upgrade Pen",
        AutoUpgradeTreadmill = "Auto Upgrade Treadmill", AutoTreadmill = "Auto Treadmill",
        AdminEventTreadmill = "Auto Treadmill Admin Event",
        AntiBan = "Anti Ban", AntiAFK = "Anti AFK", GodMode = "God Mode",
        Fly = "Fly", JumpInfinity = "Jump Infinity", AntiKnockDown = "Anti Knock Down",
        Invisible = "Invisible", AntiRagdoll = "Anti Ragdoll", AutoAntiSpeed = "Auto Anti Speed",
        AntiHit = "Tembus Tembok", SpeedBoost = "Speed Boost",
        UnlockFPS = "Unlock FPS", AutoLow = "Auto Low / Performance",
        HidePetPen = "Hide Your Pet in Pen"
    }
    genv.LoopXCode_HardenFeatureLabels = labels
    for _, key in ipairs(keys) do
        -- Admin Event punya tab Event sendiri. Speed Boost harus menempel di
        -- Walk Speed dalam Controls, jangan keduanya dimasukkan ke Features.
        if key ~= "AdminEventTreadmill" and key ~= "SpeedBoost" then
            AddToggle(labels[key], genv.LoopXCode_HardenCfg[key] ~= false, function(v)
                genv.LoopXCode_HardenToggle(key, v)
            end, "Features", HARDEN_DEFAULT_ON[key] == true)
        end
    end
    AddInput("FPS Cap", tostring(genv.LoopXCode_HardenCfg.UnlockFPSValue),
        "1-1000  (dipakai Unlock FPS / Auto Low)", function(v)
            local n = genv.LoopXCode_SetFpsCapValue(v)
            setUIValue(UIHandles["FPS Cap"], tostring(n))
        end, "Features")
end

AddToggle("Save History", true, function(v)
    genv.LoopXCode_HardenCfg.SaveHistory = v
end, "Misc", true)
AddToggle("Save UI", true, function(v) genv.LoopXCode_HardenCfg.SaveUI = v end, "Misc", true)
AddToggle("Save Menu", true, function(v) genv.LoopXCode_HardenCfg.SaveMenu = v end, "Misc", true)
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
    local FarmCfg = genv.LoopXCode_FarmCfg
    name = tostring(name or "")
    if name == "" then name = "default" end
    local harden = {}
    for _, key in ipairs(genv.LoopXCode_HardenFeatureKeys) do harden[key] = genv.LoopXCode_HardenCfg[key] end
    harden.SaveHistory = genv.LoopXCode_HardenCfg.SaveHistory
    harden.SaveUI = genv.LoopXCode_HardenCfg.SaveUI
    harden.SaveMenu = genv.LoopXCode_HardenCfg.SaveMenu
    harden.UnlockFPSValue = genv.LoopXCode_HardenCfg.UnlockFPSValue

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
        FarmCfg = {
            Enabled = FarmCfg.Enabled, Maps = jsonSafe(FarmCfg.Maps),
            LastPoints = FarmCfg.LastPoints, LastLevel = FarmCfg.LastLevel,
            LastCoins = FarmCfg.LastCoins, CoinStart = FarmCfg.CoinStart,
            CoinsGained = FarmCfg.CoinsGained,
            Deposits = FarmCfg.Deposits, LastData = FarmCfg.LastData
        },
        MiscCfg = jsonSafe(MiscCfg),
        SpeedCfg = { Enabled = SpeedCfg.Enabled, Value = SpeedCfg.Value },
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
    local FarmCfg = genv.LoopXCode_FarmCfg
    -- Load Config / startup restore tidak boleh memicu notifikasi.
    local prevSuppress = genv.LoopXCode_SuppressNotify
    genv.LoopXCode_SuppressNotify = true
    name = tostring(name or "")
    if name == "" then name = "default" end
    local bank = readConfigBank()
    local data = bank[name]
    if type(data) ~= "table" then
        genv.LoopXCode_SuppressNotify = prevSuppress
        return false
    end
    ConfigCfg.Name = tostring(data.ConfigName or name)
    setHandleValue(UIHandles["Config Name"], ConfigCfg.Name)

    local s = type(data.StealCfg) == "table" and data.StealCfg or {}
    for _, key in ipairs({ "Rarity", "Zone", "CustomIncome", "Priority", "ReelMode" }) do
        if s[key] ~= nil then StealCfg[key] = tostring(s[key]) end
    end
    if StealCfg.ReelMode ~= "Fast" then StealCfg.ReelMode = "Fast" end
    if tonumber(s.RetryDelay) then StealCfg.RetryDelay = tonumber(s.RetryDelay) end
    if tonumber(s.WalkSpeed) then StealCfg.WalkSpeed = math.max(16, math.min(50000, tonumber(s.WalkSpeed))) end
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

    local f = type(data.FarmCfg) == "table" and data.FarmCfg or {}
    if type(f.Maps) == "table" then FarmCfg.Maps = genv.LoopXCode_NormalizeFarmMaps(f.Maps) end
    if tonumber(f.LastPoints) then FarmCfg.LastPoints = tonumber(f.LastPoints) end
    if tonumber(f.LastLevel) then FarmCfg.LastLevel = tonumber(f.LastLevel) end
    if tonumber(f.LastCoins) then FarmCfg.LastCoins = tonumber(f.LastCoins) end
    if tonumber(f.CoinStart) then FarmCfg.CoinStart = tonumber(f.CoinStart) end
    if tonumber(f.CoinsGained) then FarmCfg.CoinsGained = tonumber(f.CoinsGained) end
    if tonumber(f.Deposits) then FarmCfg.Deposits = math.max(0, math.floor(tonumber(f.Deposits))) end
    if type(f.LastData) == "string" and f.LastData ~= "" then FarmCfg.LastData = f.LastData end
    FarmCfg.Enabled = f.Enabled == true
    pcall(function() setHandleValue(UIHandles["Farm Maps"], FarmCfg.Maps) end)
    pcall(function() setHandleValue(UIHandles["Auto farm"], FarmCfg.Enabled) end)
    pcall(function() genv.LoopXCode_ApplyAutoFarm(FarmCfg.Enabled) end)

    local misc = type(data.MiscCfg) == "table" and data.MiscCfg or {}
    MiscCfg.MenuBackground = misc.MenuBackground == true
    MiscCfg.AutoEquipBestSpeed = misc.AutoEquipBestSpeed ~= false
    MiscCfg.AutoEquipBestPen = misc.AutoEquipBestPen == true
    pcall(function() genv.LoopXCode_SetMenuBackground(MiscCfg.MenuBackground) end)
    pcall(function() genv.LoopXCode_SetAutoEquip(MiscCfg.AutoEquipBestSpeed, false) end)
    pcall(function() genv.LoopXCode_SetAutoEquipBestPen(MiscCfg.AutoEquipBestPen, false) end)

    local h = type(data.HudCfg) == "table" and data.HudCfg or {}
    for _, key in ipairs({ "Width", "Height", "TextSize", "Gap", "Shadow", "ShadowOffset", "Font", "LogoFont", "X", "Y", "Hidden" }) do
        if h[key] ~= nil then HudCfg[key] = h[key] end
    end
    HudCfg.Hidden = h.Hidden == true
    pcall(function() genv.LoopXCode_SetHudHidden(HudCfg.Hidden) end)
    setHandleValue(UIHandles["Hide HUD"], HudCfg.Hidden)
    HudCfg.Shadow = shadowAmount(HudCfg.Shadow, 50) * 100
    HudCfg.ShadowOffset = math.clamp(math.floor(tonumber(HudCfg.ShadowOffset) or 1), 0, 12)

    local e = type(data.ESPConfig) == "table" and data.ESPConfig or {}
    for _, key in ipairs({ "Enabled", "ESPPets", "ESPGuards", "ESPPlayers", "ShowInfo",
        "FixedSize", "TeamCheck", "PlayerSize", "GuardSize", "PetSize", "ScanInterval" }) do
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
                dst.Shadow = shadowAmount(dst.Shadow, 50) * 100
                dst.ShadowOffset = math.clamp(math.floor(tonumber(dst.ShadowOffset) or 1), 0, 12)
                pcall(setEspStyle, cat, "Size", dst.Size)
                pcall(setEspStyle, cat, "Color", dst.Color)
            end
        end
    end
    local sp = type(data.SpeedCfg) == "table" and data.SpeedCfg or {}
    if tonumber(sp.Value) then SpeedCfg.Value = math.max(16, math.min(1e6, tonumber(sp.Value))) end

    local hd = type(data.HardenCfg) == "table" and data.HardenCfg or {}
    if tonumber(hd.UnlockFPSValue) then
        genv.LoopXCode_HardenCfg.UnlockFPSValue = math.floor(math.max(1, math.min(1000, tonumber(hd.UnlockFPSValue))))
    end
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
    setHandleValue(UIHandles["Walk Speed"], tostring(SpeedCfg.Value))
    setHandleValue(UIHandles["FPS Cap"], tostring(genv.LoopXCode_HardenCfg.UnlockFPSValue))
    setHandleValue(UIHandles["Weak Lasso Catch"], StealCfg.WeakAllowed)
    setHandleValue(UIHandles["Auto Equip Best Speed"], MiscCfg.AutoEquipBestSpeed)
    setHandleValue(UIHandles["Auto Equip Best Pen"], MiscCfg.AutoEquipBestPen)
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
    genv.LoopXCode_SuppressNotify = prevSuppress
    return true
end
genv.LoopXCode_LoadConfig = loadNamedConfig

-- =====================================================================
-- 6. WINDUI — library dimuat SEKALI, window dibuat SEKALI
-- =====================================================================
-- Fungsi terpisah bukan sekadar `do`: memberi scope lokal baru supaya jumlah
-- lokal di chunk utama nggak menembus batas register Luau (200).
local function buildWindUI()
    local FarmCfg = genv.LoopXCode_FarmCfg
    -- Buang semua ScreenGui WindUI sisa run lama SEBELUM load, supaya
    -- save-state tidak menempel ke ScreenGui mati dan CreateWindow tidak error.
    for _, root in ipairs(cleanupRoots) do
        if root then
            for _, o in ipairs(root:GetDescendants()) do
                local n = tostring(o.Name or ""):lower()
                if o:IsA("ScreenGui") and (n == "windui" or n:find("windui/", 1, true)) then
                    pcall(function() o:Destroy() end)
                end
            end
        end
    end

    local okLib, lib
    do
        -- WindUI memanggil cloneref/clonereference pada Instance. Di executor
        -- dengan thread identity biasa itu bisa melempar "lacking capability
        -- Plugin", dan versi terbaru juga kadang mengirim nil. Karena WindUI
        -- cuma butuh referensi Instance yang sama, kembalikan saja argumennya.
        --Override hanya saat load, lalu pulihkan setelah selesai.
        local function safeCloneref(value)
            return value
        end
        local oldCloneref, oldClonereference
        local okSet = pcall(function()
            oldCloneref = cloneref
            oldClonereference = clonereference
            cloneref = safeCloneref
            clonereference = safeCloneref
        end)
        okLib, lib = pcall(function()
            local src = winduiSource
            if type(src) ~= "string" or src == "" then
                src = genv.LoopXCode_WindUISrc
            end
            if type(src) ~= "string" or src == "" then
                src = game:HttpGet(WINDUI_URL, true)
            end
            local result = loadstring(src)()
            if type(result) == "table" then genv.LoopXCode_WindUISrc = src end
            return result
        end)
        if okSet then
            pcall(function()
                cloneref = oldCloneref
                clonereference = oldClonereference
            end)
        end
    end

    if not (okLib and type(lib) == "table" and type(lib.CreateWindow) == "function") then
        closeLoadingOverlay()
        return
    end
    genv.LoopXCode_WindUILib = lib
    -- Library sudah siap: loading selesai di sini. Tab berikutnya dibangun di
    -- belakang layar supaya overlay nggak pernah terasa nge-stuck.
    closeLoadingOverlay()

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

    -- Latar kotak bawaan theme dimatikan. Radius dalam sengaja 0: yang boleh
    -- bulat cuma window + wallpaper; baris/tombol/dropdown kotak biar rapi.
    pcall(function()
        local themes = lib.Themes
        local dark = type(themes) == "table" and themes.Dark or nil
        if type(dark) == "table" then
            dark.LabelBackgroundTransparency = 1
            dark.LabelBackground = Color3.fromRGB(24, 28, 42)
            dark.CornerRadius = UDim.new(0, 0)
            dark.ElementCornerRadius = UDim.new(0, 0)
            dark.WindowCornerRadius = UDim.new(0, 16)
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

    -- HUD harus di atas tulisan RUN game (TopGui = 0) tapi tetap di bawah
    -- menu WindUI. Dropdown/tooltip/popup punya ScreenGui sendiri dan awalnya
    -- DisplayOrder=0, jadi kelihatan "di layer paling belakang". Sekarang
    -- dropdown ditaruh di depan menu (40), tapi masih di bawah logo (50).
    local function orderWindLayers()
        pcall(function()
            if uiScreen then
                uiScreen.DisplayOrder = 30
                uiScreen.ResetOnSpawn = false
            end
            for _, sg in ipairs(ParentGui:GetDescendants()) do
                if sg:IsA("ScreenGui") then
                    local n = string.lower(tostring(sg.Name or ""))
                    if n == "windui" or n:find("windui", 1, true) then
                        local order = 31
                        if n:find("dropdowns", 1, true) then order = 40
                        elseif n:find("tooltips", 1, true)
                            or n:find("popups", 1, true)
                            or n:find("notifications", 1, true) then
                            order = 41
                        end
                        sg.DisplayOrder = order
                        sg.ResetOnSpawn = false
                    end
                end
            end
        end)
    end
    orderWindLayers()
    local layerConn = nil
    pcall(function()
        layerConn = ParentGui.DescendantAdded:Connect(function(o)
            if o:IsA("ScreenGui") then orderWindLayers() end
        end)
    end)
    genv.LoopXCode_OrderWindLayers = orderWindLayers

    -- WindUI resize grip bisa mengecilkan window sampai tinggi 0; begitu itu
    -- terjadi semua control (termasuk Walk Speed) jadi kepotong/nggak kelihatan.
    -- Jaga minimum 540x480 seperti konfigurasi awal dan reset scroll ke atas
    -- hanya saat ukuran benar-benar bobrok.
    local lastBoundsCheck = 0
    local function enforceWindowBounds()
        if UIWindow.IsFullscreen then return end
        local main = UIWindow.UIElements and UIWindow.UIElements.Main or nil
        if not (typeof(main) == "Instance" and main:IsA("GuiObject")) then return end
        local sz = main.AbsoluteSize
        if sz.X >= 540 and sz.Y >= 480 then return end
        pcall(function()
            UIWindow:SetSize(UDim2.new(0, math.max(540, sz.X), 0, 480))
        end)
        local handle = genv.LoopXCode_UIHandles
            and genv.LoopXCode_UIHandles["Walk Speed"] or nil
        local node = handle and handle.ElementFrame or nil
        while node and not node:IsA("ScrollingFrame") do node = node.Parent end
        if node then pcall(function() node.CanvasPosition = Vector2.new(0, 0) end) end
    end
    genv.LoopXCode_EnforceWindowBounds = enforceWindowBounds
    local boundsConn = nil
    pcall(function()
        boundsConn = RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - lastBoundsCheck < 0.2 then return end
            lastBoundsCheck = now
            enforceWindowBounds()
        end)
    end)

    OnCleanup(function()
        pcall(function() if layerConn then layerConn:Disconnect() end end)
        pcall(function() if boundsConn then boundsConn:Disconnect() end end)
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
                    pcall(function()
                        local text = translateKey(key, LangCfg.Language)
                        -- Label nilai dropdown Bahasa: waktu pilih Indonesia,
                        -- tulisannya juga harus Indonesia, bukan "English".
                        if key == "English" and LangCfg.Language == "Indonesia"
                            and not o:GetFullName():find("Dropdowns", 1, true) then
                            text = "Indonesia"
                        end
                        o.Text = text
                    end)
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

    -- Dropdown punya ScreenGui sendiri. Layer sudah dinaikkan; ini yang menjaga
    -- frame menunya tetap di dalam batas window WindUI (no overflow).
    local function squareDropdownCorners(dropdown)
        local ui = (type(dropdown) == "table") and dropdown.UIElements or nil
        local menu = ui and ui.Menu
        if typeof(menu) ~= "Instance" then return end
        pcall(function()
            for _, o in ipairs(menu:GetDescendants()) do
                for _, c in ipairs(o:GetChildren()) do
                    if c:IsA("UICorner") then c.CornerRadius = UDim.new(0, 0) end
                end
            end
        end)
    end
    genv.LoopXCode_SquareDropdownCorners = squareDropdownCorners

    local function clampDropdownMenu(dropdown)
        squareDropdownCorners(dropdown)
        local ui = (type(dropdown) == "table") and dropdown.UIElements or nil
        local menu = ui and ui.Menu
        local frame = (typeof(menu) == "Instance") and menu.Parent or nil
        local win = genv.LoopXCode_UIWindow
        local root = win and win.UIElements and win.UIElements.Main or nil
        if not (typeof(frame) == "Instance" and frame:IsA("GuiObject")
            and typeof(root) == "Instance" and root:IsA("GuiObject")) then return end
        local wp, ws = root.AbsolutePosition, root.AbsoluteSize
        local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
        local margin = 8
        local minX, maxX = wp.X + margin, wp.X + ws.X - as.X - margin
        local minY, maxY = wp.Y + margin, wp.Y + ws.Y - as.Y - margin
        if maxX < minX then maxX = minX end
        if maxY < minY then maxY = minY end
        local nx, ny = math.clamp(ap.X, minX, maxX), math.clamp(ap.Y, minY, maxY)
        local dx, dy = nx - ap.X, ny - ap.Y
        if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
        pcall(function()
            frame.Position = UDim2.new(
                frame.Position.X.Scale, frame.Position.X.Offset + dx,
                frame.Position.Y.Scale, frame.Position.Y.Offset + dy)
        end)
    end
    genv.LoopXCode_ClampDropdown = clampDropdownMenu

    -- WindUI dropdown default hitam. Samakan dengan wallpaper menu dan batasi
    -- tinggi list (terutama di phone) supaya 18 rarity nggak keluar layar.
    local function styleDropdown(dropdown)
        local ui = (type(dropdown) == "table") and dropdown.UIElements or nil
        if type(ui) ~= "table" then return end
        local cap = UserInputService.TouchEnabled and 220 or 300
        pcall(function() squareDropdownCorners(dropdown) end)
        pcall(function()
            if typeof(ui.Menu) == "Instance" then
                ui.Menu.ImageColor3 = Color3.fromRGB(18, 22, 34)
                ui.Menu.ImageTransparency = 0.02
                -- Dropdown adalah elemen dalam: sudut kotak, jangan ikut bulat window.
                for _, c in ipairs(ui.Menu:GetChildren()) do
                    if c:IsA("UICorner") then c.CornerRadius = UDim.new(0, 0) end
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
                        for _, c in ipairs(o:GetChildren()) do
                            if c:IsA("UICorner") then c.CornerRadius = UDim.new(0, 0) end
                        end
                    end
                end
            end
        end)
        -- Pas dropdown dibuka, geser frame-nya balik ke dalam window. Tanpa ini
        -- list pilihan bisa keluar batas / ketutup layer lain.
        pcall(function()
            local menuFrame = (typeof(ui.Menu) == "Instance") and ui.Menu.Parent or nil
            local menuApi = dropdown.DropdownMenu
            if typeof(menuFrame) == "Instance" and type(menuApi) == "table"
                and type(menuApi.Open) == "function"
                and not menuFrame:GetAttribute("LXC_DropdownClampHooked") then
                menuFrame:SetAttribute("LXC_DropdownClampHooked", true)
                local oldOpen = menuApi.Open
                menuApi.Open = function(...)
                    local result = oldOpen(...)
                    for _, delay in ipairs({ 0, 0.04, 0.15, 0.4 }) do
                        task.delay(delay, function() pcall(clampDropdownMenu, dropdown) end)
                    end
                    return result
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

    -- WindUI memposisikan Menu relatif ke tombol yang bisa berada jauh di bawah
    -- scroll. Watch ringan ini menahan frame menu tetap di dalam window dan
    -- memaksa layer dropdown tetap depan (lihat orderWindLayers).
    local lastDropdownClamp = 0
    local dropdownClampConn = nil
    pcall(function()
        dropdownClampConn = RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - lastDropdownClamp < 0.08 then return end
            lastDropdownClamp = now
            for _, handle in pairs(UIHandles) do
                if type(handle) == "table" and handle.__type == "Dropdown" then
                    local ui = handle.UIElements
                    local frame = ui and typeof(ui.Menu) == "Instance" and ui.Menu.Parent or nil
                    if typeof(frame) == "Instance" and frame:IsA("GuiObject")
                        and frame.Visible then
                        pcall(clampDropdownMenu, handle)
                    end
                end
            end
        end)
    end)
    OnCleanup(function()
        pcall(function()
            if dropdownClampConn then dropdownClampConn:Disconnect() end
        end)
    end)

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
        -- Frame induk transparan, tapi sudutnya mengikuti window dan anaknya
        -- di-clip. Ini bikin gradient/pattern nggak keluar di sudut kotak.
        frame.BackgroundTransparency = 1
        frame.ClipsDescendants = true
        frame.ZIndex = 0
        frame.Parent = holder
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

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

        local controller = { Enabled = MiscCfg.MenuBackground == true, Busy = false }
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
    -- Pastikan wallpaper mengikuti default OFF sejak awal, bukan nyala karena
    -- controller lama / fullscreen busy state yang belum tersinkron.
    pcall(function() genv.LoopXCode_SetMenuBackground(MiscCfg.MenuBackground) end)

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
    -- Tab dibuat di sini supaya tiap kategori punya tempat sendiri:
    -- Controls = aksi langsung, Event = treadmill admin, Features = toggle fitur,
    -- Settings = preferensi UI/config, Finder = pencari pet.
    -- Finder ditaruh dekat Controls supaya tab-nya tidak terdorong keluar
    -- dari bar saat tab Event/Features/Settings ikut dibuat.
    local FinderTab = UIWindow:Tab({ Title = "Finder", Icon = "search" })
    local EventTab = UIWindow:Tab({ Title = "Event", Icon = "calendar" })
    local FeaturesTab = UIWindow:Tab({ Title = "Features", Icon = "list" })
    local SettingsTab = UIWindow:Tab({ Title = "Settings", Icon = "settings-2" })
    -- Auto Sell sengaja punya tab sendiri, terpisah dari Controls/Features.
    -- Finder tetap di urutan kedua supaya tab-nya tidak terdorong keluar bar.
    local SellTab = UIWindow:Tab({ Title = "Sell", Icon = "coins" })
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

    -- Admin Event punya tab sendiri, bukan lagi bagian dari Controls.
    -- Toggle ini menekan TAP! asli lewat Activated tombol TrainTap.Root.Button.
    local AdminEventSection = trackSection("Admin Event", EventTab:Section({ Title = "Admin Event", Opened = true }))
    local adminEventToggle = AdminEventSection:Toggle({
        Title = "Auto Treadmill Admin Event",
        Value = defaultToggle(false),
        Callback = function(v) genv.LoopXCode_HardenToggle("AdminEventTreadmill", v) end
    })
    UIHandles["Auto Treadmill Admin Event"] = adminEventToggle

    -- Auto Farm Event: tepat di bawah Auto Treadmill Admin Event. Pilih map
    -- multi, scan data turkey, lalu setor otomatis begitu turun di Safe Zone.
    local autoFarmToggle = AdminEventSection:Toggle({
        Title = "Auto farm",
        Desc = "Auto farm event turkeys; auto deposit after Safe Zone",
        Value = FarmCfg.Enabled,
        Callback = function(v) genv.LoopXCode_ApplyAutoFarm(v) end
    })
    UIHandles["Auto farm"] = autoFarmToggle
    local farmMapValues = { "Any" }
    for _, z in ipairs(ZONE_NAMES) do farmMapValues[#farmMapValues + 1] = z end
    local farmMapsDropdown = AdminEventSection:Dropdown({
        Title = "Farm Maps",
        Desc = "Select multiple maps for Auto farm",
        Values = farmMapValues,
        Value = FarmCfg.Maps,
        Multi = true,
        Callback = function(v)
            FarmCfg.Maps = genv.LoopXCode_NormalizeFarmMaps(v)
        end
    })
    UIHandles["Farm Maps"] = farmMapsDropdown
    local farmScanParagraph = AdminEventSection:Paragraph({
        Title = "Event Scan", Desc = FarmCfg.ScanLine
    })
    local farmDataParagraph = AdminEventSection:Paragraph({
        Title = "Event Data", Desc = FarmCfg.LastData
    })
    local initialCoinDesc = string.format("%s: %d | %s: %d", tr("Turkey Coins"),
        FarmCfg.LastCoins, tr("Coins gained"), FarmCfg.CoinsGained)
    local farmCoinParagraph = AdminEventSection:Paragraph({
        Title = "Turkey Coins",
        Desc = initialCoinDesc
    })
    pcall(function()
        local frame = farmCoinParagraph.ElementFrame
        if typeof(frame) == "Instance" then
            for _, o in ipairs(frame:GetDescendants()) do
                if o:IsA("TextLabel") and tostring(o.Text or "") == initialCoinDesc then
                    genv.LoopXCode_FarmCoinLabel = o
                    break
                end
            end
        end
    end)
    genv.LoopXCode_FarmSetCoins = function(_)
        pcall(function() genv.LoopXCode_RefreshFarmCoinUI() end)
    end
    pcall(function() genv.LoopXCode_RefreshFarmCoinUI() end)
    genv.LoopXCode_FarmSetDesc = function(text)
        pcall(function() farmDataParagraph:SetDesc(tostring(text)) end)
        pcall(function() farmScanParagraph:SetDesc(tostring(FarmCfg.ScanLine)) end)
    end
    AdminEventSection:Button({
        Title = "Refresh Event Scan",
        Desc = "Scan turkey data from all loaded maps",
        Callback = function()
            task.spawn(function()
                local char = LocalPlayer.Character
                local rootPart = char and char:FindFirstChild("HumanoidRootPart")
                genv.LoopXCode_FarmScan(rootPart)
                pcall(function() genv.LoopXCode_FarmSetDesc(FarmCfg.LastData) end)
                pcall(function() genv.LoopXCode_UpdateFarmCoins() end)
            end)
        end
    })

    -- Auto Equip punya section sendiri di dekat atas supaya "Auto Equip Best
    -- Speed" + "Auto Equip Best Pen" selalu kelihatan penuh, nggak kepotong
    -- scroll bawah seperti sebelumnya.
    local AutoEquipSection = trackSection("Auto Equip", Tab:Section({ Title = "Auto Equip", Opened = true }))
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

    -- Walk Speed ditaruh paling atas supaya inputnya kelihatan penuh, bukan
    -- kepotong bawah viewport seperti waktu masih di section Capture.
    local walkSpeedInput = AutoEquipSection:Input({
        Title = "Walk Speed",
        Value = tostring(SpeedCfg.Value),
        Placeholder = "50000 (16-50000)",
        Callback = function(v)
            local n = tonumber(v)
            if not n then n = SpeedCfg.Value end
            n = math.max(16, math.min(50000, n))
            SpeedCfg.Value = n
            StealCfg.WalkSpeed = math.max(16, math.min(50000, n))
            -- Walk Speed input tidak menyalakan Speed Boost otomatis.
        end
    })
    UIHandles["Walk Speed"] = walkSpeedInput

    -- Speed Boost sengaja ditaruh persis di bawah Walk Speed (Controls),
    -- bukan lagi di tab Features.
    local speedBoostToggle = AutoEquipSection:Toggle({
        Title = "Speed Boost",
        Desc = "Boost on-foot and mounted movement to this speed (16-50000)",
        Value = defaultToggle(genv.LoopXCode_HardenCfg.SpeedBoost == true),
        Callback = function(v) genv.LoopXCode_HardenToggle("SpeedBoost", v) end
    })
    UIHandles["Speed Boost"] = speedBoostToggle

    local autoEquipToggle = AutoEquipSection:Toggle({
        Title = "Auto Equip Best Speed",
        Value = defaultToggle(true),
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
    if genv.LoopXCode_AutoEquipV2 then task.spawn(equipBestSpeed) end

    local function applyAutoEquipBestPen(v, spawnAction)
        v = (v == true)
        MiscCfg.AutoEquipBestPen = v
        if spawnAction ~= false and v then
            task.spawn(function()
                if equipBestPen() then setStatus("auto equip best pen", "ready") end
            end)
        elseif spawnAction ~= false and not v
            and not StealCfg.Enabled and not ManualSteal.Active then
            setStatus("idle", "any detect")
        end
    end
    local autoEquipPenToggle = AutoEquipSection:Toggle({
        Title = "Auto Equip Best Pen",
        Value = MiscCfg.AutoEquipBestPen,
        Callback = function(v) applyAutoEquipBestPen(v, true) end
    })
    UIHandles["Auto Equip Best Pen"] = autoEquipPenToggle
    genv.LoopXCode_AutoEquipBestPenToggle = autoEquipPenToggle
    genv.LoopXCode_SetAutoEquipBestPen = function(v, spawnAction)
        v = (v == true)
        local didSet = false
        pcall(function()
            if autoEquipPenToggle and type(autoEquipPenToggle.Set) == "function" then
                autoEquipPenToggle:Set(v)
                didSet = true
            elseif autoEquipPenToggle and type(autoEquipPenToggle.SetValue) == "function" then
                autoEquipPenToggle:SetValue(v)
                didSet = true
            end
        end)
        if not didSet then applyAutoEquipBestPen(v, spawnAction) end
    end
    if MiscCfg.AutoEquipBestPen then task.spawn(equipBestPen) end
    -- Padding transparan supaya toggle pen nggak nempel pas di batas bawah
    -- Outline section (render sebelumnya kelihatan setengah terpotong).
    pcall(function()
        local content = autoEquipPenToggle.ElementFrame
            and typeof(autoEquipPenToggle.ElementFrame) == "Instance"
            and autoEquipPenToggle.ElementFrame.Parent or nil
        if content then
            local pad = Instance.new("Frame")
            pad.Name = "LXC_AutoEquipPad"
            pad.BackgroundTransparency = 1
            pad.BorderSizePixel = 0
            pad.Size = UDim2.new(1, 0, 0, 14)
            pad.LayoutOrder = 999
            pad.Parent = content
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

    -- HUD masuk Settings, bukan Controls (satu section saja, jangan dobel).
    local HudSection = trackSection("HUD", SettingsTab:Section({ Title = "HUD", Opened = true }))
    local hideHudToggle = HudSection:Toggle({
        Title = "Hide HUD",
        Desc = "Sembunyikan teks status floating supaya klik tembus ke game",
        Value = HudCfg.Hidden,
        Callback = function(v) pcall(function() genv.LoopXCode_SetHudHidden(v) end) end
    })
    UIHandles["Hide HUD"] = hideHudToggle
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
        Placeholder = "50  (0 = off, 100 = solid)",
        Callback = function(v)
            HudCfg.Shadow = math.clamp(tonumber(v) or 50, 0, 100)
            pcall(function() genv.LoopXCode_ApplyHudLayout() end)
        end
    })
    HudSection:Input({
        Title = "HUD Shadow Offset",
        Value = tostring(HudCfg.ShadowOffset),
        Placeholder = "1",
        Callback = function(v)
            HudCfg.ShadowOffset = math.clamp(math.floor(tonumber(v) or 1), 0, 12)
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
        Values = { "Fast" },
        Value = StealCfg.ReelMode,
        Callback = function(v) StealCfg.ReelMode = "Fast" end
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
        Placeholder = "1S 20M 30K 50B 1T  (blank = any)",
        Callback = function(v) StealCfg.CustomIncome = tostring(v or "") end
    })
    UIHandles["Min Income"] = incomeInput
    -- WindUI Input cuma fire callback pas Enter/FocusLost. Pasang listener langsung
    -- di TextBox supaya filter ngefek seketika pas daddy ngetik.
    pcall(function()
        local box = nil
        for _, o in ipairs(gethui():GetDescendants()) do
            if o:IsA("TextBox") and tostring(o.PlaceholderText):find("20M", 1, true) then
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
            if o:IsA("TextBox") and (tostring(o.PlaceholderText) == "50000" or tostring(o.Text) == tostring(SpeedCfg.Value)) then
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
                n = math.max(16, math.min(50000, n))
                SpeedCfg.Value = n
                StealCfg.WalkSpeed = math.max(16, math.min(50000, n))
                -- Walk Speed input tidak menyalakan Speed Boost otomatis.
            end)
        end
    end)
    -- ---------- Experimen: paksa tangkap walau lasso lemah ----------
    local ExperimentSection = trackSection("Experimen", Tab:Section({ Title = "Experimen", Opened = true }))
    local weakCatchToggle = ExperimentSection:Toggle({
        Title = "Weak Lasso Catch",
        Desc = "Catch red (too-strong) pets; on fail keep hunting green/orange",
        Value = StealCfg.WeakAllowed,
        Callback = function(v) StealCfg.WeakAllowed = (v == true) end
    })
    UIHandles["Weak Lasso Catch"] = weakCatchToggle

    -- ---------- Tab: Sell (Auto Sell dipisah dari Controls/Features) ----------
    local SellSection = trackSection("Auto Sell", SellTab:Section({ Title = "Auto Sell", Opened = true }))
    local autoSellToggle = SellSection:Toggle({
        Title = "Auto Sell Pet",
        Desc = "Sell every selected rarity automatically",
        Value = SellCfg.Enabled,
        Callback = function(v)
            SellCfg.Enabled = (v == true)
            hubNotify(tr(SellCfg.Enabled and "Auto Sell ON" or "Auto Sell OFF"),
                SellCfg.Enabled and "Success" or "Info")
        end
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
        Callback = function()
            task.spawn(function()
                local sold = tonumber(genv.LoopXCode_SellPetsNow()) or 0
                if sold > 0 then
                    hubNotify(string.format(tr("Sell Now: %d pets"), sold), "Success")
                else
                    hubNotify(tr("Sell Now: no pets"), "Info")
                end
            end)
        end
    })

    -- ---------- Tab: Finder Pet ----------
    -- Menampilkan semua pet dari game: nama, income, rarity/tier, biome (dimap mana), dan gambar pet.
    local FinderSection = FinderTab:Section({ Title = "Pet Finder", Opened = true })

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
        Placeholder = "Nama pet, mis. Bunny",
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

        -- PC.Get/CC.GetPetIncome/SC.MoneyMult berjalan di thread game dan mengubah
        -- capability thread. Hitung dulu di thread terpisah, lalu pakai tabel murni
        -- di thread yang membuat elemen WindUI.
        local incomeReady = false
        task.spawn(function()
            local inc = {}
            for _, pet in ipairs(PC.Pets or {}) do
                if type(pet) == "table" and pet.Name then
                    local n = tostring(pet.Name)
                    local cfg = petCfg(n)
                    inc[n] = petIncome(cfg)
                end
            end
            genv.LoopXCode_FinderIncome = inc
            incomeReady = true
        end)
        local incomeGuard = 0
        while not incomeReady and incomeGuard < 300 do
            task.wait()
            incomeGuard += 1
        end
        local incomes = genv.LoopXCode_FinderIncome or {}

        for _, pet in ipairs(PC.Pets or {}) do
            if shown >= (FinderState.Limit or 70) then break end
            if type(pet) == "table" and pet.Name then
                local name = tostring(pet.Name)
                local display = tostring(pet.Display or humanize(name))
                local petBiome = tostring(pet.Biome or "?")
                local matchQ = (q == "" or string.lower(name):find(q, 1, true) ~= nil
                    or string.lower(display):find(q, 1, true) ~= nil)
                if (biome == "All" or petBiome == biome) and matchQ then
                    local income = tonumber(incomes[name]) or 0
                    local tier = tostring(pet.Tier or "Common")
                    local rarity = tostring(pet.Rarity or "Common")
                    local icon = nil
                    pcall(function()
                        -- Ambil langsung dari tabel modul. Memanggil PI.Get() dari game
                        -- mengubah capability thread dan bikin WindUI gagal membuat elemen.
                        if PI then icon = PI[name] end
                    end)
                    local okPara, para = pcall(function()
                        return FinderSection:Paragraph({
                            Title = string.format("%s  |  %s/s", display, fmtIncome(income)),
                            Desc = string.format("Rarity: %s  |  Tier: %s  |  Map/Biome: %s  |  Speed: %s",
                                rarity, tier, petBiome, tostring(pet.Speed or "-")),
                            Image = icon,
                            Buttons = {{
                                Title = "STEAL | " .. display,
                                Callback = function()
                                    task.spawn(function() startManualSteal(name) end)
                                end
                            }}
                        })
                    end)
                    if okPara and para then
                        finderParagraphs[#finderParagraphs + 1] = para
                        pcall(function()
                            if icon and type(para.SetImage) == "function" then para:SetImage(icon) end
                        end)
                    end
                    shown += 1
                end
            end
        end
        genv.LoopXCode_FinderBuilt = shown
        pcall(reapplyFonts)
    end
    FinderSection:Button({
        Title = "Refresh Finder",
        Callback = function() task.spawn(refreshFinder) end
    })
    genv.LoopXCode_RefreshFinder = refreshFinder
    -- BuildFinder dipanggil dari thread terpisah supaya pembuatan ratusan
    -- elemen WindUI tidak memakai thread capability yang sama dengan loader.
    task.spawn(function() pcall(refreshFinder) end)

    -- ---------- Tab: Settings ----------
    local Sections = {
        -- Features dipindah ke tab Features sendiri, bukan lagi di Settings.
        Features = trackSection("Features", FeaturesTab:Section({ Title = "Features", Opened = true })),
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
        elseif item.Kind == "Input" then
            handle = target:Input({
                Title = item.Name, Value = item.Default, Placeholder = item.Placeholder,
                Callback = item.Callback
            })
        elseif item.Kind == "Button" then
            handle = target:Button({ Title = item.Name, Callback = item.Callback })
        end
        if handle then UIHandles[item.Name] = handle end
    end
    for _, key in ipairs(genv.LoopXCode_HardenFeatureKeys) do
        UIHandles["Harden:" .. key] = UIHandles[genv.LoopXCode_HardenFeatureLabels[key]]
    end

    -- Execute pakai default yang sudah ditentukan daddy. Config bernama
    -- HANYA dipakai kalau daddy menekan tombol Load Config; auto-load yang lama
    -- bikin Anti Ban / Anti AFK / menu background nyala sendiri dari bank lama.

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
    -- HUD FPS/CPU/GPU/status dibiarkan TRANSPARAN TOTAL (tanpa latar kotak),
    -- teks tetap kebaca karena ada bayangan teks hitam di belakangnya.
    -- Fungsi terpisah supaya register lokal WindUI induk nggak jebol.
    local function buildFloatingLogo()
    -- HUD punya ScreenGui sendiri. DisplayOrder 20 meletakkannya di atas
    -- TopGui/RUN milik game (0), tapi tetap di bawah WindUI (30+) dan logo (50).
    local HudGui = Instance.new("ScreenGui")
    HudGui.Name = "LXC_HudGui"
    HudGui.ResetOnSpawn = false
    HudGui.IgnoreGuiInset = true
    HudGui.DisplayOrder = 20
    HudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    HudGui.Enabled = not HudCfg.Hidden
    HudGui.Parent = ParentGui
    genv.LoopXCode_SetHudHidden = function(v)
        HudCfg.Hidden = (v == true)
        pcall(function() HudGui.Enabled = not HudCfg.Hidden end)
        pcall(genv.LoopXCode_HardenSave)
    end
    pcall(genv.LoopXCode_SetHudHidden, HudCfg.Hidden)

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
    HudShadow.BackgroundTransparency = 1
    HudShadow.Font = Enum.Font.GothamBold
    HudShadow.TextColor3 = Color3.fromRGB(0, 0, 0)
    HudShadow.TextXAlignment = Enum.TextXAlignment.Center
    HudShadow.TextYAlignment = Enum.TextYAlignment.Center
    HudShadow.Text = hudPlainText()
    HudShadow.Active = false
    HudShadow.Parent = HudGui

    local FloatStatus = Instance.new("TextLabel")
    FloatStatus.Name = "HUD"
    FloatStatus.Size = UDim2.new(0, HudCfg.Width, 0, HudCfg.Height)
    FloatStatus.Position = UDim2.new(0.5, -HudCfg.Width / 2, 0, HudCfg.Gap)
    FloatStatus.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
    FloatStatus.BackgroundTransparency = 1
    FloatStatus.Font = Enum.Font.GothamBold
    FloatStatus.TextSize = HudCfg.TextSize
    FloatStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatStatus.TextXAlignment = Enum.TextXAlignment.Center
    FloatStatus.TextYAlignment = Enum.TextYAlignment.Center
    FloatStatus.RichText = true
    FloatStatus.Text = hudRichText()
    FloatStatus.Active = false
    FloatStatus.Parent = HudGui

    local function clampHudPos(pos)
        local w = math.max(1, math.floor(tonumber(HudCfg.Width) or 720))
        local h = math.max(1, math.floor(tonumber(HudCfg.Height) or 108))
        local gap = math.max(0, math.floor(tonumber(HudCfg.Gap) or 10))
        local sx, sy = HudGui.AbsoluteSize.X, HudGui.AbsoluteSize.Y
        if sx <= 0 or sy <= 0 then return pos end
        local left = math.clamp(pos.X.Offset + pos.X.Scale * sx, 0, math.max(0, sx - w))
        local top = math.clamp(pos.Y.Offset + pos.Y.Scale * sy, 0, math.max(0, sy - h))
        HudCfg.X = left - sx / 2 + w / 2
        HudCfg.Y = top - gap
        local finalPos = UDim2.new(0.5, left - sx / 2, 0, top)
        -- Shadow ikut HUD saat drag, bukan cuma saat applyHudLayout dipanggil.
        if HudShadow then
            local so = math.clamp(math.floor(tonumber(HudCfg.ShadowOffset) or 1), 0, 12)
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
        local sh = shadowAmount(HudCfg.Shadow, 50)
        local so = math.clamp(math.floor(tonumber(HudCfg.ShadowOffset) or 1), 0, 12)
        HudCfg.Width, HudCfg.Height, HudCfg.TextSize, HudCfg.Gap = w, h, ts, gap
        HudCfg.ShadowOffset = so
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

    OnCleanup(function()
        pcall(function() FloatGui:Destroy() end)
        pcall(function() HudGui:Destroy() end)
    end)
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
        if menuBgController then pcall(function() menuBgController:SetEnabled(MiscCfg.MenuBackground == true) end) end
        buildFloatingLogo()
    end)
    if not okTail then genv.LoopXCode_TailError = tostring(tailErr) end
end
buildWindUI()

-- Default ON Catch/Farm/Sell jalan setelah UI dibangun. Auto-load config
-- sengaja mati, jadi ini satu-satunya jalur start saat execute.
;(function()
    if genv.LoopXCode_StealCfg.Enabled then
        pcall(function() genv.LoopXCode_ApplyAutoSteal(true) end)
    end
    if genv.LoopXCode_FarmCfg.Enabled then
        pcall(function() genv.LoopXCode_ApplyAutoFarm(true) end)
    end
    if genv.LoopXCode_HardenCfg.UnlockFPS then
        pcall(function() genv.LoopXCode_SetFpsCap(genv.LoopXCode_GetFpsCap()) end)
    end
end)()

-- =====================================================================
-- 7. RADIUS PASS — paling luar saja
-- =====================================================================
-- Yang boleh bulat: window, wallpaper menu, floating LXC, kartu loading.
-- Semua elemen dalam (baris, tombol, input, dropdown, scrollbar) dipaksa
-- kotak supaya nggak ada bulatan kecil di setiap sisi yang bikin menu aneh.
-- Function scope sendiri supaya ratusan lokal di sini tidak menambah register
-- buildWindUI (Luau batas 200 local per function).
;(function(ParentGui)
    local RADIUS_WINDOW = UDim.new(0, 16)
    local WINDOW_BG = Color3.fromRGB(14, 16, 24)
    local RESIZE_GRIP_IMAGE = "120997033468887"

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

    local function insideMenuWallpaper(obj)
        local node = obj
        while node do
            if node.Name == "LXC_MenuBackground" then return true end
            node = node.Parent
        end
        return false
    end

    -- Elemen dalam dipaksa kotak. Cuma radius yang dinolkan; warna/teks asli
    -- WindUI dibiarkan supaya perubahan tetap minimal.
    local function clearInnerRadius(obj)
        if not obj then return end
        pcall(function()
            for _, c in ipairs(obj:GetChildren()) do
                if c:IsA("UICorner") then c.CornerRadius = UDim.new(0, 0) end
            end
        end)
    end

    -- Bayangan = nama mengandung "shadow", ATAU objek daun (tanpa anak) yang
    -- letaknya di belakang induk dan lebih besar. Syarat "daun" penting supaya
    -- container yang kebetulan lebih besar nggak ikut dimatikan.
    local function isShadowLike(obj)
        local name = string.lower(tostring(obj.Name or ""))
        if name:find("shadow", 1, true) then return true end

        -- Grip resize WindUI: image 96x96 di dalam frame 32x32. Jangan
        -- dikira bayangan, karena ini pegangan putih pojok kanan bawah.
        if obj:IsA("ImageLabel") then
            local ok, img = pcall(function() return obj.Image end)
            if ok and tostring(img):find(RESIZE_GRIP_IMAGE, 1, true) then return false end
        end

        if #obj:GetChildren() > 0 then return false end
        local parent = obj.Parent
        if not parent or not parent:IsA("GuiObject") then return false end
        local ps, cs = parent.AbsoluteSize, obj.AbsoluteSize
        if ps.X <= 0 or ps.Y <= 0 then return false end
        return obj.ZIndex <= parent.ZIndex and cs.X > ps.X + 1 and cs.Y > ps.Y + 1
    end

    local function hideShadow(obj)
        pcall(function()
            obj.Visible = false
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                obj.ImageTransparency = 1
            end
            obj.BackgroundTransparency = 1
        end)
    end

    -- WindUI menween grip resize ke 0.8 saat Open dan 0.35 saat hover.
    -- Sapuan radius jangan mematikan grip ini; kalau pernah ketutup, nyalakan
    -- lagi tanpa merusak transparansi hover.
    local function restoreResizeGrip(root)
        if not root then return end
        for _, o in ipairs(root:GetDescendants()) do
            if o:IsA("ImageLabel") then
                local ok, img = pcall(function() return o.Image end)
                if ok and tostring(img):find(RESIZE_GRIP_IMAGE, 1, true) then
                    pcall(function()
                        o.Visible = true
                        if o.ImageTransparency >= 0.99 then o.ImageTransparency = 0.8 end
                    end)
                end
            end
        end
    end

    local function polish(obj)
        if not obj or not obj:IsA("GuiObject") then return end
        local name = tostring(obj.Name or "")
        local lower = string.lower(name)

        -- HUD cuma teks: latar transparan, tanpa corner/outline kotak.
        if name == "HUD" or name == "HUDShadow" then
            pcall(function()
                obj.BackgroundTransparency = 1
                if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    obj.ImageTransparency = 1
                end
            end)
            clearInnerRadius(obj)
            return
        end

        -- Wallpaper mengikuti sudut window. Cuma lapisan ini yang boleh bulat;
        -- "Background" di dalam elemen lain nggak boleh ikut terkena.
        local isWindowPlate = name == "Background" and obj.Parent
            and obj.Parent.Name == "Main"
        local isWallpaper = name == "LXC_MenuBackground"
            or ((lower == "gradient" or lower:find("pattern", 1, true))
                and insideMenuWallpaper(obj))
        if isWindowPlate or isWallpaper then
            ensureCorner(obj, RADIUS_WINDOW)
            return
        end

        if isShadowLike(obj) then
            hideShadow(obj)
            return
        end

        -- Semua elemen lain (baris, tombol, input, dropdown, scrollbar) kotak.
        clearInnerRadius(obj)
    end

    local function sweep()
        local win = genv.LoopXCode_UIWindow
        local root = win and win.UIElements and win.UIElements.Main or nil
        if not root then return end
        ensureCorner(root, RADIUS_WINDOW)
        pcall(function() root.BackgroundColor3 = WINDOW_BG end)
        for _, o in ipairs(root:GetDescendants()) do polish(o) end
        restoreResizeGrip(root)
    end

    local root = nil
    pcall(function()
        local win = genv.LoopXCode_UIWindow
        root = win and win.UIElements and win.UIElements.Main or nil
    end)

    if root then
        -- Layout WindUI baru stabil setelah frame pertama dan tab dibangun saat
        -- pertama diklik, jadi sapuan diulang bertahap.
        for _, delay in ipairs({ 0, 0.15, 0.5, 1.2, 2.5, 4 }) do
            task.delay(delay, function() pcall(sweep) end)
        end
        pcall(function()
            root.DescendantAdded:Connect(function(o)
                task.delay(0.1, function() pcall(polish, o) end)
            end)
        end)
    end

    -- Floating logo: radius. HUD + shadow tetap transparan (cuma teks).
    pcall(function()
        local floatGui = ParentGui:FindFirstChild("LXC_ToggleGui")
        if not floatGui then return end
        local btn = floatGui:FindFirstChild("LOOPXCODE_FloatingToggle")
        if btn then ensureCorner(btn, RADIUS_WINDOW) end
        local hud = floatGui:FindFirstChild("HUD")
        if hud then pcall(function() hud.BackgroundTransparency = 1 end) end
        local shadow = floatGui:FindFirstChild("HUDShadow")
        if shadow then pcall(function()
            shadow.BackgroundTransparency = 1
            shadow.Visible = true
        end) end
    end)

    -- Kartu loading: radius, tanpa bayangan kotak.
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
end)(ParentGui)

-- =====================================================================
-- 8. ANDROID EXECUTOR NOTIFICATION CLEANUP
-- =====================================================================
-- Dogle bikin banner "minimized" di tengah atas saat menu executor
-- dikecilin. Banner itu cuma muncul di Android/HP, bukan di PC. Sapu hanya
-- overlay executor yang cocok; semua root LXC / WindUI / notifikasi game
-- sengaja dikecualikan supaya toggle dan notifikasi hub tetap ada.
;(function()
    local isAndroid = false
    pcall(function()
        isAndroid = UserInputService:GetPlatform() == Enum.Platform.Android
    end)
    local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    if not isAndroid and not touchOnly then return end

    pcall(function()
        local old = genv.LoopXCode_AndroidOverlayCleanup
        if type(old) == "table" then
            for _, conn in ipairs(old.connections or {}) do
                pcall(function() conn:Disconnect() end)
            end
        end
    end)

    local state = { connections = {}, hidden = 0, fullSwept = false }
    genv.LoopXCode_AndroidOverlayCleanup = state

    local roots = {}
    local function addRoot(r)
        if r and not table.find(roots, r) then roots[#roots + 1] = r end
    end
    addRoot(ParentGui)
    pcall(function() addRoot(CoreGui) end)
    pcall(function() addRoot(LocalPlayer:FindFirstChild("PlayerGui")) end)

    local function protectedObject(o)
        local node = o
        while node do
            local n = string.lower(tostring(node.Name or ""))
            if n:find("lxc", 1, true) or n:find("loopxcode", 1, true)
                or n:find("windui", 1, true) or n == "notifications" then
                return true
            end
            node = node.Parent
        end
        return false
    end

    local function suspiciousName(o)
        local n = string.lower(tostring(o.Name or ""))
        return n:find("dogle", 1, true) ~= nil
            or n:find("notif", 1, true) ~= nil
            or n:find("toast", 1, true) ~= nil
            or n:find("banner", 1, true) ~= nil
            or n:find("minimi", 1, true) ~= nil
    end

    local function textMarked(o)
        if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
            local t = string.lower(tostring(o.Text or ""))
            return t:find("minimi", 1, true) ~= nil
                or t:find(" minimized", 1, true) ~= nil
                or t:find("diminimal", 1, true) ~= nil
        end
        return false
    end

    local function topCenter(o)
        if not o:IsA("GuiObject") or not o.Visible then return false end
        local camera = workspace.CurrentCamera
        if not camera then return false end
        local pos, size = o.AbsolutePosition, o.AbsoluteSize
        if size.X < 24 or size.Y < 10 or size.Y > 160 then return false end
        local vp = camera.ViewportSize
        local centerX = pos.X + size.X / 2
        return math.abs(centerX - vp.X / 2) <= math.max(150, vp.X * 0.3)
            and pos.Y <= vp.Y * 0.36
    end

    local function hasTopCenterMinimizeText(root)
        for _, o in ipairs(root:GetDescendants()) do
            if textMarked(o) and topCenter(o) then return true end
        end
        return false
    end

    local function removeOverlay(o)
        if not o or protectedObject(o) then return end
        pcall(function() o:Destroy() end)
        state.hidden = state.hidden + 1
    end

    local function checkObject(o)
        if not o or protectedObject(o) then return end
        if o:IsA("ScreenGui") then
            local n = string.lower(tostring(o.Name or ""))
            if n:find("notif", 1, true) or n:find("toast", 1, true)
                or n:find("banner", 1, true) or n:find("minimi", 1, true) then
                removeOverlay(o)
            elseif n:find("dogle", 1, true) and hasTopCenterMinimizeText(o) then
                -- Root executor sengaja dibiarkan; cuma banner minimized-nya
                -- yang dibuang supaya tombol/menu Dogle tetap bisa dipakai.
                for _, d in ipairs(o:GetDescendants()) do
                    if textMarked(d) and topCenter(d) then
                        local banner = d
                        while banner and banner ~= o do
                            if banner:IsA("Frame") then
                                removeOverlay(banner)
                                break
                            end
                            banner = banner.Parent
                        end
                    end
                end
            end
            return
        end
        if not o:IsA("GuiObject") then return end
        local n = string.lower(tostring(o.Name or ""))
        local nameHit = n:find("notif", 1, true) or n:find("toast", 1, true)
            or n:find("banner", 1, true) or n:find("minimi", 1, true)
        if nameHit and topCenter(o) then
            removeOverlay(o)
        elseif textMarked(o) and topCenter(o) then
            local banner = o
            while banner and banner ~= ParentGui do
                if banner:IsA("ScreenGui") or banner:IsA("Frame") then
                    removeOverlay(banner)
                    return
                end
                banner = banner.Parent
            end
        end
    end

    local function sweep()
        local fullScan = not state.fullSwept
        for _, root in ipairs(roots) do
            if root and root.Parent then
                -- gethui() dipindai tiap kali. CoreGui/PlayerGui cukup sekali
                -- saat startup; setelah itu DescendantAdded yang menangkap
                -- banner baru, supaya UI game nggak terus-menerus discan.
                if root == ParentGui or fullScan then
                    for _, o in ipairs(root:GetDescendants()) do checkObject(o) end
                else
                    for _, o in ipairs(root:GetChildren()) do
                        if suspiciousName(o) then checkObject(o) end
                    end
                end
            end
        end
        state.fullSwept = true
    end
    state.sweep = sweep

    local lastSweep = 0
    state.connections[#state.connections + 1] = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastSweep < 0.35 then return end
        lastSweep = now
        pcall(sweep)
    end)

    for _, root in ipairs(roots) do
        if root then
            pcall(function()
                state.connections[#state.connections + 1] = root.DescendantAdded:Connect(function(o)
                    task.defer(function()
                        if genv.LoopXCode_AndroidOverlayCleanup ~= state then return end
                        pcall(function() checkObject(o) end)
                    end)
                end)
            end)
        end
    end

    task.defer(function()
        if genv.LoopXCode_AndroidOverlayCleanup == state then pcall(sweep) end
    end)
end)()
