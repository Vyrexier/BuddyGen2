-- Buddy.lua
local BuddyUI = require(script.Parent.BuddyGen2_UI) or loadstring(game:HttpGet("https://raw.githubusercontent.com/Vyrexier/BuddyGen2/refs/heads/main/BuddyGen2API.luau",true))()
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

-- Constants
local TEXT_SIZE = 18
local FONT = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local MAX_WIDTH = 280
local MIN_WIDTH = 60
local CORNER_RADIUS = UDim.new(0, 16)
local ROW_GAP = 8

local FONT_NAV = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
local navTween = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local activeBtn = nil
local navCallbacks = {}

local gethui = gethui or function() return Players.LocalPlayer.PlayerGui end

-- Bootstrap UI
local gui = BuddyUI.Create()
gui.Parent = Players.LocalPlayer.PlayerGui or gethui()

local scrollFrame = BuddyUI.Get("ChatScrollingFrame")
local recipientFrame = BuddyUI.Get("Recipient")
local senderFrame = BuddyUI.Get("Sender")
local textBox = BuddyUI.Get("ChatTypingBox")
local sendBtn = BuddyUI.Get("Send")
local listContainer = BuddyUI.Get("ListContainer")

-- Clear example instances
for _, child in recipientFrame:GetChildren() do child:Destroy() end
for _, child in senderFrame:GetChildren() do child:Destroy() end

-- Layout
local function makeList(parent, align)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Vertical
	l.HorizontalAlignment = align
	l.VerticalAlignment = Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, ROW_GAP)
	l.Parent = parent
	return l
end

local listR = makeList(recipientFrame, Enum.HorizontalAlignment.Left)
local listS = makeList(senderFrame, Enum.HorizontalAlignment.Right)

local layoutOrder = 0

-- Auto canvas resize
local function updateCanvas()
	local h = math.max(listR.AbsoluteContentSize.Y, listS.AbsoluteContentSize.Y) + 16
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, h)
	recipientFrame.Size = UDim2.new(0, recipientFrame.Size.X.Offset, 0, h)
	senderFrame.Size = UDim2.new(0, senderFrame.Size.X.Offset, 0, h)
end

listR:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
listS:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

-- Measure bubble size
local function measureBubble(text)
	local size = TextService:GetTextSize(text, TEXT_SIZE, Enum.Font.SourceSansBold, Vector2.new(MAX_WIDTH - 20, math.huge))
	local w = math.clamp(size.X + 24, MIN_WIDTH, MAX_WIDTH)
	local h = math.max(size.Y + 20, 36)
	return w, h
end

-- Create bubble
local function makeBubble(parent, w, h, transparent, text, anchorRight)
	local bubble = Instance.new("Frame")
	bubble.Name = "ChatBubble"
	bubble.Size = UDim2.new(0, w, 0, h)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bubble.BackgroundTransparency = transparent and 1 or 0
	bubble.BorderSizePixel = 0
	bubble.AnchorPoint = anchorRight and Vector2.new(1, 0) or Vector2.new(0, 0)
	bubble.Position = anchorRight and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = bubble

	if not transparent and text then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -16, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(0, 0, 0)
		label.TextSize = TEXT_SIZE
		label.FontFace = FONT
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = bubble
	end

	bubble.Parent = parent
	return bubble
end

-- Add row
local function addRow(isRecipient, text)
	local w, h = measureBubble(text)
	layoutOrder += 1

	local rowR = Instance.new("Frame")
	rowR.Size = UDim2.new(1, 0, 0, h)
	rowR.BackgroundTransparency = 1
	rowR.BorderSizePixel = 0
	rowR.LayoutOrder = layoutOrder
	rowR.Parent = recipientFrame

	local rowS = Instance.new("Frame")
	rowS.Size = UDim2.new(1, 0, 0, h)
	rowS.BackgroundTransparency = 1
	rowS.BorderSizePixel = 0
	rowS.LayoutOrder = layoutOrder
	rowS.Parent = senderFrame

	if isRecipient then
		makeBubble(rowR, w, h, false, text, false)
		makeBubble(rowS, w, h, true, nil, false)
	else
		makeBubble(rowR, w, h, true, nil, true)
		makeBubble(rowS, w, h, false, text, true)
	end
end

local function makeNavButton(label, order, callback)
	
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 38)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Text = label
	btn.TextColor3 = Color3.fromRGB(160, 160, 160)
	btn.TextSize = 16
	btn.FontFace = FONT_NAV
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.LayoutOrder = order
	btn.Parent = listContainer

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20)
	pad.Parent = btn

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 0, 0)
	bar.Position = UDim2.new(0, -4, 0.5, 0)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bar.BorderSizePixel = 0
	bar.Parent = btn

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 4)
	bc.Parent = bar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	navCallbacks[btn] = callback

	local function setActive()
		if activeBtn and activeBtn ~= btn then
			TweenService:Create(activeBtn, navTween, {BackgroundTransparency = 1}):Play()
			TweenService:Create(activeBtn, navTween, {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
			local oldBar = activeBtn:FindFirstChild("Frame")
			if oldBar then
				TweenService:Create(oldBar, navTween, {Size = UDim2.new(0, 3, 0, 0)}):Play()
			end

			for b, cb in navCallbacks do
				if b ~= btn and cb then cb(false) end
			end
		end
		TweenService:Create(btn, navTween, {BackgroundTransparency = 0.88}):Play()
		TweenService:Create(btn, navTween, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(bar, navTween, {Size = UDim2.new(0, 3, 0.6, 0)}):Play()
		activeBtn = btn
		if callback then callback(true) end
	end

	btn.MouseEnter:Connect(function()
		if activeBtn ~= btn then
			TweenService:Create(btn, navTween, {TextColor3 = Color3.fromRGB(220, 220, 220)}):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if activeBtn ~= btn then
			TweenService:Create(btn, navTween, {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
		end
	end)
	
	btn.MouseButton1Click:Connect(function()
		setActive()
		if callback then callback() end
	end)

	return btn
end

-- Module
local module = {}

module._onSend = nil
module._onReceive = nil

-- Callbacks
function module:AttachOnSend(callback)
	self._onSend = callback
end

function module:AttachOnReceive(callback)
	self._onReceive = callback
end

-- Send handler (Button + Enter)
local function handleSend()
	local text = textBox.Text
	if text == "" then return end
	addRow(false, text)
	if module._onSend then module._onSend(text) end
	textBox.Text = ""
end

sendBtn.MouseButton1Click:Connect(handleSend)
textBox.FocusLost:Connect(function(enter)
	if enter then handleSend() end
end)

-- Public API
function module:Send(text)
	addRow(false, text)
	if self._onSend then self._onSend(text) end
end

function module:Receive(text)
	addRow(true, text)
	if self._onReceive then self._onReceive(text) end
end

-- ========== Setting ==========
local crop = BuddyUI.Get("Crop")

-- Clear existing children ยกเว้น UIListLayout
for _, child in crop:GetChildren() do
	if not child:IsA("UIListLayout") then child:Destroy() end
end

-- ScrollingFrame ครอบ Crop
local settingScroll = Instance.new("ScrollingFrame")
settingScroll.Size = UDim2.new(1, 0, 1, 0)
settingScroll.BackgroundTransparency = 1
settingScroll.BorderSizePixel = 0
settingScroll.ScrollBarThickness = 4
settingScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
settingScroll.ScrollingDirection = Enum.ScrollingDirection.Y
settingScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
settingScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
settingScroll.Parent = crop

local settingList = Instance.new("UIListLayout")
settingList.FillDirection = Enum.FillDirection.Vertical
settingList.HorizontalAlignment = Enum.HorizontalAlignment.Left
settingList.VerticalAlignment = Enum.VerticalAlignment.Top
settingList.SortOrder = Enum.SortOrder.LayoutOrder
settingList.Padding = UDim.new(0, 8)
settingList.Parent = settingScroll

local settingPad = Instance.new("UIPadding")
settingPad.PaddingTop = UDim.new(0, 10)
settingPad.PaddingLeft = UDim.new(0, 10)
settingPad.PaddingRight = UDim.new(0, 10)
settingPad.Parent = settingScroll

local FONT_BOLD = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local FONT_REG = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local SWIDTH = 630
local sOrder = 0

local function sNext() sOrder += 1 return sOrder end

local function sBase(h)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, SWIDTH, 0, h)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.LayoutOrder = sNext()
	f.Parent = settingScroll
	return f
end

function module:AddHeader(text)
	local f = sBase(44)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextSize = 28
	l.FontFace = FONT_BOLD
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = f
end

function module:AddDescription(text)
	local f = sBase(30)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(160, 160, 160)
	l.TextSize = 16
	l.FontFace = FONT_REG
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = true
	l.Parent = f
end

function module:AddDivider()
	local f = sBase(18)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 0.5, 0)
	line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	line.BorderSizePixel = 0
	line.Parent = f
end

function module:AddNavButton(label, order, callback)
	return makeNavButton(label, order, callback)
end

function module:AddInput(label, placeholder, callback)
	local f = sBase(78)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Text = label
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.FontFace = FONT_BOLD
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = f

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 0, 40)
	bg.Position = UDim2.new(0, 0, 0, 30)
	bg.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
	bg.BorderSizePixel = 0
	bg.Parent = f

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = bg

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -16, 1, 0)
	box.Position = UDim2.new(0, 8, 0, 0)
	box.BackgroundTransparency = 1
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.TextSize = 16
	box.FontFace = FONT_REG
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Parent = bg

	box.FocusLost:Connect(function()
		if callback then callback(box.Text) end
	end)
end

function module:AddDropdown(label, options, callback)
	local ITEM_H = 36
	local CLOSED_H = 78
	local OPEN_H = 78 + #options * ITEM_H
	local f = sBase(CLOSED_H)
	local isOpen = false
	local selectedItem = nil

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Text = label
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.FontFace = FONT_BOLD
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = f

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.Position = UDim2.new(0, 0, 0, 30)
	btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
	btn.BorderSizePixel = 0
	btn.Text = options[1] or ""
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 16
	btn.FontFace = FONT_REG
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.Parent = f

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = btn

	local bpad = Instance.new("UIPadding")
	bpad.PaddingLeft = UDim.new(0, 10)
	bpad.Parent = btn

	-- Arrow label
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(0, 30, 1, 0)
	arrow.Position = UDim2.new(1, -34, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▾"
	arrow.TextColor3 = Color3.fromRGB(180, 180, 180)
	arrow.TextSize = 18
	arrow.FontFace = FONT_REG
	arrow.Parent = btn

	-- List container (ClipsDescendants เพื่อ animate)
	local listClip = Instance.new("Frame")
	listClip.Size = UDim2.new(1, 0, 0, 0)
	listClip.Position = UDim2.new(0, 0, 0, 72)
	listClip.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	listClip.BorderSizePixel = 0
	listClip.ClipsDescendants = true
	listClip.ZIndex = 10
	listClip.Parent = f

	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 8)
	lc.Parent = listClip

	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = listClip

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	local function setSelected(item, opt)
		-- Reset สีเก่า
		if selectedItem then
			TweenService:Create(selectedItem, tweenInfo, {
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(220, 220, 220)
			}):Play()
		end
		-- Highlight ใหม่
		TweenService:Create(item, tweenInfo, {
			BackgroundTransparency = 0.85,
			TextColor3 = Color3.fromRGB(255, 255, 255)
		}):Play()
		selectedItem = item
		btn.Text = opt
	end

	for i, opt in options do
		local item = Instance.new("TextButton")
		item.Size = UDim2.new(1, 0, 0, ITEM_H)
		item.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
		item.BackgroundTransparency = 1
		item.Text = opt
		item.TextColor3 = Color3.fromRGB(220, 220, 220)
		item.TextSize = 16
		item.FontFace = FONT_REG
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.AutoButtonColor = false
		item.LayoutOrder = i
		item.ZIndex = 11
		item.Parent = listClip

		local ip = Instance.new("UIPadding")
		ip.PaddingLeft = UDim.new(0, 10)
		ip.Parent = item

		-- Hover
		item.MouseEnter:Connect(function()
			if selectedItem ~= item then
				TweenService:Create(item, tweenInfo, {BackgroundTransparency = 0.92}):Play()
			end
		end)
		item.MouseLeave:Connect(function()
			if selectedItem ~= item then
				TweenService:Create(item, tweenInfo, {BackgroundTransparency = 1}):Play()
			end
		end)

		item.MouseButton1Click:Connect(function()
			setSelected(item, opt)
			-- ปิด dropdown
			local closeTween = TweenService:Create(listClip, tweenInfo, {Size = UDim2.new(1, 0, 0, 0)})
			local frameTween = TweenService:Create(f, tweenInfo, {Size = UDim2.new(0, SWIDTH, 0, CLOSED_H)})
			local arrowTween = TweenService:Create(arrow, tweenInfo, {Rotation = 0})
			closeTween:Play() ; frameTween:Play() ; arrowTween:Play()
			isOpen = false
			if callback then callback(opt) end
		end)
	end

	btn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		local targetListH = isOpen and #options * ITEM_H or 0
		local targetFrameH = isOpen and OPEN_H or CLOSED_H
		local targetRot = isOpen and 180 or 0

		TweenService:Create(listClip, tweenInfo, {Size = UDim2.new(1, 0, 0, targetListH)}):Play()
		TweenService:Create(f, tweenInfo, {Size = UDim2.new(0, SWIDTH, 0, targetFrameH)}):Play()
		TweenService:Create(arrow, tweenInfo, {Rotation = targetRot}):Play()
	end)
end

function module:AddButton(label, text, callback)
	local f = sBase(78)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Text = label
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.FontFace = FONT_BOLD
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = f

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.Position = UDim2.new(0, 0, 0, 30)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btn.BackgroundTransparency = 0.88
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 16
	btn.FontFace = FONT_BOLD
	btn.AutoButtonColor = false
	btn.Parent = f

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = btn

	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, tweenInfo, {BackgroundTransparency = 0.75}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, tweenInfo, {BackgroundTransparency = 0.88}):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, tweenInfo, {BackgroundTransparency = 0.6}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, tweenInfo, {BackgroundTransparency = 0.88}):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
end

return module
