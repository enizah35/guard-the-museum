--!strict
-- PROTOTYPE P0.5 — registre des objets anomalables et des caméras de la carte.
-- * Lit les tags `Anomalable` (ObjectId, Category, RoomId) et `SecurityCam` (CameraId, RoomId).
-- * Capture l'état de référence (pivot, transparence, collisions) au démarrage.
-- * Applique les effets Moved / Missing et restaure l'état de référence.
-- Les modifications sont faites côté serveur, donc répliquées à tous les clients.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnomalyScheduler = require(ReplicatedStorage.Shared.Domain.Proto.AnomalyScheduler)
local Log = require(ReplicatedStorage.Shared.Log)

type ObjectRef = AnomalyScheduler.ObjectRef
type MoveParams = AnomalyScheduler.MoveParams

local log = Log.new("Night/ObjectRegistry")

type PartState = {
	part: BasePart,
	transparency: number,
	canCollide: boolean,
}

type DecalState = {
	decal: Decal, -- Texture hérite de Decal
	transparency: number,
}

type Entry = {
	ref: ObjectRef,
	instance: PVInstance,
	referencePivot: CFrame,
	parts: { PartState },
	decals: { DecalState },
}

export type CameraInfo = {
	cameraId: string,
	roomId: string,
	part: BasePart,
}

local ObjectRegistry = {}

local entries: { [string]: Entry } = {}
local orderedRefs: { ObjectRef } = {}
local cameras: { [string]: CameraInfo } = {}

local function stringAttribute(instance: Instance, name: string): string?
	local value = instance:GetAttribute(name)
	if type(value) == "string" and #value > 0 and #value <= 64 then
		return value
	end
	return nil
end

local function captureVisuals(instance: Instance): ({ PartState }, { DecalState })
	local parts: { PartState } = {}
	local decals: { DecalState } = {}
	local function visit(item: Instance)
		if item:IsA("BasePart") then
			local part = item :: BasePart
			table.insert(parts, { part = part, transparency = part.Transparency, canCollide = part.CanCollide })
		elseif item:IsA("Decal") then
			local decal = item :: Decal
			table.insert(decals, { decal = decal, transparency = decal.Transparency })
		end
	end
	visit(instance)
	for _, descendant in instance:GetDescendants() do
		visit(descendant)
	end
	return parts, decals
end

-- (Re)lit la carte et capture l'état de référence. À appeler une fois au démarrage,
-- quand tous les objets sont dans leur état normal.
function ObjectRegistry.scan()
	table.clear(entries)
	table.clear(orderedRefs)
	table.clear(cameras)

	for _, instance in CollectionService:GetTagged("Anomalable") do
		local objectId = stringAttribute(instance, "ObjectId")
		local roomId = stringAttribute(instance, "RoomId")
		if not instance:IsA("PVInstance") then
			log.warn(`{instance:GetFullName()} : tag Anomalable sur un objet non déplaçable, ignoré`)
		elseif objectId == nil or roomId == nil then
			log.warn(`{instance:GetFullName()} : attributs ObjectId/RoomId manquants, ignoré`)
		elseif entries[objectId] ~= nil then
			log.warn(`{instance:GetFullName()} : ObjectId en double « {objectId} », ignoré`)
		else
			local pv = instance :: PVInstance
			local parts, decals = captureVisuals(pv)
			local ref: ObjectRef = {
				objectId = objectId,
				roomId = roomId,
				category = stringAttribute(instance, "Category") or "Unknown",
			}
			entries[objectId] = {
				ref = ref,
				instance = pv,
				referencePivot = pv:GetPivot(),
				parts = parts,
				decals = decals,
			}
			table.insert(orderedRefs, ref)
		end
	end
	table.sort(orderedRefs, function(a: ObjectRef, b: ObjectRef): boolean
		return a.objectId < b.objectId
	end)

	for _, instance in CollectionService:GetTagged("SecurityCam") do
		local roomId = stringAttribute(instance, "RoomId")
		local cameraId = stringAttribute(instance, "CameraId") or instance.Name
		if not instance:IsA("BasePart") or roomId == nil then
			log.warn(`{instance:GetFullName()} : caméra sans RoomId ou qui n'est pas une Part, ignorée`)
		elseif cameras[cameraId] ~= nil then
			log.warn(`{instance:GetFullName()} : CameraId en double « {cameraId} », ignorée`)
		else
			cameras[cameraId] = { cameraId = cameraId, roomId = roomId, part = instance :: BasePart }
		end
	end

	local cameraCount = 0
	for _ in cameras do
		cameraCount += 1
	end
	log.info(`{#orderedRefs} objet(s) anomalable(s), {cameraCount} caméra(s)`)
end

-- Liste stable (triée par ObjectId) pour le planificateur d'anomalies.
function ObjectRegistry.refs(): { ObjectRef }
	return orderedRefs
end

function ObjectRegistry.get(objectId: string): ObjectRef?
	local entry = entries[objectId]
	return if entry then entry.ref else nil
end

-- Position de référence de l'objet (pour le contrôle de distance d'un signalement).
function ObjectRegistry.referencePosition(objectId: string): Vector3?
	local entry = entries[objectId]
	return if entry then entry.referencePivot.Position else nil
end

function ObjectRegistry.camera(cameraId: string): CameraInfo?
	return cameras[cameraId]
end

function ObjectRegistry.restore(objectId: string)
	local entry = entries[objectId]
	if entry == nil or entry.instance.Parent == nil then
		return
	end
	entry.instance:PivotTo(entry.referencePivot)
	for _, state in entry.parts do
		state.part.Transparency = state.transparency
		state.part.CanCollide = state.canCollide
	end
	for _, state in entry.decals do
		state.decal.Transparency = state.transparency
	end
end

function ObjectRegistry.restoreAll()
	for objectId in entries do
		ObjectRegistry.restore(objectId)
	end
end

-- Moved : décale et tourne l'objet autour de sa position de référence (axe vertical).
function ObjectRegistry.applyMoved(objectId: string, move: MoveParams)
	local entry = entries[objectId]
	if entry == nil or entry.instance.Parent == nil then
		return
	end
	local reference = entry.referencePivot
	local moved = CFrame.new(move.offsetX, 0, move.offsetZ) * reference * CFrame.Angles(0, math.rad(move.yawDegrees), 0)
	entry.instance:PivotTo(moved)
end

-- Missing : objet invisible et non collidable. Il reste interrogeable par raycast
-- (CanQuery inchangé) pour qu'on puisse signaler « là où il était ».
function ObjectRegistry.applyMissing(objectId: string)
	local entry = entries[objectId]
	if entry == nil or entry.instance.Parent == nil then
		return
	end
	for _, state in entry.parts do
		state.part.Transparency = 1
		state.part.CanCollide = false
	end
	for _, state in entry.decals do
		state.decal.Transparency = 1
	end
end

return ObjectRegistry
