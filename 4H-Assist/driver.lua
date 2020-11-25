local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceGUI = _G.LibStub("AceGUI-3.0");

local GetNumGroupMembers = GetNumGroupMembers;
local GetRaidRosterInfo = GetRaidRosterInfo;
local IsInRaid = IsInRaid;
local UnitName = UnitName;
local GetTime = GetTime;
local GetInstanceInfo = GetInstanceInfo;
local UnitClass = UnitClass;
local GetSpellInfo = GetSpellInfo;
local table = table;
local pairs = pairs;
local ipairs = ipairs;
local next = next;
local select = select;

local activeWindow;

local assignedRoles = ABP_4H.tCopy(ABP_4H.RaidRoles);
local roleTargets = {};
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

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup, _, _, class, _, _, _, wowRole = GetRaidRosterInfo(i);
            local slot = (5 * (subgroup - 1)) + 1;
            while slots[slot] do slot = slot + 1; end
            slots[slot] = { name = name, wowRole = wowRole, class = class };
            map[name] = slot;
            count = count + 1;
        end
    else
        slots[1] = { name = player, class = select(2, UnitClass("player")) };
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i;
            table.insert(slots, { name = UnitName(unit), class = select(2, UnitClass(unit)) });
        end
        table.sort(slots, function(a, b) return a.name < b.name; end);

        for i, raider in ipairs(slots) do
            map[raider.name] = i;
            count = count + 1;
        end
    end

    return slots, map, count;
end

local function SendStateComm(active, dist, target)
    if active then
        ABP_4H:SendComm(ABP_4H.CommTypes.STATE_SYNC, {
            active = true,
            mode = mode,
            tickDuration = tickDuration,
            roles = assignedRoles,
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
    if raider.class and healers[raider.class] then return ABP_4H.Categories.healer; end
    return ABP_4H.Categories.dps;
end

local function BuildTargets(raiders)
    local currentTargets = {};
    local currentFilledTargets = {};
    local currentMismatchedTargets = {};
    for i, role in pairs(assignedRoles) do
        currentTargets[role] = (currentTargets[role] or 0) + 1;
        if raiders[i] then
            currentFilledTargets[role] = (currentFilledTargets[role] or 0) + 1;
            if ChooseCategory(raiders[i]) ~= ABP_4H.RoleCategories[role] then
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

    local targetText = function()
        local formatStr = "%d/%d";
        if current == target and empty == 0 then
            formatStr = "|cff00ff00%d/%d|r";
        elseif current ~= target then
            formatStr = "|cffff0000%d/%d|r";
        end
        return formatStr:format(current, target);
    end

    if empty == 0 and mismatched == 0 then
        return ("%s: %s"):format(ABP_4H.RoleNamesColored[role], targetText());
    elseif empty == 0 then
        return ("%s: %s |cffff0000(%d mismatched)|r"):format(ABP_4H.RoleNamesColored[role], targetText(), mismatched);
    elseif mismatched == 0 then
        return ("%s: %s |cffff0000(%d empty)|r"):format(ABP_4H.RoleNamesColored[role], targetText(), empty);
    else
        return ("%s: %s |cffff0000(%d empty, %d mismatched)|r"):format(ABP_4H.RoleNamesColored[role], targetText(), empty, mismatched);
    end
end

local function BuildDropdown(currentRole, raiders, restricted)
    local list = { [false] = "|cffff0000Unassign|r" };
    local currentTargets, currentFilledTargets = BuildTargets(raiders);

    if currentRole then
        list[currentRole] = FormatRoleText(currentRole, currentTargets, currentFilledTargets);
    end

    for role, target in pairs(roleTargets) do
        if role ~= currentRole then
            local add = true;
            if restricted then
                add = (currentTargets[role] < target);
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
    syncElt:SetText(readyCount == count and "Ready!" or "Sync");

    for i, dropdown in pairs(dropdowns) do
        local mappedIndex = dropdown:GetUserData("mappedIndex");
        local raider = raiders[mappedIndex];
        local playerText = raider
            and ("%s%s"):format(GetStatus(raider.name, map), ABP_4H:ColorizeName(raider.name))
            or "|cff808080[Empty]|r";

        local role = assignedRoles[mappedIndex];
        local roleText = role and ABP_4H.RoleNamesColored[role] or "|cffff0000[Unassigned]|r";
        if raider and role and ChooseCategory(raider) ~= ABP_4H.RoleCategories[role] then
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
end

function ABP_4H:DriverOnStateSyncAck(data, distribution, sender, version)
    if not activeWindow then return; end

    local _, map = ABP_4H:GetRaiderSlots();
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
        currentEncounter.tickDuration = 21;
        self:RefreshCurrentEncounter();
    end

    if started and mode == self.Modes.live then
        ticks = 0;
        tickDuration = 21;
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

local lastMarkTime = 0;
local markSpellIds = { [ABP_4H.Marks.bl] = true, [ABP_4H.Marks.tl] = true, [ABP_4H.Marks.br] = true, [ABP_4H.Marks.tr] = true };
local markSpellNames = {};
ABP_4H.markSpellNames = markSpellNames;
function ABP_4H:DriverOnSpellCast(spellID, spellName)
    -- self:LogDebug("%s %d", spellName, spellID);
    if not (markSpellIds[spellID] or markSpellNames[spellName]) then return; end
    local now = GetTime();
    if now - lastMarkTime < 5 then return; end
    lastMarkTime = now;

    local currentEncounter = self:GetCurrentEncounter();
    if currentEncounter and currentEncounter.started and currentEncounter.mode == self.Modes.live then
        currentEncounter.ticks = currentEncounter.ticks + 1;
        currentEncounter.tickDuration = 12;
        self:RefreshCurrentEncounter();
    end

    if started and mode == self.Modes.live then
        ticks = ticks + 1;
        tickDuration = 12;
    end
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
    bossDeaths = {};

    if timer then self:CancelTimer(timer); end

    SendStateComm(false, "BROADCAST");
end

function ABP_4H:CreateStartWindow()
    if started then
        self:Error("An encounter is in progress! Stop it before opening this window.");
        return;
    end

    -- Default to "live" for Naxx.
    local instanceId = select(8, GetInstanceInfo());
    mode = (instanceId == 533) and self.Modes.live or self.Modes.manual;

    local windowWidth = 1100;
    local window = AceGUI:Create("Window");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("4H Assist"), self:GetVersion()));
    window:SetLayout("Flow");
    window:SetWidth(windowWidth);
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
    container:SetLayout("Flow");
    window:AddChild(container);

    local raidRoles = AceGUI:Create("InlineGroup");
    raidRoles:SetTitle("Raid Roles");
    raidRoles:SetFullWidth(true);
    raidRoles:SetLayout("Table");
    raidRoles:SetUserData("table", { columns = { 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 }});
    container:AddChild(raidRoles);

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

    local function smartFunc(widget, event, value)
        local raiders = ABP_4H:GetRaiderSlots();
        local group = widget:GetUserData("group");
        local dropdowns = window:GetUserData("dropdowns");
        local unassigned = {};

        -- Pass 1: unassign roles with no raider or an unmatching category.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            local role = assignedRoles[i];
            if role then
                if not raiders[i] or ChooseCategory(raiders[i]) ~= ABP_4H.RoleCategories[role] then
                    assignedRoles[i] = false;
                    table.insert(unassigned, role);
                    window:GetUserData("slotEditTimes")[i] = GetTime();
                    window:GetUserData("readyPlayers")[i] = nil;
                    dropdowns[dropdownMapReversed[i]]:SetValue(false);
                end
            end
        end

        -- Pass 2: reallocate above roles to raiders matching the category.
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

        -- Pass 3: if any roles are left, try to reallocate to an empty slot.
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

        -- Pass 4: if any raiders don't have a role, try to assign from all available.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            if raiders[i] and not assignedRoles[i] then
                local available = BuildDropdown(false, raiders, true);
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

        -- Pass 5: if any slots don't have a role, try to assign from all available.
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            if not assignedRoles[i] then
                local available = BuildDropdown(false, raiders, true);
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

                local smart = AceGUI:Create("Button");
                smart:SetText("Smart");
                smart:SetFullWidth(true);
                smart:SetUserData("group", i);
                smart:SetCallback("OnClick", smartFunc);
                raidRoles:AddChild(smart);
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

        local smart = AceGUI:Create("Button");
        smart:SetText("Smart");
        smart:SetFullWidth(true);
        smart:SetUserData("group", i);
        smart:SetCallback("OnClick", smartFunc);
        raidRoles:AddChild(smart);
    end

    local roleStatusElts = {};
    window:SetUserData("roleStatusElts", roleStatusElts);

    local roleStatus = AceGUI:Create("InlineGroup");
    roleStatus:SetTitle("Role Status");
    roleStatus:SetFullWidth(true);
    roleStatus:SetLayout("Table");
    roleStatus:SetUserData("table", { columns = { 1.0, 1.0, 1.0, 1.0 }});
    container:AddChild(roleStatus);

    for _, role in ipairs(self.RolesSortedStatus) do
        local roleElt = AceGUI:Create("ABPN_Label");
        roleElt:SetFullWidth(true);
        roleStatus:AddChild(roleElt);
        roleStatusElts[role] = roleElt;
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
    label:SetText("|cffff0000Mismatched|r: our guess of the player's category (tank/healer/dps) doesn't match their assigned role.");
    roleStatus:AddChild(label);

    local options = AceGUI:Create("InlineGroup");
    options:SetTitle("Options");
    options:SetFullWidth(true);
    options:SetLayout("Flow");
    container:AddChild(options);

    local modeElt = AceGUI:Create("Dropdown");
    modeElt:SetLabel("Tick Mode");
    modeElt:SetList(self.ModeNames);
    modeElt:SetValue(mode);
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
    window:SetUserData("restrictedAssignments", true);
    restricted:SetCallback("OnValueChanged", function(widget, event, value)
        window:SetUserData("restrictedAssignments", value);
        Refresh();
    end);
    options:AddChild(restricted);
    self:AddWidgetTooltip(restricted, "If assignments are capped, you cannot assign a role to more slots than it was originally allocated in the base configuration.");

    local bottom = AceGUI:Create("SimpleGroup");
    bottom:SetFullWidth(true);
    bottom:SetLayout("Table");
    bottom:SetUserData("table", { columns = { 1.0, 0 }});
    container:AddChild(bottom);

    local spacer = AceGUI:Create("Label");
    bottom:AddChild(spacer);

    local sync = AceGUI:Create("Button");
    sync:SetWidth(100);
    sync:SetText("Sync");
    sync:SetCallback("OnClick", function(widget, event)
        window:SetUserData("lastSync", GetTime());
        window:SetUserData("readyPlayers", {});
        Refresh();

        SendStateComm(true, "BROADCAST");
    end);
    bottom:AddChild(sync);
    window:SetUserData("syncElt", sync);

    container:DoLayout();
    local height = container.frame:GetHeight() + 57;
    self:BeginWindowManagement(window, "driver", {
        version = 1,
        defaultWidth = windowWidth,
        minWidth = windowWidth - 200,
        maxWidth = windowWidth + 200,
        defaultHeight = height,
    });

    window.frame:Raise();
    return window;
end

function ABP_4H:ShowStartWindow()
    if activeWindow then
        activeWindow:Hide();
        return;
    end

    activeWindow = self:CreateStartWindow();
    Refresh();
end