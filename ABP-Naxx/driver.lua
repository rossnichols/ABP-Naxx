local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;
local AceGUI = _G.LibStub("AceGUI-3.0");

local GetNumGroupMembers = GetNumGroupMembers;
local GetRaidRosterInfo = GetRaidRosterInfo;
local IsInRaid = IsInRaid;
local UnitName = UnitName;
local GetTime = GetTime;
local table = table;
local pairs = pairs;
local ipairs = ipairs;
local next = next;

local activeWindow;

-- The assigned role is an index into ABP_Naxx.RaidRoles.
-- Initialize by lining the indices up - e.g., the raider
-- in slot 1 will have the role in RaidRoles[1].
local assignedRoles = {};
local unassignedRoles = {};
for i = 1, #ABP_Naxx.RaidRoles do assignedRoles[i] = i; end

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

local mode = ABP_Naxx.Modes.manual;
local tickDuration = 30;

local readyPlayers = {};
local slotEditTimes = {};
local lastSync = 0;

local function GetStatus(player, map)
    local slot = map[player];
    local slotEditTime = slotEditTimes[slot] or 0;
    if slotEditTime >= lastSync then
        return "|TInterface\\RAIDFRAME\\ReadyCheck-NotReady.blp:0|t";
    end
    if readyPlayers[slot] then return "|TInterface\\RAIDFRAME\\ReadyCheck-Ready.blp:0|t"; end
    return "|TInterface\\RAIDFRAME\\ReadyCheck-Waiting.blp:0|t";
end

function ABP_Naxx:GetRaiderSlots()
    local slots = {};
    local map = {};
    local player = UnitName("player");
    local playerSlot;
    local count = 0;

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i);
            local slot = (5 * (subgroup - 1)) + 1;
            while slots[slot] do slot = slot + 1; end
            slots[slot] = name;
            map[name] = slot;
            count = count + 1;
        end
    else
        slots[1] = player;
        for i = 1, GetNumGroupMembers() do
            slots[i + 1] = UnitName("party" .. i);
        end
        table.sort(slots);

        for i, name in ipairs(slots) do
            map[name] = i;
            count = count + 1;
        end
    end

    return slots, map, count;
end

local function Refresh()
    local window = activeWindow;
    if not window then return; end

    local dropdowns = window:GetUserData("dropdowns");
    local raiders, map, count = ABP_Naxx:GetRaiderSlots();

    window:GetUserData("tickDurationElt"):SetDisabled(mode ~= ABP_Naxx.Modes.timer);

    local syncElt = window:GetUserData("syncElt");
    local allAssigned = true;
    local readyCount = 0;
    for index, player in pairs(readyPlayers) do
        if raiders[index] ~= player then
            readyPlayers[index] = nil;
            slotEditTimes[index] = GetTime();
        else
            readyCount = readyCount + 1;
        end
    end
    syncElt:SetText(readyCount == count and "Ready!" or "Sync");
    syncElt:SetUserData("ready", readyCount == count);

    for i, dropdown in pairs(dropdowns) do
        local mappedIndex = dropdown:GetUserData("mappedIndex");
        local player = raiders[mappedIndex];
        local playerText = raiders[mappedIndex]
            and ("%s%s"):format(GetStatus(player, map), ABP_Naxx:ColorizeName(player))
            or "|cff808080[Empty]|r";
        local roleText = "|cffff0000[Unassigned]|r";
        local availableRoles = {};
        local listedRoles = {};
        local currentRole = assignedRoles[mappedIndex];
        if currentRole then
            roleText = ABP_Naxx.RoleNames[ABP_Naxx.RaidRoles[currentRole]];
            availableRoles[currentRole] = roleText;
            listedRoles[roleText] = true;
        end
        for role in pairs(unassignedRoles) do
            if role then
                local text = ABP_Naxx.RoleNames[ABP_Naxx.RaidRoles[role]];
                if not listedRoles[text] then
                    availableRoles[role] = text;
                    listedRoles[text] = true;
                end
            end
        end
        availableRoles[false] = "|cffff0000Unassign|r";
        dropdown:SetList(availableRoles);
        dropdown:SetText(("%s     %s"):format(playerText, roleText));

        if player and not currentRole then allAssigned = false; end
    end

    syncElt:SetDisabled(not allAssigned);
end

function ABP_Naxx:DriverOnStateSyncAck(data, distribution, sender, version)
    local _, map = ABP_Naxx:GetRaiderSlots();
    if data.role == self.RaidRoles[assignedRoles[map[sender]]] then
        readyPlayers[map[sender]] = sender;
    else
        slotEditTimes[map[sender]] = GetTime();
    end
    Refresh();
end

function ABP_Naxx:DriverOnGroupUpdate()
    Refresh();
end

function ABP_Naxx:CreateStartWindow()
    local windowWidth = 1000;
    local window = AceGUI:Create("Window");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("ABP Naxx Helper"), self:GetVersion()));
    window:SetLayout("Flow");
    window:SetWidth(windowWidth);
    self:OpenWindow(window);
    window:SetCallback("OnClose", function(widget)
        self:CloseWindow(widget);
        self:EndWindowManagement(widget);
        AceGUI:Release(widget);
        activeWindow = nil;
    end);

    local container = AceGUI:Create("SimpleGroup");
    container:SetFullWidth(true);
    container:SetLayout("Flow");
    window:AddChild(container);

    local raidRoles = AceGUI:Create("InlineGroup");
    raidRoles:SetTitle("Raid Roles");
    raidRoles:SetFullWidth(true);
    raidRoles:SetLayout("Table");
    raidRoles:SetUserData("table", { columns = { 1.0, 1.0, 1.0, 1.0 }});
    container:AddChild(raidRoles);

    local dropdowns = {};
    window:SetUserData("dropdowns", dropdowns);

    local function unassignFunc(widget, event, value)
        local group = widget:GetUserData("group");
        local dropdowns = window:GetUserData("dropdowns");
        for i = (group - 1) * 5 + 1, (group - 1) * 5 + 5 do
            assignedRoles[i] = false;
            unassignedRoles[i] = true;
            dropdowns[dropdownMapReversed[i]]:SetValue(false);
        end
        Refresh();
    end

    for i = 1, 4 do
        local label = AceGUI:Create("Label");
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
            end
            for i = 1, 4 do
                local label = AceGUI:Create("Label");
                label:SetText(" ");
                raidRoles:AddChild(label);
            end
            for i = 1, 4 do
                local label = AceGUI:Create("Label");
                label:SetText("Group " .. i + 4);
                raidRoles:AddChild(label);
            end
        end

        local config = AceGUI:Create("Dropdown");
        local mappedIndex = dropdownMap[i];
        config:SetUserData("mappedIndex", mappedIndex);
        config:SetValue(assignedRoles[mappedIndex]);
        config:SetFullWidth(true);
        config:SetCallback("OnValueChanged", function(widget, event, value)
            local mappedIndex = widget:GetUserData("mappedIndex");
            local oldRole = assignedRoles[mappedIndex];
            assignedRoles[mappedIndex] = value;
            unassignedRoles[value] = nil;
            if oldRole then unassignedRoles[oldRole] = true; end
            slotEditTimes[mappedIndex] = GetTime();
            readyPlayers[mappedIndex] = nil;
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
    end

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
        readyPlayers = {};
        Refresh();
    end);
    options:AddChild(modeElt);
    window:SetUserData("modeElt", modeElt);

    local tickDurationElt = AceGUI:Create("Slider");
    tickDurationElt:SetSliderValues(10, 60, 5);
    tickDurationElt:SetValue(tickDuration);
    tickDurationElt:SetLabel("Tick Duration");
    tickDurationElt:SetCallback("OnValueChanged", function(widget, event, value)
        tickDuration = value;
        readyPlayers = {};
        Refresh();
    end);
    options:AddChild(tickDurationElt);
    window:SetUserData("tickDurationElt", tickDurationElt);

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
        if widget:GetUserData("ready") then
            window:Hide();
        else
            lastSync = GetTime();
            readyPlayers = {};
            Refresh();

            self:SendComm(ABP_Naxx.CommTypes.STATE_SYNC, {
                mode = mode,
                tickDuration = tickDuration,
                roles = assignedRoles,
            }, "BROADCAST");
        end
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

function ABP_Naxx:ShowStartWindow()
    if activeWindow then
        activeWindow:Hide();
        return;
    end

    activeWindow = self:CreateStartWindow();
    Refresh();
end