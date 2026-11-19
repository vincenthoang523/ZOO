-- StallCheck: proves nothing on Safari Sam's stall floats. Uses EnclosureCheck's contact graph (box test for Parts,
-- real collision geometry for MeshParts). The stall stands on the Plaza disc, so a part is grounded when it reaches
-- the plaza top (y 0.1). Safari Sam and the invisible colliders are left out.
-- The per-shell check inside each mesh is floating_report() in blender/build_zoo_kit.py; this one checks the placed
-- meshes and the Sign part against each other and the ground.
-- Usage: print(require(game.ServerStorage.StallCheck:Clone()).run())

local Check = require(game.ServerStorage.EnclosureCheck:Clone())
local PLAZA = workspace.Zoo.Plaza
local PLAZA_TOP = PLAZA.Position.Y + PLAZA.Size.X / 2 -- disc lies with its axis on X

return {
	run = function()
		local stall = workspace.Zoo.SafariStall
		local n, floating, unanchored = Check.model(stall, stall:FindFirstChild("SafariSam"), PLAZA_TOP)
		local lines = { string.format("SafariStall: %d visible parts, %d floating, %d unanchored", n, #floating, #unanchored) }
		for _, f in floating do table.insert(lines, "  FLOATING " .. f) end
		for _, u in unanchored do table.insert(lines, "  UNANCHORED " .. u) end
		table.insert(lines, (#floating + #unanchored == 0) and "RESULT: CLEAN" or "RESULT: PROBLEMS")
		return table.concat(lines, "\n")
	end,
}
