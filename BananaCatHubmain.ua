--[[
Banana Cat Hub - Delta compatibility and diagnostics loader
Version: 1.4 (2026-10-11) — runtime guards, settings recovery and diagnostics

This loader downloads the original script supplied by the user, applies a
limited set of compatibility fixes, saves the complete patched source when
Delta supports file writing, and then launches it.

Keeps the original menu; changes quest, farm and Trial runtime handling.
Other original features and external dependencies are not live-verified.
It is NOT a replacement menu or a verified bypass for game-side restrictions.
Version 1.4 stages: missing materials -> craft -> island search/event -> Draco trial.
The recipe and game interfaces are from the supplied source, not live verified.
This code has NOT been tested in a live Blox Fruits/Delta session.

Never run untrusted scripts without inspecting the original source.
]]

local SOURCE_URL = "https://raw.githubusercontent.com/ptlhub2026/ptlhub/refs/heads/main/3nn_main.lua.txt"
local SAVE_FOLDER = "Banana Cat Hub"
local SAVE_FILE = SAVE_FOLDER .. "/BananaCatHub_Delta_v1_4_Full.lua"
local LOG_FILE = SAVE_FOLDER .. "/Delta_Fix_Errors.txt"
local PREFIX = "[BananaCat Delta Fix] "

local function info(message)
    print(PREFIX .. tostring(message))
end

local function problem(message)
    warn(PREFIX .. tostring(message))
end

if type(getgenv) ~= "function" then
    problem("Delta/getgenv() is unavailable; cannot start.")
    return
end

local env = getgenv()
if env.__BC_DELTA_PATCH_RUNNING then
    problem("The Delta patch loader is already running. Do not execute it twice.")
    return
end

-- The original UI and workers cannot be safely recreated in the same session.
if env.__BF_LOADED or env.LoadScript then
    problem("A Banana Cat Hub session is already loaded. Leave and rejoin Blox Fruits, then use ONLY this file once.")
    return
end

env.__BC_DELTA_PATCH_RUNNING = true
local function stop(message)
    env.__BC_DELTA_PATCH_RUNNING = false
    problem(message)
end

if type(loadstring) ~= "function" then
    stop("Delta does not expose loadstring().")
    return
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local players = game:GetService("Players")
local deadline = os.clock() + 25
while not players.LocalPlayer and os.clock() < deadline do
    task.wait(0.1)
end
if not players.LocalPlayer then
    stop("LocalPlayer is not ready.")
    return
end

-- Download as TEXT ONLY. We patch it before compilation/execution.
local downloaded, original = pcall(function()
    local ok, body = pcall(function() return game:HttpGet(SOURCE_URL, true) end)
    if ok and type(body)=="string" then return body end
    local req = (type(request)=="function" and request) or (type(http_request)=="function" and http_request)
      or (type(syn)=="table" and syn.request) or (type(http)=="table" and http.request)
    if type(req)~="function" then error(tostring(body)) end
    local response = req({Url=SOURCE_URL,Method="GET"})
    if type(response)~="table" or tonumber(response.StatusCode)~=200 or type(response.Body)~="string" then
     error("HTTP download failed")
    end
    return response.Body
end)
if not downloaded or type(original) ~= "string" then
    stop("Failed to download original source: " .. tostring(original))
    return
end
if #original < 100000
    or not original:find("function toTarget(", 1, true)
    or not original:find("function AttackAOE(", 1, true)
    or not original:find("Settings = ReadSetting()", 1, true)
then
    stop("The GitHub source no longer matches the inspected Banana Cat Hub file. Stopping rather than patching unrelated code.")
    return
end

local source = original:gsub("\r\n", "\n")
local counts = {}
local function escapePattern(value)
    return (value:gsub("([^%w])", "%%%1"))
end
local function replaceLiteral(name, oldText, newText)
    local amount
    source, amount = source:gsub(escapePattern(oldText), function()
        return newText
    end)
    counts[name] = amount
    info(name .. " -> " .. tostring(amount) .. " replacement(s)")
    return amount
end

if replaceLiteral("Settings IO recovery", [====[function SaveSettings(b, t, A)
	if A ~= nil then
		Settings[b] = Settings[b] or {}
		Settings[b][t] = A
	elseif b ~= nil then
		Settings[b] = t
	end
	if not isfolder(FolderName) then
		makefolder(FolderName)
	end
	writefile(FolderName .. "/" .. SaveFileName, HttpService:JSONEncode(Settings))
end
if getgenv().Config then
	Settings = getgenv().Config
	SaveSettings()
end
function ReadSetting()
	local b, t = pcall(function()
		if not isfolder(FolderName) then
			makefolder(FolderName)
		end
		return HttpService:JSONDecode(readfile(FolderName .. "/" .. SaveFileName))
	end)
	if b then
		return t
	else
		SaveSettings()
		return ReadSetting()
	end
end
]====], [====[function SaveSettings(key, value, member)
 if type(Settings) ~= "table" then Settings = {} end
 if member ~= nil then
  if type(Settings[key]) ~= "table" then Settings[key] = {} end
  Settings[key][value] = member
 elseif key ~= nil then Settings[key] = value end
 if type(isfolder)~="function" or type(makefolder)~="function" or type(writefile)~="function" then return end
 local ok, err = pcall(function()
  if not isfolder(FolderName) then makefolder(FolderName) end
  writefile(FolderName .. "/" .. SaveFileName, HttpService:JSONEncode(Settings))
 end)
 if not ok and not getgenv().__BC_SETTINGS_WARNED then
  getgenv().__BC_SETTINGS_WARNED=true
  warn("[BananaCat] Settings kept in memory; save failed: " .. tostring(err))
 end
end
function ReadSetting()
 if type(getgenv().Config)=="table" then return getgenv().Config end
 if type(readfile)=="function" then
  local ok, decoded = pcall(function()
   return HttpService:JSONDecode(readfile(FolderName .. "/" .. SaveFileName))
  end)
  if ok and type(decoded)=="table" then return decoded end
 end
 return type(Settings)=="table" and Settings or {}
end
]====]) ~= 1 then
 stop("Source mismatch: Settings IO recovery") return
end

if replaceLiteral("Team selection readiness", [====[repeat
	wait()
until b:FindFirstChild("ChooseTeam")
repeat
	task.wait()
	pcall(function()
		if Settings["Select Team"] == "Pirate" then
			FireButton(
				game:GetService("Players").LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container.Pirates.Frame.TextButton
			)
			wait(1)
		else
			FireButton(
				game:GetService("Players").LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container.Marines.Frame.TextButton
			)
			wait(1)
		end
	end)
until game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)")
		and (game:GetService("Players").LocalPlayer.PlayerGui["Main (minimal)"]:FindFirstChild("ChooseTeam"))
		and not game:GetService("Players").LocalPlayer.PlayerGui["Main (minimal)"]:WaitForChild("ChooseTeam").Visible
	or game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main")
		and (game:GetService("Players").LocalPlayer.PlayerGui.Main:FindFirstChild("ChooseTeam"))
		and not game:GetService("Players").LocalPlayer.PlayerGui.Main:WaitForChild("ChooseTeam").Visible
]====], [====[local teamDeadline = os.clock()+45
while game.Players.LocalPlayer.Team == nil and os.clock()<teamDeadline do
 local gui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
 for _, name in ipairs({"Main (minimal)","Main"}) do
  local main = gui and gui:FindFirstChild(name)
  local chooser = main and main:FindFirstChild("ChooseTeam")
  local container = chooser and chooser:FindFirstChild("Container")
  local team = container and container:FindFirstChild(Settings["Select Team"]=="Marine" and "Marines" or "Pirates")
  local frame = team and team:FindFirstChild("Frame")
  local button = frame and frame:FindFirstChild("TextButton")
  if chooser and chooser.Visible and button then FireButton(button) end
 end
 task.wait(0.5)
end
if game.Players.LocalPlayer.Team == nil then error("Choose a team manually, then rejoin and retry") end
]====]) ~= 1 then
 stop("Source mismatch: Team selection readiness") return
end

if replaceLiteral("Request API selection", [====[getgenv().ExploitReq = syn and syn.request
	or identifyexecutor() == "Fluxus" and request
	or http_request
	or http.request
	or requests
]====], [====[getgenv().ExploitReq = (type(request)=="function" and request)
 or (type(http_request)=="function" and http_request)
 or (type(syn)=="table" and type(syn.request)=="function" and syn.request)
 or (type(http)=="table" and type(http.request)=="function" and http.request)
 or (type(requests)=="function" and requests)
]====]) ~= 1 then
 stop("Source mismatch: Request API selection") return
end

-- 1. A plain-text source should not call an undefined code-protector macro.
replaceLiteral("Protection directive", "LPH_ATTRIBUTES(VM(NONE))", "do end -- BC_DELTA: ignored source protection directive")

-- 2. Fix 'S' (Players service) when calculating hit targets. This was an
--    undeclared alias in the inspected source section.
replaceLiteral("Player hit target lookup", "S:GetPlayerFromCharacter(", 'game:GetService("Players"):GetPlayerFromCharacter(')

-- 3. Roblox service/member names are case-sensitive in Lua.
replaceLiteral("LocalPlayer capitalization", "game.Players.localPlayer", "game.Players.LocalPlayer")

-- 4. Some executors don't define a global 'http'; avoid indexing nil.
replaceLiteral("HTTP request nil guard", "or http.request", "or (http and http.request)")

-- 5. Set missing defaults; preserve the user's saved toggles.
replaceLiteral(
    "Missing farm defaults",
    "Settings = ReadSetting()",
    [[Settings = ReadSetting()
if Settings["Select Method Farm"] == nil then
    SaveSettings("Select Method Farm", "Level Farm")
end
if Settings["Select Weapon"] == nil then
    SaveSettings("Select Weapon", "Melee")
end]]
)


-- Quest and Trial fixes matched against the supplied source.
replaceLiteral("Quest state helpers", [====[function DontQuest()
	return Z.Data and Z.Data.QuestData ~= nil
end
function GetNameDoubleQuest()
	if DontQuest() then
		for C, J in next, Z.Data.QuestData.Task, nil do
			return C
		end
	end
end
]====], [====[
function BCPath(object, ...)
 for _, name in ipairs({...}) do
  if not object then return nil end
  object = object:FindFirstChild(name)
 end
 return object
end
function BCLivingRoot()
 local char = t.Character
 local human = char and char:FindFirstChildOfClass("Humanoid")
 local root = char and char:FindFirstChild("HumanoidRootPart")
 if human and human.Health > 0 and root and root:IsA("BasePart") then return root end
end
function BCTransformed()
 local frame = BCPath(t, "PlayerGui", "TransformationHUD", "ImageLabel")
 return frame and frame:IsA("GuiObject") and frame.Visible or false
end
function BCFarmRunning()
 return Settings["Start Farm"] and StackFarm and not Settings["Auto Trial"] and not Settings["Auto Trial Draco"] and not Settings["Fully Trial Draco"] and BCLivingRoot() ~= nil
end
-- A visible quest and its task data can arrive on different frames.
function BCQuestVisible()
 local gui = t:FindFirstChild("PlayerGui")
 if not gui then return false end
 for _, name in ipairs({"Main", "Main (minimal)"}) do
  local main = gui:FindFirstChild(name)
  local frame = main and main:FindFirstChild("Quest")
  if frame and frame:IsA("GuiObject") and frame.Visible then return true end
 end
 return false
end
function DontQuest()
 local data = Z and Z.Data
 local quest = data and data.QuestData
 return type(quest) == "table" and type(quest.Task) == "table" and next(quest.Task) ~= nil
end
function GetNameDoubleQuest()
 if DontQuest() then
  for name, amount in pairs(Z.Data.QuestData.Task) do
   if type(name) == "string" and type(amount) == "number" and amount > 0 then return name end
  end
 end
end
function BCQuestStatus(message)
 local env = getgenv()
 if env.__BC_QUEST_STATUS ~= message or os.clock() - (env.__BC_QUEST_STATUS_AT or 0) > 15 then
  env.__BC_QUEST_STATUS, env.__BC_QUEST_STATUS_AT = message, os.clock()
  warn("[BananaCat Quest] " .. message)
 end
end
]====])
replaceLiteral("Quest point initialization", [====[function CFrameQuest()
	local B = {}
	for C, J in next, H, nil do
		if C ~= "MarineQuest" then
			for F, F in next, J, nil do
				B[F.LevelReq] = C
			end
		end
	end
	getgenv().questpoint = {}
	for C, J in next, Z.Data.NPCList, nil do
		for F, q in next, J.Levels, nil do
			F = B[q]
			if C.Parent.Name ~= "Marine Leader" and F and not getgenv().questpoint[F] then
				getgenv().questpoint[F] = CFrame.new(J.Position)
			end
		end
	end
	getgenv().questpoint.SkyExp1Quest = CFrame.new(-7857.28516, 5544.34033, -382.321503)
end
]====], [====[function CFrameQuest()
 getgenv().questpoint = getgenv().questpoint or {}
 local list = Z and Z.Data and Z.Data.NPCList
 if type(list) == "table" then
  for _, npc in pairs(list) do
   if type(npc) == "table" and type(npc.InternalQuestName) == "string" then
    local pos = npc.Position
    if typeof(pos) == "CFrame" or typeof(pos) == "Vector3" then
     getgenv().questpoint[npc.InternalQuestName] = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
    end
   end
  end
 end
 getgenv().questpoint.SkyExp1Quest = CFrame.new(-7857.28516, 5544.34033, -382.321503)
end
]====])
replaceLiteral("Quest selection", [====[local function B(C)
	local J = Z.Data.QuestData
	local F, q, c = J and (next(J.Task)), 0, {}
	for D, r in pairs(Z.Data.NPCList) do
		if not table.find(V, r.InternalQuestName) then
			for V, n in pairs(r.Levels) do
				D = H[r.InternalQuestName][V]
				if D then
					local u, W = next(D.Task)
					if W and W > 1 and n <= C and n >= q then
						c = {
							Level = n,
							Name = r.NPCName,
							QuestName = r.InternalQuestName,
							Pos = r.Position,
							Id = V,
							Mob = u,
						}
						if F == u and V > 1 then
							J = H[r.InternalQuestName][V - 1]
							if J and J.Task then
								for H, C in pairs(J.Task) do
									if H ~= F and C > 1 then
										c.Mob = H
										c.Id = V - 1
										break
									end
								end
							end
						end
						q = n
					end
				end
			end
		end
	end
	return c
end
]====], [====[local function B(level)
 local list = Z and Z.Data and Z.Data.NPCList
 if type(list) ~= "table" then return nil end
 local best
 for _, npc in pairs(list) do
  if type(npc) == "table" and type(npc.Levels) == "table"
   and not table.find(V, npc.InternalQuestName)
   and (typeof(npc.Position) == "Vector3" or typeof(npc.Position) == "CFrame") then
   local definitions = type(H) == "table" and H[npc.InternalQuestName]
   for id, required in pairs(npc.Levels) do
    local questId = tonumber(id)
    local definition = definitions and (definitions[id] or definitions[questId])
    required = tonumber(required)
    if questId and required and required <= level and type(definition) == "table"
     and type(definition.Task) == "table" and (not best or required > best.Level) then
     for mob, amount in pairs(definition.Task) do
      if type(amount) == "number" and amount > 1 then
       best = {Level=required, QuestName=npc.InternalQuestName, Id=questId, Pos=npc.Position, Mob=mob}
       break
      end
     end
    end
   end
  end
 end
 return best
end
]====])
replaceLiteral("Quest acceptance", [====[TakeQuestLevel = function()
	local V = B(t.Data.Level.Value)
	if not V or not V.Pos then
		return
	end
	local H, B, C =
		typeof(V.Pos) == "CFrame" and V.Pos.Position or V.Pos,
		t.Character and (t.Character:FindFirstChild("HumanoidRootPart")),
		t.Character and (t.Character:FindFirstChild("Humanoid"))
	if not B or not C then
		return
	end
	if (H - B.Position).Magnitude <= 8 and C.Health > 0 then
		wait(2)
		CommF:InvokeServer("StartQuest", tostring(V.QuestName), V.Id)
	else
		toTarget(CFrame.new(H) * CFrame.new(0, 4, 2), true)
	end
end

]====], [====[TakeQuestLevel = function()
 if BCQuestVisible() or DontQuest() then return end
 getgenv().__BC_QUEST_MOB = nil
 local data = t:FindFirstChild("Data")
 local level = data and data:FindFirstChild("Level")
 local quest = level and B(level.Value)
 if not quest then BCQuestStatus("Waiting for quest/NPC data") return end
 local character = t.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local human = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not human or human.Health <= 0 then return end
 local pos = typeof(quest.Pos) == "CFrame" and quest.Pos.Position or quest.Pos
 if (pos-root.Position).Magnitude > 8 then
  toTarget(CFrame.new(pos) * CFrame.new(0,4,2), true)
  return
 end
 local env = getgenv()
 if os.clock() - (env.__BC_QUEST_TRY or -10) < 2 then return end
 env.__BC_QUEST_TRY = os.clock()
 local result = CommF:InvokeServer("StartQuest", quest.QuestName, quest.Id)
 BCQuestStatus("Requested " .. quest.QuestName .. "; waiting for confirmation: " .. tostring(result))
end

]====])
replaceLiteral("Special quest throttle", [====[function QuestBoneAndkatakuri(V, H)
]====], [====[function QuestBoneAndkatakuri(V, H)
 if BCQuestVisible() or DontQuest() then return end
 if os.clock() - (getgenv().__BC_SPECIAL_QUEST_TRY or -10) < 2 then return end
 getgenv().__BC_SPECIAL_QUEST_TRY = os.clock()
]====])
replaceLiteral("Trial entry and lifecycle", [====[function AutoTrialV4()
	if Settings["Auto Finish Train Quest"] and Settings["Stack Train With Trial Race"] and (CheckGoTrain()) then
		return
	end
	local g = game.Lighting.ClockTime
	if
		(CheckMoon() == "Full Moon" and not (g > 5 and g < 12) or CheckMoon() == "Next Night")
		and Settings["Hop Server [Trial Or Pull Lever]"]
	then
		if getgenv().TurnOffHOPSVPullAndTrial then
			getgenv().TurnOffHOPSVPullAndTrial:SetStage(false)
		end
		task.wait(3)
	elseif Settings["Hop Server [Trial Or Pull Lever]"] then
		HopServer()
		return
	end
	g = GetTempleOfTime()
	if not g and not VerifyNearbyTrial() then
		toTarget(CFrame.new(28282.5703125, 14896.8505859375, 105.1042709350586))
		return
	end
	if
		g and (g.FFABorder:FindFirstChild("Forcefield")) and g.FFABorder.Forcefield.Transparency == 1
		or (VerifyNearbyTrial())
	then
		if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
			if VerifyNearbyTrial() and not getgenv().VerifyTrial then
				getgenv().VerifyTrial = true
			end
			repeat
				wait()
			until VerifyNearbyTrial()
				or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			local R = game.Players.LocalPlayer.Data.Race.Value
			if R == "Human" then
				repeat
					task.wait()
					local m = TrialHuman()
					if m then
						repeat
							task.wait()
							sizepart(m)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
							ClickM1(m)
							UsedualFlock()
						until not IsMobAlive(m)
							or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
							or (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - game:GetService(
									"Workspace"
								)._WorldOrigin.Locations["Trial of Strength"].Position).Magnitude
								> 1000
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or (
							game.Players.LocalPlayer.Character.HumanoidRootPart.Position
							- game:GetService("Workspace")._WorldOrigin.Locations["Trial of Strength"].Position
						).Magnitude
						> 1000
			elseif R == "Skypiea" then
				repeat
					task.wait()
					if
						game:GetService("Workspace")._WorldOrigin.Locations["Trial of the King"]
						and (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - game:GetService(
								"Workspace"
							)._WorldOrigin.Locations["Trial of the King"].CFrame.Position).Magnitude
							<= 1000
					then
						toTarget(game:GetService("Workspace").Map.SkyTrial.Model.FinishPart.CFrame)
						task.wait(3)
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or workspace.Map:FindFirstChild("Temple of Time") and workspace.Map["Temple of Time"].FFABorder.Forcefield.Transparency == 0
					or t:DistanceFromCharacter(game:GetService("Workspace").Map.SkyTrial.Model.FinishPart.Position)
						> 1000
			elseif R == "Fishman" then
				local m = if game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Water")
					then (game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Water"))
					else nil
				if m and (m.Position - t.Character.HumanoidRootPart.Position).Magnitude < 1500 then
					local m = GetSeaBeastTrial()
					repeat
						task.wait()
						if m then
							local l = m:FindFirstChild("HumanoidRootPart")
							getgenv().AimPos = CFrame.new(l.Position.X, 40, l.Position.Z)
							TeleportSeabeast2(m)
							if t:DistanceFromCharacter(l.Position) < 400 then
								AutoAllSkill()
							end
						end
					until not m
						or not m.Parent
						or m.Health.Value == 0
						or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
						or workspace.Map:FindFirstChild("Temple of Time") and workspace.Map["Temple of Time"].FFABorder.Forcefield.Transparency == 0
						or t:DistanceFromCharacter(
								game:GetService("Workspace")._WorldOrigin.Locations
									:FindFirstChild("Trial of Water").Position
							)
							> 1000
				end
			elseif R == "Mink" then
				repeat
					task.wait()
					if
						(
							game.Players.LocalPlayer.Character.HumanoidRootPart.Position
							- game:GetService("Workspace")._WorldOrigin.Locations["Trial of Speed"].Position
						).Magnitude <= 1000
					then
						toTarget(game:GetService("Workspace").StartPoint.CFrame * CFrame.new(0, 2, 0))
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or t:DistanceFromCharacter(
							game:GetService("Workspace")._WorldOrigin.Locations
								:FindFirstChild("Trial of Speed").Position
						)
						> 1000
			elseif R == "Ghoul" then
				repeat
					task.wait()
					local m = TrialGhoul()
					if m then
						repeat
							task.wait()
							sizepart(m)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
							UsedualFlock()
							ClickM1(m)
						until not IsMobAlive(m)
							or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
							or t:DistanceFromCharacter(
									game:GetService("Workspace")._WorldOrigin.Locations
										:FindFirstChild("Trial of Carnage").Position
								)
								> 1000
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or t:DistanceFromCharacter(
							game:GetService("Workspace")._WorldOrigin.Locations
								:FindFirstChild("Trial of Carnage").Position
						)
						> 1000
			elseif R == "Cyborg" then
				repeat
					task.wait()
					toTarget(CFrame.new(28282.5703125, 14896.8505859375, 105.1042709350586))
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			end
		else
			if not g then
				return
			end
			local R = g[t.Data.Race.Value .. "Corridor"].Door.Door.RightDoor.Union
			if t:DistanceFromCharacter(R.Position) > 8 then
				toTarget(R.CFrame)
			end
			if Settings["Multi Trial"] and (CheckMultiTeleDoor()) and t:DistanceFromCharacter(R.Position) <= 8 then
				game:service("VirtualInputManager"):SendKeyEvent(true, "T", false, game)
				task.wait()
				game:service("VirtualInputManager"):SendKeyEvent(false, "T", false, game)
				return
			end
			if Settings["Auto Turn On V3 Near Door"] and (CheckMultiPlayerNearDoor()) then
				game:service("VirtualInputManager"):SendKeyEvent(true, "T", false, game)
				task.wait()
				game:service("VirtualInputManager"):SendKeyEvent(false, "T", false, game)
			end
		end
	elseif getgenv().VerifyTrial then
		if not Settings["Multi Trial"] and not Settings["Auto Reset Character"] then
			Settings["Auto Trial"] = false
			ToggleAutoTrial:SetStage(false)
		end
		getgenv().VerifyTrial = false
	end
end
]====], [====[function BCTrialMessage(message)
 local env = getgenv()
 if env.__BC_TRIAL_STATUS ~= message or os.clock()-(env.__BC_TRIAL_STATUS_AT or 0)>15 then
  env.__BC_TRIAL_STATUS, env.__BC_TRIAL_STATUS_AT = message, os.clock()
  warn("[BananaCat Trial] " .. message)
 end
end
function BCTrialTimer()
 if not Settings["Auto Trial"] or not BCLivingRoot() then return false end
 for _, name in ipairs({"Main", "Main (minimal)"}) do
  local timer = BCPath(t, "PlayerGui", name, "TopHUDList", "RaidTimer")
  if timer and timer:IsA("GuiObject") and timer.Visible then return true end
 end
 return false
end
function BCTrialLocation(name, radius)
 local root = BCLivingRoot()
 local location = BCPath(workspace, "_WorldOrigin", "Locations", name)
 if root and location and location:IsA("BasePart") then
  return (root.Position-location.Position).Magnitude <= (radius or 1000)
 end
 return false
end
function BCNearbyTrial()
 for _, name in ipairs({"Trial of the Machine","Trial of Speed","Trial of Strength","Trial of Water","Trial of the King","Trial of Carnage","Trial of Flames"}) do
  if BCTrialLocation(name, 1500) then return true end
 end
 return false
end
function BCEnterTemple()
 local root = BCLivingRoot()
 if not root then return end
 local env = getgenv()
 if os.clock()-(env.__BC_TRIAL_POLL or -10)>=2 then
  env.__BC_TRIAL_POLL = os.clock()
  env.__BC_TRIAL_PROGRESS = CommF:InvokeServer("RaceV4Progress", "Check")
 end
 if not Settings["Auto Trial"] or not BCLivingRoot() then return end
 local stage = env.__BC_TRIAL_PROGRESS
 local tree = CFrame.new(3032.780029296875,2280.85107421875,-7325.47802734375)
 local temple = Vector3.new(28282.5703125,14896.8505859375,105.1042709350586)
 if stage == 1 then
  if os.clock()-(env.__BC_TRIAL_ACTION or -10)>=3 then
   env.__BC_TRIAL_ACTION=os.clock()
   BCTrialMessage("Starting NPC progress")
   CommF:InvokeServer("RaceV4Progress", "Begin")
  end
  return
 end
 root = BCLivingRoot()
 if not root then return end
 if (root.Position-temple).Magnitude>1500 then
  BCTrialMessage("Moving to the Great Tree NPC")
  if (root.Position-tree.Position).Magnitude>8 then
   toTarget(tree, true)
  elseif os.clock()-(env.__BC_TRIAL_ACTION or -10)>=3 then
   env.__BC_TRIAL_ACTION=os.clock()
   CommF:InvokeServer("RaceV4Progress", "Teleport")
  end
  return
 end
 if stage==3 and os.clock()-(env.__BC_TRIAL_ACTION or -10)>=3 then
  env.__BC_TRIAL_ACTION=os.clock()
  CommF:InvokeServer("RaceV4Progress", "Continue")
 end
end
function AutoTrialV4()
 if not Settings["Auto Trial"] or not BCLivingRoot() then return end
 if Settings["Auto Finish Train Quest"] and Settings["Stack Train With Trial Race"] and CheckGoTrain() then return end
 local nearby = BCNearbyTrial()
 local active = BCTrialTimer() and nearby
 local env = getgenv()
 if active then
  env.VerifyTrial = true
  local race = BCPath(t,"Data","Race")
  race = race and race.Value
  if race == "Human" or race == "Ghoul" then
   local location = race == "Human" and "Trial of Strength" or "Trial of Carnage"
   if not BCTrialLocation(location) then return end
   local mob = race == "Human" and TrialHuman() or nil
   if race == "Ghoul" then mob = TrialGhoul() end
   if not IsMobAlive(mob) or not BCTrialTimer() then return end
   sizepart(mob)
   local part = mob:FindFirstChild("HumanoidRootPart")
   if not part then return end
   toTarget(part.CFrame * CFrame.new(Settings["Select Weapon"] == "Blox Fruit" and -7 or 7,20,0))
   if not BCTrialTimer() or not IsMobAlive(mob) then return end
   ClickM1(mob)
   UsedualFlock()
  elseif race == "Skypiea" then
   local finish = BCPath(workspace,"Map","SkyTrial","Model","FinishPart")
   if BCTrialLocation("Trial of the King") and finish and finish:IsA("BasePart") then toTarget(finish.CFrame) end
  elseif race == "Fishman" then
   if not BCTrialLocation("Trial of Water",1500) then return end
   local mob = GetSeaBeastTrial()
   local part = mob and mob.Parent and mob:FindFirstChild("HumanoidRootPart")
   local health = mob and mob:FindFirstChild("Health")
   if not part or not part:IsA("BasePart") or not health or not (health:IsA("NumberValue") or health:IsA("IntValue")) or health.Value<=0 then return end
   env.AimPos = CFrame.new(part.Position.X,40,part.Position.Z)
   TeleportSeabeast2(mob)
   local root = BCLivingRoot()
   if root and BCTrialTimer() and part.Parent and (root.Position-part.Position).Magnitude<400 then AutoAllSkill() end
  elseif race == "Mink" then
   local start = workspace:FindFirstChild("StartPoint")
   if BCTrialLocation("Trial of Speed") and start and start:IsA("BasePart") then toTarget(start.CFrame*CFrame.new(0,2,0)) end
  elseif race == "Cyborg" then
   if BCTrialLocation("Trial of the Machine",1500) then toTarget(CFrame.new(28282.5703125,14896.8505859375,105.1042709350586)) end
  else
   BCTrialMessage("Race is not handled by this Trial routine: " .. tostring(race))
  end
  return
 end
 if env.VerifyTrial then
  env.VerifyTrial = false
  if not Settings["Multi Trial"] and not Settings["Auto Reset Character"] then
   SaveSettings("Auto Trial",false)
   if ToggleAutoTrial and type(ToggleAutoTrial.SetStage)=="function" then ToggleAutoTrial:SetStage(false) end
   return
  end
 end
 -- Do not server-hop while a trial timer is active or a trial map is nearby.
 if not nearby and not BCTrialTimer() and Settings["Hop Server [Trial Or Pull Lever]"] then
  local hour, moon = game.Lighting.ClockTime, CheckMoon()
  if (moon=="Full Moon" and not (hour>5 and hour<12)) or moon=="Next Night" then
   if env.TurnOffHOPSVPullAndTrial then env.TurnOffHOPSVPullAndTrial:SetStage(false) end
  else HopServer() return end
 end
 if nearby then BCTrialMessage("Waiting for trial timer") return end
 BCEnterTemple()
 local root = BCLivingRoot()
 if not root or not Settings["Auto Trial"] then return end
 if (root.Position-Vector3.new(28282.5703125,14896.8505859375,105.1042709350586)).Magnitude>1500 then return end
 local temple = BCPath(workspace,"Map","Temple of Time")
 if not temple or temple:GetAttribute("ClientBorrowed") then return end
 local field = BCPath(temple,"FFABorder","Forcefield")
 if not field or not field:IsA("BasePart") or field.Transparency~=1 then
  BCTrialMessage("Waiting for temple access/lever conditions") return
 end
 local race = BCPath(t,"Data","Race")
 local door = race and BCPath(temple,tostring(race.Value).."Corridor","Door","Door","RightDoor","Union")
 if not door or not door:IsA("BasePart") then BCTrialMessage("Waiting for race door to load") return end
 if (root.Position-door.Position).Magnitude>8 then toTarget(door.CFrame) return end
 BCTrialMessage("Waiting at race door for trial conditions/other players")
 if os.clock()-(env.__BC_TRIAL_KEY_AT or -10)<2 then return end
 if (Settings["Multi Trial"] and CheckMultiTeleDoor()) or (Settings["Auto Turn On V3 Near Door"] and CheckMultiPlayerNearDoor()) then
  env.__BC_TRIAL_KEY_AT=os.clock()
  local input = game:GetService("VirtualInputManager")
  input:SendKeyEvent(true,Enum.KeyCode.T,false,game)
  task.wait()
  input:SendKeyEvent(false,Enum.KeyCode.T,false,game)
 end
end
]====])
replaceLiteral("Farm state and movement ownership", [====[function FarmMethod()
	local f, V, H = Settings["Select Method Farm"]
	local C, J = 9999, 2
	if f == "Farm Katakuri" then
		C, V, H = 2275, y, "CakeQuest2"
	elseif f == "Farm Bones" then
		C, V, H = 2050, e, "HauntedQuest2"
	elseif f == "Farm Tyrant of the Skies" then
		C, V, H = 2575, Y, "TikiQuest3"
	else
		V = if f == "Aura Farm" and (DetectMobAura()) then { DetectMobAura() } else V
	end
	if Settings["Farm Material"] then
		V = NameMaterials[Settings["Select Material"]]
		if not NameWorldMaterials[Settings["Select Material"]][game.PlaceId] then
			f = NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId2]
				or NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId3]
				or NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId]
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(f)
			return
		end
	end
	f = V or (GetNameDoubleQuest()) or ""
	if not t.PlayerGui.Main:FindFirstChild("Quest").Visible and typeof(f) == "string" then
		TakeQuestLevel()
	else
		if
			Settings["Auto Quest [Katakuri/Bone/Tyrant]"]
			and t.Data.Level.Value >= C
			and not t.PlayerGui.Main:FindFirstChild("Quest").Visible
		then
			QuestBoneAndkatakuri(H, J)
			return
		end
		if not Settings["Farm Material"] and Settings["Select Method Farm"] == "Farm Tyrant of the Skies" then
			if CheckNameBoss("Tyrant of the Skies") then
				V = CheckNameBoss("Tyrant of the Skies")
				repeat
					task.wait()
					sizepart(V)
					if
						game:GetService("Players").LocalPlayer.PlayerGui.TransformationHUD.ImageLabel.Visible
						and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
					then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					elseif Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(V)
				until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm
				return
			else
				local V = workspace:FindFirstChild("Map", true)
					and (workspace.Map:FindFirstChild("TikiOutpost", true))
					and (workspace.Map.TikiOutpost:FindFirstChild("IslandModel", true))
				if V then
					local Y, H, C, J =
						V:FindFirstChild("Eye1", true),
						V:FindFirstChild("Eye2", true),
						V:FindFirstChild("Eye3", true),
						V:FindFirstChild("Eye4", true)
					if
						Y
						and H
						and C
						and J
						and Y.Transparency == 0
						and H.Transparency == 0
						and C.Transparency == 0
						and J.Transparency == 0
					then
						local V = DetectModelDestroyTyrant()
						if V then
							if t:DistanceFromCharacter(V.WorldPivot.Position) > 10 then
								toTarget(V.WorldPivot)
							elseif CheckItemInventory("Skull Guitar") then
								if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Skull Guitar" then
									game:GetService("ReplicatedStorage").Remotes.CommF_
										:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Skull Guitar" }))
								else
									equiptool(NameWeapon("Gun"))
									getgenv().SpamGunSkullGuitar(V.WorldPivot)
								end
							else
								getgenv().AimPos = V.WorldPivot
								AutoAllSkill()
							end
						end
						return
					end
				end
			end
		end
		if
			not Settings["Farm Material"]
			and Settings["Select Method Farm"] == "Farm Katakuri"
			and not Settings["Ignore Attack Katakuri"]
		then
			if CheckNameBoss("Cake Prince") then
				local V = CheckNameBoss("Cake Prince")
				repeat
					task.wait()
					sizepart(V)
					if
						game:GetService("Players").LocalPlayer.PlayerGui.TransformationHUD.ImageLabel.Visible
						and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
					then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					elseif Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(V)
				until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm
				return
			else
				spawn(function()
					if Settings["Hop Find Katakuri"] then
						SpecialHop("Cake Prince")
					end
				end)
			end
		end
		local V = DetectMob(f)
		if not V then
			if typeof(f) == "table" then
				if #N >= #f then
					N = {}
					return
				end
				local Y = DetectNameTablePart(f)
				local H = DetectPartSpawnMob(Y)
				if H then
					table.insert(N, Y)
					repeat
						task.wait()
						toTarget(H.CFrame * CFrame.new(0, 60, 0))
					until (H.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(f))
						or not Settings["Start Farm"]
						or not StackFarm
					wait(1)
				end
			else
				local Y = DetectPartSpawnMob(f, true)
				if Y then
					Instance.new("IntValue", Y).Name = "Ignored"
					repeat
						task.wait()
						toTarget(Y.CFrame * CFrame.new(0, 60, 0))
					until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(f))
						or not Settings["Start Farm"]
						or not StackFarm
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			end
		else
			repeat
				task.wait()
				sizepart(V)
				BringMob(V)
				FarmMastery(V)
				ClickM1(V)
				if
					game:GetService("Players").LocalPlayer.PlayerGui.TransformationHUD.ImageLabel.Visible
					and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
				then
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				elseif Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, getgenv().YPosFruit, 0))
				else
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm
			if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
				getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
			end
		end
	end
end
spawn(function()
	while task.wait() do
		local f, f = pcall(function()
			if Settings["Start Farm"] and StackFarm then
				FarmMethod()
			end
		end)
		if f then
			print(f)
		end
	end
end)
]====], [====[function FarmMethod()
 if not BCFarmRunning() then return end
	local f, V, H = Settings["Select Method Farm"]
	local C, J = 9999, 2
	if f == "Farm Katakuri" then
		C, V, H = 2275, y, "CakeQuest2"
	elseif f == "Farm Bones" then
		C, V, H = 2050, e, "HauntedQuest2"
	elseif f == "Farm Tyrant of the Skies" then
		C, V, H = 2575, Y, "TikiQuest3"
	else
		V = if f == "Aura Farm" and (DetectMobAura()) then { DetectMobAura() } else V
	end
	if Settings["Farm Material"] then
		local material = Settings["Select Material"]
        local worlds = NameWorldMaterials and NameWorldMaterials[material]
        V = NameMaterials and NameMaterials[material]
        if type(worlds) ~= "table" or not V then
         BCQuestStatus("Select a valid material before farming") return
        end
		if not NameWorldMaterials[Settings["Select Material"]][game.PlaceId] then
			f = NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId2]
				or NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId3]
				or NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId]
			if f then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(f) end
			return
		end
	end
 local questVisible = BCQuestVisible() or DontQuest()
 local activeMob = GetNameDoubleQuest()
 getgenv().__BC_QUEST_MOB = nil
 f = V or activeMob or ""
 if questVisible and type(V) == "table" and activeMob and table.find(V, activeMob) then
  f = activeMob
 end
 if questVisible and f == "" then
  BCQuestStatus("Quest visible but Task data is missing; waiting for GuideModule")
  return
 end
 if not questVisible and typeof(f) == "string" then
		TakeQuestLevel()
	else
		if
			Settings["Auto Quest [Katakuri/Bone/Tyrant]"]
			and t.Data.Level.Value >= C
			and not questVisible
		then
			QuestBoneAndkatakuri(H, J)
			return
		end
		if not Settings["Farm Material"] and Settings["Select Method Farm"] == "Farm Tyrant of the Skies" then
			if CheckNameBoss("Tyrant of the Skies") then
				V = CheckNameBoss("Tyrant of the Skies")
				repeat
					task.wait()
					if not BCFarmRunning() or not IsMobAlive(V) then return end
					sizepart(V)
					if
						BCTransformed()
						and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
					then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					elseif Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(V)
				until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm or Settings["Auto Trial"]
				return
			else
				local V = workspace:FindFirstChild("Map", true)
					and (workspace.Map:FindFirstChild("TikiOutpost", true))
					and (workspace.Map.TikiOutpost:FindFirstChild("IslandModel", true))
				if V then
					local Y, H, C, J =
						V:FindFirstChild("Eye1", true),
						V:FindFirstChild("Eye2", true),
						V:FindFirstChild("Eye3", true),
						V:FindFirstChild("Eye4", true)
					if
						Y
						and H
						and C
						and J
						and Y.Transparency == 0
						and H.Transparency == 0
						and C.Transparency == 0
						and J.Transparency == 0
					then
						local V = DetectModelDestroyTyrant()
						if V then
							if t:DistanceFromCharacter(V.WorldPivot.Position) > 10 then
								toTarget(V.WorldPivot)
							elseif CheckItemInventory("Skull Guitar") then
								if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Skull Guitar" then
									game:GetService("ReplicatedStorage").Remotes.CommF_
										:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Skull Guitar" }))
								else
									equiptool(NameWeapon("Gun"))
									getgenv().SpamGunSkullGuitar(V.WorldPivot)
								end
							else
								getgenv().AimPos = V.WorldPivot
								AutoAllSkill()
							end
						end
						return
					end
				end
			end
		end
		if
			not Settings["Farm Material"]
			and Settings["Select Method Farm"] == "Farm Katakuri"
			and not Settings["Ignore Attack Katakuri"]
		then
			if CheckNameBoss("Cake Prince") then
				local V = CheckNameBoss("Cake Prince")
				repeat
					task.wait()
					if not BCFarmRunning() or not IsMobAlive(V) then return end
					sizepart(V)
					if
						BCTransformed()
						and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
					then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					elseif Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(V)
				until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm or Settings["Auto Trial"]
				return
			else
				spawn(function()
					if Settings["Hop Find Katakuri"] then
						SpecialHop("Cake Prince")
					end
				end)
			end
		end
		local V = DetectMob(f)
		if not V then
			if typeof(f) == "table" then
				if #N >= #f then
					N = {}
					return
				end
				local Y = DetectNameTablePart(f)
				local H = Y and DetectPartSpawnMob(Y)
				if H and Y then
					table.insert(N, Y)
					repeat
						task.wait()
						if not BCFarmRunning() or not H.Parent then return end
						toTarget(H.CFrame * CFrame.new(0, 60, 0))
					until (H.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(f))
						or not Settings["Start Farm"]
						or not StackFarm or Settings["Auto Trial"]
					wait(1)
				end
			else
				local Y = DetectPartSpawnMob(f, true)
				if Y then
					Instance.new("IntValue", Y).Name = "Ignored"
					repeat
						task.wait()
						if not BCFarmRunning() or not Y.Parent then return end
						toTarget(Y.CFrame * CFrame.new(0, 60, 0))
					until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(f))
						or not Settings["Start Farm"]
						or not StackFarm or Settings["Auto Trial"]
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			end
		else
			repeat
				task.wait()
				if not BCFarmRunning() or not IsMobAlive(V) then return end
				sizepart(V)
				BringMob(V)
				FarmMastery(V)
				ClickM1(V)
				if
					BCTransformed()
					and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
				then
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				elseif Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, getgenv().YPosFruit, 0))
				else
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm or Settings["Auto Trial"]
			if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
				getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
			end
		end
	end
end
spawn(function()
	while task.wait() do
		local ok, err = pcall(function()
			if Settings["Start Farm"] and StackFarm then
				FarmMethod()
			end
		end)
		if not ok then
            BCQuestStatus("Farm error: " .. tostring(err))
		end
	end
end)
]====])
for _, name in ipairs({"Quest state helpers","Quest point initialization","Quest selection","Quest acceptance","Special quest throttle","Trial entry and lifecycle","Farm state and movement ownership"}) do
 if counts[name] ~= 1 then
  stop("Source version mismatch for " .. name .. "; expected one match")
  return
 end
end

if replaceLiteral("Draco worker lifecycle", [====[function CheckRelicChuaDat(b)]====], [====[-- v1.3: cancellable workers for the two Draco toggles.
local BCWorkers = {}
function BCStopMotion()
 if type(BCDracoCleanup)=="function" then pcall(BCDracoCleanup) end
 local manager = getgenv().TweenManager
 if manager and type(manager.CancelCurrent)=="function" then pcall(manager.CancelCurrent) end
end
function BCSetDracoWorker(key, enabled, step)
 local previous = BCWorkers[key]
 BCWorkers[key] = nil
 if previous and previous ~= coroutine.running() then pcall(task.cancel, previous) end
 if key=="Fully Trial Draco" then
  local env=getgenv()
  if enabled and not env.__BC_DRACO_AUX then
   env.__BC_DRACO_AUX={v4=Settings["Auto Turn On V4"]==true,gear=Settings["Auto Choose Gears"]==true}
  elseif not enabled and env.__BC_DRACO_AUX then
   local saved=env.__BC_DRACO_AUX
   env.__BC_DRACO_AUX=nil
   if env.__BC_DRACO_RESTORE_V4 then env.__BC_DRACO_RESTORE_V4(saved.v4) end
   local gear=env.ToggleAutoChooseGears
   if gear and type(gear.SetStage)=="function" then gear:SetStage(saved.gear) end
  end
 end
 SaveSettings(key, enabled == true)
 BCStopMotion()
 if not enabled then return end
 local other=key=="Fully Trial Draco" and "Auto Trial Draco" or "Fully Trial Draco"
 if Settings[other] then
  BCSetDracoWorker(other,false)
  if other=="Auto Trial Draco" and ToggleAutoTrialDraco then ToggleAutoTrialDraco:SetStage(false) end
  if other=="Fully Trial Draco" and getgenv().__BC_FULLY_DRACO_TOGGLE then getgenv().__BC_FULLY_DRACO_TOGGLE:SetStage(false) end
 end
 if key=="Fully Trial Draco" and type(BCDracoReset)=="function" then BCDracoReset() end
 BCWorkers[key] = task.defer(function()
  local self = coroutine.running()
  while BCWorkers[key]==self and Settings[key] do
   local ok, err = pcall(step)
   if not ok then
    BCTrialMessage(key .. ": " .. tostring(err))
    local label=getgenv().__BC_DRACO_PIPELINE_LABEL
    if label and type(label.SetText)=="function" then pcall(label.SetText,"Fully Draco ERROR: "..tostring(err)) end
   end
   task.wait(0.15)
  end
  if BCWorkers[key]==self then BCWorkers[key]=nil end
 end)
end
function BCDracoTimer()
 for _, main in ipairs({"Main", "Main (minimal)"}) do
  local timer=BCPath(t,"PlayerGui",main,"TopHUDList","RaidTimer")
  if timer and timer:IsA("GuiObject") and timer.Visible then return true end
 end
 return false
end
function BCDracoStep()
 if not BCLivingRoot() then return end
 if not BCTrialLocation("Trial of Flames",3000) then
  local portal=BCPath(workspace,"Map","PrehistoricIsland","TrialTeleport")
  if portal and portal:IsA("BasePart") then toTarget(portal.CFrame)
  else BCTrialMessage("Draco: waiting for Prehistoric Island / TrialTeleport") end
  return
 end
 local door=BCPath(workspace,"Map","DracoTrial","TrialDoor","DoorTouch")
 if door and door:IsA("BasePart") and door:FindFirstChild("TouchInterest") then
  toTarget(door.CFrame)
  return
 end
 if not BCDracoTimer() then
  local remote=BCPath(game:GetService("ReplicatedStorage"),"Remotes","DracoTrial")
  if remote and remote:IsA("RemoteFunction") then
   local env=getgenv()
   if os.clock()-(env.__BC_DRACO_START or -10)>3 then
    env.__BC_DRACO_START=os.clock()
    remote:InvokeServer()
   end
  else BCTrialMessage("Draco: waiting for trial remote") end
  return
 end
 local objects=CheckModelTrialDraco()
 local carrying, carryKey=GetRelicChuanbiDat(objects)
 local relic, relicKey=GetRelicChuaDat(objects)
 local key=carrying and carryKey or relicKey
 if not key then BCTrialMessage("Draco: waiting for relics") return end
 local index=key:match("^RelicModel(%d+)$")
 local target=index and objects[(carrying and "EndRelic" or "Relic")..index]
 if not target or not (target:IsA("Model") or target:IsA("BasePart")) then return end
 local prompt=target:FindFirstChildWhichIsA("ProximityPrompt",true)
 local pivot=target:GetPivot()
 if t:DistanceFromCharacter(pivot.Position)>8 then toTarget(pivot,true) return end
 if not prompt or not prompt.Enabled then return end
 if type(fireproximityprompt)~="function" then
  BCTrialMessage("Draco: fireproximityprompt unavailable; interact manually") return
 end
 local env=getgenv()
 if os.clock()-(env.__BC_DRACO_PROMPT or -10)>2 then
  env.__BC_DRACO_PROMPT=os.clock()
  fireproximityprompt(prompt)
 end
end

function CheckRelicChuaDat(b)]====]) ~= 1 then stop("Source mismatch: Draco worker lifecycle") return end

if replaceLiteral("Draco primary part readiness", [====[and (X.PrimaryPart:FindFirstChild("AlignPosition"))]====], [====[and X.PrimaryPart and (X.PrimaryPart:FindFirstChild("AlignPosition"))]====]) ~= 1 then stop("Source mismatch: Draco primary part readiness") return end

if replaceLiteral("Draco map readiness", [====[v28 = workspace:WaitForChild("Map"):WaitForChild("DracoTrial")]====], [====[local v28 = BCPath(workspace,"Map","DracoTrial")
 if not v28 or not workspace:FindFirstChild("_WorldOrigin") then return b end]====]) ~= 1 then stop("Source mismatch: Draco map readiness") return end

if replaceLiteral("Draco mesh readiness", [====[			s = l:FindFirstChildWhichIsA("MeshPart")
			if s.Color]====], [====[			s = l:FindFirstChildWhichIsA("MeshPart")
			if s and s.Color]====]) ~= 1 then stop("Source mismatch: Draco mesh readiness") return end

if replaceLiteral("Draco mesh 232-106-110", [====[if s.Color == Color3.fromRGB(232, 106, 110) then]====], [====[if s and s.Color == Color3.fromRGB(232, 106, 110) then]====]) ~= 1 then stop("Source mismatch: Draco mesh 232-106-110") return end

if replaceLiteral("Draco mesh 191-153-0", [====[if s.Color == Color3.fromRGB(191, 153, 0) then]====], [====[if s and s.Color == Color3.fromRGB(191, 153, 0) then]====]) ~= 1 then stop("Source mismatch: Draco mesh 191-153-0") return end

if replaceLiteral("Auto Draco toggle", [====[	function(b)
		if b then
			spawn(function()
				while Settings["Auto Trial Draco"] and (task.wait(0.1)) do
					local s, s = pcall(function()
						if
							t:DistanceFromCharacter(workspace._WorldOrigin.Locations["Trial of Flames"].Position)
							<= 3000
						then
							if workspace.Map.DracoTrial.TrialDoor.DoorTouch:FindFirstChild("TouchInterest") then
								getgenv().DoneTrialDraco = true
								toTarget(workspace.Map.DracoTrial.TrialDoor.DoorTouch.CFrame)
								wait(2)
								return
							end
							if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
								local X = CheckModelTrialDraco()
								local g, R = GetRelicChuaDat(X)
								local l, S = GetRelicChuanbiDat(X)
								if l then
									local l = X["EndRelic" .. S:split("RelicModel")[2]]
									local S = l:FindFirstChildWhichIsA("ProximityPrompt", true)
									if t:DistanceFromCharacter(l.WorldPivot.Position) > 8 then
										toTarget(l.WorldPivot)
									else
										wait(2)
										fireproximityprompt(S)
										wait(2)
									end
								elseif g then
									local g = X["Relic" .. R:split("RelicModel")[2]]
									local X = g:FindFirstChildWhichIsA("ProximityPrompt", true)
									if t:DistanceFromCharacter(g.WorldPivot.Position) > 8 then
										toTarget(g.WorldPivot)
									else
										wait(2)
										fireproximityprompt(X)
										wait(2)
									end
								end
							else
								game.ReplicatedStorage.Remotes.DracoTrial:InvokeServer()
								wait(3)
							end
						else
							if getgenv().DoneTrialDraco then
								A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done Trial", ShowTime = 5 })
								getgenv().DoneTrialDraco = false
								ToggleAutoTrialDraco:SetStage(false)
								return
							end
							if game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland") then
								if workspace.Map.PrehistoricIsland:FindFirstChild("TrialTeleport") then
									toTarget(workspace.Map.PrehistoricIsland.TrialTeleport.CFrame)
								else
									local X = DetectNpc("Fossil Expert")
									if X then
										toTarget(X.HumanoidRootPart.CFrame)
										return
									end
								end
							else
								A.CreateNoti({
									Title = "Banana Cat Hub",
									Desc = "Not have Prehistoric Island",
									ShowTime = 5,
								})
								wait(5)
							end
						end
					end)
					if s then
						print(s)
					end
				end
			end)
		end
		SaveSettings("Auto Trial Draco", b)
	end]====], [====[	function(b)
  BCSetDracoWorker("Auto Trial Draco", b, BCDracoStep)
 end]====]) ~= 1 then stop("Source mismatch: Auto Draco toggle") return end

if replaceLiteral("Fully Draco toggle", [====[	function(g)
		if g then
			spawn(function()
				while Settings["Fully Trial Draco"] and (task.wait(0.1)) do
					local R, R = pcall(function()
						FullyDraco()
					end)
					if R then
						print(R)
					end
				end
			end)
		end
		SaveSettings("Fully Trial Draco", g)
	end]====], [====[	function(g)
  BCSetDracoWorker("Fully Trial Draco", g, FullyDraco)
 end]====]) ~= 1 then stop("Source mismatch: Fully Draco toggle") return end

if replaceLiteral("Fully Draco trial stage", [====[		if t:DistanceFromCharacter(workspace._WorldOrigin.Locations["Trial of Flames"].Position) <= 3000 then
			if workspace.Map.DracoTrial.TrialDoor.DoorTouch:FindFirstChild("TouchInterest") then
				getgenv().DoneTrialDraco = true
				toTarget(workspace.Map.DracoTrial.TrialDoor.DoorTouch.CFrame)
				wait(2)
				return
			end
			if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
				local g = CheckModelTrialDraco()
				local R, m = GetRelicChuaDat(g)
				local l, S = GetRelicChuanbiDat(g)
				if l then
					local l = g["EndRelic" .. S:split("RelicModel")[2]]
					local S = l:FindFirstChildWhichIsA("ProximityPrompt", true)
					if t:DistanceFromCharacter(l.WorldPivot.Position) > 8 then
						toTarget(l.WorldPivot)
					else
						wait(2)
						fireproximityprompt(S)
						wait(2)
					end
				elseif R then
					local R = g["Relic" .. m:split("RelicModel")[2]]
					local g = R:FindFirstChildWhichIsA("ProximityPrompt", true)
					if t:DistanceFromCharacter(R.WorldPivot.Position) > 8 then
						toTarget(R.WorldPivot)
					else
						wait(2)
						fireproximityprompt(g)
						wait(2)
					end
				end
			else
				game.ReplicatedStorage.Remotes.DracoTrial:InvokeServer()
				wait(3)
			end]====], [====[  if BCTrialLocation("Trial of Flames",3000) then
   BCDracoStep()]====]) ~= 1 then stop("Source mismatch: Fully Draco trial stage") return end

if replaceLiteral("Fully Draco stage readiness", [====[function FullyDraco()
	if not Settings["Auto Turn On V4"] then]====], [====[function FullyDraco()
 if not Settings["Fully Trial Draco"] or not BCLivingRoot() then return end
 getgenv().__BC_DRACO_RESTORE_V4 = function(value)
  if m and type(m.SetStage)=="function" then m:SetStage(value) end
 end
 local status = CheckAcientOneDracoStatus()
 if type(status)~="string" or status=="Draco status pending" then
  BCTrialMessage("Draco: waiting for character/NPC progress") return
 end
 if status=="You Are Done Your Race." then return end
 if not Settings["Auto Turn On V4"] and m and type(m.SetStage)=="function" then]====]) ~= 1 then stop("Source mismatch: Fully Draco stage readiness") return end

if replaceLiteral("Draco NPC readiness", [====[function CheckAcientOneDracoStatus()
	if not game.Players.LocalPlayer.Character:FindFirstChild("RaceTransformed") then]====], [====[function CheckAcientOneDracoStatus()
 local char=game.Players.LocalPlayer.Character
 if not char then return "Draco status pending" end
 if not char:FindFirstChild("RaceTransformed") then]====]) ~= 1 then stop("Source mismatch: Draco NPC readiness") return end

if replaceLiteral("Draco NPC remote readiness", [====[local K = game.workspace.HydraIslandClient.RemoteFunction:InvokeServer("Interacted")]====], [====[local npc=workspace:FindFirstChild("HydraIslandClient")
   local remote=npc and npc:FindFirstChild("RemoteFunction")
   if not remote then return "Draco status pending" end
   local K = remote:InvokeServer("Interacted")]====]) ~= 1 then stop("Source mismatch: Draco NPC remote readiness") return end

if replaceLiteral("Farm toggle motion cleanup", [====[SaveSettings("Start Farm", V)
	end]====], [====[SaveSettings("Start Farm", V)
  if not V then
   local manager=getgenv().TweenManager
   if manager then manager.CancelCurrent() end
  end
 end]====]) ~= 1 then stop("Source mismatch: Farm toggle motion cleanup") return end

if replaceLiteral("Retain Fully Draco toggle", [====[RaceDracoSection.CreateToggle(
	{
		Title = "Fully Trial Draco",]====], [====[getgenv().__BC_FULLY_DRACO_TOGGLE = RaceDracoSection.CreateToggle(
	{
		Title = "Fully Trial Draco",]====]) ~= 1 then stop("Source mismatch: Fully Draco toggle handle") return end
if replaceLiteral("Draco inventory snapshot", [====[getgenv().CheckCountItem = function(f, V)
	local Y, H, C = next, B()
	for J, J in Y, H, C do
		if J.Name == f and J.Count and J.Count >= V then
			return true
		end
	end
	return false
end]====], [====[getgenv().CheckCountItem = function(f, V)
	local Y, H, C = next, B()
	for J, J in Y, H, C do
		if J.Name == f and J.Count and J.Count >= V then
			return true
		end
	end
	return false
end
function BCDracoReadInventory()
 local items=B()
 if type(items)~="table" then error("ItemReplicationService not ready") end
 local counts={}
 for _, item in pairs(items) do
  if type(item)=="table" and type(item.Name)=="string" then
   counts[item.Name]=(counts[item.Name] or 0)+(tonumber(item.Count) or 1)
  end
 end
 return counts
end
]====]) ~= 1 then stop("Source mismatch: Draco inventory snapshot") return end
if replaceLiteral("Fully Draco staged workflow", [====[getgenv().__BC_FULLY_DRACO_TOGGLE = RaceDracoSection.CreateToggle(
	{
		Title = "Fully Trial Draco",]====], [====[-- v1.4: staged Draco preparation and trial. Reuses only interfaces found in supplied source.
do
 local D = {state={}, boats=setmetatable({}, {__mode="k"})}
 function D.say(message)
  getgenv().__BC_DRACO_STAGE=message
  local label=getgenv().__BC_DRACO_PIPELINE_LABEL
  if label and type(label.SetText)=="function" then pcall(label.SetText,"Fully Draco: "..message) end
  BCTrialMessage(message)
 end
 function D.due(key, seconds)
  local now=os.clock()
  if now-(D.state[key] or -math.huge)<seconds then return false end
  D.state[key]=now
  return true
 end
 function D.live()
  return Settings["Fully Trial Draco"]==true and BCLivingRoot()~=nil
 end
 function D.pivot(object)
  if object and (object:IsA("Model") or object:IsA("BasePart")) then return object:GetPivot() end
 end
 function D.timer(name)
  for _, main in ipairs({"Main","Main (minimal)"}) do
   local timer=BCPath(t,"PlayerGui",main,"TopHUDList",name)
   if timer and timer:IsA("GuiObject") and timer.Visible then return true end
  end
  return false
 end
 function D.remote(name)
  return BCPath(game:GetService("ReplicatedStorage"),"Modules","Net",name)
 end
 function D.npc(name)
  for _, parent in ipairs({workspace,game:GetService("ReplicatedStorage")}) do
   local folder=parent:FindFirstChild("NPCs")
   local npc=folder and folder:FindFirstChild(name)
   if D.pivot(npc) then return npc end
  end
  if NPCManager and type(NPCManager.getNPCsByName)=="function" then
   local ok, list=pcall(NPCManager.getNPCsByName,name)
   local item=ok and type(list)=="table" and list[1]
   local model=item and item._modelState and item._modelState._instance
   if D.pivot(model) then return model end
  end
 end
 function D.stopBoat()
  local tween=getgenv().TweenBoat
  if tween then pcall(function() tween:Cancel() end) end
  for part, collision in pairs(D.boats) do
   if part.Parent then part.CanCollide=collision end
   D.boats[part]=nil
  end
 end
 function BCDracoCleanup()
  D.stopBoat()
  if D.state.held then
   pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(false,D.state.held,false,game) end)
   D.state.held=nil
  end
  if getgenv().AimPos==D.state.aim then getgenv().AimPos=nil end
 end
 function BCDracoReset()
  BCDracoCleanup()
  D.state={}
  getgenv().DoneTrialDraco=false
  D.say("Starting: checking map and materials")
 end
 function D.aim(target, pivot)
  D.state.aim=pivot
  getgenv().AimPos=pivot
  if G then G.Hit=pivot; G.Target=target end
 end
 function D.skill(target,pivot)
  D.aim(target,pivot)
  local tool=NameWeapon(Settings["Select Weapon"] or "Melee",true) or NameWeapon("Melee",true)
  if not tool then D.say("No usable weapon equipped for skills") return end
  if not t.Character:FindFirstChild(tool.Name) then equiptool(tool.Name) return end
  if not BCPath(t,"PlayerGui","Main","Skills",tool.Name) then return end
  local skill=CheckCDSkillTransformation(tool,{Z=true,X=true,C=true,V=true})
  if skill and D.live() then
   local input=game:GetService("VirtualInputManager")
   D.state.held=skill.Name
   input:SendKeyEvent(true,skill.Name,false,game)
   task.wait(0.1)
   input:SendKeyEvent(false,skill.Name,false,game)
   D.state.held=nil
  end
 end
 function D.attack(mob,volcano)
  local root=mob and mob:FindFirstChild("HumanoidRootPart")
  if not root or not IsMobAlive(mob) or not D.live() then return end
  toTarget(root.CFrame*CFrame.new(7,20,0))
  if not D.live() or not root.Parent then return end
  if volcano then
   local weapon=NameWeapon(Settings["Select Weapon Kill Golem"] or "Melee")
   if weapon then equiptool(weapon) end
   if type(getgenv().ClickM1Volcano)=="function" then getgenv().ClickM1Volcano(mob) else ClickM1(mob) end
  else
   sizepart(mob)
   BringMob(mob)
   ClickM1(mob)
  end
 end
 function D.farm(names)
  local mob=DetectMob(names)
  if mob and IsMobAlive(mob) then D.attack(mob,false) return end
  local list=type(names)=="table" and names or {names}
  D.state.spawnIndex=D.state.spawnIndex or 1
  if D.due("spawnCycle",8) then D.state.spawnIndex=D.state.spawnIndex%#list+1 end
  local spawn=DetectPartSpawnMob(list[D.state.spawnIndex],true)
  local pivot=D.pivot(spawn)
  if pivot then toTarget(pivot*CFrame.new(0,35,0)) else DeleteIgnoredMobSpawn() end
 end
 function D.questKind(text)
  if type(text)~="string" then return nil end
  local lower=string.lower(text)
  if lower:find("hydra enforcer",1,true) then return "Hydra Enforcer" end
  if lower:find("venomous assailant",1,true) then return "Venomous Assailant" end
  if lower:find("tree",1,true) then return "trees" end
 end
 function D.embers()
  -- Do not mark a live ember Ignored: each short tick must keep following it.
  for _, object in ipairs(workspace:GetChildren()) do
   local part=object.Name=="EmberTemplate" and object:FindFirstChild("Part")
   if part and part:IsA("BasePart") and part.Position.Y > -100 then
    D.say("Collecting Blaze Ember")
    D.state.hadEmber=true
    toTarget(part.CFrame,true)
    return
   end
  end
  if D.state.hadEmber then
   D.state.hadEmber=false
   getgenv().QuestHunterDragon=nil
   D.state.questPoll=nil
  end
  local remote=D.remote("RF/DragonHunter")
  if not remote then D.say("Waiting for Dragon Hunter remote to load") return end
  local quest=getgenv().QuestHunterDragon
  if D.due("questPoll",4) then
   local reply=remote:InvokeServer({Context="Check"})
   if not D.live() then return end
   quest=type(reply)=="table" and reply.Text or nil
   getgenv().QuestHunterDragon=quest
  end
  local kind=D.questKind(quest)
  if not kind then
   local npc=D.npc("Dragon Hunter")
   local pivot=D.pivot(npc)
   if not pivot then D.say("Dragon Hunter not loaded: move near the Dojo once") return end
   if t:DistanceFromCharacter(pivot.Position)>8 then
    D.say("Moving to Dragon Hunter")
    toTarget(pivot*CFrame.new(0,0,4),true)
   elseif D.due("questRequest",4) then
    local reply=remote:InvokeServer({Context="RequestQuest"})
    if not D.live() then return end
    local text=type(reply)=="table" and reply.Text or nil
    getgenv().QuestHunterDragon=text
    D.say("Dragon Hunter: "..tostring(text or reply))
   end
   return
  end
  D.say("Blaze Ember quest: "..kind)
  if kind~="trees" then D.farm(kind) return end
  local tree=D.state.tree
  if not tree or not tree.Parent or tree:GetAttribute("AlreadyDestroyedClient") then
   tree=DetectTree(); D.state.tree=tree
  end
  local pivot=D.pivot(tree)
  if not pivot then return end
  local position=tree:FindFirstChild("Meshes/plant1_Icosphere",true) and pivot or pivot*CFrame.new(5,-20,0)
  toTarget(position,true)
  if D.live() and t:DistanceFromCharacter(position.Position)<50 then D.skill(tree,pivot) end
 end
 function D.searchIsland()
  D.say("Searching for Prehistoric Island by boat")
  local folder=workspace:FindFirstChild("Boats")
  if not folder then D.say("Waiting for Boats folder") return end
  local boat
  for _, model in ipairs(folder:GetChildren()) do
   local owner=model:FindFirstChild("Owner")
   local health=model:FindFirstChild("Humanoid")
   if model:IsA("Model") and owner and tostring(owner.Value)==t.Name and health and health.Value>0 then
    boat=model; break
   end
  end
  local seat=boat and boat:FindFirstChild("VehicleSeat")
  if not seat or t:DistanceFromCharacter(seat.Position)>4000 then
   local dock=CFrame.new(-16204.0810546875,9.0863618850708,479.2259521484375)
   if t:DistanceFromCharacter(dock.Position)>8 then toTarget(dock,true)
   elseif D.due("buyBoat",5) then CommF:InvokeServer("BuyBoat","PirateBrigade") end
   return
  end
  local human=t.Character:FindFirstChildOfClass("Humanoid")
  if not human or human.SeatPart~=seat then
   D.stopBoat()
   toTarget(seat.CFrame,true)
   return
  end
  for _, part in ipairs(boat:GetDescendants()) do
   if part:IsA("BasePart") then
    if D.boats[part]==nil then D.boats[part]=part.CanCollide end
    part.CanCollide=false
   end
  end
  -- Same sea-search direction as supplied script; advance in bounded legs.
  if not D.state.boatGoal or (seat.Position-D.state.boatGoal.Position).Magnitude<500 then
   D.state.boatGoal=CFrame.new(-118834.515625,seat.Position.Y,seat.Position.Z+12000)
  end
  manageTween(seat,D.state.boatGoal,350,"TweenBoat")
 end
 function D.prompt(object,key)
  local pivot=D.pivot(object)
  if not pivot then return end
  local prompt=object:FindFirstChildWhichIsA("ProximityPrompt",true)
  if t:DistanceFromCharacter(pivot.Position)>8 then toTarget(pivot,true) return end
  if not prompt or not prompt.Enabled then D.say("Waiting for enabled prompt: "..key) return end
  if type(fireproximityprompt)~="function" then D.say("Delta lacks fireproximityprompt; interact manually") return end
  if D.due(key,3) and D.live() then fireproximityprompt(prompt) end
 end
 function D.island(island)
  D.stopBoat()
  local core=island:FindFirstChild("Core")
  local portal=island:FindFirstChild("TrialTeleport")
  local rock=island:FindFirstChild("TrialRock",true)
  if portal and portal:IsA("BasePart") and rock and rock:IsA("BasePart") and rock.Transparency==1 then
   D.say("Island unlocked: entering Trial of Flames")
   toTarget(portal.CFrame,true)
   return
  end
  if not core then D.say("Waiting for island Core to stream in") return end
  if not D.timer("PrehistoricRaidTimer") and not D.timer("RaidTimer") then
   local activation=core:FindFirstChild("ActivationPrompt")
   if activation then
    D.say("Activating Prehistoric Island event")
    D.prompt(activation,"activateIsland")
   else
    D.say("Waiting for island event / Trial entrance conditions")
    local npc=D.npc("Fossil Expert")
    local pivot=D.pivot(npc) or D.pivot(core)
    if pivot then toTarget(pivot,true) end
   end
   return
  end
  -- Choose one combat action per tick; alternate so rocks cannot starve behind golems.
  local golem=DetectGolem()
  local rocks=core:FindFirstChild("VolcanoRocks")
  local rockTarget
  if rocks then
   for _, object in ipairs(rocks:GetChildren()) do
    local specs=BCPath(object,"VFXLayer","Specs")
    if object.Name=="Rock" and specs and specs.Enabled and D.pivot(object) then rockTarget=object; break end
   end
  end
  if rockTarget and (not golem or D.due("rockTurn",2)) then
   D.say("Island event: cooling volcanic rock")
   local pivot=D.pivot(rockTarget)
   local offset=X[math.floor(pivot.Position.Y)] or CFrame.new(0,35,0)
   toTarget(pivot*offset,true)
   if D.live() and t:DistanceFromCharacter(pivot.Position)<100 then D.skill(rockTarget,pivot) end
  elseif golem then
   D.say("Island event: defending relic from Lava Golem")
   D.attack(golem,true)
  else
   D.say("Island event: waiting for golems / volcanic rocks")
   local skull=BCPath(core,"PrehistoricRelic","Skull")
   local pivot=D.pivot(skull)
   if pivot then toTarget(pivot*CFrame.new(0,35,0)) end
  end
 end
 function BCChooseDracoStage(state)
  if not state.enabled then return "off" end
  if not state.alive then return "respawn" end
  if state.nearTrial then return "trial" end
  if state.exitedTrial then return "verify" end
  if state.island then return "island" end
  if not state.inventoryKnown then return "inventory" end
  if state.magnet then return "sail" end
  if state.scrap<10 then return "scrap" end
  if state.ember<15 then return "ember" end
  return "craft"
 end
 function FullyDraco()
  if not D.live() then return end
  local race=BCPath(t,"Data","Race")
  if not race or race.Value~="Draco" then D.say("Requires Draco race; current: "..tostring(race and race.Value)) return end
  if game.PlaceId~=getgenv().CheckPlaceId then D.say("Requires Third Sea") return end
  local near=BCTrialLocation("Trial of Flames",3000)
  local island=BCPath(workspace,"Map","PrehistoricIsland")
  -- Preparation never waits on HydraIslandClient or Ancient One status.
  if not near and not island and not D.state.trialEntered and D.due("inventoryPoll",2) then
   local ok, items=pcall(BCDracoReadInventory)
   D.state.inventory=ok and type(items)=="table" and items or nil
   if not ok then D.say("Inventory read failed: "..tostring(items)) end
  end
  local items=D.state.inventory or {}
  local stage=BCChooseDracoStage({enabled=true,alive=true,nearTrial=near,
   exitedTrial=D.state.trialEntered==true and not near,island=island~=nil,
   inventoryKnown=D.state.inventory~=nil,magnet=(items["Volcanic Magnet"] or 0)>0,
   scrap=items["Scrap Metal"] or 0,ember=items["Blaze Ember"] or 0})
  if stage=="trial" then
   D.state.trialEntered=true
   D.say("Trial of Flames: relic pickup / placement / exit")
   BCDracoStep()
  elseif stage=="verify" then
   D.say("Returned from trial: checking server progress")
   if D.due("verifyProgress",4) then
    local ok, status=pcall(CheckAcientOneDracoStatus)
    if ok and type(status)=="string" then
     if status:find("Can Buy Gear",1,true) or status=="You Are Done Your Race." or status=="Required Train More" then
      local toggle=getgenv().__BC_FULLY_DRACO_TOGGLE
      if toggle then toggle:SetStage(false) else BCSetDracoWorker("Fully Trial Draco",false) end
      D.say("Server progress after trial: "..status)
     else D.say("Trial completion not confirmed: "..status.."; toggle OFF/ON to retry") end
    end
   end
  elseif stage=="island" then D.island(island)
  elseif stage=="inventory" then D.say("Waiting for inventory data; check Delta Console")
  elseif stage=="scrap" then
   D.say("Farming Scrap Metal: "..tostring(items["Scrap Metal"] or 0).."/10")
   D.farm({"Jungle Pirate","Musketeer Pirate"})
  elseif stage=="ember" then D.embers()
  elseif stage=="craft" then
   D.say("Crafting Volcanic Magnet (10 Scrap Metal + 15 Blaze Ember)")
   local remote=D.remote("RF/Craft")
   if not remote then D.say("Waiting for crafting remote") return end
   if D.due("craft",5) then
    local result=remote:InvokeServer("Craft","Volcanic Magnet",1,{})
    if not D.live() then return end
    D.state.inventoryPoll=nil
    D.say("Craft request returned: "..tostring(result).."; checking inventory")
   end
  elseif stage=="sail" then D.searchIsland() end
 end
 getgenv().__BC_DRACO_PIPELINE_LABEL=RaceDracoSection.CreateLabel({Title="Fully Draco: OFF"})
end

getgenv().__BC_FULLY_DRACO_TOGGLE = RaceDracoSection.CreateToggle(
	{
		Title = "Fully Trial Draco",]====]) ~= 1 then stop("Source mismatch: Fully Draco staged workflow") return end
if replaceLiteral("Draco skill aim condition", [====[or Settings["Auto Quest Dragon Hunter"]\10 or Settings["Auto Quest Dojo Trainer"]]====], [====[or Settings["Auto Quest Dragon Hunter"]\10 or Settings["Fully Trial Draco"]\10 or Settings["Auto Quest Dojo Trainer"]]====]) ~= 1 then stop("Source mismatch: Draco skill aim condition") return end

-- 6. Many loops hide errors inside pcall. The scoped wrapper preserves the
--    original return values while reporting the FIRST errors in the console.
--    Limit the rate and the total count so RenderStepped does not spam Delta.
local instrument = [==[
-- BEGIN Banana Cat Hub Delta diagnostics
local Workspace = game:GetService("Workspace")
local __BC_NATIVE_PCALL = pcall
local __BC_SEEN_ERRORS = {}
local __BC_ERROR_COUNT = 0
local function pcall(...)
    local results = table.pack(__BC_NATIVE_PCALL(...))
    if results[1] == false then
        local message = tostring(results[2])
        local now = os.clock()
        local previous = __BC_SEEN_ERRORS[message]
        if __BC_ERROR_COUNT < 30 and (not previous or now - previous > 20) then
            __BC_SEEN_ERRORS[message] = now
            __BC_ERROR_COUNT = __BC_ERROR_COUNT + 1
            warn("[BananaCat Delta Fix][caught error] " .. message)
            local shared = getgenv()
            shared.__BC_DELTA_ERRORS = shared.__BC_DELTA_ERRORS or {}
            table.insert(shared.__BC_DELTA_ERRORS, message)
            if type(appendfile) == "function" then
                __BC_NATIVE_PCALL(function()
                    appendfile("Banana Cat Hub/Delta_Fix_Errors.txt", message .. "\n")
                end)
            end
        end
    end
    return table.unpack(results, 1, results.n)
end
-- END Banana Cat Hub Delta diagnostics
]==]
source = instrument .. "\n" .. source

-- Structural verification: at least these two critical areas must still be present.
if (counts["Protection directive"] or 0) == 0
    or (counts["Player hit target lookup"] or 0) == 0
    or (counts["Missing farm defaults"] or 0) ~= 1
then
    stop("Critical patch markers not found; refusing to execute a mismatched version.")
    return
end

local compiled, compiler, compileError = pcall(loadstring, source)
if not compiled then
 stop("Compiler raised an error: " .. tostring(compiler)) return
end
if not compiler then
    stop("Luau compile failed: " .. tostring(compileError))
    return
end

-- Save the COMPLETE modified (~19k lines) code to Delta's local script folder.
local folderAvailable = false
if type(isfolder) == "function" and type(makefolder) == "function" then
    local ok, message = pcall(function()
        if not isfolder(SAVE_FOLDER) then
            makefolder(SAVE_FOLDER)
        end
    end)
    folderAvailable = ok
    if not ok then
        problem("Couldn't create output directory: " .. tostring(message))
    end
end
if folderAvailable and type(writefile) == "function" then
    local saved, why = pcall(function()
        writefile(SAVE_FILE, source)
        writefile(LOG_FILE, "Banana Cat Hub Delta Fix log (2026-10-11)\n")
    end)
    if saved then
        info("The full fixed Lua source was saved to: " .. SAVE_FILE)
    else
        problem("The patched script is in memory; could not write it: " .. tostring(why))
    end
else
    problem("File APIs are not available. Running patched source from memory.")
end

if type(debug) ~= "table"
    or type(debug.getupvalues) ~= "function"
    or type(debug.getupvalue) ~= "function"
then
    problem("Some debug.getupvalue(s) APIs are missing in this Delta build. Some features may still fail.")
end

if not (workspace:FindFirstChild("Enemies") and game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")) then
    problem("Enemies/Remotes was not found at startup; the game may still be loading or may have changed.")
end

info("Launching original Banana Cat Hub with source-matched patches (live testing required).")
local success, executionError = pcall(compiler)
-- Keep session lock: spawned workers may survive both success and failure.
if not success then
    problem("Main script stopped: " .. tostring(executionError))
    problem("If the menu already appeared, rejoin before another attempt.")
    return
end

info("Loader returned. Open Delta Console and check for '[caught error]' if a feature fails.")
info("Full patched script: " .. SAVE_FILE)
