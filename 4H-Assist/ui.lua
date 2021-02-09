local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceGUI = _G.LibStub("AceGUI-3.0");

local UnitName = UnitName;
local UnitIsUnit = UnitIsUnit;
local IsItemInRange = IsItemInRange;
local UnitIsConnected = UnitIsConnected;
local UnitIsDeadOrGhost = UnitIsDeadOrGhost;
local UnitDebuff = UnitDebuff;
local UnitExists = UnitExists;
local GetRaidTargetIndex = GetRaidTargetIndex;
local GetNumGroupMembers = GetNumGroupMembers;
local IsInRaid = IsInRaid;
local UnitGUID = UnitGUID;
local UnitIsEnemy = UnitIsEnemy;
local UnitHealth = UnitHealth;
local UnitHealthMax = UnitHealthMax;
local IsShiftKeyDown = IsShiftKeyDown;
local table = table;
local pairs = pairs;
local math = math;
local setmetatable = setmetatable;
local tostring = tostring;
local tonumber = tonumber;
local select = select;
local next = next;
local ipairs = ipairs;

local activeWindow;
local dbmPendingAlert, dbmMoveAlert, dbmTickAlert, dbmMarkAlert;
local currentEncounter;
local debuffCounts = {};
local lastAlertedPending;
local lastAlertedMove;
local lastAlertedTick;

local function GetPositions(role, tick, onlyOriginal)
    if role == ABP_4H.Roles.independent then return; end

    local rotation = ABP_4H.Rotations[role];
    local currentPos, nextPos, nextDifferentPos;
    if tick == -1 then
        tick = 0;
        currentPos = rotation[0];
        nextPos = currentPos;
    else
        tick = tick % 12;
        currentPos = rotation[tick];
        nextPos = rotation[tick + 1];
    end

    nextDifferentPos = nextPos;
    while nextDifferentPos == currentPos do
        tick = tick + 1;
        tick = tick % 12;
        nextDifferentPos = rotation[tick];
    end

    if currentEncounter and not onlyOriginal then
        for mark in pairs(currentEncounter.bossDeaths) do
            if ABP_4H.MarkPositions[mark][currentPos] then
                currentPos = ABP_4H.MapPositions.safe;
            end
            if ABP_4H.MarkPositions[mark][nextPos] then
                nextPos = ABP_4H.MapPositions.safe;
            end
            if ABP_4H.MarkPositions[mark][nextDifferentPos] then
                nextDifferentPos = ABP_4H.MapPositions.safe;
            end
        end
    end

    return currentPos, nextPos, nextDifferentPos;
end

local function GetNeighbors(window, raiders)
    local neighbors = {};
    local tick = window:GetUserData("tick");
    local myPos = GetPositions(window:GetUserData("role"), tick);

    local roles = currentEncounter.roles;
    for _, raider in pairs(raiders) do
        local player = raider.name;
        if raider.fake or (not UnitIsUnit(player, "player") and UnitIsConnected(player) and not UnitIsDeadOrGhost(player)) then
            local role = roles[player];
            local currentPos = GetPositions(role, tick);
            if currentPos == myPos then
                table.insert(neighbors, player);
            end
        end
    end

    return neighbors;
end

local function ShowingIconsForRole(role)
    if role == ABP_4H.Roles.independent or UnitIsDeadOrGhost("player") then return false; end

    return not currentEncounter or
        ABP_4H.TopRoles[role] or
        not currentEncounter.bossDeaths[ABP_4H.Marks.bl] or
        not currentEncounter.bossDeaths[ABP_4H.Marks.br];
end

local function EndEncounter()
    currentEncounter = nil;
    lastAlertedPending = nil;
    lastAlertedMove = nil;
    lastAlertedTick = nil;
    debuffCounts = {};

    if activeWindow then
        activeWindow:SetUserData("closeConfirmed", true);
        activeWindow:Hide();
    end
end

local function RefreshNeighbors(raiders, map)
    local neighborsElt = activeWindow:GetUserData("neighborsElt");
    if neighborsElt then
        local neighbors = GetNeighbors(activeWindow, raiders);
        local showingRole = ShowingIconsForRole(activeWindow:GetUserData("role"));

        if showingRole then
            neighborsElt:SetText(table.concat(neighbors, " "));
        else
            neighborsElt:SetText("");
        end
        neighborsElt:SetHeight(neighborsElt:GetStringHeight());

        local container = activeWindow:GetUserData("contentContainer");
        container:DoLayout();
        local height = container.frame:GetHeight() + 50;
        activeWindow:SetHeight(height);
        local minW = activeWindow.frame:GetMinResize();
        local maxW = activeWindow.frame:GetMaxResize();
        activeWindow.frame:SetMinResize(minW, height);
        activeWindow.frame:SetMaxResize(maxW, height);

        if showingRole then
            -- Now that the height of the window has been adjusted properly,
            -- check range to all neighbors. This is deferred until after the
            -- size has been updated since it's a more expensive operation.
            for i, neighbor in pairs(neighbors) do
                local inRange;
                if raiders[map[neighbor]].fake then
                    inRange = (math.random() < 0.95);
                else
                    inRange = IsItemInRange(21519, neighbor);
                end
                neighbors[i] = (inRange and "|cff00ff00%s|r" or "|cffff0000%s|r"):format(neighbor);
            end
            neighborsElt:SetText(table.concat(neighbors, " "));
        end
    end
end

local function MakeFakeCount(tick, role, mark)
    if role == ABP_4H.Roles.independent then return 0; end

    local count = 0;
    local oldest = tick - 7;
    local positions = ABP_4H.MarkPositions[mark];
    for checkedTick = oldest, tick - 1 do
        if checkedTick >= 0 then
            local checkedPos = GetPositions(role, checkedTick);
            if positions[checkedPos] then
                count = count + 1;
            end
        end
    end
    if count > 0 then
        local checkedTick = oldest - 1;
        while checkedTick >= 0 do
            local checkedPos = GetPositions(role, checkedTick);
            if positions[checkedPos] then
                count = count + 1;
                checkedTick = checkedTick - 1;
            else
                break;
            end
        end
    end

    return count;
end

local function GetMarkCount(unit, mark)
    local i = 1;
    local name, _, count, _, _, _, _, _, _, spellID = UnitDebuff(unit, i);
    while name do
        if spellID == mark then
            return count;
        end

        i = i + 1;
        name, _, count, _, _, _, _, _, _, spellID = UnitDebuff(unit, i);
    end

    return 0;
end


local cachedUnits = {};

local function CheckUnit(unit, bossUnits, bossTargets, searching)
    if UnitExists(unit) and UnitIsEnemy("player", unit) then
        local npcID = tonumber((select(6, ("-"):split(UnitGUID(unit)))));
        local mark = npcID and ABP_4H.BossMarks[npcID];
        if mark and searching[mark] then
            searching[mark] = nil;
            cachedUnits[unit] = true;
            bossUnits[mark] = unit;
            unit = unit .. "target";
            if UnitExists(unit) then
                bossTargets[mark] = unit;
            end
        end
    end
end

local function GetBossUnits()
    local bossUnits, bossTargets = {}, {};
    if currentEncounter.mode == ABP_4H.Modes.live then
        local searching = {
            [ABP_4H.Marks.tl] = true,
            [ABP_4H.Marks.tr] = true,
            [ABP_4H.Marks.bl] = true,
            [ABP_4H.Marks.br] = true,
        };
        for unit in pairs(cachedUnits) do
            CheckUnit(unit, bossUnits, bossTargets, searching);
        end

        local i = 1;
        while UnitExists("boss" .. i) do
            if not next(searching) then break; end
            CheckUnit("boss" .. i, bossUnits, bossTargets, searching);
            i = i + 1;
        end

        local groupSize = math.max(GetNumGroupMembers(), 1);
        for i = 1, groupSize do
            if not next(searching) then break; end
            local unit = "target";
            if IsInRaid() then
                unit = "raid" .. i .. "target";
            elseif i ~= groupSize then
                unit = "party" .. i .. "target";
            end
            CheckUnit(unit, bossUnits, bossTargets, searching);
        end
    end

    return bossUnits, bossTargets;
end

local function RefreshMarks()
    local role = activeWindow:GetUserData("role");
    local tick = activeWindow:GetUserData("tick");
    local showingRole = ShowingIconsForRole(role);

    local tomb = {
        [true] = "|TInterface\\Minimap\\POIIcons.blp:0:0:0:-8:128:128:112:128:0:16|t",
        [false] = "|TInterface\\Minimap\\POIIcons.blp:0:0:0:-8:128:128:72.5:81:0.25:4.5|t",
    };

    local markElts = activeWindow:GetUserData("markElts");
    local bossElts = activeWindow:GetUserData("bossElts");
    if markElts then
        local texts = setmetatable({
            [0] = "|cff00ff000|r",
            [1] = "|cffffff001|r",
            [2] = "|cffffff002|r",
            [3] = "|cffff00003|r",
        }, { __index = function(t, k)
            -- return tomb[ABP_4H:IsClassic()];
            return ("|cffff0000%s|r"):format(tostring(k));
        end});
        local health = setmetatable({}, { __index = function(t, k)
            if k < 21 then return ("|cffff0000%d|r"):format(k); end
            if k < 71 then return ("|cffffff00%d|r"):format(k); end
            return ("|cff00ff00%d|r"):format(k);
        end});
        if currentEncounter and currentEncounter.mode == ABP_4H.Modes.live then
            local showedMarkAlert = false;
            local bossUnits = GetBossUnits();
            for mark, unit in pairs(bossUnits) do
                bossUnits[mark] = health[math.ceil(UnitHealth(unit) * 100 / UnitHealthMax(unit))];
            end
            local updated = {};
            local i = 1;
            local name, _, count, _, _, _, _, _, _, spellID = UnitDebuff("player", i);
            while name do
                local elt = markElts[spellID];
                if elt then
                    updated[elt] = true;
                    elt:SetText(texts[count]);
                    bossElts[spellID]:SetText(bossUnits[spellID] or "");
                    if not showedMarkAlert and count >= 4 and debuffCounts[spellID] ~= count and dbmMarkAlert and ABP_4H:Get("showMarkAlert") then
                        dbmMarkAlert:Show();
                        showedMarkAlert = true;
                    end
                    if not showingRole then
                        if count == 3 and debuffCounts[spellID] ~= count and dbmMoveAlert and ABP_4H:Get("showMoveAlert") then
                            dbmMoveAlert:Show();
                        end
                        if count == 2 and debuffCounts[spellID] ~= count and dbmPendingAlert and ABP_4H:Get("showAlert") then
                            dbmPendingAlert:Show();
                        end
                    end
                    debuffCounts[spellID] = count;
                end

                i = i + 1;
                name, _, count, _, _, _, _, _, _, spellID = UnitDebuff("player", i);
            end

            for mark, elt in pairs(markElts) do
                if currentEncounter.bossDeaths[mark] then
                    elt:SetText(tomb[ABP_4H:IsClassic()]);
                    bossElts[mark]:SetText("");
                elseif not updated[elt] then
                    elt:SetText(texts[0]);
                    bossElts[mark]:SetText(bossUnits[mark] or "");
                    debuffCounts[mark] = 0;
                end
            end
        else
            for mark, elt in pairs(markElts) do
                if currentEncounter and currentEncounter.bossDeaths[mark] then
                    elt:SetText(tomb[ABP_4H:IsClassic()]);
                else
                    local count = MakeFakeCount(tick, role, mark);
                    elt:SetText(texts[count]);
                end
            end
        end
    end
end

local function RefreshTanks(raiders, map)
    local tick = activeWindow:GetUserData("tick");

    local tankElts = activeWindow:GetUserData("tankElts");
    if tankElts then
        local _, bossTargets = GetBossUnits();

        local currentTanks, upcomingTanks = {}, {};
        local markMap = {
            [ABP_4H.MapPositions.tankdpsTL] = ABP_4H.Marks.tl,
            [ABP_4H.MapPositions.tankdpsTR] = ABP_4H.Marks.tr,
            [ABP_4H.MapPositions.tankdpsBL] = ABP_4H.Marks.bl,
            [ABP_4H.MapPositions.tankdpsBR] = ABP_4H.Marks.br,
        };
        for _, raider in pairs(raiders) do
            local role = currentEncounter.roles[raider.name];
            if ABP_4H.RoleCategories[role] == ABP_4H.Categories.tank then
                local pos, _, nextDiff = GetPositions(role, currentEncounter.ticks, true);
                local alive = raider.fake or (UnitIsConnected(raider.name) and not UnitIsDeadOrGhost(raider.name));
                local playerText = alive and raider.name or ("|cffff0000%s|r"):format(raider.name);
                local icon = UnitExists(raider.name) and GetRaidTargetIndex(raider.name);
                local iconText = icon and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s.blp:0:0:0:%%s|t"):format(icon);
                local fakeCount = raider.fake or currentEncounter.mode ~= ABP_4H.Modes.live;
                if pos == ABP_4H.MapPositions.safe then
                    local count = alive and (fakeCount and MakeFakeCount(tick, role, markMap[nextDiff]) or GetMarkCount(raider.name, markMap[nextDiff]));
                    upcomingTanks[nextDiff] = { player = raider.name, text = playerText, icon = iconText, count = ("%%s[%d]%%s"):format(count) };
                else
                    local count = alive and (fakeCount and MakeFakeCount(tick, role, markMap[pos]) or GetMarkCount(raider.name, markMap[pos]));
                    currentTanks[pos] = { player = raider.name, text = playerText, icon = iconText, count = ("%%s[%d]%%s"):format(count) };
                end
            end
        end

        if currentEncounter.bossDeaths[ABP_4H.Marks.tl] then
            tankElts[ABP_4H.Marks.tl]:SetText("");
        else
            local current = currentTanks[ABP_4H.MapPositions.tankdpsTL];
            local upcoming = upcomingTanks[ABP_4H.MapPositions.tankdpsTL];

            local mark = ABP_4H.Marks.tl;
            local tank = "";
            if bossTargets[mark] and (not current or current.player ~= UnitName(bossTargets[mark])) then
                local icon = GetRaidTargetIndex(bossTargets[mark]);
                local iconText = icon and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s.blp:0:0:0:%%s|t"):format(icon);
                local count = ("%%s[%d]%%s"):format(GetMarkCount(bossTargets[mark], mark));
                tank = ("%s|cffffa500%s%s|r\n"):format(
                    iconText and iconText:format(0) or "",
                    count and count:format("", " ") or "",
                    UnitName(bossTargets[mark]));
            end

            if tankElts[ABP_4H.Marks.tl]:GetUserData("canvas") == "fill" then
                tankElts[ABP_4H.Marks.tl]:SetText(("%s%s|cff00ff00%s%s|r\n%s|cffcccccc%s%s|r"):format(
                    tank,
                    current and current.icon and current.icon:format(0) or "",
                    current and current.count and current.count:format("", " ") or "",
                    current and current.text or "",
                    upcoming and upcoming.icon and upcoming.icon:format(0) or "",
                    upcoming and upcoming.count and upcoming.count:format("", " ") or "",
                    upcoming and upcoming.text or ""));
            else
                tankElts[ABP_4H.Marks.tl]:SetText(("%s|cff00ff00%s%s|r%s\n|cffcccccc%s%s|r%s"):format(
                    tank,
                    current and current.text or "",
                    current and current.count and current.count:format(" ", "") or "",
                    current and current.icon and current.icon:format(0) or "",
                    upcoming and upcoming.text or "",
                    upcoming and upcoming.count and upcoming.count:format(" ", "") or "",
                    upcoming and upcoming.icon and upcoming.icon:format(0) or ""));
            end
        end

        if currentEncounter.bossDeaths[ABP_4H.Marks.tr] then
            tankElts[ABP_4H.Marks.tr]:SetText("");
        else
            local current = currentTanks[ABP_4H.MapPositions.tankdpsTR];
            local upcoming = upcomingTanks[ABP_4H.MapPositions.tankdpsTR];

            local mark = ABP_4H.Marks.tr;
            local tank = "";
            if bossTargets[mark] and (not current or current.player ~= UnitName(bossTargets[mark])) then
                local icon = GetRaidTargetIndex(bossTargets[mark]);
                local iconText = icon and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s.blp:0:0:0:%%s|t"):format(icon);
                local count = ("%%s[%d]%%s"):format(GetMarkCount(bossTargets[mark], mark));
                tank = ("|cffffa500%s%s|r%s\n"):format(
                    UnitName(bossTargets[mark]),
                    count and count:format(" ", "") or "",
                    iconText and iconText:format(0) or "");
            end

            if tankElts[ABP_4H.Marks.tr]:GetUserData("canvas") == "fill" then
                tankElts[ABP_4H.Marks.tr]:SetText(("%s|cff00ff00%s%s|r%s\n|cffcccccc%s%s|r%s"):format(
                    tank,
                    current and current.text or "",
                    current and current.count and current.count:format(" ", "") or "",
                    current and current.icon and current.icon:format(0) or "",
                    upcoming and upcoming.text or "",
                    upcoming and upcoming.count and upcoming.count:format(" ", "") or "",
                    upcoming and upcoming.icon and upcoming.icon:format(0) or ""));
            else
                tankElts[ABP_4H.Marks.tr]:SetText(("%s%s|cff00ff00%s%s|r\n%s|cffcccccc%s%s|r"):format(
                    tank,
                    current and current.icon and current.icon:format(0) or "",
                    current and current.count and current.count:format("", " ") or "",
                    current and current.text or "",
                    upcoming and upcoming.icon and upcoming.icon:format(0) or "",
                    upcoming and upcoming.count and upcoming.count:format("", " ") or "",
                    upcoming and upcoming.text or ""));
            end
        end

        if currentEncounter.bossDeaths[ABP_4H.Marks.bl] then
            tankElts[ABP_4H.Marks.bl]:SetText("");
        else
            local current = currentTanks[ABP_4H.MapPositions.tankdpsBL];
            local upcoming = upcomingTanks[ABP_4H.MapPositions.tankdpsBL];

            local mark = ABP_4H.Marks.bl;
            local tank = "";
            if bossTargets[mark] and (not current or current.player ~= UnitName(bossTargets[mark])) then
                local icon = GetRaidTargetIndex(bossTargets[mark]);
                local iconText = icon and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s.blp:0:0:0:%%s|t"):format(icon);
                local count = ("%%s[%d]%%s"):format(GetMarkCount(bossTargets[mark], mark));
                tank = ("\n%s|cffffa500%s%s|r"):format(
                    iconText and iconText:format(-16) or "",
                    count and count:format("", " ") or "",
                    UnitName(bossTargets[mark]));
            end

            if tankElts[ABP_4H.Marks.bl]:GetUserData("canvas") == "fill" then
                tankElts[ABP_4H.Marks.bl]:SetText(("%s|cffcccccc%s%s|r\n%s|cff00ff00%s%s|r%s"):format(
                    upcoming and upcoming.icon and upcoming.icon:format(-16) or "",
                    upcoming and upcoming.count and upcoming.count:format("", " ") or "",
                    upcoming and upcoming.text or "",
                    current and current.icon and current.icon:format(-16) or "",
                    current and current.count and current.count:format("", " ") or "",
                    current and current.text or "",
                    tank));
            else
                tankElts[ABP_4H.Marks.bl]:SetText(("|cffcccccc%s%s|r%s\n|cff00ff00%s%s|r%s%s"):format(
                    upcoming and upcoming.text or "",
                    upcoming and upcoming.count and upcoming.count:format(" ", "") or "",
                    upcoming and upcoming.icon and upcoming.icon:format(-16) or "",
                    current and current.text or "",
                    current and current.count and current.count:format(" ", "") or "",
                    current and current.icon and current.icon:format(-16) or "",
                    tank));
            end
        end

        if currentEncounter.bossDeaths[ABP_4H.Marks.br] then
            tankElts[ABP_4H.Marks.br]:SetText("");
        else
            local current = currentTanks[ABP_4H.MapPositions.tankdpsBR];
            local upcoming = upcomingTanks[ABP_4H.MapPositions.tankdpsBR];

            local mark = ABP_4H.Marks.br;
            local tank = "";
            if bossTargets[mark] and (not current or current.player ~= UnitName(bossTargets[mark])) then
                local icon = GetRaidTargetIndex(bossTargets[mark]);
                local iconText = icon and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s.blp:0:0:0:%%s|t"):format(icon);
                local count = ("%%s[%d]%%s"):format(GetMarkCount(bossTargets[mark], mark));
                tank = ("\n|cffffa500%s%s|r%s"):format(
                    UnitName(bossTargets[mark]),
                    count and count:format(" ", "") or "",
                    iconText and iconText:format(-16) or "");
            end

            if tankElts[ABP_4H.Marks.br]:GetUserData("canvas") == "fill" then
                tankElts[ABP_4H.Marks.br]:SetText(("|cffcccccc%s%s|r%s\n|cff00ff00%s%s|r%s%s"):format(
                    upcoming and upcoming.text or "",
                    upcoming and upcoming.count and upcoming.count:format(" ", "") or "",
                    upcoming and upcoming.icon and upcoming.icon:format(-16) or "",
                    current and current.text or "",
                    current and current.count and current.count:format(" ", "") or "",
                    current and current.icon and current.icon:format(-16) or "",
                    tank));
            else
                tankElts[ABP_4H.Marks.br]:SetText(("%s|cffcccccc%s%s|r\n%s|cff00ff00%s%s|r%s"):format(
                    upcoming and upcoming.icon and upcoming.icon:format(-16) or "",
                    upcoming and upcoming.count and upcoming.count:format("", " ") or "",
                    upcoming and upcoming.text or "",
                    current and current.icon and current.icon:format(-16) or "",
                    current and current.count and current.count:format("", " ") or "",
                    current and current.text or "",
                    tank));
            end
        end
    end
end

local function Refresh()
    if not activeWindow then return; end
    local current = activeWindow:GetUserData("current");
    local upcoming = activeWindow:GetUserData("upcoming");
    local image = activeWindow:GetUserData("image");
    local role = activeWindow:GetUserData("role");
    local tick = activeWindow:GetUserData("tick");

    current:SetVisible(false);
    upcoming:SetVisible(false);

    if not currentEncounter or currentEncounter.driving then
        local tickTrigger = activeWindow:GetUserData("tickTrigger");
        local reset = activeWindow:GetUserData("reset");

        if not role then
            if reset then
                reset:SetDisabled(true);
            end
            if tickTrigger then
                tickTrigger:SetDisabled(true);
                tickTrigger:SetText("Ticks");
            end
            return;
        end

        if reset then
            reset:SetDisabled(tick == -1);
        end
        if tickTrigger then
            tickTrigger:SetDisabled(false);
            tickTrigger:SetText(tick == -1 and "Start" or ("Tick (%d)"):format(tick));
        end
    end

    if ShowingIconsForRole(role) then
        local currentPos, nextPos, nextDiffPos = GetPositions(role, tick);
        local nextPosPreview = false;
        local liveWaitingForCombat = currentEncounter and currentEncounter.mode == ABP_4H.Modes.live and
            currentEncounter.ticks == 0 and currentEncounter.tickDuration == 0;
        if currentEncounter and (not currentEncounter.started or liveWaitingForCombat) then
            nextPosPreview = true;
            nextPos = nextDiffPos;
        end

        if tick >= 1 and currentEncounter and dbmMoveAlert and ABP_4H:Get("showMoveAlert") then
            local prevPos = GetPositions(role, tick - 1);
            if prevPos ~= currentPos and lastAlertedMove ~= tick then
                lastAlertedMove = tick;
                dbmMoveAlert:Show();
            end
        end

        current:SetVisible(true);
        current:SetUserData("canvas-X", currentPos[1]);
        current:SetUserData("canvas-Y", currentPos[2]);
        local size = ABP_4H.SmallPositions[currentPos] and 16 or 24;
        current:SetWidth(size);
        current:SetHeight(size);

        if nextPos ~= currentPos then
            upcoming:SetVisible(true);
            upcoming:SetUserData("canvas-X", nextPos[1]);
            upcoming:SetUserData("canvas-Y", nextPos[2]);
            local size = ABP_4H.SmallPositions[nextPos] and 16 or 24;
            upcoming:SetWidth(size);
            upcoming:SetHeight(size);

            if currentEncounter and dbmPendingAlert and ABP_4H:Get("showAlert") and lastAlertedPending ~= tick and lastAlertedMove ~= tick and not nextPosPreview then
                lastAlertedPending = tick;
                dbmPendingAlert:Show();
            end
        end
        image:DoLayout();
    end

    RefreshMarks();
    if currentEncounter then
        local raiders, map = ABP_4H:GetRaiderSlots();
        RefreshNeighbors(raiders, map);
        RefreshTanks(raiders, map);
    end
end

function ABP_4H:UIOnGroupJoined()
    self:SendComm(self.CommTypes.STATE_SYNC_REQUEST, {}, "BROADCAST");
end

function ABP_4H:UIOnGroupLeft()
    EndEncounter();
end

function ABP_4H:UIOnStateSync(data, distribution, sender, version)
    if data.active then
        local player = UnitName("player");
        local role = data.roles[player];
        if not role and GetNumGroupMembers() == 0 then
            role = self.Roles.independent;
        end

        if data.started then
            if data.mode ~= ABP_4H.Modes.live and dbmTickAlert and lastAlertedTick ~= data.ticks then
                lastAlertedTick = data.ticks;
                dbmTickAlert:Show(data.ticks);
            end
        else
            self:SendComm(self.CommTypes.STATE_SYNC_ACK, {
                role = role,
            }, "WHISPER", sender);
        end

        currentEncounter = {
            roles = data.roles,
            mode = data.mode,
            tickDuration = data.tickDuration,
            role = role,
            driving = (sender == player),
            started = data.started,
            ticks = data.ticks,
            bossDeaths = data.bossDeaths,
        };
    else
        EndEncounter();
    end

    if activeWindow then
        activeWindow:SetUserData("closeConfirmed", true);
        activeWindow:Hide();
    end

    if currentEncounter then
        self:ShowMainWindow();
    end
end

function ABP_4H:DumpRoles()
    if not currentEncounter then
        self:Notify("Try again when you've been assigned a role by someone in the raid!");
        return;
    end

    local roles = {};
    for player, role in pairs(currentEncounter.roles) do
        role = self.NormalizedHealerMap[role] or role;
        roles[role] = roles[role] or {};
        table.insert(roles[role], player);
    end

    for _, role in ipairs(self.RolesSorted) do
        if roles[role] then
            table.sort(roles[role]);
            for _, player in ipairs(roles[role]) do
                self:Notify("%s => %s", self:ColorizeName(player), self.RoleNamesColored[role]);
            end
        end
    end
end

function ABP_4H:GetCurrentEncounter()
    return currentEncounter;
end

function ABP_4H:RefreshCurrentEncounter()
    if currentEncounter and currentEncounter.started then
        self:RefreshMainWindow();
    else
        EndEncounter();
    end
end

function ABP_4H:RefreshMainWindow()
    if activeWindow then
        activeWindow:SetUserData("closeConfirmed", true);
        activeWindow:Hide();
        self:ShowMainWindow();
    end
end

function ABP_4H:OnUITimer()
    if activeWindow then
        RefreshMarks();
        if currentEncounter then
            local raiders, map = ABP_4H:GetRaiderSlots();
            RefreshNeighbors(raiders, map);
            RefreshTanks(raiders, map);
        end
    end
end

function ABP_4H:UIOnPlayerAura()
    if activeWindow and activeWindow:GetUserData("tick") then
        RefreshMarks();
        self:UIOnAura("player");
    end
end

function ABP_4H:UIOnAura(unit)
    if activeWindow and currentEncounter then
        local role = currentEncounter.roles[UnitName(unit)];
        if role and ABP_4H.RoleCategories[role] == ABP_4H.Categories.tank then
            local raiders, map = ABP_4H:GetRaiderSlots();
            RefreshTanks(raiders, map);
        end
    end
end

function ABP_4H:UIOnLogout()
    if activeWindow then
        activeWindow:SetUserData("closeConfirmed", true);
        activeWindow:Hide();
    end
end

function ABP_4H:CreateMainWindow()
    if not dbmPendingAlert and _G.DBM and _G.DBM.NewMod then
        local mod = _G.DBM:NewMod("4H Assist");
        _G.DBM:GetModLocalization("4H Assist"):SetGeneralLocalization{ name = "4H Assist" }
        dbmPendingAlert = mod:NewSpecialWarning("Move after next mark!", nil, nil, nil, 1);
        dbmMoveAlert = mod:NewSpecialWarning("Time to move!", nil, nil, nil, 1);
        dbmMarkAlert = mod:NewSpecialWarning("TOO MANY MARKS!", nil, nil, nil, 4);
        dbmTickAlert = mod:NewAnnounce("Mark %d", 1, "136172");
    end

    local windowWidth = 320;
    local window = AceGUI:Create("ABPN_TransparentWindow");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("4H Assist"), self:GetVersion()));
    window:SetLayout("Flow");
    self:BeginWindowManagement(window, "main", {
        version = 1,
        defaultWidth = windowWidth,
        minWidth = windowWidth - 200,
        maxWidth = windowWidth + 200,
        defaultHeight = 400,
    });
    window:SetCallback("OnClose", function(widget)
        if not currentEncounter or widget:GetUserData("closeConfirmed") or IsShiftKeyDown() or not self:Get("confirmClose") then
            self:EndWindowManagement(widget);
            local timer = widget:GetUserData("timer");
            if timer then self:CancelTimer(timer); end
            AceGUI:Release(widget);
            activeWindow = nil;
            _G.StaticPopup_Hide("ABP_4H_CONFIRM_CLOSE");
        else
            _G.StaticPopup_Show("ABP_4H_CONFIRM_CLOSE");
            widget:Show();
        end
    end);

    local container = AceGUI:Create("ABPN_TransparentGroup");
    container:SetFullWidth(true);
    container:SetLayout("Flow");
    window:AddChild(container);
    window:SetUserData("contentContainer", container);

    if currentEncounter then
        local role = currentEncounter.role;
        window:SetUserData("role", role);
        window:SetUserData("tick", currentEncounter.started and currentEncounter.ticks or -1);

        local mainLine = AceGUI:Create("ABPN_TransparentGroup");
        mainLine:SetFullWidth(true);
        mainLine:SetLayout("table");
        mainLine:SetUserData("table", { columns = { 1.0, 1.0 } });
        container:AddChild(mainLine);

        local roleElt = AceGUI:Create("ABPN_Label");
        roleElt:SetFullWidth(true);
        roleElt:SetText(self.RoleNamesColored[role]);
        roleElt:SetFont("GameFontHighlightOutline");
        mainLine:AddChild(roleElt);

        local tickElt = AceGUI:Create("ABPN_Label");
        tickElt:SetFullWidth(true);
        local tickText = currentEncounter.started and ("Marks: %d"):format(currentEncounter.ticks) or "Not Started";
        local liveWaitingForCombat = currentEncounter and currentEncounter.mode == ABP_4H.Modes.live and
            currentEncounter.ticks == 0 and currentEncounter.tickDuration == 0;
        if liveWaitingForCombat then
            tickText = "Waiting";
        end
        tickElt:SetText(tickText);
        tickElt:SetJustifyH("RIGHT");
        tickElt:SetFont("GameFontHighlightOutline");
        mainLine:AddChild(tickElt);

        if currentEncounter.started and currentEncounter.tickDuration > 0 and
           (currentEncounter.mode == self.Modes.timer or currentEncounter.mode == self.Modes.live) then
            local statusbar = AceGUI:Create("ABPN_StatusBar");
            statusbar:SetFullWidth(true);
            statusbar:SetHeight(5);
            statusbar:SetDuration(currentEncounter.tickDuration);
            container:AddChild(statusbar);
        end
    else
        local roleSelector = AceGUI:Create("Dropdown");
        roleSelector:SetText("Choose a Role");
        roleSelector:SetFullWidth(true);
        roleSelector:SetList(self.RoleNamesColored, self.RolesSorted);
        roleSelector:SetCallback("OnValueChanged", function(widget, event, value)
            local healerSetup = ABP_4H:GetHealerSetup();
            if self.RoleCategories[value] == self.Categories.healer then
                value = self.HealerMap[healerSetup][value];
            end
            window:SetUserData("role", value);
            window:SetUserData("tick", -1);
            Refresh();
        end);
        container:AddChild(roleSelector);
    end

    if not currentEncounter or currentEncounter.driving then
        local mainLine = AceGUI:Create("ABPN_TransparentGroup");
        mainLine:SetFullWidth(true);
        mainLine:SetLayout("table");
        mainLine:SetUserData("table", { columns = { 1.0, 1.0 } });
        container:AddChild(mainLine);

        if not currentEncounter or (currentEncounter.started and currentEncounter.mode ~= ABP_4H.Modes.live) then
            local tickTrigger = AceGUI:Create("ABPN_Button");
            tickTrigger:SetFullWidth(true);
            tickTrigger:SetCallback("OnClick", function(widget, event, button)
                if currentEncounter then
                    self:AdvanceEncounter(button == "LeftButton");
                else
                    local increment = button == "LeftButton" and 1 or -1;
                    window:SetUserData("tick", math.max(window:GetUserData("tick") + increment, -1));
                    Refresh();
                end
            end);
            mainLine:AddChild(tickTrigger);
            window:SetUserData("tickTrigger", tickTrigger);
            self:AddWidgetTooltip(tickTrigger, "Once started, left-click to add a tick and right-click to remove one.");
        end

        local liveWaitingForCombat = currentEncounter and currentEncounter.mode == ABP_4H.Modes.live and
            currentEncounter.ticks == 0 and currentEncounter.tickDuration == 0;
        if not currentEncounter or (currentEncounter.started and (currentEncounter.mode ~= self.Modes.live or liveWaitingForCombat)) then
            local reset = AceGUI:Create("Button");
            reset:SetText("Stop");
            reset:SetFullWidth(true);
            reset:SetCallback("OnClick", function(widget)
                if currentEncounter then
                    self:StopEncounter();
                else
                    window:SetUserData("tick", -1);
                    Refresh();
                end
            end);
            mainLine:AddChild(reset);
            window:SetUserData("reset", reset);
        end

        if currentEncounter and currentEncounter.mode ~= self.Modes.live and currentEncounter.started then
            local bosses = {
                [self.Bosses.korthazz] = "Thane Korth'azz (BL)",
                [self.Bosses.blaumeux] = "Lady Blaumeux (TL)",
                [self.Bosses.mograine] = "Highlord Mograine (BR)",
                [self.Bosses.zeliek] = "Sir Zeliek (TR)",
            };
            local deathSelector = AceGUI:Create("Dropdown");
            deathSelector:SetDisabled(not currentEncounter.started);
            deathSelector:SetFullWidth(true);
            deathSelector:SetUserData("cell", { colspan = 2 });
            deathSelector:SetMultiselect(true);
            deathSelector:SetList(bosses);
            for id in pairs(bosses) do
                if currentEncounter.bossDeaths[self.BossMarks[id]] then
                    deathSelector:SetItemValue(id, true);
                end
            end
            deathSelector:SetText("Boss Deaths");
            deathSelector:SetCallback("OnValueChanged", function(widget, event, value, checked)
                self:ScheduleTimer(function() self:DriverOnDeath(value, checked) end, 0);
            end);
            mainLine:AddChild(deathSelector);
        end
    end

    local image = AceGUI:Create("ABPN_ImageGroup");
    image:SetFullWidth(true);
    image:SetHeight(10);
    image:SetLayout("ABPN_Canvas");
    image:SetUserData("canvas-baseline", 225)
    image:SetImage("Interface\\AddOns\\4H-Assist\\Assets\\map.tga");
    image:SetImageAlpha(self:Get("alpha"));
    container:AddChild(image);
    window:SetUserData("image", image);
    image:SetCallback("OnWidthSet", function(widget, event, value)
        if math.floor(widget.content.height + 0.5) ~= math.floor(value + 0.5) then
            widget:SetHeight(value);
            local neighborsElt = window:GetUserData("neighborsElt");
            if neighborsElt then
                neighborsElt:SetHeight(neighborsElt:GetStringHeight());
            end

            local tankElts = window:GetUserData("tankElts");
            if tankElts then
                local shouldBeFill = (value > 250);
                local canvasData = tankElts[self.Marks.tl]:GetUserData("canvas");
                local isFill = (canvasData == "fill");
                if canvasData == nil or shouldBeFill ~= isFill then
                    if shouldBeFill then
                        tankElts[self.Marks.tl]:SetUserData("canvas", "fill");
                        tankElts[self.Marks.tl]:SetUserData("canvas-left", 30);
                        tankElts[self.Marks.tl]:SetUserData("canvas-right", 0);
                        tankElts[self.Marks.tl]:SetJustifyH("LEFT");
                        tankElts[self.Marks.tr]:SetUserData("canvas", "fill");
                        tankElts[self.Marks.tr]:SetUserData("canvas-left", 0);
                        tankElts[self.Marks.tr]:SetUserData("canvas-right", -30);
                        tankElts[self.Marks.tr]:SetJustifyH("RIGHT");
                        tankElts[self.Marks.bl]:SetUserData("canvas", "fill");
                        tankElts[self.Marks.bl]:SetUserData("canvas-left", 30);
                        tankElts[self.Marks.bl]:SetUserData("canvas-right", 0);
                        tankElts[self.Marks.bl]:SetJustifyH("LEFT");
                        tankElts[self.Marks.br]:SetUserData("canvas", "fill");
                        tankElts[self.Marks.br]:SetUserData("canvas-left", 0);
                        tankElts[self.Marks.br]:SetUserData("canvas-right", -30);
                        tankElts[self.Marks.br]:SetJustifyH("RIGHT");
                    else
                        tankElts[self.Marks.tl]:SetUserData("canvas", "outside-left");
                        tankElts[self.Marks.tl]:SetUserData("canvas-left", 0);
                        tankElts[self.Marks.tl]:SetUserData("canvas-right", -5);
                        tankElts[self.Marks.tl]:SetJustifyH("RIGHT");
                        tankElts[self.Marks.tr]:SetUserData("canvas", "outside-right");
                        tankElts[self.Marks.tr]:SetUserData("canvas-left", 10);
                        tankElts[self.Marks.tr]:SetUserData("canvas-right", 0);
                        tankElts[self.Marks.tr]:SetJustifyH("LEFT");
                        tankElts[self.Marks.bl]:SetUserData("canvas", "outside-left");
                        tankElts[self.Marks.bl]:SetUserData("canvas-left", 0);
                        tankElts[self.Marks.bl]:SetUserData("canvas-right", -5);
                        tankElts[self.Marks.bl]:SetJustifyH("RIGHT");
                        tankElts[self.Marks.br]:SetUserData("canvas", "outside-right");
                        tankElts[self.Marks.br]:SetUserData("canvas-left", 10);
                        tankElts[self.Marks.br]:SetUserData("canvas-right", 0);
                        tankElts[self.Marks.br]:SetJustifyH("LEFT");
                    end

                    if activeWindow and currentEncounter then
                        local raiders, map = ABP_4H:GetRaiderSlots();
                        RefreshTanks(raiders, map);
                    end
                end
            end

            container:DoLayout();
            local height = container.frame:GetHeight() + 50;
            window:SetHeight(height);
            local minW = window.frame:GetMinResize();
            local maxW = window.frame:GetMaxResize();
            window.frame:SetMinResize(minW, height);
            window.frame:SetMaxResize(maxW, height);
        end
    end);

    local current = AceGUI:Create("ABPN_Icon");
    current:SetWidth(24);
    current:SetHeight(24);
    current:SetImage("Interface\\MINIMAP\\Minimap_skull_elite.blp");
    image:AddChild(current);
    window:SetUserData("current", current);

    local upcoming = AceGUI:Create("ABPN_Icon");
    upcoming:SetWidth(24);
    upcoming:SetHeight(24);
    upcoming:SetImage("Interface\\MINIMAP\\Minimap_skull_normal.blp");
    image:AddChild(upcoming);
    window:SetUserData("upcoming", upcoming);

    local markElts = {};
    window:SetUserData("markElts", markElts);
    local bossElts = {};
    window:SetUserData("bossElts", bossElts);

    local markTL = AceGUI:Create("ABPN_Label");
    markTL:SetUserData("canvas-fill", true);
    markTL:SetFont("GameFontNormalHuge3Outline");
    markTL:SetWordWrap(true);
    markTL:SetJustifyH("LEFT");
    markTL:SetJustifyV("TOP");
    image:AddChild(markTL);
    markElts[self.Marks.tl] = markTL; -- Blaumeux

    local markTL = AceGUI:Create("ABPN_Label");
    markTL:SetUserData("canvas-fill-scaled", true);
    markTL:SetFont("GameFontNormalHuge3Outline");
    markTL:EnableMouse(true);
    markTL:SetWordWrap(true);
    markTL:SetJustifyH("LEFT");
    markTL:SetJustifyV("TOP");
    markTL:SetUserData("canvas-left", 5);
    markTL:SetUserData("canvas-top", -5);
    markTL:SetUserData("canvas-right", -50);
    markTL:SetUserData("canvas-bottom", 50);
    image:AddChild(markTL);
    self:AddWidgetTooltip(markTL, "Lady Blaumeux");

    local markTL = AceGUI:Create("ABPN_Label");
    markTL:SetUserData("canvas-fill", true);
    markTL:SetFont("GameFontNormalOutline");
    markTL:SetWordWrap(true);
    markTL:SetJustifyH("LEFT");
    markTL:SetJustifyV("TOP");
    markTL:SetUserData("canvas-top", -26);
    image:AddChild(markTL);
    bossElts[self.Marks.tl] = markTL;

    local markTR = AceGUI:Create("ABPN_Label");
    markTR:SetUserData("canvas-fill", true);
    markTR:SetFont("GameFontNormalHuge3Outline");
    markTR:SetWordWrap(true);
    markTR:SetJustifyH("RIGHT");
    markTR:SetJustifyV("TOP");
    image:AddChild(markTR);
    markElts[self.Marks.tr] = markTR; -- Zeliek

    local markTR = AceGUI:Create("ABPN_Label");
    markTR:SetUserData("canvas-fill-scaled", true);
    markTR:SetFont("GameFontNormalHuge3Outline");
    markTR:EnableMouse(true);
    markTR:SetWordWrap(true);
    markTR:SetJustifyH("RIGHT");
    markTR:SetJustifyV("TOP");
    markTR:SetUserData("canvas-left", 50);
    markTR:SetUserData("canvas-top", -5);
    markTR:SetUserData("canvas-right", -5);
    markTR:SetUserData("canvas-bottom", 50);
    image:AddChild(markTR);
    self:AddWidgetTooltip(markTR, "Sir Zeliek");

    local markTR = AceGUI:Create("ABPN_Label");
    markTR:SetUserData("canvas-fill", true);
    markTR:SetFont("GameFontNormalOutline");
    markTR:SetWordWrap(true);
    markTR:SetJustifyH("RIGHT");
    markTR:SetJustifyV("TOP");
    markTR:SetUserData("canvas-top", -26);
    image:AddChild(markTR);
    bossElts[self.Marks.tr] = markTR;

    local markBL = AceGUI:Create("ABPN_Label");
    markBL:SetUserData("canvas-fill", true);
    markBL:SetFont("GameFontNormalHuge3Outline");
    markBL:SetWordWrap(true);
    markBL:SetJustifyH("LEFT");
    markBL:SetJustifyV("BOTTOM");
    image:AddChild(markBL);
    markElts[self.Marks.bl] = markBL; -- Korth'azz

    local markBL = AceGUI:Create("ABPN_Label");
    markBL:SetUserData("canvas-fill-scaled", true);
    markBL:SetFont("GameFontNormalHuge3Outline");
    markBL:EnableMouse(true);
    markBL:SetWordWrap(true);
    markBL:SetJustifyH("LEFT");
    markBL:SetJustifyV("BOTTOM");
    markBL:SetUserData("canvas-left", 5);
    markBL:SetUserData("canvas-top", -50);
    markBL:SetUserData("canvas-right", -50);
    markBL:SetUserData("canvas-bottom", 5);
    image:AddChild(markBL);
    self:AddWidgetTooltip(markBL, "Thane Korth'azz");

    local markBL = AceGUI:Create("ABPN_Label");
    markBL:SetUserData("canvas-fill", true);
    markBL:SetFont("GameFontNormalOutline");
    markBL:SetWordWrap(true);
    markBL:SetJustifyH("LEFT");
    markBL:SetJustifyV("BOTTOM");
    markBL:SetUserData("canvas-bottom", 26);
    image:AddChild(markBL);
    bossElts[self.Marks.bl] = markBL;

    local markBR = AceGUI:Create("ABPN_Label");
    markBR:SetUserData("canvas-fill", true);
    markBR:SetFont("GameFontNormalHuge3Outline");
    markBR:SetWordWrap(true);
    markBR:SetJustifyH("RIGHT");
    markBR:SetJustifyV("BOTTOM");
    image:AddChild(markBR);
    markElts[self.Marks.br] = markBR; -- Mograine

    local markBR = AceGUI:Create("ABPN_Label");
    markBR:SetUserData("canvas-fill-scaled", true);
    markBR:SetFont("GameFontNormalHuge3Outline");
    markBR:EnableMouse(true);
    markBR:SetWordWrap(true);
    markBR:SetJustifyH("RIGHT");
    markBR:SetJustifyV("BOTTOM");
    markBR:SetUserData("canvas-left", 50);
    markBR:SetUserData("canvas-top", -50);
    markBR:SetUserData("canvas-right", -5);
    markBR:SetUserData("canvas-bottom", 5);
    image:AddChild(markBR);
    self:AddWidgetTooltip(markBR, "Highlord Mograine");

    local markBR = AceGUI:Create("ABPN_Label");
    markBR:SetUserData("canvas-fill", true);
    markBR:SetFont("GameFontNormalOutline");
    markBR:SetWordWrap(true);
    markBR:SetJustifyH("RIGHT");
    markBR:SetJustifyV("BOTTOM");
    markBR:SetUserData("canvas-bottom", 26);
    image:AddChild(markBR);
    bossElts[self.Marks.br] = markBR;

    if currentEncounter then
        local raiders = ABP_4H:GetRaiderSlots();

        if self:Get("showTanks") then
            local tankElts = {};
            window:SetUserData("tankElts", tankElts);

            local tankTL = AceGUI:Create("ABPN_Label");
            tankTL:SetFont("GameFontHighlightOutline");
            tankTL:SetWordWrap(true);
            tankTL:SetJustifyV("TOP");
            image:AddChild(tankTL);
            tankElts[self.Marks.tl] = tankTL; -- Blaumeux

            local tankTR = AceGUI:Create("ABPN_Label");
            tankTR:SetFont("GameFontHighlightOutline");
            tankTR:SetWordWrap(true);
            tankTR:SetJustifyV("TOP");
            image:AddChild(tankTR);
            tankElts[self.Marks.tr] = tankTR; -- Zeliek

            local tankBL = AceGUI:Create("ABPN_Label");
            tankBL:SetFont("GameFontHighlightOutline");
            tankBL:SetWordWrap(true);
            tankBL:SetJustifyV("BOTTOM");
            image:AddChild(tankBL);
            tankElts[self.Marks.bl] = tankBL; -- Korth'azz

            local tankBR = AceGUI:Create("ABPN_Label");
            tankBR:SetFont("GameFontHighlightOutline");
            tankBR:SetWordWrap(true);
            tankBR:SetJustifyV("BOTTOM");
            image:AddChild(tankBR);
            tankElts[self.Marks.br] = tankBR; -- Mograine
        end

        if self:Get("showNeighbors") then
            local neighborsElt = AceGUI:Create("ABPN_Label");
            container:AddChild(neighborsElt);
            neighborsElt:SetFont("GameFontHighlightOutline");
            neighborsElt:SetFullWidth(true);
            neighborsElt:SetWordWrap(true);
            neighborsElt:SetJustifyH("LEFT");
            neighborsElt:SetJustifyV("TOP");
            neighborsElt:SetText("");
            neighborsElt:SetHeight(neighborsElt:GetStringHeight());
            window:SetUserData("neighborsElt", neighborsElt);
            window:SetUserData("timer", self:ScheduleRepeatingTimer(self.OnUITimer, 0.5, self));
        end
    end

    image.content.height = 0;
    container:DoLayout();
    local height = container.frame:GetHeight() + 50;
    window:SetHeight(height);
    local minW = window.frame:GetMinResize();
    local maxW = window.frame:GetMaxResize();
    window.frame:SetMinResize(minW, height);
    window.frame:SetMaxResize(maxW, height);

    window.frame:Raise();
    return window;
end

function ABP_4H:ShowMainWindow()
    if activeWindow then
        activeWindow:SetUserData("closeConfirmed", true);
        activeWindow:Hide();
        return;
    end

    if not currentEncounter and not self:CanOpenWindow() then
        _G.StaticPopup_Show("ABP_4H_MAP_BLOCKED");
        return;
    end

    activeWindow = self:CreateMainWindow();
    Refresh();
end

StaticPopupDialogs["ABP_4H_MAP_BLOCKED"] = ABP_4H:StaticDialogTemplate(ABP_4H.StaticDialogTemplates.JUST_BUTTONS, {
    text = "Opening the map window directly is restricted to raid lead/assists when in Naxxramas! It will open automatically when you're assigned a role.",
    button1 = "Ok",
});

StaticPopupDialogs["ABP_4H_CONFIRM_CLOSE"] = ABP_4H:StaticDialogTemplate(ABP_4H.StaticDialogTemplates.JUST_BUTTONS, {
    text = "Close the map? You can reopen via |cff00ff00/fh show|r or binding a key. |cffaaaaaaBypass this confirmation by holding <shift> or disabling in settings.|r",
    button1 = "Close",
    button2 = "Cancel",
    showAlert = true,
    OnAccept = function(self, data)
        if activeWindow then
            activeWindow:SetUserData("closeConfirmed", true);
            activeWindow:Hide();
        end
    end,
});
