

local Workspace = game:GetService("Workspace")

--Parameters
local px_size = 8 --pixel size
local load_avatar = false
local c3 = 0.045 --Used for in linear lerp(), don't really recommend changing anything here
local c2 = 0.89 --Used for in linear lerp(), don't really recommend changing anything here

-- setting up the pixel abd grid frame templates
local pixel_frame_template = Instance.new("Frame")
pixel_frame_template.Size = UDim2.fromOffset(px_size, px_size)
pixel_frame_template.BorderSizePixel = 0
pixel_frame_template.AnchorPoint = Vector2.new(0.5, 0.5)

local grid_frame_template = pixel_frame_template:Clone()
grid_frame_template.Parent = pixel_frame_template
grid_frame_template.Size = UDim2.fromScale(1, 1)
grid_frame_template.AnchorPoint = Vector2.new(0, 0)
grid_frame_template.Position = UDim2.fromOffset(0, 0)
grid_frame_template.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
grid_frame_template.Name = "GridLayout"

local pixelGrid = {}

-- The entire reason why I chose to use CIELUV instead of RGB is so I could get more accurate color results when using lerp()
local LerpCIELUV do
	
	local clamp = math.clamp
	local C3 = Color3.new
	local black = C3(0, 0, 0)

	local function RgbToLuv13(c)
		local r, g, b = c.r, c.g, c.b
		r = r < 0.0404482362771076 and r/12.92 or 0.87941546140213*(r + 0.055)^2.4
		g = g < 0.0404482362771076 and g/12.92 or 0.87941546140213*(g + 0.055)^2.4
		b = b < 0.0404482362771076 and b/12.92 or 0.87941546140213*(b + 0.055)^2.4
		local y = 0.2125862307855956*r + 0.71517030370341085*g + 0.0722004986433362*b
		local z = 3.6590806972265883*r + 11.4426895800574232*g + 4.1149915024264843*b
		local l = y > 0.008856451679035631 and 116*y^(1/3) - 16 or 903.296296296296*y
		if z > 1e-15 then
			local x = 0.9257063972951867*r - 0.8333736323779866*g - 0.09209820666085898*b
			return l, l*x/z, l*(9*y/z - 0.46832)
		else
			return l, -0.19783*l, -0.46832*l
		end
	end
	function LerpCIELUV(c0, c1)
		local l0, u0, v0 = RgbToLuv13(c0)
		local l1, u1, v1 = RgbToLuv13(c1)

		return function(t)
			local l = (1 - t)*l0 + t*l1
			if l < 0.0197955 then
				return black
			end
			local u = ((1 - t)*u0 + t*u1)/l + 0.19783
			local v = ((1 - t)*v0 + t*v1)/l + 0.46832

			-- CIELUV->XYZ
			local y = (l + 16)/116
			y = y > 0.206896551724137931 and y*y*y or 0.12841854934601665*y - 0.01771290335807126
			local x = y*u/v
			local z = y*((3 - 0.75*u)/v - 5)

			-- XYZ->linear sRGB
			local r =  7.2914074*x - 1.5372080*y - 0.4986286*z
			local g = -2.1800940*x + 1.8757561*y + 0.0415175*z
			local b =  0.1253477*x - 0.2040211*y + 1.0569959*z

			if r < 0 and r < g and r < b then
				r, g, b = 0, g - r, b - r
			elseif g < 0 and g < b then
				r, g, b = r - g, 0, b - g
			elseif b < 0 then
				r, g, b = r - b, g - b, 0
			end

			return C3(
				clamp(r < 3.1306684425e-3 and 12.92*r or 1.055*r^(1/2.4) - 0.055, 0, 1),
				clamp(g < 3.1306684425e-3 and 12.92*g or 1.055*g^(1/2.4) - 0.055, 0, 1),
				clamp(b < 3.1306684425e-3 and 12.92*b or 1.055*b^(1/2.4) - 0.055, 0, 1)
			)
		end
	end
end

-- creates an array of pixels
script.Parent.Parent.TextButton.MouseButton1Click:Connect(function()
	script.Parent.Parent.TextButton.Sound:Play()
for y = 0, script.Parent.Parent.MainFrame.AbsoluteSize.Y + px_size, px_size do
		for x = 0, script.Parent.Parent.MainFrame.AbsoluteSize.X + px_size, px_size do
		local newPixel = pixel_frame_template:Clone()
		newPixel.Parent = script.Parent.Parent.MainFrame
		newPixel.Position = UDim2.fromOffset(x, y)
		newPixel.Name = x .. " " .. y
			table.insert(pixelGrid, newPixel)
	end
end
	

	--[[ for each pixel it shoots a ray which if the material of the object that was hit by that same ray is glass,
	then it will bounce of that material and return the color data of whatever it hits next]]

	for _, pixel in pairs(pixelGrid) do
		local unitRay = workspace.CurrentCamera:ScreenPointToRay(pixel.AbsolutePosition.X, pixel.AbsolutePosition.Y)
		local raycastParams = RaycastParams.new()
		if not load_avatar then
			raycastParams.FilterDescendantsInstances = {game:GetService("Players").LocalPlayer.Character}
		end
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local raycast = workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, raycastParams)
		if raycast then
			if raycast.Instance == workspace.Terrain then
				if raycast.Material == Enum.Material.Water then
					pixel.BackgroundColor3 = workspace.Terrain.WaterColor
				else
					pixel.BackgroundColor3 = workspace.Terrain:GetMaterialColor(raycast.Material)
				end
			else
				pixel.BackgroundColor3 = raycast.Instance.Color

				if raycast.Material == Enum.Material.Glass then
					
					for i=0,5 do
					raycastParams.FilterType = Enum.RaycastFilterType.Exclude
						local a = 2*math.pi*math.random()
						local x = math.random()
						local r = math.sqrt(1 - x*x)*4.1
						local y, z = r*math.cos(a), r*math.sin(a) -- creates a random point on the hemisphere
						local r2 = workspace:Raycast(raycast.Position,Vector3.new(x,y,z),raycastParams) -- shoots another raycast from the original raycast's position
					if r2 ~= nil then
							local r2lerp_cieluv =  LerpCIELUV(r2.Instance.Color,raycast.Instance.Color) -- Lerps the reflected color with the original color using CIELUV
								raycast.Instance.Color = r2lerp_cieluv(c2)
							pixel.BackgroundColor3 = raycast.Instance.Color
						end
					end
				end
				if raycast.Instance:FindFirstChild("PointLight") ~= nil then -- this is only for any object that emits a pointlight
					for i=0,7 do
						local intesity = 5
						raycastParams.FilterType = Enum.RaycastFilterType.Exclude
						local cf = raycast.Instance.CFrame
						local lv = cf.LookVector
						local r3 = Workspace:Blockcast(CFrame.new(raycast.Instance.Position),raycast.Instance.Size,lv*intesity,raycastParams) -- makes a block cast the same size as the block that's emitting light
						if r3 ~= nil then
							local r3lerp_cieluv = LerpCIELUV(r3.Instance.Color,raycast.Instance:FindFirstChild("PointLight").Color) -- Lerps all the raycast colors that were fired from the object to the object's pointlight color value
							r3.Instance.Color = r3lerp_cieluv(c3)
							pixel.BackgroundColor3 = r3.Instance.Color
						end
						raycast.Instance.Color = raycast.Instance:FindFirstChild("PointLight").Color -- sets the object color to the color of its pointlight to avoid any visual issues
						pixel.BackgroundColor3 = raycast.Instance.Color
					end
				end
			end
			local transparencyValue = (1 / raycast.Distance) * 10 > 0.1 and (1 / raycast.Distance) * 10 or 0.1
			pixel:FindFirstChildOfClass("Frame").BackgroundTransparency = transparencyValue
		else
			pixel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			pixel:FindFirstChildOfClass("Frame").BackgroundTransparency = 0
		end
	end
end)
