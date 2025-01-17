-------------------------------------------------------------------------------
-- SF Editor Interface
-- Originally created by Jazzelhawk
--
-- To do:
-- Find new icons
-------------------------------------------------------------------------------

SF.Editor = {}

AddCSLuaFile("syntaxmodes/starfall.lua")
AddCSLuaFile("sfframe.lua")
AddCSLuaFile("sfderma.lua")
AddCSLuaFile("docs.lua")
AddCSLuaFile("sfhelper.lua")
AddCSLuaFile("themes.lua")
AddCSLuaFile("xml.lua")


-----------------
-- Tab Handlers
------------------

if CLIENT then
	SF.Editor.TabHandlers = { }
	SF.Editor.CurrentTabHandler = CreateClientConVar("sf_editor_tab_editor", "wire", true, false)
end

l = file.Find("starfall/editor/tabhandlers/tab_*.lua", "LUA")
for _, name in pairs(l) do
	name = name:sub(5,-5)
	AddCSLuaFile("starfall/editor/tabhandlers/tab_"..name..".lua")
	if CLIENT then
		SF.Editor.TabHandlers[name] = include("starfall/editor/tabhandlers/tab_"..name..".lua")
	end
end

SF.Editor.HelperURL = CreateConVar("sf_editor_helperurl", "http://thegrb93.github.io/StarfallEx/", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "URL for website used by SF Helper, change to allow custom documentation.")

------------------
-- Editor
--
-- For interaction with other modules and initialization
--
------------------

if CLIENT then
	include("docs.lua")
	include("sfhelper.lua")
	include("sfderma.lua")
	include("sfframe.lua") -- Editor's frame
	include("themes.lua")

	-- Colors
	SF.Editor.colors = {}
	SF.Editor.colors.dark = Color(36, 41, 53)
	SF.Editor.colors.meddark = Color(48, 57, 92)
	SF.Editor.colors.med = Color(78, 122, 199)
	SF.Editor.colors.medlight = Color(127, 178, 240)
	SF.Editor.colors.light = Color(173, 213, 247)

	local invalid_filename_chars = {
		["*"] = "",
		["?"] = "",
		[">"] = "",
		["<"] = "",
		["|"] = "",
		["\\"] = "",
		['"'] = "",
	}


	local function createLibraryMap ()

		local libMap, libs = {}, {}

		libMap["Environment"] = {}
		for name, val in pairs(SF.DefaultEnvironment) do
			table.insert(libMap["Environment"], name)
			table.insert(libs, name)
		end

		for lib, tbl in pairs(SF.Libraries) do
			libMap[lib] = {}
			for name, val in pairs(tbl) do
				table.insert(libMap[lib], name)
				table.insert(libs, lib.."\\."..name)
			end
		end

		for lib, tbl in pairs(SF.Types) do
			if istable(tbl.__index) then
				for name, val in pairs(tbl.__index) do
					table.insert(libs, "\\:"..name)
				end
			end
		end

		return libMap, table.concat(libs, "|")
	end

	function SF.Editor.init ()

		if not file.Exists("starfall", "DATA") then
			file.CreateDir("starfall")
		end
		if SF.Editor.editor then return end

		SF.Editor.createEditor()
		SF.Editor.initialized = true

		SF.CallHook("editorinit")
	end

	function SF.Editor.open ()
		if not SF.Editor.initialized then SF.Editor.init() end
		SF.Editor.editor:Open()
		RunConsoleCommand("starfall_event", "editor_open")
	end

	function SF.Editor.openFile(fl,forceNewTab)
		if not SF.Editor.initialized then SF.Editor.init() end
		SF.Editor.editor:Open(fl, nil, forceNewTab)
	end

	function SF.Editor.openWithCode(name, code,forceNewTab)
		if not SF.Editor.initialized then SF.Editor.init() end
		SF.Editor.editor:Open(name, code, forceNewTab)
	end

	function SF.Editor.pasteCode(code)
		SF.Editor.editor:PasteCode(code)
	end

	function SF.Editor.close ()
		SF.Editor.editor:Close()
	end

	function SF.Editor.getCode ()
		return SF.Editor.editor:GetCode() or ""
	end

	function SF.Editor.getOpenFile()
		local path = SF.Editor.editor:GetChosenFile()
		if path then
			path = path:match("starfall/(.+)") or path
		end
		return path
	end

	function SF.Editor.renameFile(oldFile, newFile)
		local contents = file.Read(oldFile)
		file.Write(newFile, contents)
		if file.Read(newFile)==contents then
			file.Delete(oldFile)
			SF.AddNotify(LocalPlayer(), "File renamed as " .. newFile .. ".", "GENERIC", 7, "DRIP3")
			for i = 1, SF.Editor.editor:GetNumTabs() do
				local ed = SF.Editor.editor:GetTabContent(i)
				local path = ed.chosenfile
				if path and path == oldFile then
					ed.chosenfile = newFile
					ed:OnTextChanged()
				end
			end
		else
			SF.AddNotify(LocalPlayer(), "Failed to rename " .. oldFile .. " to " .. newFile, "ERROR", 7, "ERROR1")
		end
	end

	function SF.Editor.getOpenFiles()
		local files = {}
		for i = 1, SF.Editor.editor:GetNumTabs() do
			local tab = SF.Editor.editor:GetTabContent(i)
			local path = tab.chosenfile
			if path and tab.GetCode then
				files[path:match("starfall/(.+)") or path] = tab:GetCode()
			end
		end
		return files
	end

	function SF.Editor.createEditor ()
		local editor = vgui.Create("StarfallEditorFrame") --Should define own frame later

		if SF.Editor.editor then SF.Editor.editor:Remove() end
		SF.Editor.editor = editor

		for k, v in pairs(SF.Editor.TabHandlers) do
			if v.Init then v:Init() end
		end

		editor:Setup("Starfall Editor", "starfall", "Starfall")
	end

	function SF.Editor.createGlobalPermissionsPanel(client, server)
		if server != false then -- default to true
			server = true
		end
		if client != false then -- defualt to true
			client = true
		end
		local permsPanel = vgui.Create("StarfallPermissions")

		SF.Permissions.refreshSettingsCache () -- Refresh cache first
		local clientProviders = SF.Permissions.providers

		if LocalPlayer():IsSuperAdmin() and server then
			SF.Permissions.requestPermissions(function(serverProviders)
				permsPanel:AddProviders(serverProviders, true)
				if client then
					permsPanel:AddProviders(clientProviders)
				end
			end)
		elseif client then
			permsPanel:AddProviders(clientProviders)
		end
		permsPanel:Dock(FILL)
		return permsPanel
	end
	function SF.Editor.openPermissionsPopup()
		local frame = vgui.Create("StarfallFrame")
		frame:SetSize(600, math.min(900, ScrH()))
		frame:Center()
		frame:SetTitle("Permissions")
		frame:Open()
		local permsPanel = SF.Editor.createGlobalPermissionsPanel()
		permsPanel:SetParent(frame)
		permsPanel:Dock(FILL)
	end


	--- (Client) Builds a table for the compiler to use
	-- @param mainfile Manual selection of which file should be main. Otherwise it's the open file
	-- @return True if ok, false if a file was missing
	-- @return A table with mainfile name and files
	function SF.Editor.BuildIncludesTable(mainfile)
		if not SF.Editor.editor then SF.Editor.init() end
		local openfiles = SF.Editor.getOpenFiles()
		if not (mainfile and (openfiles[mainfile] or file.Exists("starfall/" .. mainfile, "DATA"))) then
			mainfile = SF.Editor.getOpenFile() or "main"
			if #mainfile == 0 then return false, "Invalid main file" end
			openfiles[mainfile] = SF.Editor.getCode()
		end

		local tbl = {}
		tbl.mainfile = mainfile
		tbl.files = {}
		tbl.includes = {}

		local ppdata = {}

		local function findCodePath(path, curdir)
			if string.sub(path, 1, 1)~="/" then
				codepath = SF.NormalizePath(curdir .. path)
				if openfiles[codepath] or file.Exists("starfall/" .. codepath, "DATA") then return codepath end
			end
			codepath = SF.NormalizePath(path)
			if openfiles[codepath] or file.Exists("starfall/" .. codepath, "DATA") then return codepath end
		end

		local function recursiveLoad (path, curdir)
			local code, codedir, codepath

			local codepath = findCodePath(path, curdir)
			if not codepath then
				error("Bad include: " .. path)
			end

			if tbl.files[codepath] then return end

			code = openfiles[codepath] or file.Read("starfall/" .. codepath, "DATA")
			if not code then
				error("Bad include: " .. path)
			end

			codedir = string.GetPathFromFilename(codepath)
			tbl.files[codepath] = code
			SF.Preprocessor.ParseDirectives(codepath, code, ppdata)

			local clientmain = ppdata.clientmain and ppdata.clientmain[codepath]
			if clientmain then
				ppdata.clientmain[codepath] = findCodePath(clientmain, curdir) or clientmain
			end
			if ppdata.includes and ppdata.includes[codepath] then
				local inc = ppdata.includes[codepath]
				if not tbl.includes[codepath] then
					tbl.includes[codepath] = inc
				else
					assert(tbl.includes[codepath] == inc)
				end

				for i = 1, #inc do
					recursiveLoad(inc[i], codedir)
				end
			end
			if ppdata.includedirs and ppdata.includedirs[codepath] then
				local inc = ppdata.includedirs[codepath]

				for i = 1, #inc do
					local origdir = inc[i]
					local dir = origdir
					local files
					if string.sub(dir, 1, 1)~="/" then
						dir = SF.NormalizePath(codedir .. origdir)
						files = file.Find("starfall/" .. dir .. "/*", "DATA")
					end
					if not files or #files==0 then
						dir = SF.NormalizePath(origdir)
						files = file.Find("starfall/" .. dir .. "/*", "DATA")
					end
					for j = 1, #files do
						recursiveLoad(files[j], dir .. "/")
					end
				end
			end
		end
		local ok, msg = pcall(recursiveLoad, mainfile, string.GetPathFromFilename(mainfile))

		local function findCycle (file, visited, recStack)
			if not visited[file] then
				--Mark the current file as visited and part of recursion stack
				visited[file] = true
				recStack[file] = true

				--Recurse for all the files included in this file
				for k, v in pairs(ppdata.includes[file] or {}) do
					if recStack[v] then
						return true, file
					elseif not visited[v] then
						local cyclic, cyclicFile = findCycle(v, visited, recStack)
						if cyclic then return true, cyclicFile end
					end
				end
			end

			--Remove this file from the recursion stack
			recStack[file] = false
			return false, nil
		end

		local isCyclic = false
		local cyclicFile = nil
		for k, v in pairs(ppdata.includes or {}) do
			local cyclic, file = findCycle(k, {}, {})
			if cyclic then
				isCyclic = true
				cyclicFile = file
				break
			end
		end

		if isCyclic then
			return false, "Loop in includes from: " .. cyclicFile
		end

		local clientmain = ppdata.clientmain and ppdata.clientmain[tbl.mainfile]
		if clientmain and not tbl.files[clientmain] then
			return false, "Clientmain not found: " .. clientmain
		end

		if ok then
			return true, tbl
		else
			local _1, _2, file = string.find(msg, "(Bad include%: .*)")
			if file then
				return false, file
			else
				error(msg, 0)
			end
		end
	end

	-- CLIENT ANIMATION

	local busy_players = { }
	hook.Add("EntityRemoved", "starfall_busy_animation", function (ply)
		busy_players[ply] = nil
	end)

	local emitter = ParticleEmitter(vector_origin)

	net.Receive("starfall_editor_status", function(len)
		local ply = net.ReadEntity()
		local status = net.ReadBit() ~= 0 -- net.ReadBit returns 0 or 1, despite net.WriteBit taking a boolean
		if not ply:IsValid() or ply == LocalPlayer() then return end

		busy_players[ply] = status or nil
	end)

	local rolldelta = math.rad(80)
	timer.Create("starfall_editor_status", 1 / 3, 0, function ()
		rolldelta = -rolldelta
		for ply, _ in pairs(busy_players) do
			local BoneIndx = ply:LookupBone("ValveBiped.Bip01_Head1") or ply:LookupBone("ValveBiped.HC_Head_Bone") or 0
			local BonePos, BoneAng = ply:GetBonePosition(BoneIndx)
			local particle = emitter:Add("radon/starfall2", BonePos + Vector(math.random(-10, 10), math.random(-10, 10), 60 + math.random(0, 10)))
			if particle then
				particle:SetColor(math.random(30, 50), math.random(40, 150), math.random(180, 220))
				particle:SetVelocity(Vector(0, 0, -40))

				particle:SetDieTime(1.5)
				particle:SetLifeTime(0)

				particle:SetStartSize(10)
				particle:SetEndSize(5)

				particle:SetStartAlpha(255)
				particle:SetEndAlpha(0)

				particle:SetRollDelta(rolldelta)
			end
		end
	end)
	concommand.Add("sf_editor_restart", function()
		if not SF.Editor.initialized then return end
		SF.Editor.editor:Close()
		for k, v in pairs(SF.Editor.TabHandlers) do
			if v.Cleanup then v:Cleanup() end
		end
		SF.Editor.initialized = false
		SF.Editor.editor:Remove()
		SF.Editor.editor = nil
		SF.Editor.open ()
		print("Editor reloaded")
	end)
	concommand.Add("sf_editor_reload", function()
		include("starfall/editor/editor.lua")
	end)
elseif SERVER then

	util.AddNetworkString("starfall_editor_status")

	local starfall_event = {}

	concommand.Add("starfall_event", function (ply, command, args)
		local handler = starfall_event[args[1] or ""]
		if not handler then return end
		return handler(ply, args)
	end)

	function starfall_event.editor_open (ply, args)
		net.Start("starfall_editor_status")
		net.WriteEntity(ply)
		net.WriteBit(true)
		net.Broadcast()
	end

	function starfall_event.editor_close (ply, args)
		net.Start("starfall_editor_status")
		net.WriteEntity(ply)
		net.WriteBit(false)
		net.Broadcast()
	end
end
