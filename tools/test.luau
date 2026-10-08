--!strict
-- Lanceur de tests Lune : `lune run tools/test [filtre]`
--   * découvre tests/**/*.spec.luau ;
--   * exécute chaque cas `it` dans un pcall ;
--   * code de sortie 1 si un cas (ou le chargement d'une spec) échoue.
-- Le filtre optionnel ne garde que les fichiers dont le chemin le contient.

local fs = require("@lune/fs")
local process = require("@lune/process")

local TestKit = require("@tools/lib/TestKit")

local TESTS_DIR = "tests"

local function findSpecs(dir: string, out: { string })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local full = `{dir}/{name}`
		if fs.isDir(full) then
			findSpecs(full, out)
		elseif string.sub(name, -10) == ".spec.luau" then
			table.insert(out, full)
		end
	end
end

local filter = process.args[1]
local specs: { string } = {}
if not fs.isDir(TESTS_DIR) then
	print(`Dossier {TESTS_DIR}/ introuvable (lancer depuis la racine du dépôt).`)
	process.exit(1)
end
findSpecs(TESTS_DIR, specs)

local passed, failed = 0, 0
local failures: { string } = {}

for _, specPath in specs do
	if filter == nil or string.find(specPath, filter, 1, true) then
		print(specPath)
		-- Chemin relatif à ce fichier (tools/), sans l'extension.
		local modulePath = "../" .. string.sub(specPath, 1, -6)
		local loaded, loadErr = pcall(function()
			return (require :: any)(modulePath)
		end)
		if not loaded then
			failed += 1
			local message = `{specPath} : chargement impossible : {loadErr}`
			table.insert(failures, message)
			print(`  ÉCHEC  (chargement) {loadErr}`)
		end
		for _, case in TestKit.collect() do
			local ok, err = pcall(case.fn)
			if ok then
				passed += 1
				print(`  ok     {case.name}`)
			else
				failed += 1
				table.insert(failures, `{specPath} : {case.name} : {err}`)
				print(`  ÉCHEC  {case.name}\n         {err}`)
			end
		end
	end
end

print("")
if #failures > 0 then
	print("Échecs :")
	for _, message in failures do
		print(`  - {message}`)
	end
end
print(`{passed} réussi(s), {failed} échoué(s), {#specs} fichier(s) de spec trouvé(s).`)

if failed > 0 or passed == 0 then
	process.exit(1)
end
