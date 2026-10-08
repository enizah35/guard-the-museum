--!strict
-- Vérifie que chaque fichier .luau de src/, tests/ et tools/ commence par `--!strict`.
-- src/vendor/ est exclu (modules tiers copiés tels quels).
-- Usage : `lune run tools/check-strict` (code de sortie 1 si un fichier est fautif).

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS = { "src", "tests", "tools" }
local EXCLUDED = { ["src/vendor"] = true }

local offenders: { string } = {}
local checked = 0

local function walk(dir: string)
	if EXCLUDED[dir] then
		return
	end
	for _, name in fs.readDir(dir) do
		local full = `{dir}/{name}`
		if fs.isDir(full) then
			walk(full)
		elseif string.sub(name, -5) == ".luau" then
			checked += 1
			local firstLine = string.match(fs.readFile(full), "^[^\r\n]*") or ""
			if firstLine ~= "--!strict" then
				table.insert(offenders, full)
			end
		end
	end
end

for _, root in ROOTS do
	if fs.isDir(root) then
		walk(root)
	end
end

if #offenders > 0 then
	table.sort(offenders)
	print("Fichiers sans `--!strict` en première ligne :")
	for _, path in offenders do
		print(`  - {path}`)
	end
	process.exit(1)
end
print(`--!strict présent dans les {checked} fichiers .luau vérifiés.`)
