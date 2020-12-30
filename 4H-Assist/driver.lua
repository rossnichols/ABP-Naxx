local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceGUI = _G.LibStub("AceGUI-3.0");

local GetNumGroupMembers = GetNumGroupMembers;
local GetRaidRosterInfo = GetRaidRosterInfo;
local IsInRaid = IsInRaid;
local UnitName = UnitName;
local GetTime = GetTime;
local GetServerTime = GetServerTime;
local UnitClass = UnitClass;
local GetSpellInfo = GetSpellInfo;
local table = table;
local pairs = pairs;
local ipairs = ipairs;
local next = next;
local select = select;
local math = math;
local mod = mod;
local type = type;

local activeWindow;

local assignedRoles;
local processedRoles;
local fakePlayers;
local roleTargets = { [ABP_4H.Roles.independent] = 0 };
for _, role in pairs(ABP_4H.RaidRoles) do
    roleTargets[role] = (roleTargets[role] or 0) + 1;
end

-- Since the dropdown elements are added row-by-row,
-- we need to map the index of the dropdown to the index
-- into the raid. For example, group 1 (indices 1-5) are
-- represented by dropdowns 1, 5, 9, 13, and 17.
local dropdownMap = {};
for i = 1, 5 do
    for j = 1, 4 do
        table.insert(dropdownMap, i + (j - 1) * 5);
    end
end
for i = 1, 5 do
    for j = 1, 4 do
        table.insert(dropdownMap, 20 + i + (j - 1) * 5);
    end
end
local dropdownMapReversed = {};
for i, mapped in pairs(dropdownMap) do dropdownMapReversed[mapped] = i; end

local mode = ABP_4H.Modes.live;
local tickDuration = 12;

local started = false;
local ticks = 0;
local timer;
local bossDeaths = {};

function ABP_4H:GetRaiderSlots()
    local slots = {};
    local map = {};
    local player = UnitName("player");
    local playerSlot;
    local count = 0;
    local groupSize = GetNumGroupMembers();

    if IsInRaid() then
        for i = 1, groupSize do
            local name, _, subgroup, _, _, class, _, _, _, wowRole = GetRaidRosterInfo(i);
            local slot = (5 * (subgroup - 1)) + 1;
            while slots[slot] do slot = slot + 1; end
            slots[slot] = { name = name, wowRole = wowRole, class = class };
            map[name] = slot;
            count = count + 1;
        end
    elseif groupSize > 0 then
        slots[1] = { name = player, class = select(2, UnitClass("player")) };
        for i = 1, groupSize - 1 do
            local unit = "party" .. i;
            table.insert(slots, { name = UnitName(unit), class = select(2, UnitClass(unit)) });
        end
        table.sort(slots, function(a, b) return a.name < b.name; end);

        for i, raider in ipairs(slots) do
            map[raider.name] = i;
            count = count + 1;
        end
    else
        if not fakePlayers then
            fakePlayers = {};
            local raidersText = ABP_4H:GetGlobal("fakeRaiders");
            for fakeRaider in raidersText:gmatch("%S+") do
                local class;
                local guildInfo = self:GetGuildInfo(fakeRaider);
                if guildInfo then
                    fakeRaider = guildInfo.player;
                    class = guildInfo[11];
                end
                table.insert(fakePlayers, { name = fakeRaider, class = class, fake = true } );
            end
        end

        slots = self.tCopy(fakePlayers);
        for i, raider in ipairs(slots) do
            map[raider.name] = i;
            count = count + 1;
        end
    end

    return slots, map, count;
end

local function SendStateComm(active, dist, target)
    if active then
        -- Every time the roles are broadcast, convert them into
        -- a map based on player names. When sending a direct comm,
        -- the last map will be sent, in case the roster has shifted.
        if dist == "BROADCAST" then
            local raiders = ABP_4H:GetRaiderSlots();
            processedRoles = {};
            local previousRoles = ABP_4H:GetPrevRoles();
            local healerSetup = ABP_4H:GetHealerSetup();
            for slot, raider in pairs(raiders) do
                local role = assignedRoles[slot];
                previousRoles[raider.name:lower()] = role;
                if ABP_4H.RoleCategories[role] == ABP_4H.Categories.healer then
                    role = ABP_4H.HealerMap[healerSetup][role];
                end
                processedRoles[raider.name] = role;
            end
        end

        ABP_4H:SendComm(ABP_4H.CommTypes.STATE_SYNC, {
            active = true,
            mode = mode,
            tickDuration = tickDuration,
            roles = processedRoles,
            started = started,
            ticks = ticks,
            bossDeaths = bossDeaths,
        }, dist, target);
    else
        ABP_4H:SendComm(ABP_4H.CommTypes.STATE_SYNC, {
            active = false,
        }, dist, target);
    end
end

local function GetStatus(player, map)
    local slot = map[player];
    local slotEditTime = activeWindow:GetUserData("slotEditTimes")[slot] or 0;
    if slotEditTime >= activeWindow:GetUserData("lastSync") then
        return "|TInterface\\RAIDFRAME\\ReadyCheck-NotReady.blp:0|t";
    end
    if activeWindow:GetUserData("readyPlayers")[slot] then return "|TInterface\\RAIDFRAME\\ReadyCheck-Ready.blp:0|t"; end
    return "|TInterface\\RAIDFRAME\\ReadyCheck-Waiting.blp:0|t";
end

local function ChooseCategory(raider)
    local healers = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true };
    if raider.wowRole == "maintank" then return ABP_4H.Categories.tank; end

    local nonHealersText = ABP_4H:Get("nonHealers");
    local nonHealers = {};
    for nonHealer in nonHealersText:gmatch("%S+") do nonHealers[nonHealer:lower()] = true; end
    if raider.class and healers[raider.class] and not nonHealers[raider.name:lower()] then return ABP_4H.Categories.healer; end

    return ABP_4H.Categories.dps;
end

local function CategoryIsMismatched(raider, role)
    return ABP_4H.RoleCategories[role] ~= ABP_4H.Categories.none and ChooseCategory(raider) ~= ABP_4H.RoleCategories[role];
end

local function BuildTargets(raiders)
    local currentTargets = {};
    local currentFilledTargets = {};
    local currentMismatchedTargets = {};
    for i, role in pairs(assignedRoles) do
        currentTargets[role] = (currentTargets[role] or 0) + 1;
        if raiders[i] then
            currentFilledTargets[role] = (currentFilledTargets[role] or 0) + 1;
            if CategoryIsMismatched(raiders[i], role) then
                currentMismatchedTargets[role] = (currentMismatchedTargets[role] or 0) + 1;
            end
        end
    end
    for role in pairs(roleTargets) do
        currentTargets[role] = currentTargets[role] or 0;
        currentFilledTargets[role] = currentFilledTargets[role] or 0;
    end

    return currentTargets, currentFilledTargets, currentMismatchedTargets;
end

local function FormatRoleText(role, currentTargets, currentFilledTargets, currentMismatchedTargets)
    local current = currentTargets[role];
    local filled = currentFilledTargets[role];
    local mismatched = currentMismatchedTargets and currentMismatchedTargets[role] or 0;
    local empty = current - filled;
    local target = roleTargets[role];

    local formatStr = "%d/%d";
    if target == 0 then
        formatStr = "%d";
    elseif current == target and empty == 0 then
        formatStr = "|cff00ff00%d/%d|r";
    elseif current ~= target then
        formatStr = "|cffff0000%d/%d|r";
    end
    local targetText = formatStr:format(current, target);

    if target == 0 or (empty == 0 and mismatched == 0) then
        return ("%s: %s"):format(ABP_4H.RoleNamesColored[role], targetText);
    elseif empty == 0 then
        return ("%s: %s |cffff0000(%d mismatched)|r"):format(ABP_4H.RoleNamesColored[role], targetText, mismatched);
    elseif mismatched == 0 then
        return ("%s: %s |cffff0000(%d empty)|r"):format(ABP_4H.RoleNamesColored[role], targetText, empty);
    else
        return ("%s: %s |cffff0000(%d empty, %d mismatched)|r"):format(ABP_4H.RoleNamesColored[role], targetText, empty, mismatched);
    end
end

local function BuildDropdown(currentRole, raiders, restricted, ignoreZeroTarget)
    local list = { [false] = "|cffff0000Unassign|r" };
    local currentTargets, currentFilledTargets = BuildTargets(raiders);

    if currentRole then
        list[currentRole] = FormatRoleText(currentRole, currentTargets, currentFilledTargets);
    end

    for role, target in pairs(roleTargets) do
        if role ~= currentRole then
            local add = true;
            if restricted then
                add = (currentTargets[role] < target or (target == 0 and not ignoreZeroTarget));
            end

            if add then
                list[role] = FormatRoleText(role, currentTargets, currentFilledTargets);
            end
        end
    end

    local sorted = {};
    for _, role in ipairs(ABP_4H.RolesSorted) do
        if list[role] then table.insert(sorted, role); end
    end
    table.insert(sorted, false);

    return list, sorted;
end

local function Refresh()
    local window = activeWindow;
    if not window then return; end

    local dropdowns = window:GetUserData("dropdowns");
    local readyPlayers = window:GetUserData("readyPlayers");
    local slotEditTimes = window:GetUserData("slotEditTimes");
    local raiders, map, count = ABP_4H:GetRaiderSlots();

    window:GetUserData("tickDurationElt"):SetDisabled(mode ~= ABP_4H.Modes.timer);

    local syncElt = window:GetUserData("syncElt");
    local allAssigned = true;
    local readyCount = 0;
    for index, player in pairs(readyPlayers) do
        if not raiders[index] or raiders[index].name ~= player then
            readyPlayers[index] = nil;
            if map[player] then
                slotEditTimes[map[player]] = GetTime();
            end
        else
            readyCount = readyCount + 1;
        end
    end

    local textColor = "ffff00";
    if readyCount == 0 then textColor = "ff0000"; end
    if readyCount == count then textColor = "00ff00"; end
    window:GetUserData("countElt"):SetText(("|cff%s%d / %d|r players have confirmed their roles."):format(textColor, readyCount, count));

    for i, dropdown in pairs(dropdowns) do
        local mappedIndex = dropdown:GetUserData("mappedIndex");
        local raider = raiders[mappedIndex];
        local playerText = raider
            and ("%s%s"):format(GetStatus(raider.name, map), ABP_4H:ColorizeName(raider.name, raider.class))
            or "|cff808080[Empty]|r";

        local role = assignedRoles[mappedIndex];
        local roleText = role and ABP_4H.RoleNamesColored[role] or "|cffff0000[Unassigned]|r";
        if raider and role and CategoryIsMismatched(raider, role) then
            roleText = ("|cffff0000%s|r"):format( ABP_4H.RoleNames[role]);
        end
        dropdown:SetList(BuildDropdown(role, raiders, window:GetUserData("restrictedAssignments")));
        dropdown:SetText(("%s     %s"):format(playerText, roleText));

        if raider and not role then allAssigned = false; end
    end

    local currentTargets, currentFilledTargets, currentMismatchedTargets = BuildTargets(raiders);
    local roleStatusElts = window:GetUserData("roleStatusElts");
    for role, elt in pairs(roleStatusElts) do
        elt:SetText(FormatRoleText(role, currentTargets, currentFilledTargets, currentMismatchedTargets));
    end

    syncElt:SetDisabled(not allAssigned);
    window:GetUserData("startElt"):SetDisabled(window:GetUserData("lastSync") == 0);
end

function ABP_4H:DriverOnStateSyncAck(data, distribution, sender, version)
    if not activeWindow then return; end

    local _, map = ABP_4H:GetRaiderSlots();
    if not map[sender] then return; end

    if data.role == assignedRoles[map[sender]] then
        activeWindow:GetUserData("readyPlayers")[map[sender]] = sender;
    else
        activeWindow:GetUserData("readyPlayers")[map[sender]] = nil;
        activeWindow:GetUserData("slotEditTimes")[map[sender]] = GetTime();
    end
    Refresh();
end

function ABP_4H:DriverOnGroupUpdate()
    Refresh();
end

function ABP_4H:DriverOnStateSyncRequest(data, distribution, sender, version)
    if not started and (not activeWindow or activeWindow:GetUserData("lastSync") == 0) then return; end

    local _, map = ABP_4H:GetRaiderSlots();
    if not assignedRoles[map[sender]] then return; end

    if activeWindow then
        activeWindow:GetUserData("readyPlayers")[map[sender]] = nil;
        activeWindow:GetUserData("slotEditTimes")[map[sender]] = activeWindow:GetUserData("lastSync") - 1;
    end

    SendStateComm(true, "WHISPER", sender);
    Refresh();
end

function ABP_4H:DriverOnLogout()
    if activeWindow then
        activeWindow:Hide();
    end

    if started then
        self:StopEncounter();
    end
end

function ABP_4H:DriverOnEncounterStart(bossId, bossName)
    -- self:LogDebug("start %d %s", bossId, bossName);
    if bossId ~= 1121 then return; end

    local currentEncounter = self:GetCurrentEncounter();
    if currentEncounter and currentEncounter.started and currentEncounter.mode == self.Modes.live then
        currentEncounter.ticks = 0;
        currentEncounter.tickDuration = 20;
        self:RefreshCurrentEncounter();
    end

    if started and mode == self.Modes.live then
        ticks = 0;
        tickDuration = 20;
    end
end

function ABP_4H:DriverOnEncounterEnd(bossId, bossName)
    -- self:LogDebug("stop %d %s", bossId, bossName);
    if bossId ~= 1121 then return; end

    local currentEncounter = self:GetCurrentEncounter();
    if currentEncounter and currentEncounter.started and currentEncounter.mode == self.Modes.live then
        currentEncounter.started = false;
        currentEncounter.ticks = 0;
        self:RefreshCurrentEncounter();
    end

    if started and mode == self.Modes.live then
        started = false;
        ticks = 0;
        bossDeaths = {};
    end
end

function ABP_4H:DriverOnLoadingScreen()
    local currentEncounter = self:GetCurrentEncounter();
    if currentEncounter and currentEncounter.started and currentEncounter.mode == self.Modes.live then
        currentEncounter.started = false;
        currentEncounter.ticks = 0;
        self:RefreshCurrentEncounter();
    end

    if started and mode == self.Modes.live then
        started = false;
        ticks = 0;
        bossDeaths = {};
    end
end

local lastMarkTime = 0;
local markSpellIds = { [ABP_4H.Marks.bl] = true, [ABP_4H.Marks.tl] = true, [ABP_4H.Marks.br] = true, [ABP_4H.Marks.tr] = true };
local markSpellNames = {};
ABP_4H.markSpellNames = markSpellNames;

local function OnNewMark(now, sendComm, newTickCount)
    local currentEncounter = ABP_4H:GetCurrentEncounter();
    if currentEncounter and currentEncounter.started and currentEncounter.mode == ABP_4H.Modes.live then
        -- Update mark count if the passed-in value doesn't match our current,
        -- or if the time difference since our last update is too high.
        -- ABP_4H:LogDebug("New mark: ticks=%d lastTime=%d newTicks=%d newTime=%d",
            -- currentEncounter.ticks, lastMarkTime, newTickCount or -1, now);
        if (newTickCount and newTickCount ~= currentEncounter.ticks) or (math.abs(now - lastMarkTime) > 5) then
            lastMarkTime = now;
            newTickCount = newTickCount or currentEncounter.ticks + 1;
            local offset = GetServerTime() - now;

            currentEncounter.ticks = newTickCount;
            currentEncounter.tickDuration = 12 - offset;
            ABP_4H:RefreshCurrentEncounter();

            if sendComm then
                ABP_4H:SendComm(ABP_4H.CommTypes.MARK_UPDATE, {
                    time = now,
                    ticks = newTickCount,
                }, "BROADCAST");
            end

            if started and mode == ABP_4H.Modes.live then
                ticks = newTickCount;
                tickDuration = 12 - offset;
            end
        end
    end
end

function ABP_4H:DriverOnSpellCast(spellID, spellName, npcID)
    -- self:LogDebug("%s %d", spellName, spellID);
    if not (markSpellIds[spellID] or markSpellNames[spellName]) then return; end
    if not self.BossMarks[npcID] then return; end

    OnNewMark(GetServerTime(), true);
end

function ABP_4H:DriverOnMarkUpdate(data, distribution, sender)
    OnNewMark(data.time, false, data.ticks);
end

function ABP_4H:InitSpells()
    markSpellNames = { ["Mark of Korth'azz"] = true, ["Mark of Blaumeux"] = true, ["Mark of Mograine"] = true, ["Mark of Zeliek"] = true, -- failsafe
                       [GetSpellInfo(ABP_4H.Marks.bl)] = true, [GetSpellInfo(ABP_4H.Marks.tl)] = true, [GetSpellInfo(ABP_4H.Marks.br)] = true, [GetSpellInfo(ABP_4H.Marks.tr)] = true };
end

function ABP_4H:DriverOnDeath(npcID, dead)
    -- self:LogDebug("%s %s.", npcID, dead and "dead" or "alive");
    if not self.BossMarks[npcID] then return; end

    local currentEncounter = self:GetCurrentEncounter();
    if currentEncounter and currentEncounter.started then
        currentEncounter.bossDeaths[self.BossMarks[npcID]] = dead or nil;
        self:RefreshCurrentEncounter();
    end

    if started then
        bossDeaths[self.BossMarks[npcID]] = dead or nil;
        if mode ~= self.Modes.live then
            SendStateComm(true, "BROADCAST");
        end
    end
end

function ABP_4H:OnTimer()
    self:AdvanceEncounter(true);
end

function ABP_4H:AdvanceEncounter(forward)
    if forward then
        if started then
            ticks = ticks + 1;
        else
            started = true;
            ticks = 0;
            if mode == self.Modes.live then
                tickDuration = 0;
            end
        end
    elseif started then
        ticks = ticks - 1;
        if ticks == -1 then
            started = false;
            ticks = 0;
        end
    end

    SendStateComm(true, "BROADCAST");

    if mode == self.Modes.timer then
        if timer then self:CancelTimer(timer); end
        timer = self:ScheduleTimer(self.OnTimer, tickDuration, self);
    end

    if activeWindow then activeWindow:Hide(); end
end

function ABP_4H:StopEncounter()
    started = false;
    ticks = 0;
    tickDuration = 12;
    bossDeaths = {};

    if timer then self:CancelTimer(timer); end

    SendStateComm(false, "BROADCAST");
end

function ABP_4H:CreateStartWindow()
    if started then
        self:Error("An encounter is in progress! Stop it before opening this window.");
        return;
    end

    fakePlayers = nil;
    assignedRoles = assignedRoles or self:LoadCurrentLayout();
    mode = self:IsInNaxx() and self.Modes.live or self.Modes.manual;

    local windowWidth = 1200;
    local window = AceGUI:Create("ABPN_Window");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("4H Assist"), self:GetVersion()));
    window:SetLayout("Flow");
    self:BeginWindowManagement(window, "driver", {
        version = 1,
        defaultWidth = windowWidth,
        minWidth = windowWidth - 100,
        maxWidth = windowWidth + 200,
        defaultHeight = 400,
    });
    self:OpenWindow(window);
    window:SetCallback("OnClose", function(widget)
        if not started then
            SendStateComm(false, "BROADCAST");
        end
        self:CloseWindow(widget);
        self:EndWindowManagement(widget);
        AceGUI:Release(widget);
        activeWindow = nil;
    end);

    window:SetUserData("lastSync", 0);
    window:SetUserData("slotEditTimes", {});
    window:SetUserData("readyPlayers", {});

    local container = AceGUI:Create("SimpleGroup");
    container:SetFullWidth(true);
    container:SetFullHeight(true);
    container:SetLayout("Flow");
    window:AddChild(container);

    local scroll = AceGUI:Create("ScrollFrame");
    scroll:SetFullWidth(true);
    scroll:SetFullHeight(true);
    scroll:SetLayout("Flow");
    container:AddChild(scroll);

    if GetNumGroupMembers() == 0 then
        local label = AceGUI:Create("ABPN_Label");
        label:SetFullWidth(true);
        label:SetText("Simulate a raid group using the \"Raiders\" edit box below. If you sync, assignments will be remembered (for the current layout) when they're actually grouped with you.");
        scroll:AddChild(label);
    end

    local raidRoles = AceGUI:Create("InlineGroup");
    raidRoles:SetTitle("Raid Roles");
    raidRoles:SetFullWidth(true);
    raidRoles:SetLayout("Table");
    raidRoles:SetUserData("table", { columns = { 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 }});
    scroll:AddChild(raidRoles);

    local dropdowns = {};
    window:SetUserData("dropdowns", dropdowns);

    local function unassignFunc(widget, event, value)
        local group = widget:GetUserData("group");
        local dropdowns = window:GetUserData("dropdowns");
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            assignedRoles[i] = false;
            window:GetUserData("slotEditTimes")[i] = GetTime();
            window:GetUserData("readyPlayers")[i] = nil;
            dropdowns[dropdownMapReversed[i]]:SetValue(false);
        end
        Refresh();
    end

    local function smartFunc(widget, event, value, skipEmptySlots)
        local raiders = ABP_4H:GetRaiderSlots();
        local group = widget:GetUserData("group");
        local dropdowns = window:GetUserData("dropdowns");
        local previousRoles = ABP_4H:GetPrevRoles();
        local unassigned = {};

        -- If the previous role for a player is present in the group or unassigned, give it to them.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            local prevRole = raiders[i] and previousRoles[raiders[i].name:lower()];
            if prevRole and assignedRoles[i] ~= prevRole then
                for j = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
                    local role = assignedRoles[j];
                    if role == prevRole then
                        assignedRoles[j] = false;
                        window:GetUserData("slotEditTimes")[j] = GetTime();
                        window:GetUserData("readyPlayers")[j] = nil;
                        dropdowns[dropdownMapReversed[j]]:SetValue(false);

                        if assignedRoles[i] then
                            table.insert(unassigned, assignedRoles[i]);
                        end
                        assignedRoles[i] = role;
                        window:GetUserData("slotEditTimes")[i] = GetTime();
                        window:GetUserData("readyPlayers")[i] = nil;
                        dropdowns[dropdownMapReversed[i]]:SetValue(role);
                        break;
                    end
                end

                if assignedRoles[i] ~= prevRole then
                    for oldI, oldRole in ipairs(unassigned) do
                        if oldRole == prevRole then
                            assignedRoles[i] = oldRole;
                            table.remove(unassigned, oldI);
                            window:GetUserData("slotEditTimes")[i] = GetTime();
                            window:GetUserData("readyPlayers")[i] = nil;
                            dropdowns[dropdownMapReversed[i]]:SetValue(oldRole);
                            break;
                        end
                    end
                end

                if assignedRoles[i] ~= prevRole then
                    local available = BuildDropdown(false, raiders, true, true);
                    for availableRole in pairs(available) do
                        if availableRole and availableRole == prevRole then
                            assignedRoles[i] = availableRole;
                            window:GetUserData("slotEditTimes")[i] = GetTime();
                            window:GetUserData("readyPlayers")[i] = nil;
                            dropdowns[dropdownMapReversed[i]]:SetValue(availableRole);
                            break;
                        end
                    end
                end
            end
        end

        -- Unassign roles with no raider or an unmatching category.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            local role = assignedRoles[i];
            if role then
                local prevRole = raiders[i] and previousRoles[raiders[i].name:lower()];
                if not raiders[i] or (role ~= prevRole and CategoryIsMismatched(raiders[i], role)) then
                    assignedRoles[i] = false;
                    table.insert(unassigned, role);
                    window:GetUserData("slotEditTimes")[i] = GetTime();
                    window:GetUserData("readyPlayers")[i] = nil;
                    dropdowns[dropdownMapReversed[i]]:SetValue(false);
                end
            end
        end

        -- Reallocate above roles to raiders matching the category.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            local role = assignedRoles[i];
            if raiders[i] and not role then
                for oldI, oldRole in ipairs(unassigned) do
                    if ChooseCategory(raiders[i]) == ABP_4H.RoleCategories[oldRole] then
                        assignedRoles[i] = oldRole;
                        table.remove(unassigned, oldI);
                        window:GetUserData("slotEditTimes")[i] = GetTime();
                        window:GetUserData("readyPlayers")[i] = nil;
                        dropdowns[dropdownMapReversed[i]]:SetValue(oldRole);
                        break;
                    end
                end
            end
        end

        if not skipEmptySlots then
            -- If any roles are left, try to reallocate to an empty slot.
            for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
                if not raiders[i] and not assignedRoles[i] then
                    local oldI, oldRole = next(unassigned);
                    if oldI then
                        assignedRoles[i] = oldRole;
                        table.remove(unassigned, oldI);
                        window:GetUserData("slotEditTimes")[i] = GetTime();
                        window:GetUserData("readyPlayers")[i] = nil;
                        dropdowns[dropdownMapReversed[i]]:SetValue(oldRole);
                    end
                end
            end
        end

        -- If any raiders don't have a role, see if their previous role is available.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            if raiders[i] and not assignedRoles[i] then
                local prevRole = previousRoles[raiders[i].name:lower()];
                if prevRole then
                    local available = BuildDropdown(false, raiders, true, true);
                    for availableRole in pairs(available) do
                        if availableRole == prevRole or prevRole == self.Roles.independent then
                            assignedRoles[i] = prevRole;
                            window:GetUserData("slotEditTimes")[i] = GetTime();
                            window:GetUserData("readyPlayers")[i] = nil;
                            dropdowns[dropdownMapReversed[i]]:SetValue(prevRole);
                            break;
                        end
                    end
                end
            end
        end

        -- If any raiders don't have a role, try to assign from available roles that defaulted to the same group.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            if raiders[i] and not assignedRoles[i] then
                local available = BuildDropdown(false, raiders, true, true);
                for availableRole in pairs(available) do
                    if availableRole and ChooseCategory(raiders[i]) == ABP_4H.RoleCategories[availableRole] then
                        local originalGroup = 0;
                        for j, role in ipairs(self.RaidRoles) do
                            if role == availableRole then
                                originalGroup = math.floor((j - 1) / 5) + 1;
                                break;
                            end
                        end
                        if originalGroup == group then
                            assignedRoles[i] = availableRole;
                            window:GetUserData("slotEditTimes")[i] = GetTime();
                            window:GetUserData("readyPlayers")[i] = nil;
                            dropdowns[dropdownMapReversed[i]]:SetValue(availableRole);
                            break;
                        end
                    end
                end
            end
        end

        -- If any raiders don't have a role, try to assign from all available.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            if raiders[i] and not assignedRoles[i] then
                local available = BuildDropdown(false, raiders, true, true);
                for availableRole in pairs(available) do
                    if availableRole and ChooseCategory(raiders[i]) == ABP_4H.RoleCategories[availableRole] then
                        assignedRoles[i] = availableRole;
                        window:GetUserData("slotEditTimes")[i] = GetTime();
                        window:GetUserData("readyPlayers")[i] = nil;
                        dropdowns[dropdownMapReversed[i]]:SetValue(availableRole);
                        break;
                    end
                end
            end
        end

        if not skipEmptySlots then
            -- If any slots don't have a role, try to assign from all available.
            for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
                if not assignedRoles[i] then
                    local available = BuildDropdown(false, raiders, true, true);
                    for availableRole in pairs(available) do
                        if availableRole then
                            assignedRoles[i] = availableRole;
                            window:GetUserData("slotEditTimes")[i] = GetTime();
                            window:GetUserData("readyPlayers")[i] = nil;
                            dropdowns[dropdownMapReversed[i]]:SetValue(availableRole);
                            break;
                        end
                    end
                end
            end
        end

        Refresh();
    end

    for i = 1, 4 do
        local label = AceGUI:Create("Label");
        label:SetUserData("cell", { colspan = 2 });
        label:SetText("Group " .. i);
        raidRoles:AddChild(label);
    end

    for i = 1, #self.RaidRoles do
        if i == 21 then
            for i = 1, 4 do
                local unassign = AceGUI:Create("Button");
                unassign:SetText("Unassign");
                unassign:SetFullWidth(true);
                unassign:SetUserData("group", i);
                unassign:SetCallback("OnClick", unassignFunc);
                raidRoles:AddChild(unassign);
                self:AddWidgetTooltip(unassign, "Unassign all roles in this group.");

                local smart = AceGUI:Create("Button");
                smart:SetText("Smart Assign");
                smart:SetFullWidth(true);
                smart:SetUserData("group", i);
                smart:SetCallback("OnClick", smartFunc);
                raidRoles:AddChild(smart);
                self:AddWidgetTooltip(smart, "Smart-assign all roles in this group, based on the player's category (tank/healer/dps). Roles currently assigned in the same group will be prioritized first, then unassigned roles.");
            end

            local label = AceGUI:Create("Label");
            label:SetUserData("cell", { colspan = 8 });
            label:SetText(" ");
            raidRoles:AddChild(label);

            for i = 1, 4 do
                local label = AceGUI:Create("Label");
                label:SetUserData("cell", { colspan = 2 });
                label:SetText("Group " .. i + 4);
                raidRoles:AddChild(label);
            end
        end

        local config = AceGUI:Create("Dropdown");
        config:SetUserData("cell", { colspan = 2 });
        local mappedIndex = dropdownMap[i];
        config:SetUserData("mappedIndex", mappedIndex);
        config:SetValue(assignedRoles[mappedIndex]);
        config:SetFullWidth(true);
        config:SetCallback("OnValueChanged", function(widget, event, value)
            local mappedIndex = widget:GetUserData("mappedIndex");
            assignedRoles[mappedIndex] = value;
            window:GetUserData("slotEditTimes")[mappedIndex] = GetTime();
            window:GetUserData("readyPlayers")[mappedIndex] = nil;
            Refresh();
        end);
        raidRoles:AddChild(config);
        table.insert(dropdowns, config);
    end

    for i = 1, 4 do
        local unassign = AceGUI:Create("Button");
        unassign:SetText("Unassign");
        unassign:SetFullWidth(true);
        unassign:SetUserData("group", i + 4);
        unassign:SetCallback("OnClick", unassignFunc);
        raidRoles:AddChild(unassign);
        self:AddWidgetTooltip(unassign, "Unassign all roles in this group.");

        local smart = AceGUI:Create("Button");
        smart:SetText("Smart Assign");
        smart:SetFullWidth(true);
        smart:SetUserData("group", i + 4);
        smart:SetCallback("OnClick", smartFunc);
        raidRoles:AddChild(smart);
        self:AddWidgetTooltip(smart, "Smart-assign all roles in this group, based on the player's category (tank/healer/dps). Roles currently assigned in the same group will be prioritized first, then unassigned roles.");
    end

    local label = AceGUI:Create("ABPN_Label");
    label:SetFullWidth(true);
    label:SetText("Smart assignment remembers past syncs on a per-layout basis. Once raiders are in the proper group, smart-assign the raid to apply it.");
    scroll:AddChild(label);

    local unassign = AceGUI:Create("Button");
    unassign:SetText("Unassign All");
    unassign:SetWidth(150);
    unassign:SetCallback("OnClick", function(widget, event, value)
        for i = 1, 8 do
            widget:SetUserData("group", i);
            unassignFunc(widget, event, value);
        end
    end);
    scroll:AddChild(unassign);
    self:AddWidgetTooltip(unassign, "Unassign all roles in the raid.");

    local smart = AceGUI:Create("Button");
    smart:SetText("Smart Assign All");
    smart:SetWidth(150);
    smart:SetCallback("OnClick", function(widget, event, value)
        -- First pass: skip filling empty slots (in case the roles are better suited to another group).
        for i = 1, 8 do
            widget:SetUserData("group", i);
            smartFunc(widget, event, value, true);
        end
        -- Second pass: normal behavior (empty slots given an available role).
        for i = 1, 8 do
            widget:SetUserData("group", i);
            smartFunc(widget, event, value, false);
        end
    end);
    scroll:AddChild(smart);
    self:AddWidgetTooltip(smart, "Smart-assign all roles in the raid, based on the player's category (tank/healer/dps). Roles currently assigned in the same group will be prioritized first, then unassigned roles.");

    local roleStatusElts = {};
    window:SetUserData("roleStatusElts", roleStatusElts);

    local roleStatus = AceGUI:Create("InlineGroup");
    roleStatus:SetTitle("Role Status");
    roleStatus:SetFullWidth(true);
    roleStatus:SetLayout("Table");
    roleStatus:SetUserData("table", { columns = { 1.0, 1.0, 1.0, 1.0 }});
    scroll:AddChild(roleStatus);

    local countElt = AceGUI:Create("ABPN_Label");
    countElt:SetFullWidth(true);
    countElt:SetHeight(20);
    countElt:SetJustifyV("TOP");
    countElt:SetUserData("cell", { colspan = 4 });
    roleStatus:AddChild(countElt);
    window:SetUserData("countElt", countElt);

    for _, role in ipairs(self.RolesSortedStatus) do
        local roleElt = AceGUI:Create("ABPN_Label");
        roleElt:SetFullWidth(true);
        roleStatus:AddChild(roleElt);
        roleStatusElts[role] = roleElt;
    end

    local remainder = mod(#self.RolesSortedStatus, 4);
    if remainder ~= 0 then
        for i = 1, 4 - remainder do
            local roleElt = AceGUI:Create("ABPN_Label");
            roleStatus:AddChild(roleElt);
        end
    end

    local label = AceGUI:Create("ABPN_Label");
    label:SetFullWidth(true);
    label:SetFont(_G.GameFontHighlightSmall);
    label:SetUserData("cell", { colspan = 4 });
    label:SetText("|cffff0000Empty|r: the raid slot has a role assigned, but there's no player in it.");
    roleStatus:AddChild(label);

    local label = AceGUI:Create("ABPN_Label");
    label:SetFullWidth(true);
    label:SetFont(_G.GameFontHighlightSmall);
    label:SetUserData("cell", { colspan = 4 });
    label:SetText("|cffff0000Mismatched|r: the player's assumed category (tank/healer/dps) doesn't match their assigned role.");
    roleStatus:AddChild(label);

    local options = AceGUI:Create("InlineGroup");
    options:SetTitle("Options");
    options:SetFullWidth(true);
    options:SetLayout("ABPN_Table");
    options:SetUserData("table", { columns = { 0, 0, 0, 0, 0 }});
    scroll:AddChild(options);

    local names = AceGUI:Create("MultiLineEditBox");
    names:SetLabel("Raiders");
    names:SetFullHeight(true);
    names:SetText(self:GetGlobal("fakeRaiders"));
    names:SetCallback("OnEnterPressed", function(widget, event, value)
        self:SetGlobal("fakeRaiders", value);
        fakePlayers = {};
        self:ShowStartWindow(true);
    end);
    names:SetUserData("cell", { rowspan = 3, paddingBottom = 3, paddingH = 2 });
    options:AddChild(names);
    self:AddWidgetTooltip(names, "List raiders that will populate the window when you're ungrouped. If you sync, assignments will be remembered (for the current layout) when they're actually grouped with you.");
    names:SetDisabled(GetNumGroupMembers() > 0);

    local nonHealers = AceGUI:Create("MultiLineEditBox");
    nonHealers:SetLabel("Non-Healer Overrides");
    nonHealers:SetFullHeight(true);
    nonHealers:SetText(self:Get("nonHealers"));
    nonHealers:SetCallback("OnEnterPressed", function(widget, event, value)
        self:Set("nonHealers", value);
        Refresh();
    end);
    nonHealers:SetUserData("cell", { rowspan = 3, paddingBottom = 3, paddingH = 2 });
    options:AddChild(nonHealers);
    self:AddWidgetTooltip(nonHealers, "List druids/priests/paladins/shaman that should not be considered as healers.");

    local modeElt = AceGUI:Create("Dropdown");
    modeElt:SetLabel("Tick Mode");
    modeElt:SetList(self.ModeNames);
    modeElt:SetValue(mode);
    modeElt:SetUserData("cell", { paddingH = 10, align = "CENTER" });
    modeElt:SetCallback("OnValueChanged", function(widget, event, value)
        mode = value;
        window:SetUserData("readyPlayers", {});
        window:SetUserData("lastSync", 0);
        Refresh();
    end);
    options:AddChild(modeElt);
    window:SetUserData("modeElt", modeElt);
    self:AddWidgetTooltip(modeElt, "The mode determines how ticks are advanced: " ..
        "live (based on fighting the bosses), manual (by you clicking a button), or " ..
        "timed (based on the adjancent slider).");

    local tickDurationElt = AceGUI:Create("Slider");
    tickDurationElt:SetSliderValues(3, 60, 3);
    tickDurationElt:SetValue(tickDuration);
    tickDurationElt:SetLabel("Tick Duration");
    tickDurationElt:SetUserData("cell", { paddingH = 10, align = "CENTER" });
    tickDurationElt:SetCallback("OnValueChanged", function(widget, event, value)
        tickDuration = value;
        window:SetUserData("readyPlayers", {});
        window:SetUserData("lastSync", 0);
        Refresh();
    end);
    options:AddChild(tickDurationElt);
    window:SetUserData("tickDurationElt", tickDurationElt);
    self:AddWidgetTooltip(tickDurationElt, "In timed mode, add a new tick this often. You can still adjust ticks manually (the timer will reset).");

    local restricted = AceGUI:Create("CheckBox");
    restricted:SetWidth(180);
    restricted:SetLabel("Capped Assignments");
    restricted:SetValue(true);
    restricted:SetUserData("cell", { paddingH = 10 });
    window:SetUserData("restrictedAssignments", true);
    restricted:SetCallback("OnValueChanged", function(widget, event, value)
        window:SetUserData("restrictedAssignments", value);
        Refresh();
    end);
    options:AddChild(restricted);
    self:AddWidgetTooltip(restricted, "If assignments are capped, you cannot assign a role to more slots than it was originally allocated in the base configuration.");

    local loadLayout = AceGUI:Create("Dropdown");
    loadLayout:SetLabel("Load Layout");
    loadLayout:SetList(self:GetLayouts());
    loadLayout:SetValue(self:GetCurrentLayout());
    loadLayout:SetUserData("cell", { paddingH = 10, align = "CENTER" });
    loadLayout:SetCallback("OnValueChanged", function(widget, event, value)
        self:Set("selectedRaidLayout", value);
        assignedRoles = self:LoadCurrentLayout();
        Refresh();
    end);
    options:AddChild(loadLayout);
    self:AddWidgetTooltip(loadLayout, "Load a saved layout of raid roles.");

    local save = AceGUI:Create("Button");
    save:SetWidth(150);
    save:SetText("Save Layout");
    save:SetUserData("cell", { paddingH = 10, paddingBottom = 5, align = "BOTTOM" });
    save:SetCallback("OnClick", function(widget, event)
        local layout = self:GetCurrentLayout();
        if type(layout) ~= "string" then layout = nil; end
        _G.StaticPopup_Show("ABP_4H_SAVE_LAYOUT", nil, nil, { initialText = layout });
    end);
    options:AddChild(save);
    self:AddWidgetTooltip(save, "Save the current layout of raid roles.");

    local delete = AceGUI:Create("Button");
    delete:SetWidth(150);
    delete:SetText("Delete Layout");
    delete:SetDisabled(self:GetCurrentLayout() == 1);
    delete:SetUserData("cell", { paddingH = 10, paddingBottom = 5, align = "BOTTOM" });
    delete:SetCallback("OnClick", function(widget, event)
        local layout = self:GetCurrentLayout();
        if layout == 2 then layout = "Legacy Saved (Per-Char)"; end
        _G.StaticPopup_Show("ABP_4H_DELETE_LAYOUT", self:ColorizeText(layout));
    end);
    options:AddChild(delete);
    self:AddWidgetTooltip(delete, "Delete the current layout.");

    local healerOpts = { healerCCW = "Counter-clockwise", healerZeliak = "Staggered Zeliak" };
    local healerOptsElt = AceGUI:Create("Dropdown");
    healerOptsElt:SetFullWidth(true);
    healerOptsElt:SetUserData("cell", { paddingH = 10 });
    healerOptsElt:SetMultiselect(true);
    healerOptsElt:SetList(healerOpts);
    healerOptsElt:SetItemValue()
    for k in pairs(healerOpts) do
        healerOptsElt:SetItemValue(k, self:Get(k));
    end
    healerOptsElt:SetLabel("Healer Opts");
    healerOptsElt:SetCallback("OnValueChanged", function(widget, event, value, checked)
        self:Set(value, checked);
        window:SetUserData("readyPlayers", {});
        window:SetUserData("lastSync", 0);
        Refresh();
    end);
    options:AddChild(healerOptsElt);
    self:AddWidgetTooltip(healerOptsElt, "|cff00ff00Counter-clockwise|r: If checked, healers will rotate counterclockwise instead of clockwise.\n\n" ..
        "|cff00ff00Staggered Zeliak|r: If checked, healer positions in Zeliak's corner will be staggered, with the healer moving each mark.");

    local bottom = AceGUI:Create("SimpleGroup");
    bottom:SetFullWidth(true);
    bottom:SetLayout("Table");
    bottom:SetUserData("table", { columns = { 1.0, 0, 0, 0 }});
    scroll:AddChild(bottom);

    local label = AceGUI:Create("ABPN_Label");
    label:SetFont(_G.GameFontHighlightSmall);
    label:SetFullWidth(true);
    label:SetUserData("cell", { colspan = 4 });
    label:SetText(("Brought to you by %s of <%s>, %s!"):format(
        self:ColorizeText("Xanido"), self:ColorizeText("Always Be Pulling"), self:ColorizeText("US-Atiesh (Alliance)")));
    bottom:AddChild(label);

    local info = AceGUI:Create("ABPN_Label");
    info:SetFont(_G.GameFontHighlightSmall);
    info:SetFullWidth(true);
    info:SetText(("%s: leave a comment on CurseForge/WoWInterface/GitHub, or reach out to %s on reddit."):format(
        self:ColorizeText("Feedback/support"), self:ColorizeText("ross456")));
    bottom:AddChild(info);

    local vc = AceGUI:Create("Button");
    vc:SetWidth(150);
    vc:SetText("Version Check");
    vc:SetCallback("OnClick", function(widget, event)
        self:PerformVersionCheck();
    end);
    bottom:AddChild(vc);
    self:AddWidgetTooltip(vc, "Perform a version check. For the addon to work, everyone must have it, and ideally be on your version (for breaking changes).");

    local sync = AceGUI:Create("Button");
    sync:SetWidth(100);
    sync:SetText("Sync");
    sync:SetCallback("OnClick", function(widget, event)
        window:SetUserData("lastSync", GetTime());
        window:SetUserData("readyPlayers", {});
        Refresh();

        SendStateComm(true, "BROADCAST");

        local raiders = ABP_4H:GetRaiderSlots();
        local i, raider = next(raiders);
        local updateFunc;
        updateFunc = function()
            if i then
                if raider.fake then
                    self:DriverOnStateSyncAck({ role = assignedRoles[i]--[[ , fake = true ]] }, "WHISPER", raider.name);
                end

                i, raider = next(raiders, i);
                self:ScheduleTimer(updateFunc, 0);
            end
        end
        self:ScheduleTimer(updateFunc, 0);
    end);
    bottom:AddChild(sync);
    window:SetUserData("syncElt", sync);
    self:AddWidgetTooltip(sync, "Broadcast the current role configuration to the raid.");

    local start = AceGUI:Create("Button");
    start:SetWidth(100);
    start:SetText("Start");
    start:SetCallback("OnClick", function(widget, event)
        self:AdvanceEncounter(true);
    end);
    bottom:AddChild(start);
    window:SetUserData("startElt", start);
    self:AddWidgetTooltip(start, "Start the encounter!");

    container:DoLayout();
    local height = math.min(_G.UIParent:GetHeight(), scroll.content:GetHeight() + 57);
    window:SetHeight(height);
    local minW = window.frame:GetMinResize();
    local maxW = window.frame:GetMaxResize();
    window.frame:SetMinResize(minW, height - 400);
    window.frame:SetMaxResize(maxW, height);

    window.frame:Raise();
    return window;
end

function ABP_4H:ShowStartWindow(reopen)
    if activeWindow then
        activeWindow:Hide();
        if not reopen then return; end
    end

    if not self:CanOpenWindow() then
        _G.StaticPopup_Show("ABP_4H_START_BLOCKED");
        return;
    end

    activeWindow = self:CreateStartWindow();
    Refresh();
end

StaticPopupDialogs["ABP_4H_START_BLOCKED"] = ABP_4H:StaticDialogTemplate(ABP_4H.StaticDialogTemplates.JUST_BUTTONS, {
    text = "Opening the raid config window is restricted to raid lead/assists when in Naxxramas!",
    button1 = "Ok",
});
StaticPopupDialogs["ABP_4H_SAVE_LAYOUT"] = ABP_4H:StaticDialogTemplate(ABP_4H.StaticDialogTemplates.EDIT_BOX, {
    text = "Enter a name for the layout:",
    button1 = "Save",
    button2 = "Cancel",
    Commit = function(text, data)
        ABP_4H:SaveLayout(text, assignedRoles);
        ABP_4H:Set("selectedRaidLayout", text);
        ABP_4H:ShowStartWindow(true);
    end,
});
StaticPopupDialogs["ABP_4H_DELETE_LAYOUT"] = ABP_4H:StaticDialogTemplate(ABP_4H.StaticDialogTemplates.JUST_BUTTONS, {
    text = "Delete the %s layout?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(text, data)
        ABP_4H:DeleteLayout(ABP_4H:GetCurrentLayout());
        assignedRoles = ABP_4H:LoadCurrentLayout();
        ABP_4H:Set("selectedRaidLayout", 1);
        ABP_4H:ShowStartWindow(true);
    end,
});
