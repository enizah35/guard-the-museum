--!strict
-- PROTOTYPE P0.5 — CARTE DE SECOURS, à supprimer dès que la greybox de l'aile 1 existe.
-- Si aucun objet tagué `Anomalable` n'est présent dans le Workspace, génère un petit
-- musée : 4 salles 40×40 en carré reliées par des portes, 12 objets tagués, 3 caméras.
-- Suppression : effacer ce fichier et son appel dans Main.server.luau (ou mettre
-- `fallbackMapEnabled = false` dans Content/ProtoConfig).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local FallbackMap = {}

local ROOM_SIZE = 40
local WALL_HEIGHT = 14
local WALL_THICKNESS = 1
local DOOR_WIDTH = 8
local FLOOR_TOP = 0.05 -- juste au-dessus d'une éventuelle Baseplate (sommet à y = 0)

type RoomDef = {
	id: string,
	center: Vector3,
	floorColor: Color3,
}

type ObjectDef = {
	room: string,
	name: string,
	category: string,
	shape: "Block" | "Ball",
	size: Vector3,
	offset: Vector3, -- par rapport au centre de la salle (x, z ; y ignoré)
	color: Color3,
	material: Enum.Material,
}

type CameraDef = {
	id: string,
	room: string,
	corner: Vector3, -- position par rapport au centre de la salle
}

local ROOMS: { RoomDef } = {
	{ id = "Hall", center = Vector3.new(0, 0, 0), floorColor = Color3.fromRGB(120, 105, 90) },
	{ id = "Galerie", center = Vector3.new(40, 0, 0), floorColor = Color3.fromRGB(95, 110, 125) },
	{ id = "Sculptures", center = Vector3.new(40, 0, 40), floorColor = Color3.fromRGB(110, 120, 100) },
	{ id = "Archives", center = Vector3.new(0, 0, 40), floorColor = Color3.fromRGB(125, 100, 110) },
}

local OBJECTS: { ObjectDef } = {
	{
		room = "Hall",
		name = "Vase",
		category = "Vase",
		shape = "Block",
		size = Vector3.new(2, 3, 2),
		offset = Vector3.new(-10, 0, -9),
		color = Color3.fromRGB(60, 110, 200),
		material = Enum.Material.SmoothPlastic,
	},
	{
		room = "Hall",
		name = "Banc",
		category = "Furniture",
		shape = "Block",
		size = Vector3.new(6, 1.5, 2),
		offset = Vector3.new(9, 0, -10),
		color = Color3.fromRGB(110, 75, 45),
		material = Enum.Material.Wood,
	},
	{
		room = "Hall",
		name = "Statue",
		category = "Statue",
		shape = "Block",
		size = Vector3.new(2, 6, 2),
		offset = Vector3.new(-9, 0, 10),
		color = Color3.fromRGB(170, 170, 170),
		material = Enum.Material.Marble,
	},
	{
		room = "Galerie",
		name = "Totem",
		category = "Statue",
		shape = "Block",
		size = Vector3.new(2, 7, 2),
		offset = Vector3.new(-8, 0, -10),
		color = Color3.fromRGB(190, 60, 50),
		material = Enum.Material.Wood,
	},
	{
		room = "Galerie",
		name = "Urne",
		category = "Vase",
		shape = "Ball",
		size = Vector3.new(3, 3, 3),
		offset = Vector3.new(10, 0, 0),
		color = Color3.fromRGB(220, 180, 60),
		material = Enum.Material.Metal,
	},
	{
		room = "Galerie",
		name = "Coffre",
		category = "Furniture",
		shape = "Block",
		size = Vector3.new(4, 2.5, 3),
		offset = Vector3.new(-6, 0, 11),
		color = Color3.fromRGB(80, 55, 35),
		material = Enum.Material.WoodPlanks,
	},
	{
		room = "Sculptures",
		name = "Buste",
		category = "Statue",
		shape = "Block",
		size = Vector3.new(2.5, 4, 2.5),
		offset = Vector3.new(-10, 0, -6),
		color = Color3.fromRGB(235, 235, 225),
		material = Enum.Material.Marble,
	},
	{
		room = "Sculptures",
		name = "Obelisque",
		category = "Statue",
		shape = "Block",
		size = Vector3.new(2, 9, 2),
		offset = Vector3.new(0, 0, 0),
		color = Color3.fromRGB(205, 185, 140),
		material = Enum.Material.Sandstone,
	},
	{
		room = "Sculptures",
		name = "Sphere",
		category = "Artifact",
		shape = "Ball",
		size = Vector3.new(3, 3, 3),
		offset = Vector3.new(9, 0, 10),
		color = Color3.fromRGB(70, 160, 90),
		material = Enum.Material.Glass,
	},
	{
		room = "Archives",
		name = "Caisse",
		category = "Furniture",
		shape = "Block",
		size = Vector3.new(3, 3, 3),
		offset = Vector3.new(10, 0, -8),
		color = Color3.fromRGB(200, 120, 50),
		material = Enum.Material.WoodPlanks,
	},
	{
		room = "Archives",
		name = "Globe",
		category = "Artifact",
		shape = "Ball",
		size = Vector3.new(2.5, 2.5, 2.5),
		offset = Vector3.new(-9, 0, -2),
		color = Color3.fromRGB(70, 190, 210),
		material = Enum.Material.SmoothPlastic,
	},
	{
		room = "Archives",
		name = "Armure",
		category = "Statue",
		shape = "Block",
		size = Vector3.new(2, 6, 1.5),
		offset = Vector3.new(4, 0, 11),
		color = Color3.fromRGB(150, 155, 165),
		material = Enum.Material.DiamondPlate,
	},
}

-- La salle Archives n'a volontairement pas de caméra : il faut y aller à pied.
local CAMERAS: { CameraDef } = {
	{ id = "CAM-1", room = "Hall", corner = Vector3.new(-18, 11, 18) },
	{ id = "CAM-2", room = "Galerie", corner = Vector3.new(18, 11, 18) },
	{ id = "CAM-3", room = "Sculptures", corner = Vector3.new(18, 11, -18) },
}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local WALL_COLOR = Color3.fromRGB(200, 195, 180)

-- Mur parallèle à l'axe X (à z fixe), de x1 à x2, avec des portes centrées sur `doors`.
local function wallAlongX(parent: Instance, z: number, x1: number, x2: number, doors: { number })
	local cursor = x1
	local stops = table.clone(doors)
	table.sort(stops)
	table.insert(stops, math.huge)
	for _, door in stops do
		local segmentEnd = if door == math.huge then x2 else door - DOOR_WIDTH / 2
		if segmentEnd > cursor then
			local length = segmentEnd - cursor
			makePart(
				"Wall",
				Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS),
				CFrame.new(cursor + length / 2, FLOOR_TOP + WALL_HEIGHT / 2, z),
				WALL_COLOR,
				parent
			)
		end
		cursor = door + DOOR_WIDTH / 2
	end
end

-- Mur parallèle à l'axe Z (à x fixe), de z1 à z2, avec des portes centrées sur `doors`.
local function wallAlongZ(parent: Instance, x: number, z1: number, z2: number, doors: { number })
	local cursor = z1
	local stops = table.clone(doors)
	table.sort(stops)
	table.insert(stops, math.huge)
	for _, door in stops do
		local segmentEnd = if door == math.huge then z2 else door - DOOR_WIDTH / 2
		if segmentEnd > cursor then
			local length = segmentEnd - cursor
			makePart(
				"Wall",
				Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length),
				CFrame.new(x, FLOOR_TOP + WALL_HEIGHT / 2, cursor + length / 2),
				WALL_COLOR,
				parent
			)
		end
		cursor = door + DOOR_WIDTH / 2
	end
end

local function roomCenter(roomId: string): Vector3
	for _, room in ROOMS do
		if room.id == roomId then
			return room.center
		end
	end
	error(`FallbackMap: salle inconnue {roomId}`)
end

local function buildRooms(parent: Instance)
	local half = ROOM_SIZE / 2
	for _, room in ROOMS do
		local roomFolder = Instance.new("Folder")
		roomFolder.Name = room.id
		roomFolder.Parent = parent
		local floor = makePart(
			"Floor",
			Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
			CFrame.new(room.center.X, FLOOR_TOP - 0.5, room.center.Z),
			room.floorColor,
			roomFolder
		)
		floor.Material = Enum.Material.Slate
		floor:SetAttribute("RoomId", room.id)

		local lamp = makePart(
			"Lamp",
			Vector3.new(1, 1, 1),
			CFrame.new(room.center.X, FLOOR_TOP + WALL_HEIGHT - 1, room.center.Z),
			Color3.fromRGB(255, 240, 200),
			roomFolder
		)
		lamp.Transparency = 1
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.CanTouch = false
		local light = Instance.new("PointLight")
		light.Range = 32
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 225, 180)
		light.Parent = lamp
	end

	-- Murs extérieurs (x : -20 → 60, z : -20 → 60) puis murs intérieurs percés de portes.
	local minX, maxX = -half, ROOM_SIZE * 2 - half
	local minZ, maxZ = -half, ROOM_SIZE * 2 - half
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = parent
	wallAlongX(walls, minZ, minX, maxX, {})
	wallAlongX(walls, maxZ, minX, maxX, {})
	wallAlongZ(walls, minX, minZ, maxZ, {})
	wallAlongZ(walls, maxX, minZ, maxZ, {})
	wallAlongZ(walls, half, minZ, maxZ, { 0, ROOM_SIZE })
	wallAlongX(walls, half, minX, maxX, { 0, ROOM_SIZE })
end

local function buildObjects(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Anomalables"
	folder.Parent = parent
	for _, def in OBJECTS do
		local center = roomCenter(def.room)
		local part = makePart(
			`{def.room}_{def.name}`,
			def.size,
			CFrame.new(center.X + def.offset.X, FLOOR_TOP + def.size.Y / 2, center.Z + def.offset.Z),
			def.color,
			folder
		)
		part.Shape = if def.shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
		part.Material = def.material
		part:SetAttribute("ObjectId", `{def.room}_{def.name}`)
		part:SetAttribute("Category", def.category)
		part:SetAttribute("RoomId", def.room)
		CollectionService:AddTag(part, "Anomalable")
	end
end

local function buildCameras(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "SecurityCams"
	folder.Parent = parent
	for _, def in CAMERAS do
		local center = roomCenter(def.room)
		local position = center + def.corner
		local target = Vector3.new(center.X, FLOOR_TOP + 2, center.Z)
		local cam =
			makePart(def.id, Vector3.new(1, 1, 1.6), CFrame.lookAt(position, target), Color3.new(0.1, 0.1, 0.1), folder)
		cam.CanCollide = false
		cam.CanQuery = false
		cam.CanTouch = false
		cam:SetAttribute("CameraId", def.id)
		cam:SetAttribute("RoomId", def.room)
		CollectionService:AddTag(cam, "SecurityCam")
	end
end

local function ensureSpawn(parent: Instance)
	if Workspace:FindFirstChildWhichIsA("SpawnLocation", true) ~= nil then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FallbackSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, FLOOR_TOP, 0)
	spawn.Duration = 0 -- pas de bulle de protection
	spawn.Parent = parent
end

local function nightLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(60, 60, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 70)
end

-- Génère la carte si aucun objet `Anomalable` n'existe. Renvoie true si elle a été générée.
function FallbackMap.ensure(): boolean
	if #CollectionService:GetTagged("Anomalable") > 0 then
		return false
	end
	local model = Instance.new("Model")
	model.Name = "FallbackMuseum"
	-- Toujours répliqué en entier (vues caméras de salles lointaines avec StreamingEnabled).
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	buildRooms(model)
	buildObjects(model)
	buildCameras(model)
	ensureSpawn(model)
	nightLighting()
	model.Parent = Workspace
	return true
end

return FallbackMap
