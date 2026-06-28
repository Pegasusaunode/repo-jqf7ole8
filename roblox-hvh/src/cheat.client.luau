--!nocheck
-- =====================================================================
--  CS:GO-style HVH (rage) cheat menu for Roblox  ::  client entry point
-- ---------------------------------------------------------------------
--  Behaviour requested by the user:
--    * The menu is bound to the [Delete] key.
--    * The very first time it is opened a small smooth loading bar drops
--      in from the top, then the real menu slides out.
--    * It is a CS:GO "rage / HVH" style cheat with tabs and real working
--      features that actually affect the game (the two NPCs in the place).
--    * EVERYTHING is randomly rolled on each launch: the cheat name, the
--      menu style/colours and the "quality / power" of the cheat itself
--      (it can roll bad, mid or insane -> aimbot accuracy, smoothing, FOV,
--      which features even exist, how many shots whiff, etc).
--
--  The cheat abuses the (fully client-trusted) gun remotes that already
--  ship inside the SSG-08 tool:  TakeDamage / CastRay / PlaySound.
--  That is exactly how a real HVH "rage" bot behaves: it talks straight
--  to the damage remote instead of relying on the local mouse.
-- =====================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--========================================================================
-- 0.  RNG / helpers
--========================================================================
local rng = Random.new(os.clock() * 1e6 + tick())

local function chance(p) return rng:NextNumber() < p end
local function pick(t) return t[rng:NextInteger(1, #t)] end
local function lerp(a, b, t) return a + (b - a) * t end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

--========================================================================
-- 1.  ROLL THE BUILD  (name + theme + quality/power)
--========================================================================
local BRAND_A = {"Aim","Never","Game","One","Fatal","Skeet","Void","Nix","Spect","Hyper","Celest","Phant","Onyx","Astra","Rage"}
local BRAND_B = {"ware","lose","sense","tap","ity","re","ware","tux","ral","ion","ial","om","ware","l","bot"}
local BRAND_T = {".cc",".net",".gg"," v2"," v4"," Lite"," Premium"," Internal"," Beta"," HVH"}

local function rollName()
	local n = pick(BRAND_A) .. pick(BRAND_B)
	if chance(0.7) then n = n .. pick(BRAND_T) end
	return n
end

-- quality tiers: weighted so "mid" is most common, "insane" rare, "skid" possible
local TIERS = {
	{name = "SKID",     weight = 22, mul = 0.45},
	{name = "FREE",     weight = 26, mul = 0.62},
	{name = "MID",      weight = 28, mul = 0.80},
	{name = "PAID",     weight = 16, mul = 0.92},
	{name = "INTERNAL", weight = 8,  mul = 1.00},
}
local function rollTier()
	local total = 0
	for _, t in ipairs(TIERS) do total += t.weight end
	local r = rng:NextNumber() * total
	for _, t in ipairs(TIERS) do
		r -= t.weight
		if r <= 0 then return t end
	end
	return TIERS[#TIERS]
end

local THEMES = {
	{bg = rgb(18,18,22),  panel = rgb(26,26,32),  accent = rgb(120,90,255)},  -- purple (neverlose-ish)
	{bg = rgb(16,18,16),  panel = rgb(24,28,24),  accent = rgb(120,255,140)}, -- green
	{bg = rgb(20,16,16),  panel = rgb(30,22,22),  accent = rgb(255,90,90)},   -- red
	{bg = rgb(14,16,22),  panel = rgb(22,26,34),  accent = rgb(90,180,255)},  -- blue (skeet-ish)
	{bg = rgb(22,18,14),  panel = rgb(32,26,20),  accent = rgb(255,170,60)},  -- orange
	{bg = rgb(18,16,20),  panel = rgb(28,24,30),  accent = rgb(255,90,200)},  -- pink
	{bg = rgb(12,12,12),  panel = rgb(20,20,20),  accent = rgb(230,230,230)}, -- mono / b&w
}

local CORNERS = {0, 4, 8, 12}           -- some builds are sharp, some rounded
local FONTS   = {Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.Code, Enum.Font.SourceSansBold, Enum.Font.Nunito}

local Build = {}
Build.name   = rollName()
Build.tier   = rollTier()
Build.theme  = pick(THEMES)
Build.corner = pick(CORNERS)
Build.font   = pick(FONTS)
Build.glow   = chance(0.55)            -- accent stroke / drop shadow on the panel
Build.scan   = chance(0.4)             -- animated accent scanline on the title bar
Build.watermark = chance(0.85)

-- power derived from the tier multiplier (with a bit of variance per build)
local mul = Build.tier.mul * lerp(0.9, 1.1, rng:NextNumber())
Build.power = {
	hitChance   = math.clamp(mul, 0.30, 0.99),       -- % of rage shots that actually connect
	smoothing   = math.clamp((1.15 - mul) * 8, 0.4, 9), -- lower tier => more jitter / slower snap
	maxFov      = math.floor(lerp(80, 360, mul)),    -- aimbot field of view (px)
	hsChance    = math.clamp(mul - 0.1, 0.05, 0.95), -- chance a connecting shot is a headshot
	dmgScale    = lerp(0.7, 1.6, mul),               -- damage multiplier on the remote
	resolver    = mul > 0.7,                         -- "resolver" present on higher tiers
}

-- low tier builds randomly ship with broken / missing features (realism)
local function featureWorks(baseChance)
	-- higher tier = features almost always work
	return chance(math.clamp(baseChance + (mul - 0.6), 0.05, 0.99))
end

--========================================================================
-- 2.  STATE  (the actual feature flags / values the loops read)
--========================================================================
local F = {
	-- RAGE
	aimbot       = false,
	silent       = false,   -- damage lands regardless of where you look
	autoshoot    = false,   -- full rage bot: fires by itself
	hitbox       = "Head",  -- Head / Torso / Random
	rageFov      = math.min(Build.power.maxFov, 200),
	-- ANTI-AIM
	spin         = false,
	jitter       = false,
	fakelag      = false,
	-- VISUALS
	boxEsp       = false,
	healthBar    = false,
	nameEsp      = false,
	tracers      = false,
	chams        = false,
	fovCircle    = false,
	-- MISC
	walkspeed    = 16,
	jumppower    = 50,
	infJump      = false,
	fly          = false,
	flySpeed     = 60,
	fullbright   = false,
	bigHitbox    = false,
}

-- which features this build is allowed to even show / use
local Available = {
	aimbot    = true,
	silent    = featureWorks(0.7),
	autoshoot = featureWorks(0.6),
	resolver  = Build.power.resolver,
	spin      = featureWorks(0.7),
	jitter    = featureWorks(0.6),
	fakelag   = featureWorks(0.5),
	boxEsp    = featureWorks(0.85),
	healthBar = featureWorks(0.8),
	nameEsp   = featureWorks(0.8),
	tracers   = featureWorks(0.7),
	chams     = featureWorks(0.65),
	fovCircle = featureWorks(0.85),
	fly       = featureWorks(0.6),
	bigHitbox = featureWorks(0.55),
}

--========================================================================
-- 3.  GAME HOOKS  (find the gun remotes + targets)
--========================================================================
local function getCharacter()
	return LocalPlayer.Character
end

-- locate the SSG-08 remotes wherever the tool currently lives
local function getRemotes()
	local spots = {getCharacter(), LocalPlayer:FindFirstChild("Backpack")}
	for _, parent in ipairs(spots) do
		if parent then
			for _, child in ipairs(parent:GetChildren()) do
				if child:IsA("Tool") then
					local rem = child:FindFirstChild("Remotes")
					if rem and rem:FindFirstChild("TakeDamage") then
						return rem, child
					end
				end
			end
		end
	end
	return nil, nil
end

-- every living NPC / player except us
local function getTargets()
	local list = {}
	local myChar = getCharacter()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Humanoid") and inst.Health > 0 then
			local model = inst.Parent
			if model and model ~= myChar then
				local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
				local head = model:FindFirstChild("Head")
				if hrp then
					table.insert(list, {model = model, hum = inst, hrp = hrp, head = head or hrp})
				end
			end
		end
	end
	return list
end

local function hitboxPart(t)
	if F.hitbox == "Head" then return t.head end
	if F.hitbox == "Torso" then return t.hrp end
	-- Random
	return chance(0.5) and t.head or t.hrp
end

-- pick the target whose chosen hitbox is closest to the screen centre and within FOV
local function selectTarget(fovPx)
	local best, bestDist
	local centre = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	for _, t in ipairs(getTargets()) do
		local part = hitboxPart(t)
		if part then
			local sp, on = Camera:WorldToViewportPoint(part.Position)
			if on then
				local d = (Vector2.new(sp.X, sp.Y) - centre).Magnitude
				if d <= fovPx and (not bestDist or d < bestDist) then
					best, bestDist = t, d
				end
			end
		end
	end
	return best
end

local theme = Build.theme

--========================================================================
-- 3b.  BOOT  -  bind the toggle key FIRST + show a visible "loaded" toast,
--       so the cheat is usable even if something in the UI build errors.
--========================================================================
local toggleMenu                  -- assigned by the UI build below
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local function showToast(text, color, life)
	local tg = Instance.new("ScreenGui")
	tg.Name = "_boot" .. tostring(rng:NextInteger(100, 999))
	tg.ResetOnSpawn = false
	tg.IgnoreGuiInset = true
	tg.DisplayOrder = 10000
	tg.Parent = playerGui
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, 6)
	l.Size = UDim2.new(0, 380, 0, 24)
	l.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	l.BackgroundTransparency = 0.1
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextColor3 = color or theme.accent
	l.Text = text
	l.Parent = tg
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = l
	if life ~= math.huge then
		task.delay(life or 5, function() tg:Destroy() end)
	end
	return tg, l
end

showToast(Build.name .. "   loaded  -  press DELETE", theme.accent, 6)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Insert then
		if toggleMenu then
			toggleMenu()
		else
			showToast("menu is still loading / failed to build", Color3.fromRGB(255, 180, 60), 3)
		end
	elseif input.KeyCode == Enum.KeyCode.Space and F.infJump then
		local char = getCharacter()
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

--========================================================================
-- 4.  UI  BUILD  (wrapped in pcall so a failure can't kill the toggle key)
--========================================================================
local buildOk, buildErr = pcall(function()

local gui = Instance.new("ScreenGui")
gui.Name = "_" .. tostring(rng:NextInteger(100000, 999999)) -- obscure-ish name
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.Parent = playerGui

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or Build.corner)
	c.Parent = parent
	return c
end
local function stroke(parent, col, th)
	local s = Instance.new("UIStroke")
	s.Color = col or theme.accent
	s.Thickness = th or 1
	s.Transparency = 0.25
	s.Parent = parent
	return s
end
local function label(parent, text, size, col)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Build.font
	l.Text = text
	l.TextSize = size or 14
	l.TextColor3 = col or rgb(235,235,235)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

----------------------------------------------------------------------
-- 4a.  Loading bar (top, shown once on first open)
----------------------------------------------------------------------
local function playLoader(done)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, -40)
	holder.Size = UDim2.new(0, 300, 0, 30)
	holder.BackgroundColor3 = theme.panel
	holder.BackgroundTransparency = 0.05
	holder.Parent = gui
	corner(holder, math.max(4, Build.corner))
	stroke(holder, theme.accent, 1)

	local title = label(holder, Build.name, 13, rgb(245,245,245))
	title.Position = UDim2.new(0, 10, 0, 2)
	title.Size = UDim2.new(1, -20, 0, 13)

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(0, 10, 0, 19)
	barBg.Size = UDim2.new(1, -20, 0, 4)
	barBg.BackgroundColor3 = rgb(60,60,68)
	barBg.Parent = holder
	corner(barBg, 2)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = theme.accent
	bar.Parent = barBg
	corner(bar, 2)

	-- drop in
	TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 0, 24)}):Play()

	local steps = {"loading modules", "bypassing", "injecting", "ready"}
	task.spawn(function()
		local n = 18
		for i = 1, n do
			local a = i / n
			bar.Size = UDim2.new(a, 0, 1, 0)
			title.Text = string.format("%s  -  %s", Build.name, steps[math.min(#steps, math.ceil(a * #steps))])
			task.wait(rng:NextNumber(0.03, 0.085)) -- slightly uneven = feels real
		end
		task.wait(0.15)
		TweenService:Create(holder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Position = UDim2.new(0.5, 0, 0, -45), BackgroundTransparency = 1}):Play()
		task.wait(0.32)
		holder:Destroy()
		done()
	end)
end

----------------------------------------------------------------------
-- 4b.  Main window
----------------------------------------------------------------------
local win = Instance.new("Frame")
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.Position = UDim2.new(0.5, 0, 0.5, 0)
win.Size = UDim2.new(0, 520, 0, 360)
win.BackgroundColor3 = theme.bg
win.Visible = false
win.Parent = gui
corner(win)
if Build.glow then stroke(win, theme.accent, 1.5) end

-- title bar
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 34)
bar.BackgroundColor3 = theme.panel
bar.Parent = win
corner(bar)
local barFix = Instance.new("Frame") -- square off the bottom of the rounded bar
barFix.Size = UDim2.new(1, 0, 0, 12)
barFix.Position = UDim2.new(0, 0, 1, -12)
barFix.BackgroundColor3 = theme.panel
barFix.BorderSizePixel = 0
barFix.Parent = bar

local titleTxt = label(bar, Build.name, 15, rgb(245,245,245))
titleTxt.Position = UDim2.new(0, 12, 0, 0)
titleTxt.Size = UDim2.new(0.6, 0, 1, 0)
titleTxt.Font = Enum.Font.GothamBold

local badge = label(bar, Build.tier.name, 12, theme.accent)
badge.Position = UDim2.new(1, -110, 0, 0)
badge.Size = UDim2.new(0, 100, 1, 0)
badge.TextXAlignment = Enum.TextXAlignment.Right
badge.Font = Enum.Font.GothamBold

if Build.scan then
	local scan = Instance.new("Frame")
	scan.Size = UDim2.new(0, 60, 0, 2)
	scan.Position = UDim2.new(0, 0, 1, -2)
	scan.BackgroundColor3 = theme.accent
	scan.BorderSizePixel = 0
	scan.Parent = bar
	task.spawn(function()
		while scan.Parent do
			scan.Position = UDim2.new(0, -60, 1, -2)
			TweenService:Create(scan, TweenInfo.new(2.2, Enum.EasingStyle.Linear),
				{Position = UDim2.new(1, 0, 1, -2)}):Play()
			task.wait(2.4)
		end
	end)
end

-- tab column
local tabCol = Instance.new("Frame")
tabCol.Position = UDim2.new(0, 0, 0, 34)
tabCol.Size = UDim2.new(0, 120, 1, -34)
tabCol.BackgroundColor3 = theme.panel
tabCol.BorderSizePixel = 0
tabCol.Parent = win
local tabList = Instance.new("UIListLayout")
tabList.Padding = UDim.new(0, 4)
tabList.Parent = tabCol
local tabPad = Instance.new("UIPadding")
tabPad.PaddingTop = UDim.new(0, 8)
tabPad.PaddingLeft = UDim.new(0, 8)
tabPad.PaddingRight = UDim.new(0, 8)
tabPad.Parent = tabCol

-- content area
local content = Instance.new("Frame")
content.Position = UDim2.new(0, 120, 0, 34)
content.Size = UDim2.new(1, -120, 1, -34)
content.BackgroundTransparency = 1
content.Parent = win

local pages = {}
local tabButtons = {}
local function showTab(name)
	for n, page in pairs(pages) do page.Visible = (n == name) end
	for n, btn in pairs(tabButtons) do
		btn.TextColor3 = (n == name) and theme.accent or rgb(170,170,175)
		btn.BackgroundTransparency = (n == name) and 0.85 or 1
	end
end

local function addTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 30)
	btn.BackgroundColor3 = theme.accent
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamMedium
	btn.Text = name
	btn.TextSize = 13
	btn.TextColor3 = rgb(170,170,175)
	btn.Parent = tabCol
	corner(btn, 6)
	tabButtons[name] = btn

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = theme.accent
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = content
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 6)
	lay.Parent = page
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = page
	pages[name] = page

	btn.MouseButton1Click:Connect(function() showTab(name) end)
	return page
end

----------------------------------------------------------------------
-- 4c.  Components: toggle / slider / dropdown
----------------------------------------------------------------------
local function makeToggle(page, text, available, default, onChange)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.AutoButtonColor = false
	row.Text = ""
	row.Parent = page

	local name = label(row, text, 14, available and rgb(225,225,228) or rgb(110,110,115))
	name.Position = UDim2.new(0, 30, 0, 0)
	name.Size = UDim2.new(1, -40, 1, 0)

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0, 2, 0.5, 0)
	box.Size = UDim2.new(0, 18, 0, 18)
	box.BackgroundColor3 = rgb(45,45,52)
	box.Parent = row
	corner(box, 5)
	stroke(box, rgb(70,70,78), 1)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = theme.accent
	fill.BackgroundTransparency = 1
	fill.Parent = box
	corner(fill, 5)

	if not available then
		local lk = label(row, "broken", 11, rgb(150,90,90))
		lk.Position = UDim2.new(1, -70, 0, 0)
		lk.Size = UDim2.new(0, 60, 1, 0)
		lk.TextXAlignment = Enum.TextXAlignment.Right
		return
	end

	local state = default or false
	local function render()
		fill.BackgroundTransparency = state and 0 or 1
	end
	render()
	row.MouseButton1Click:Connect(function()
		state = not state
		render()
		onChange(state)
	end)
	if state then onChange(state) end
end

local function makeSlider(page, text, min, max, default, suffix, onChange)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 40)
	holder.BackgroundTransparency = 1
	holder.Parent = page

	local name = label(holder, text, 14, rgb(225,225,228))
	name.Size = UDim2.new(1, -60, 0, 18)
	local val = label(holder, tostring(default) .. (suffix or ""), 13, theme.accent)
	val.Position = UDim2.new(1, -60, 0, 0)
	val.Size = UDim2.new(0, 60, 0, 18)
	val.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("TextButton")
	track.Text = ""
	track.AutoButtonColor = false
	track.Position = UDim2.new(0, 0, 0, 26)
	track.Size = UDim2.new(1, 0, 0, 6)
	track.BackgroundColor3 = rgb(45,45,52)
	track.Parent = holder
	corner(track, 3)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = theme.accent
	fill.Parent = track
	corner(fill, 3)

	local function set(a)
		a = math.clamp(a, 0, 1)
		local v = math.floor(lerp(min, max, a) + 0.5)
		fill.Size = UDim2.new(a, 0, 1, 0)
		val.Text = tostring(v) .. (suffix or "")
		onChange(v)
	end
	set((default - min) / (max - min))

	local dragging = false
	local function fromX(x)
		set((x - track.AbsolutePosition.X) / track.AbsoluteSize.X)
	end
	track.MouseButton1Down:Connect(function() dragging = true end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			fromX(i.Position.X)
		end
	end)
	track.MouseButton1Click:Connect(function()
		fromX(UserInputService:GetMouseLocation().X)
	end)
end

local function makeDropdown(page, text, options, default, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.Parent = page
	local name = label(row, text, 14, rgb(225,225,228))
	name.Size = UDim2.new(0.5, 0, 1, 0)

	local btn = Instance.new("TextButton")
	btn.Position = UDim2.new(0.5, 0, 0, 1)
	btn.Size = UDim2.new(0.5, 0, 0, 24)
	btn.BackgroundColor3 = rgb(40,40,47)
	btn.Font = Build.font
	btn.TextSize = 13
	btn.TextColor3 = theme.accent
	btn.Text = default
	btn.Parent = row
	corner(btn, 5)

	local idx = table.find(options, default) or 1
	btn.MouseButton1Click:Connect(function()
		idx = (idx % #options) + 1
		btn.Text = options[idx]
		onChange(options[idx])
	end)
end

----------------------------------------------------------------------
-- 4d.  Populate tabs
----------------------------------------------------------------------
local pRage   = addTab("RAGE")
local pAnti   = addTab("ANTI-AIM")
local pVis    = addTab("VISUALS")
local pMisc   = addTab("MISC")

makeToggle(pRage, "Aimbot", Available.aimbot, false, function(s) F.aimbot = s end)
makeToggle(pRage, "Silent Aim", Available.silent, false, function(s) F.silent = s end)
makeToggle(pRage, "Auto Shoot (rage)", Available.autoshoot, false, function(s) F.autoshoot = s end)
makeDropdown(pRage, "Hitbox", {"Head","Torso","Random"}, "Head", function(v) F.hitbox = v end)
makeSlider(pRage, "Aimbot FOV", 30, Build.power.maxFov, F.rageFov, "px", function(v) F.rageFov = v end)
do
	local note = label(pRage, string.format("hit chance ~%d%%  -  smoothing %.1f%s",
		math.floor(Build.power.hitChance * 100), Build.power.smoothing,
		Build.power.resolver and "  -  resolver: ON" or "  -  resolver: OFF"), 12, rgb(140,140,148))
	note.Size = UDim2.new(1, 0, 0, 18)
end

makeToggle(pAnti, "Spinbot", Available.spin, false, function(s) F.spin = s end)
makeToggle(pAnti, "Jitter", Available.jitter, false, function(s) F.jitter = s end)
makeToggle(pAnti, "Fake Lag", Available.fakelag, false, function(s) F.fakelag = s end)

makeToggle(pVis, "Box ESP", Available.boxEsp, false, function(s) F.boxEsp = s end)
makeToggle(pVis, "Health Bar", Available.healthBar, false, function(s) F.healthBar = s end)
makeToggle(pVis, "Name / Distance", Available.nameEsp, false, function(s) F.nameEsp = s end)
makeToggle(pVis, "Tracers", Available.tracers, false, function(s) F.tracers = s end)
makeToggle(pVis, "Chams (highlight)", Available.chams, false, function(s) F.chams = s end)
makeToggle(pVis, "FOV Circle", Available.fovCircle, false, function(s) F.fovCircle = s end)

makeSlider(pMisc, "WalkSpeed", 16, 250, 16, "", function(v) F.walkspeed = v end)
makeSlider(pMisc, "JumpPower", 50, 350, 50, "", function(v) F.jumppower = v end)
makeToggle(pMisc, "Infinite Jump", true, false, function(s) F.infJump = s end)
makeToggle(pMisc, "Fly", Available.fly, false, function(s) F.fly = s end)
makeSlider(pMisc, "Fly Speed", 20, 250, 60, "", function(v) F.flySpeed = v end)
makeToggle(pMisc, "Fullbright", true, false, function(s) F.fullbright = s end)
makeToggle(pMisc, "Big NPC Hitbox", Available.bigHitbox, false, function(s) F.bigHitbox = s end)

showTab("RAGE")

-- footer credit / build info
local foot = label(win, string.format("%s  |  tier: %s  |  press DELETE to toggle", Build.name, Build.tier.name), 11, rgb(120,120,128))
foot.AnchorPoint = Vector2.new(0.5, 1)
foot.Position = UDim2.new(0.5, 0, 1, -6)
foot.Size = UDim2.new(1, -20, 0, 14)
foot.TextXAlignment = Enum.TextXAlignment.Center

----------------------------------------------------------------------
-- 4e.  drag the window by the title bar
----------------------------------------------------------------------
do
	local dragging, dragStart, startPos
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = i.Position
			startPos = win.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

--========================================================================
-- 5.  WATERMARK
--========================================================================
local wm
if Build.watermark then
	wm = label(gui, Build.name, 14, theme.accent)
	wm.AnchorPoint = Vector2.new(1, 0)
	wm.Position = UDim2.new(1, -10, 0, 8)
	wm.Size = UDim2.new(0, 260, 0, 18)
	wm.TextXAlignment = Enum.TextXAlignment.Right
	wm.Font = Enum.Font.GothamBold
	wm.Visible = true
	task.spawn(function()
		while wm.Parent do
			wm.Text = string.format("%s  |  %d fps  |  %s", Build.name,
				math.floor(1 / RunService.RenderStepped:Wait()), Build.tier.name)
		end
	end)
end

--========================================================================
-- 6.  TOGGLE / OPEN  (Delete key)
--========================================================================
local opened = false
local firstOpen = true
local menuShown = false

local function showMenu()
	win.Visible = true
	win.Size = UDim2.new(0, 520, 0, 0)
	TweenService:Create(win, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{Size = UDim2.new(0, 520, 0, 360)}):Play()
	menuShown = true
end

local function hideMenu()
	local t = TweenService:Create(win, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
		{Size = UDim2.new(0, 520, 0, 0)})
	t:Play()
	t.Completed:Connect(function() win.Visible = false end)
	menuShown = false
end

toggleMenu = function()
	opened = not opened
	if opened then
		if firstOpen then
			firstOpen = false
			playLoader(function() showMenu() end)
		else
			showMenu()
		end
	else
		if menuShown then hideMenu() end
	end
end

end) -- end UI-build pcall

if not buildOk then
	warn("[HVH] UI build error: " .. tostring(buildErr))
	showToast("UI error: " .. string.sub(tostring(buildErr), 1, 90), Color3.fromRGB(255, 80, 80), math.huge)
end

--========================================================================
-- 7.  COMBAT LOOP  (aimbot / silent / autoshoot)
--========================================================================
local lastShot = 0
local function doDamage(target, isHead)
	local rem, tool = getRemotes()
	if not rem then return end
	local td = rem:FindFirstChild("TakeDamage")
	local cr = rem:FindFirstChild("CastRay")
	if not td then return end

	local baseDmg = 28 * Build.power.dmgScale
	local cfg = tool and tool:FindFirstChild("Configuration")
	if cfg and cfg:FindFirstChild("Damage") then
		baseDmg = cfg.Damage.Value * Build.power.dmgScale
		if isHead and cfg:FindFirstChild("HeadshotMultiplier") then
			baseDmg = baseDmg * cfg.HeadshotMultiplier.Value
		end
	elseif isHead then
		baseDmg = baseDmg * 2
	end

	td:FireServer(target.hum, baseDmg)

	-- tracer/visual beam through the gun's own remote (only meaningful when equipped)
	if cr and tool and tool:FindFirstChild("Handle") then
		local part = isHead and target.head or target.hrp
		local origin = tool.Handle.Position
		local dir = (part.Position - origin)
		cr:FireServer(Ray.new(origin, dir.Unit * 2048), part.Position)
	end
end

RunService.RenderStepped:Connect(function()
	if not (F.aimbot or F.autoshoot or F.silent) then return end
	local target = selectTarget(F.rageFov)
	if not target then return end
	local part = hitboxPart(target)
	if not part then return end

	-- aimbot: drag the camera toward the hitbox (smoothing depends on build power)
	if F.aimbot then
		local want = CFrame.new(Camera.CFrame.Position, part.Position)
		local alpha = math.clamp(1 / Build.power.smoothing, 0.05, 1)
		Camera.CFrame = Camera.CFrame:Lerp(want, alpha)
	end

	-- auto shoot / silent: fire on the gun's firerate
	if F.autoshoot or F.silent then
		local _, tool = getRemotes()
		local firerate = 0.12
		local cfg = tool and tool:FindFirstChild("Configuration")
		if cfg and cfg:FindFirstChild("Firerate") then firerate = math.max(0.05, cfg.Firerate.Value) end
		if (os.clock() - lastShot) >= firerate then
			lastShot = os.clock()
			-- not every shot connects -> lower tiers whiff more (requested "some miss")
			if chance(Build.power.hitChance) then
				local isHead = (F.hitbox == "Head") or (F.hitbox ~= "Torso" and chance(Build.power.hsChance))
				doDamage(target, isHead)
			end
		end
	end
end)

--========================================================================
-- 8.  ANTI-AIM  (spin / jitter the character)  + fake lag stutter
--========================================================================
local fakeLagTick = 0
RunService.Stepped:Connect(function(_, dt)
	local char = getCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if F.spin then
		hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(40), 0)
	elseif F.jitter then
		hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(chance(0.5) and 160 or -160), 0)
	end

	if F.fakelag then
		fakeLagTick += dt
		if fakeLagTick > 0.18 then
			fakeLagTick = 0
			hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * 0.1
		end
	end
end)

--========================================================================
-- 9.  MISC LOOP  (walkspeed / jumppower / fly / fullbright / hitbox)
--========================================================================
local flyBV, flyBG
local function ensureFly(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not flyBV then
		flyBV = Instance.new("BodyVelocity")
		flyBV.MaxForce = Vector3.new(1,1,1) * 1e5
		flyBV.Velocity = Vector3.zero
		flyBV.Parent = hrp
		flyBG = Instance.new("BodyGyro")
		flyBG.MaxTorque = Vector3.new(1,1,1) * 1e5
		flyBG.P = 1e4
		flyBG.Parent = hrp
	end
end
local function stopFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
end

local defaultBright = Lighting.Brightness
local defaultClock  = Lighting.ClockTime
local originalSizes = {}

RunService.Heartbeat:Connect(function()
	local char = getCharacter()
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			if math.abs(hum.WalkSpeed - F.walkspeed) > 0.5 then hum.WalkSpeed = F.walkspeed end
			if math.abs(hum.JumpPower - F.jumppower) > 0.5 then hum.JumpPower = F.jumppower end
		end

		if F.fly then
			ensureFly(char)
			if flyBV then
				local dir = Vector3.zero
				local cf = Camera.CFrame
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
				flyBV.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * F.flySpeed
				flyBG.CFrame = cf
			end
		else
			stopFly()
		end
	end

	-- fullbright
	if F.fullbright then
		Lighting.Brightness = 3
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 1e9
	end

	-- big NPC hitbox (genuinely changes the target parts -> easier to hit)
	for _, t in ipairs(getTargets()) do
		if F.bigHitbox then
			if not originalSizes[t.head] and t.head:IsA("BasePart") then
				originalSizes[t.head] = t.head.Size
			end
			if t.head:IsA("BasePart") then
				t.head.Size = Vector3.new(8, 8, 8)
				t.head.Transparency = 0.6
				t.head.CanCollide = false
			end
		end
	end
	if not F.bigHitbox then
		for part, size in pairs(originalSizes) do
			if part and part.Parent then
				part.Size = size
				part.Transparency = 0
			end
			originalSizes[part] = nil
		end
	end
end)

--========================================================================
-- 10.  ESP  (boxes / health / name / tracers / chams / fov circle)
--========================================================================
local espGui = Instance.new("ScreenGui")
espGui.Name = "_esp" .. tostring(rng:NextInteger(100, 999))
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 9998
espGui.Parent = LocalPlayer.PlayerGui

local fovRing = Instance.new("Frame")
fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
fovRing.BackgroundTransparency = 1
fovRing.Parent = espGui
do
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1,0) c.Parent = fovRing
	local s = Instance.new("UIStroke") s.Color = theme.accent s.Thickness = 1.5 s.Transparency = 0.3 s.Parent = fovRing
end

local espCache = {}   -- model -> {box, hp, hpbg, name, tracer}
local highlights = {} -- model -> Highlight

local function getEsp(model)
	if espCache[model] then return espCache[model] end
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Parent = espGui
	local bs = Instance.new("UIStroke") bs.Color = theme.accent bs.Thickness = 1.5 bs.Parent = box

	local hpbg = Instance.new("Frame")
	hpbg.BackgroundColor3 = rgb(0,0,0)
	hpbg.BorderSizePixel = 0
	hpbg.Parent = espGui
	local hp = Instance.new("Frame")
	hp.BackgroundColor3 = rgb(80,255,90)
	hp.BorderSizePixel = 0
	hp.Parent = hpbg

	local nm = Instance.new("TextLabel")
	nm.BackgroundTransparency = 1
	nm.Font = Enum.Font.GothamBold
	nm.TextSize = 12
	nm.TextColor3 = rgb(245,245,245)
	nm.TextStrokeTransparency = 0.4
	nm.Parent = espGui

	local tr = Instance.new("Frame")
	tr.AnchorPoint = Vector2.new(0.5, 0)
	tr.BackgroundColor3 = theme.accent
	tr.BorderSizePixel = 0
	tr.Parent = espGui

	espCache[model] = {box = box, hpbg = hpbg, hp = hp, name = nm, tracer = tr, stroke = bs}
	return espCache[model]
end

local function hideEsp(e)
	e.box.Visible = false e.hpbg.Visible = false e.name.Visible = false e.tracer.Visible = false
end

RunService.RenderStepped:Connect(function()
	-- fov circle
	fovRing.Visible = F.fovCircle and (F.aimbot or F.autoshoot or F.silent)
	if fovRing.Visible then
		fovRing.Position = UDim2.new(0.5, 0, 0.5, 0)
		fovRing.Size = UDim2.new(0, F.rageFov * 2, 0, F.rageFov * 2)
	end

	local active = {}
	if F.boxEsp or F.healthBar or F.nameEsp or F.tracers or F.chams then
		for _, t in ipairs(getTargets()) do
			active[t.model] = true
			-- chams
			if F.chams then
				if not highlights[t.model] then
					local h = Instance.new("Highlight")
					h.FillColor = theme.accent
					h.FillTransparency = 0.55
					h.OutlineColor = rgb(255,255,255)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = t.model
					highlights[t.model] = h
				end
			elseif highlights[t.model] then
				highlights[t.model]:Destroy() highlights[t.model] = nil
			end

			local e = getEsp(t.model)
			local headPos = (t.head and t.head.Position or t.hrp.Position) + Vector3.new(0, 1.5, 0)
			local footPos = t.hrp.Position - Vector3.new(0, 3, 0)
			local hScr, onH = Camera:WorldToViewportPoint(headPos)
			local fScr = Camera:WorldToViewportPoint(footPos)
			if onH then
				local h = math.abs(fScr.Y - hScr.Y)
				local w = h * 0.55
				local x = hScr.X - w / 2
				local y = hScr.Y
				-- box
				e.box.Visible = F.boxEsp
				e.box.Position = UDim2.new(0, x, 0, y)
				e.box.Size = UDim2.new(0, w, 0, h)
				-- health
				e.hpbg.Visible = F.healthBar
				if F.healthBar then
					e.hpbg.Position = UDim2.new(0, x - 6, 0, y)
					e.hpbg.Size = UDim2.new(0, 3, 0, h)
					local frac = math.clamp(t.hum.Health / math.max(1, t.hum.MaxHealth), 0, 1)
					e.hp.Size = UDim2.new(1, 0, frac, 0)
					e.hp.Position = UDim2.new(0, 0, 1 - frac, 0)
					e.hp.BackgroundColor3 = rgb(math.floor(255 * (1 - frac)), math.floor(255 * frac), 70)
				end
				-- name + distance
				e.name.Visible = F.nameEsp
				if F.nameEsp then
					local dist = math.floor((Camera.CFrame.Position - t.hrp.Position).Magnitude)
					e.name.Text = string.format("%s [%dm]", t.model.Name, dist)
					e.name.Position = UDim2.new(0, x - 20, 0, y - 16)
					e.name.Size = UDim2.new(0, w + 40, 0, 14)
				end
				-- tracer
				e.tracer.Visible = F.tracers
				if F.tracers then
					local cx, cy = Camera.ViewportSize.X / 2, Camera.ViewportSize.Y
					local tx, ty = hScr.X, hScr.Y + h
					local mid = Vector2.new((cx + tx)/2, (cy + ty)/2)
					local len = (Vector2.new(tx,ty) - Vector2.new(cx,cy)).Magnitude
					local ang = math.atan2(ty - cy, tx - cx)
					e.tracer.Position = UDim2.new(0, mid.X, 0, mid.Y)
					e.tracer.Size = UDim2.new(0, 1.5, 0, len)
					e.tracer.Rotation = math.deg(ang) - 90
				end
			else
				hideEsp(e)
			end
		end
	end

	-- cleanup esp for dead / gone models
	for model, e in pairs(espCache) do
		if not active[model] then hideEsp(e) end
	end
	for model, h in pairs(highlights) do
		if not active[model] then h:Destroy() highlights[model] = nil end
	end
end)

--========================================================================
-- 11.  boot
--========================================================================
-- tiny console breadcrumb so the dev can see which build rolled
print(string.format("[%s] loaded  -  tier=%s  hit=%d%% fov=%d smoothing=%.1f",
	Build.name, Build.tier.name, math.floor(Build.power.hitChance * 100),
	Build.power.maxFov, Build.power.smoothing))
