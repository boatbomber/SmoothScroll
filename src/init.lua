-- SmoothScroll module
-- By boatbomber (2019)

local RS, UIS, CAS = game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("ContextActionService")

if not RS:IsClient() then
	error("SmoothScroll can only be used on the client")
end

local PlayerGui	= game.Players.LocalPlayer:WaitForChild("PlayerGui")
local Mouse		= game.Players.LocalPlayer:GetMouse()
local ipairs,pairs	= ipairs,pairs


task.wait() --Because we're about to call Mouse.ViewSizeY, we wait to ensure the property has actually updated

local DEFAULT_SENS,DEFAULT_FRICT = Mouse.ViewSizeY/27, 0.78


local Objects = {}
local ScrollBarHolder
local DraggingBar = false

--PC only
if not UIS.TouchEnabled then
	
	ScrollBarHolder = Instance.new("ScreenGui")
		ScrollBarHolder.Name = "SmoothScroll"
		ScrollBarHolder.Parent = PlayerGui
	
	RS.Heartbeat:Connect(function()
		for Frame, Info in pairs(Objects) do
			if Info.Velocity > 0.05 or Info.Velocity < -0.05 then
				Info.Velocity = Info.Velocity*Info.Frict				
				if Info.Axis == "X" then
					Frame.CanvasPosition = Vector2.new(Frame.CanvasPosition.X+Info.Velocity,Frame.CanvasPosition.Y)
					
					if math.abs(Info.LastPos-Frame.CanvasPosition.X) == 0 then
						--Hit end, remove velocity so scrolling back responds instantly
						Info.Velocity = 0
					end
					Info.LastPos = Frame.CanvasPosition.X
				else
					Frame.CanvasPosition = Vector2.new(Frame.CanvasPosition.X,Frame.CanvasPosition.Y+Info.Velocity)

					if math.abs(Info.LastPos-Frame.CanvasPosition.Y) == 0 then
						--Hit end, remove velocity so scrolling back responds instantly
						Info.Velocity = 0
					end
					Info.LastPos = Frame.CanvasPosition.Y
				end
			end
		end
	end)
	
	--Trackpad support
	UIS.PointerAction:Connect(function(Wheel,Pan,Pinch,GP)
		if not DraggingBar then
			local HoveredObjects = PlayerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)	
			for i, Frame in ipairs(HoveredObjects) do
				local Info = Objects[Frame]
				
				if Info and Info.Visibility.Visible == true then
					Info.Velocity = Info.Velocity - (Info.Sens * Pan.Y * (Info.Inverted and -1 or 1))
					break
				end
			end
		end
	end)
	
	--Mouse wheel support
	CAS:BindActionAtPriority("SmoothScroll", function(Name,State,Input)
		
		if DraggingBar then return Enum.ContextActionResult.Pass end
		
		local Processed = false
		
		local HoveredObjects = PlayerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)	
		for i, Frame in ipairs(HoveredObjects) do
			local Info = Objects[Frame]
			
			if Info and Info.Visibility.Visible == true then
				Info.Velocity = Info.Velocity - (Info.Sens * Input.Position.Z * (Info.Inverted and -1 or 1))
				Processed = true
				break
			end
		end
		
		return Processed and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
		
	end, false, 8000, Enum.UserInputType.MouseWheel)

end

-- This visibility tracker is taken from Crazyman32's MouseOver module (August 18, 2018)

local OnScreenTracker = {}
OnScreenTracker.__index = OnScreenTracker

function OnScreenTracker.new(obj)
	
	assert(typeof(obj) == "Instance" and obj:IsA("GuiObject"), "Argument #1 expected GuiObject")
	local visibleChanged = Instance.new("BindableEvent")
	
	local self = setmetatable({
		GuiObject = obj;
		Visible = nil;
		Changed = visibleChanged.Event;
		_path = {};
		_conn = {};
		_root = nil;
		_visibleChanged = visibleChanged;
	}, OnScreenTracker)
	
	local function CheckVisible()
		local vis = (self._root and self._root.Enabled or false)
		if (vis) then
			local path = self._path
			for i, p in ipairs(path) do
				if (not p.Visible) then
					vis = false
					break
				end
			end
		end
		if (vis ~= self.Visible) then
			self.Visible = vis
			visibleChanged:Fire(vis)
		end
	end
	
	local function BuildAncestryPath()
		for _,c in ipairs(self._conn) do c:Disconnect() end
		local path = {}
		local conn = {}
		local root = nil
		local parent = obj
		while (parent and (parent:IsA("GuiObject") or parent:IsA("Folder"))) do
			if parent:IsA("GuiObject") then
				conn[#conn + 1] = parent:GetPropertyChangedSignal("Visible"):Connect(CheckVisible)
				path[#path + 1] = parent
			end
			parent = parent.Parent
		end
		if (parent and parent:IsA("LayerCollector")) then
			conn[#conn + 1] = parent:GetPropertyChangedSignal("Enabled"):Connect(CheckVisible)
			root = parent
		end
		self._path = path
		self._conn = conn
		self._root = root
		CheckVisible()
	end
	
	self._ancestry = obj.AncestryChanged:Connect(function(child, parent)
		BuildAncestryPath()
	end)
	BuildAncestryPath()
	
	return self
	
end

function OnScreenTracker:Destroy()
	self._visibleChanged:Fire(false)
	self._visibleChanged:Destroy()
	self._ancestry:Disconnect()
	for _,c in ipairs(self._conn) do c:Disconnect() end
end


local function CreateBar(Frame,Axis)
	
	--Safety checks
	
	Axis = Axis or "Y"
	if not (Frame and typeof(Frame) == "Instance" and Frame.ClassName == "ScrollingFrame") then
		warn("Invalid frame to create custom bar")
		return
	end
	
	local Bar = Instance.new("TextButton")
		Bar.Name = Frame.Name.."_Scroller_"..Axis
		Bar.Text = ""
		Bar.BackgroundTransparency = 1
		Bar.Visible = Objects[Frame].Visibility.Visible
		
	--Localize frame stuff
	local absSize,absPos,scrollThick = Frame.AbsoluteSize,Frame.AbsolutePosition,Frame.ScrollBarThickness
	
	local BarDrag
	Bar.MouseButton1Down:Connect(function()
		if not DraggingBar and not BarDrag then
			DraggingBar = true
			
			local LastPos = Vector2.new(Mouse.X,Mouse.Y)
			BarDrag = UIS.InputChanged:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseMovement then
					
					local Pos = Vector2.new(Input.Position.X,Input.Position.Y)
					local Delta = Pos-LastPos
					local DeltaPercent = (Axis == "Y" and Delta.Y or Delta.X)/(Axis == "Y" and Frame.AbsoluteWindowSize.Y or Frame.AbsoluteWindowSize.X)
					
					local Parent = Frame:FindFirstAncestorWhichIsA("GuiBase2d")
					
					local CanvasSize = Vector2.new(
						(Frame.CanvasSize.X.Scale*Parent.AbsoluteSize.X)+Frame.CanvasSize.X.Offset,
						(Frame.CanvasSize.Y.Scale*Parent.AbsoluteSize.Y)+Frame.CanvasSize.Y.Offset
					)

					Frame.CanvasPosition = Vector2.new(Frame.CanvasPosition.X+(Axis == "X" and CanvasSize.X*DeltaPercent or 0),Frame.CanvasPosition.Y+(Axis == "Y" and CanvasSize.Y*DeltaPercent or 0))
					
					LastPos = Pos
				end
			end)
		end
	end)
	local DragEnded = UIS.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and BarDrag then
			DraggingBar = false
			BarDrag:Disconnect()
			BarDrag = nil
		end
	end)
	
	Objects[Frame].Visibility.Changed:Connect(function(Visible)
		Bar.Visible = Visible
		
		if not Visible and BarDrag then
			DraggingBar = false
			BarDrag:Disconnect()
			BarDrag = nil
		end
	end)
		
	if Axis == "X" then
		--Initial bar
		Bar.Size = UDim2.new(0,absSize.X,0,scrollThick)
		Bar.Position = UDim2.new(
			0,absPos.X,
			0,absPos.Y+absSize.Y-scrollThick
		)
	else
		--Initial bar
		Bar.Size = UDim2.new(0,scrollThick,0,absSize.Y)
		Bar.Position = UDim2.new(
			0,Frame.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Right and absPos.X+absSize.X-scrollThick or absPos.X,
			0,absPos.Y
		)
	end
	
	local Updater
	Updater = Frame.Changed:Connect(function(Prop)
		if Objects[Frame] then
			if Frame:FindFirstAncestorWhichIsA("GuiBase2d") then
				--Ensure bar stays updated
				
				if Prop == "AbsoluteSize" or Prop == "AbsolutePosition" or Prop == "AbsolutePosition" or Prop == "CanvasSize" or Prop == "ScrollBarThickness" then
					--Update frame stuff
					absSize,absPos,scrollThick = Frame.AbsoluteSize,Frame.AbsolutePosition,Frame.ScrollBarThickness
					
					if Axis == "X" then
						--Update bar
						Bar.Size = UDim2.new(0,absSize.X,0,scrollThick)
						Bar.Position = UDim2.new(
							0,absPos.X,
							0,absPos.Y+absSize.Y-scrollThick
						)
					else
						--Update bar
						Bar.Size = UDim2.new(0,scrollThick,0,absSize.Y)
						Bar.Position = UDim2.new(
							0,Frame.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Right and absPos.X+absSize.X-scrollThick or absPos.X,
							0,absPos.Y
						)
					end
				end
				
			end
		else
			Bar:Destroy()
			Updater:Disconnect()
			DragEnded:Disconnect()
			if BarDrag then
				BarDrag:Disconnect()
				BarDrag = nil
			end
		end
	end)
	
	Bar.Parent = ScrollBarHolder
end

local SmoothScroll = {}

--[[**
    Sets a ScrollingFrame to scroll smoothly
			
    @param Frame [ScrollingFrame] The ScrollingFrame object to apply smoothing to
	@param Sensitivity [Optional Number] How many pixels it scrolls per wheel turn
	@param Friction [Optional Number] What the velocity is multiplied by each frame
	@param Inverted [Optional Bool] Inverts the scrolling direction
	@param Axis [Optional String] "X" or "Y". If left out, will default to whichever Axis is scrollable or "Y" if both are valid
			
    @returns nil		
**--]]
function SmoothScroll.Enable(Frame, Sensitivity, Friction, Inverted, Axis)
	if not UIS.TouchEnabled then
		
		--Safety check
		if not (Frame and typeof(Frame) == "Instance" and Frame.ClassName == "ScrollingFrame") then
			warn("Invalid frame to smooth")
			return
		end
		
		if not Objects[Frame] then
			Frame.ScrollingEnabled = false
			
			local Actives,Connections = {},{}
			
			for _,desc in ipairs(Frame:GetDescendants()) do
				if desc:IsA("GuiObject") then
					Actives[desc] = desc.Active
					desc.Active = false
					Connections[#Connections+1] = desc:GetPropertyChangedSignal("Active"):Connect(function()
						desc.Active = false
					end)
				end
			end
			
			local parent = Frame
			while (parent and (parent:IsA("GuiObject") or parent:IsA("Folder"))) do
				if parent:IsA("GuiObject") then
					Actives[parent] = parent.Active
					parent.Active = false
					Connections[#Connections+1] = parent:GetPropertyChangedSignal("Active"):Connect(function()
						parent.Active = false
					end)
				end
				parent = parent.Parent
			end
			
			Connections[#Connections+1] = Frame.DescendantAdded:Connect(function(desc)
				if desc:IsA("GuiObject") then
					Objects[Frame].Actives[desc] = desc.Active
					desc.Active = false
					Objects[Frame].Connections[#Objects[Frame].Connections+1] = desc:GetPropertyChangedSignal("Active"):Connect(function()
						desc.Active = false
					end)
				end
			end)
			
			
			if Axis and (Axis == "X" or Axis == "Y") then
				--Leave Axis as defined by param
			else
				Axis = "Y" --Default to Y
				if (Frame.CanvasSize.Y.Offset>0 or Frame.CanvasSize.Y.Scale>0) then
					Axis = "Y"
				elseif (Frame.CanvasSize.X.Offset>0 or Frame.CanvasSize.X.Scale>0) then
					Axis = "X"
				end
			end
			
			Objects[Frame] = {
				Connections	= Connections;
				Actives		= Actives;
				
				Velocity	= 0;
				LastPos		= 0;
				Visibility	= OnScreenTracker.new(Frame);
				
				Inverted	= Inverted;
				Axis		= Axis;
				Frict		= math.clamp(type(Friction)=="number" and Friction or DEFAULT_FRICT,0.2,0.99);
				Sens		= math.clamp(type(Sensitivity)=="number" and Sensitivity or DEFAULT_SENS,0.01,99999999999999999);
			}
			
			CreateBar(Frame, "X")
			CreateBar(Frame, "Y")
		else
			--Already enabled, so just update the new settings passed
			Objects[Frame].Sens		= math.clamp(type(Sensitivity)=="number" and Sensitivity or DEFAULT_SENS,0.01,99999999999999999);
			Objects[Frame].Frict	= math.clamp(type(Friction)=="number" and Friction or DEFAULT_FRICT,0.2,0.99);
			Objects[Frame].Inverted	= Inverted
		end
		
	else
		warn("SmoothScroll only works for PC")
	end
end

--[[**
    Sets a ScrollingFrame to scroll normally
			
    @param Frame [ScrollingFrame] The ScrollingFrame object to remove smoothing from
			
    @returns nil		
**--]]
function SmoothScroll.Disable(Frame)

	if Objects[Frame] then
		-- Return default behavior
		Frame.ScrollingEnabled = true
		-- Disconnect mouse events and desc events
		for i,c in ipairs(Objects[Frame].Connections) do
			c:Disconnect()
		end
		-- Destroy tracker
		Objects[Frame].Visibility:Destroy()
		-- Return prior Active properties
		for desc,a in pairs(Objects[Frame].Actives) do
			desc.Active = a
		end
		
		-- Remove from update queue
		Objects[Frame] = nil
	end
	
end

return
