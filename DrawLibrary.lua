local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

if getgenv().DrawLibrary then
	pcall(function()
		getgenv().DrawLibrary.RemoveAll()
	end)
end

for _, folder in ipairs(workspace.CurrentCamera:GetChildren()) do
	if folder.Name == "CircleRender" or folder.Name == "SquareRender" or folder.Name == "TriangleRender" then
		folder:Destroy()
	end
end

local DrawLibrary = {
	ActiveCircles = {},
	ActiveSquares = {},
	ActiveTriangles = {},
}

local function createShape(shapeType, points, LineWidth, LineColor, Character, Animation, Offset)
	local shape = {
		Parts = {},
		Enabled = true,
		Connection = nil,
		Character = Character,
		Offset = Offset,
		Folder = nil,
		LastPosition = nil,
		Animation = Animation,
		AnimationThread = nil,
		CurrentOffset = Offset,
		CharacterConnection = nil,
		PlayerConnection = nil,
		Points = points,
		ShapeType = shapeType,
	}
	
	shape.Folder = Instance.new("Folder")
	shape.Folder.Name = shapeType .. "Render"
	shape.Folder.Parent = workspace.CurrentCamera
	
	for i = 1, #points do
		local part = Instance.new("Part")
		part.Name = "S" .. i
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = LineColor
		part.Size = Vector3.new(LineWidth, LineWidth, 1)
		part.Parent = shape.Folder
		
		local highlight = Instance.new("Highlight")
		highlight.Adornee = part
		highlight.FillColor = LineColor
		highlight.FillTransparency = 0
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = part
		
		table.insert(shape.Parts, {Part = part, Highlight = highlight})
	end
	
	local function setupCharacterWatch()
		if shape.CharacterConnection then
			shape.CharacterConnection:Disconnect()
			shape.CharacterConnection = nil
		end
		
		if shape.Character then
			shape.CharacterConnection = shape.Character.AncestryChanged:Connect(function(_, parent)
				if not parent then
					shape:Destroy()
				end
			end)
		end
	end
	
	local function getPlayerFromCharacter(char)
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character == char then
				return player
			end
		end
		return nil
	end
	
	if Character then
		setupCharacterWatch()
		
		local player = getPlayerFromCharacter(Character)
		if player then
			shape.PlayerConnection = player.CharacterRemoving:Connect(function()
				shape:Destroy()
			end)
			
			Players.PlayerRemoving:Connect(function(removingPlayer)
				if removingPlayer == player then
					shape:Destroy()
				end
			end)
		end
	end
	
	if Animation and Animation.Offsets then
		shape.AnimationThread = task.spawn(function()
			while shape.Enabled do
				for _, animData in ipairs(Animation.Offsets) do
					if not shape.Enabled then break end
					
					local targetOffset = animData[1]
					local easingDirection = animData[2] or Enum.EasingDirection.Out
					local easingStyle = animData[3] or Enum.EasingStyle.Quad
					local duration = animData[4] or 1
					
					local startOffset = shape.CurrentOffset
					local elapsed = 0
					
					while elapsed < duration and shape.Enabled do
						local dt = RunService.Heartbeat:Wait()
						elapsed = elapsed + dt
						
						local alpha = math.clamp(elapsed / duration, 0, 1)
						local easedAlpha = TweenService:GetValue(alpha, easingStyle, easingDirection)
						
						shape.CurrentOffset = startOffset:Lerp(targetOffset, easedAlpha)
						shape.LastPosition = nil
					end
					
					if shape.Enabled then
						shape.CurrentOffset = targetOffset
					end
				end
			end
		end)
	end
	
	shape.SetEnabled = function(self, enabled)
		self.Enabled = enabled
	end
	
	shape.SetColor = function(self, color)
		for _, data in ipairs(self.Parts) do
			data.Part.Color = color
			data.Highlight.FillColor = color
		end
	end
	
	shape.SetThickness = function(self, thickness)
		for _, data in ipairs(self.Parts) do
			data.Part.Size = Vector3.new(thickness, thickness, data.Part.Size.Z)
		end
	end
	
	shape.SetOffset = function(self, offset)
		self.Offset = offset
		self.CurrentOffset = offset
		self.LastPosition = nil
	end
	
	shape.SetAnimation = function(self, animation)
		self.Animation = animation
		if self.AnimationThread then
			task.cancel(self.AnimationThread)
			self.AnimationThread = nil
		end
		if animation and animation.Offsets then
			self.AnimationThread = task.spawn(function()
				while self.Enabled do
					for _, animData in ipairs(animation.Offsets) do
						if not self.Enabled then break end
						
						local targetOffset = animData[1]
						local easingDirection = animData[2] or Enum.EasingDirection.Out
						local easingStyle = animData[3] or Enum.EasingStyle.Quad
						local duration = animData[4] or 1
						
						local startOffset = self.CurrentOffset
						local elapsed = 0
						
						while elapsed < duration and self.Enabled do
							local dt = RunService.Heartbeat:Wait()
							elapsed = elapsed + dt
							
							local alpha = math.clamp(elapsed / duration, 0, 1)
							local easedAlpha = TweenService:GetValue(alpha, easingStyle, easingDirection)
							
							self.CurrentOffset = startOffset:Lerp(targetOffset, easedAlpha)
							self.LastPosition = nil
						end
						
						if self.Enabled then
							self.CurrentOffset = targetOffset
						end
					end
				end
			end)
		end
	end
	
	shape.StopAnimation = function(self)
		if self.AnimationThread then
			task.cancel(self.AnimationThread)
			self.AnimationThread = nil
		end
		self.CurrentOffset = self.Offset
		self.LastPosition = nil
	end
	
	shape.Destroy = function(self)
		self.Enabled = false
		
		if self.AnimationThread then
			task.cancel(self.AnimationThread)
			self.AnimationThread = nil
		end
		
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end
		
		if self.CharacterConnection then
			self.CharacterConnection:Disconnect()
			self.CharacterConnection = nil
		end
		
		if self.PlayerConnection then
			self.PlayerConnection:Disconnect()
			self.PlayerConnection = nil
		end
		
		if self.Character then
			if self.ShapeType == "Circle" and DrawLibrary.ActiveCircles[self.Character] == self then
				DrawLibrary.ActiveCircles[self.Character] = nil
			elseif self.ShapeType == "Square" and DrawLibrary.ActiveSquares[self.Character] == self then
				DrawLibrary.ActiveSquares[self.Character] = nil
			elseif self.ShapeType == "Triangle" and DrawLibrary.ActiveTriangles[self.Character] == self then
				DrawLibrary.ActiveTriangles[self.Character] = nil
			end
		end
		
		if self.Folder then
			self.Folder:Destroy()
			self.Folder = nil
		end
		
		self.Parts = {}
	end
	
	return shape
end

DrawLibrary.RenderCircle = function(Offset, LineWidth, Radius, LineColor, Character, Segments, Animation)
	Offset = Offset or Vector3.new(0, 0, 0)
	LineWidth = LineWidth or 0.1
	Radius = Radius or 5
	LineColor = LineColor or Color3.new(1, 1, 1)
	Segments = Segments or 32
	Character = Character or Players.LocalPlayer.Character
	Animation = Animation or nil
	
	if Character and DrawLibrary.ActiveCircles[Character] then
		DrawLibrary.ActiveCircles[Character]:Destroy()
		DrawLibrary.ActiveCircles[Character] = nil
	end
	
	local points = {}
	for i = 1, Segments do
		table.insert(points, i)
	end
	
	local circle = createShape("Circle", points, LineWidth, LineColor, Character, Animation, Offset)
	circle.Radius = Radius
	circle.Segments = Segments
	
	local angleStep = (math.pi * 2) / Segments
	local segmentLength = 2 * Radius * math.sin(angleStep / 2)
	
	for _, data in ipairs(circle.Parts) do
		data.Part.Size = Vector3.new(LineWidth, LineWidth, segmentLength)
	end
	
	circle.Connection = RunService.Heartbeat:Connect(function()
		if not circle.Enabled then
			if circle.Folder and circle.Folder.Parent then
				circle.Folder.Parent = nil
			end
			return
		end
		
		local char = circle.Character
		if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
			circle:Destroy()
			return
		end
		
		if not circle.Folder or not circle.Folder.Parent then
			if circle.Folder then
				circle.Folder.Parent = workspace.CurrentCamera
			else
				return
			end
		end
		
		local rootPos = char.HumanoidRootPart.Position
		local centerPos = rootPos + circle.CurrentOffset
		
		if circle.LastPosition and (centerPos - circle.LastPosition).Magnitude < 0.01 then
			return
		end
		circle.LastPosition = centerPos
		
		for i = 1, Segments do
			local angle = (i - 0.5) * angleStep
			local x = math.cos(angle) * circle.Radius
			local z = math.sin(angle) * circle.Radius
			local midPoint = centerPos + Vector3.new(x, 0, z)
			
			local nextAngle = angle + angleStep / 2
			local lookX = math.cos(nextAngle) * circle.Radius
			local lookZ = math.sin(nextAngle) * circle.Radius
			local lookPoint = centerPos + Vector3.new(lookX, 0, lookZ)
			
			circle.Parts[i].Part.CFrame = CFrame.lookAt(midPoint, lookPoint)
		end
	end)
	
	circle.SetRadius = function(self, radius)
		self.Radius = radius
		self.LastPosition = nil
		local newSegmentLength = 2 * radius * math.sin(angleStep / 2)
		for _, data in ipairs(self.Parts) do
			data.Part.Size = Vector3.new(data.Part.Size.X, data.Part.Size.Y, newSegmentLength)
		end
	end
	
	circle.SetCharacter = function(self, char)
		if self.Character and DrawLibrary.ActiveCircles[self.Character] == self then
			DrawLibrary.ActiveCircles[self.Character] = nil
		end
		
		self.Character = char
		self.LastPosition = nil
		
		if char then
			DrawLibrary.ActiveCircles[char] = self
		end
	end
	
	if Character then
		DrawLibrary.ActiveCircles[Character] = circle
	end
	
	return circle
end

DrawLibrary.RenderSquare = function(Offset, LineWidth, Size, LineColor, Character, Animation)
	Offset = Offset or Vector3.new(0, 0, 0)
	LineWidth = LineWidth or 0.1
	Size = Size or 5
	LineColor = LineColor or Color3.new(1, 1, 1)
	Character = Character or Players.LocalPlayer.Character
	Animation = Animation or nil
	
	if Character and DrawLibrary.ActiveSquares[Character] then
		DrawLibrary.ActiveSquares[Character]:Destroy()
		DrawLibrary.ActiveSquares[Character] = nil
	end
	
	local points = {1, 2, 3, 4}
	local square = createShape("Square", points, LineWidth, LineColor, Character, Animation, Offset)
	square.Size = Size
	
	for _, data in ipairs(square.Parts) do
		data.Part.Size = Vector3.new(LineWidth, LineWidth, Size)
	end
	
	square.Connection = RunService.Heartbeat:Connect(function()
		if not square.Enabled then
			if square.Folder and square.Folder.Parent then
				square.Folder.Parent = nil
			end
			return
		end
		
		local char = square.Character
		if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
			square:Destroy()
			return
		end
		
		if not square.Folder or not square.Folder.Parent then
			if square.Folder then
				square.Folder.Parent = workspace.CurrentCamera
			else
				return
			end
		end
		
		local rootPos = char.HumanoidRootPart.Position
		local centerPos = rootPos + square.CurrentOffset
		
		if square.LastPosition and (centerPos - square.LastPosition).Magnitude < 0.01 then
			return
		end
		square.LastPosition = centerPos
		
		local halfSize = square.Size / 2
		local corners = {
			centerPos + Vector3.new(-halfSize, 0, -halfSize),
			centerPos + Vector3.new(halfSize, 0, -halfSize),
			centerPos + Vector3.new(halfSize, 0, halfSize),
			centerPos + Vector3.new(-halfSize, 0, halfSize),
		}
		
		for i = 1, 4 do
			local nextI = i % 4 + 1
			local point1 = corners[i]
			local point2 = corners[nextI]
			local midPoint = (point1 + point2) / 2
			
			square.Parts[i].Part.Size = Vector3.new(LineWidth, LineWidth, (point2 - point1).Magnitude)
			square.Parts[i].Part.CFrame = CFrame.lookAt(midPoint, point2)
		end
	end)
	
	square.SetSize = function(self, size)
		self.Size = size
		self.LastPosition = nil
	end
	
	square.SetCharacter = function(self, char)
		if self.Character and DrawLibrary.ActiveSquares[self.Character] == self then
			DrawLibrary.ActiveSquares[self.Character] = nil
		end
		
		self.Character = char
		self.LastPosition = nil
		
		if char then
			DrawLibrary.ActiveSquares[char] = self
		end
	end
	
	if Character then
		DrawLibrary.ActiveSquares[Character] = square
	end
	
	return square
end

DrawLibrary.RenderTriangle = function(Offset, LineWidth, Size, LineColor, Character, Animation)
	Offset = Offset or Vector3.new(0, 0, 0)
	LineWidth = LineWidth or 0.1
	Size = Size or 5
	LineColor = LineColor or Color3.new(1, 1, 1)
	Character = Character or Players.LocalPlayer.Character
	Animation = Animation or nil
	
	if Character and DrawLibrary.ActiveTriangles[Character] then
		DrawLibrary.ActiveTriangles[Character]:Destroy()
		DrawLibrary.ActiveTriangles[Character] = nil
	end
	
	local points = {1, 2, 3}
	local triangle = createShape("Triangle", points, LineWidth, LineColor, Character, Animation, Offset)
	triangle.Size = Size
	
	triangle.Connection = RunService.Heartbeat:Connect(function()
		if not triangle.Enabled then
			if triangle.Folder and triangle.Folder.Parent then
				triangle.Folder.Parent = nil
			end
			return
		end
		
		local char = triangle.Character
		if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
			triangle:Destroy()
			return
		end
		
		if not triangle.Folder or not triangle.Folder.Parent then
			if triangle.Folder then
				triangle.Folder.Parent = workspace.CurrentCamera
			else
				return
			end
		end
		
		local rootPos = char.HumanoidRootPart.Position
		local centerPos = rootPos + triangle.CurrentOffset
		
		if triangle.LastPosition and (centerPos - triangle.LastPosition).Magnitude < 0.01 then
			return
		end
		triangle.LastPosition = centerPos
		
		local radius = triangle.Size / math.sqrt(3)
		local corners = {
			centerPos + Vector3.new(0, 0, -radius),
			centerPos + Vector3.new(radius * math.cos(math.rad(30)), 0, radius * math.sin(math.rad(30))),
			centerPos + Vector3.new(-radius * math.cos(math.rad(30)), 0, radius * math.sin(math.rad(30))),
		}
		
		for i = 1, 3 do
			local nextI = i % 3 + 1
			local point1 = corners[i]
			local point2 = corners[nextI]
			local midPoint = (point1 + point2) / 2
			
			triangle.Parts[i].Part.Size = Vector3.new(LineWidth, LineWidth, (point2 - point1).Magnitude)
			triangle.Parts[i].Part.CFrame = CFrame.lookAt(midPoint, point2)
		end
	end)
	
	triangle.SetSize = function(self, size)
		self.Size = size
		self.LastPosition = nil
	end
	
	triangle.SetCharacter = function(self, char)
		if self.Character and DrawLibrary.ActiveTriangles[self.Character] == self then
			DrawLibrary.ActiveTriangles[self.Character] = nil
		end
		
		self.Character = char
		self.LastPosition = nil
		
		if char then
			DrawLibrary.ActiveTriangles[char] = self
		end
	end
	
	if Character then
		DrawLibrary.ActiveTriangles[Character] = triangle
	end
	
	return triangle
end

DrawLibrary.GetCircle = function(Character)
	return DrawLibrary.ActiveCircles[Character]
end

DrawLibrary.GetSquare = function(Character)
	return DrawLibrary.ActiveSquares[Character]
end

DrawLibrary.GetTriangle = function(Character)
	return DrawLibrary.ActiveTriangles[Character]
end

DrawLibrary.RemoveAll = function()
	for _, circle in pairs(DrawLibrary.ActiveCircles) do
		if circle and circle.Destroy then
			circle:Destroy()
		end
	end
	DrawLibrary.ActiveCircles = {}
	
	for _, square in pairs(DrawLibrary.ActiveSquares) do
		if square and square.Destroy then
			square:Destroy()
		end
	end
	DrawLibrary.ActiveSquares = {}
	
	for _, triangle in pairs(DrawLibrary.ActiveTriangles) do
		if triangle and triangle.Destroy then
			triangle:Destroy()
		end
	end
	DrawLibrary.ActiveTriangles = {}
	
	for _, folder in ipairs(workspace.CurrentCamera:GetChildren()) do
		if folder.Name == "CircleRender" or folder.Name == "SquareRender" or folder.Name == "TriangleRender" then
			folder:Destroy()
		end
	end
end

DrawLibrary.ClearShapesWithNameIfCan = function(NameOfTarget)
	if not NameOfTarget then return false end
	
	local found = false
	
	for char, shape in pairs(DrawLibrary.ActiveCircles) do
		if char and char.Name == NameOfTarget then
			shape:Destroy()
			found = true
			break
		end
	end
	
	for char, shape in pairs(DrawLibrary.ActiveSquares) do
		if char and char.Name == NameOfTarget then
			shape:Destroy()
			found = true
			break
		end
	end
	
	for char, shape in pairs(DrawLibrary.ActiveTriangles) do
		if char and char.Name == NameOfTarget then
			shape:Destroy()
			found = true
			break
		end
	end
	
	return found
end

DrawLibrary.ClearShapesWithExcludeList = function(excludeList)
	excludeList = excludeList or {}
	
	local excludeSet = {}
	for _, name in ipairs(excludeList) do
		excludeSet[name] = true
	end
	
	local toRemove = {}
	
	for char, shape in pairs(DrawLibrary.ActiveCircles) do
		if char and not excludeSet[char.Name] then
			table.insert(toRemove, {shape = shape, type = "circle", char = char})
		end
	end
	
	for char, shape in pairs(DrawLibrary.ActiveSquares) do
		if char and not excludeSet[char.Name] then
			table.insert(toRemove, {shape = shape, type = "square", char = char})
		end
	end
	
	for char, shape in pairs(DrawLibrary.ActiveTriangles) do
		if char and not excludeSet[char.Name] then
			table.insert(toRemove, {shape = shape, type = "triangle", char = char})
		end
	end
	
	for _, data in ipairs(toRemove) do
		data.shape:Destroy()
	end
end

getgenv().DrawLibrary = DrawLibrary
