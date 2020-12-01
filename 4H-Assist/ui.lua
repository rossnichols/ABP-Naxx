local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceGUI = _G.LibStub("AceGUI-3.0");

local UnitName = UnitName;
local UnitIsUnit = UnitIsUnit;
local IsItemInRange = IsItemInRange;
local UnitIsConnected = UnitIsConnected;
local UnitIsDeadOrGhost = UnitIsDeadOrGhost;
local UnitDebuff = UnitDebuff;
local GetRaidTargetIndex = GetRaidTargetIndex;
local table = table;
local pairs = pairs;
local math = math;
local setmetatable = setmetatable;
local tostring = tostring;

local activeWindow;
local dbmPendingAlert, dbmMoveAlert, dbmTickAlert;
local currentEncounter;
local lastAlertedPending;
local lastAlertedMove;

local function GetPositions(role, tick, onlyOriginal)
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
        if currentEncounter.bossDeaths[ABP_4H.Marks.bl] and currentEncounter.bossDeaths[ABP_4H.Marks.br] then
            local map = {
                [ABP_4H.MapPositions.tankdpsBL] = ABP_4H.MapPositions.tankdpsTL,
                [ABP_4H.MapPositions.tankdpsBR] = ABP_4H.MapPositions.tankdpsTR,
            };
            currentPos = map[currentPos] or currentPos;
            nextPos = map[nextPos] or nextPos;
            nextDifferentPos = map[nextDifferentPos] or nextDifferentPos;
        end
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
                local inRange;
                if raider.fake then
                    inRange = (math.random() < 0.95);
                else
                    inRange = IsItemInRange(21519, player);
                end
                local formatStr = inRange and "|cff00ff00%s|r" or "|cffff0000%s|r";

                -- for i = 1, math.random(1, 15) do
                    table.insert(neighbors, formatStr:format(player));
                -- end
            end
        end
    end

    return neighbors;
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

    local rotation = ABP_4H.Rotations[role];
    local currentPos, nextPos = GetPositions(role, tick);

    if tick > 1 and currentEncounter and dbmMoveAlert and ABP_4H:Get("showMoveAlert") then
        local prevPos = GetPositions(role, tick - 1);
        if prevPos ~= currentPos and lastAlertedMove ~= tick then
            lastAlertedMove = tick;
            dbmMoveAlert:Show("Time to move!");
        end
    end

    current:SetVisible(true);
    current:SetUserData("canvas-X", currentPos[1]);
    current:SetUserData("canvas-Y", currentPos[2]);

    if nextPos ~= currentPos then
        upcoming:SetVisible(true);
        upcoming:SetUserData("canvas-X", nextPos[1]);
        upcoming:SetUserData("canvas-Y", nextPos[2]);

        if currentEncounter and dbmPendingAlert and ABP_4H:Get("showAlert") and lastAlertedPending ~= tick then
            lastAlertedPending = tick;
            dbmPendingAlert:Show("Move after next mark!");
        end
    end
    image:DoLayout();

    local neighborsElt = activeWindow:GetUserData("neighborsElt");
    if neighborsElt then
        local raiders = ABP_4H:GetRaiderSlots();
        local neighbors = GetNeighbors(activeWindow, raiders);
        neighborsElt:SetText(table.concat(neighbors, " "));
        neighborsElt:SetHeight(neighborsElt:GetStringHeight());

        local container = activeWindow:GetUserData("contentContainer");
        container:DoLayout();
        local height = container.frame:GetHeight() + 50;
        activeWindow:SetHeight(height);
        local minW = activeWindow.frame:GetMinResize();
        local maxW = activeWindow.frame:GetMaxResize();
        activeWindow.frame:SetMinResize(minW, height);
        activeWindow.frame:SetMaxResize(maxW, height);
    end

    local tomb = {
        [true] = "|TInterface\\Minimap\\POIIcons.blp:0:0:0:-8:128:128:112:128:0:16|t",
        [false] = "|TInterface\\Minimap\\POIIcons.blp:0:0:0:-8:128:128:72.5:81:0.25:4.5|t",
    };

    local markElts = activeWindow:GetUserData("markElts");
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
        if currentEncounter and currentEncounter.mode == ABP_4H.Modes.live then
            local updated = {};
            local i = 1;
            local name, _, count, _, _, _, _, _, _, spellID = UnitDebuff("player", i);
            while name do
                local elt = markElts[spellID];
                if elt then
                    updated[elt] = true;
                    elt:SetText(texts[count]);
                end

                i = i + 1;
                name, _, count, _, _, _, _, _, _, spellID = UnitDebuff("player", i);
            end

            for mark, elt in pairs(markElts) do
                if currentEncounter.bossDeaths[mark] then
                    elt:SetText(tomb[ABP_4H:IsClassic()]);
                elseif not updated[elt] then
                    elt:SetText(texts[0]);
                end
            end
        else
            for mark, elt in pairs(markElts) do
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

                if currentEncounter and currentEncounter.bossDeaths[mark] then
                    elt:SetText(tomb[ABP_4H:IsClassic()]);
                else
                    elt:SetText(texts[count]);
                end
            end
        end
    end
end

function ABP_4H:UIOnGroupJoined()
    self:SendComm(self.CommTypes.STATE_SYNC_REQUEST, {}, "BROADCAST");
end

function ABP_4H:UIOnGroupLeft()
    currentEncounter = nil;
    lastAlertedPending = nil;
    lastAlertedMove = nil;
    if activeWindow then activeWindow:Hide(); end
end

function ABP_4H:UIOnStateSync(data, distribution, sender, version)
    if data.active then
        local player = UnitName("player");
        local _, map = self:GetRaiderSlots();
        local role = data.roles[map[player]];

        if data.started then
            if data.mode ~= ABP_4H.Modes.live and dbmTickAlert then
                local extra = "";
                -- local currentPos, nextPos = GetPositions(role, data.ticks - 1);
                -- if currentPos ~= nextPos then
                --     extra = " - NEW POSITION!"
                -- end
                dbmTickAlert:Show(("Mark %d%s"):format(data.ticks, extra));
            end
        else
            self:SendComm(self.CommTypes.STATE_SYNC_ACK, {
                role = role,
            }, "WHISPER", sender);
        end

        local processedRoles = {};
        for player, slot in pairs(map) do
            processedRoles[player] = data.roles[slot];
        end

        currentEncounter = {
            roles = processedRoles,
            mode = data.mode,
            tickDuration = data.tickDuration,
            role = role,
            driving = (sender == player),
            started = data.started,
            ticks = data.ticks,
            bossDeaths = data.bossDeaths,
        };
    else
        currentEncounter = nil;
        lastAlertedPending = nil;
        lastAlertedMove = nil;
    end

    if activeWindow then activeWindow:Hide(); end

    if currentEncounter then
        self:ShowMainWindow();
    end
end

function ABP_4H:GetCurrentEncounter()
    return currentEncounter;
end

function ABP_4H:RefreshCurrentEncounter()
    if currentEncounter and currentEncounter.started then
        self:RefreshMainWindow();
    else
        activeWindow:Hide();
        currentEncounter = nil;
        lastAlertedPending = nil;
        lastAlertedMove = nil;
    end
end

function ABP_4H:RefreshMainWindow()
    if activeWindow then
        activeWindow:Hide();
        self:ShowMainWindow();
    end
end

function ABP_4H:OnUITimer()
    Refresh();
end

function ABP_4H:UIOnAura()
    Refresh();
end

function ABP_4H:CreateMainWindow()
    if not dbmPendingAlert and _G.DBM and _G.DBM.NewMod then
        local mod = _G.DBM:NewMod("4H Assist");
        _G.DBM:GetModLocalization("4H Assist"):SetGeneralLocalization{ name = "4H Assist" }
        dbmPendingAlert = mod:NewSpecialWarning("%s", nil, nil, nil, 1);
        dbmMoveAlert = mod:NewSpecialWarning("%s ", nil, nil, nil, 1);
        dbmTickAlert = mod:NewAnnounce("%s", 1, "136172");
    end

    local windowWidth = 400;
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
        self:EndWindowManagement(widget);
        local timer = widget:GetUserData("timer");
        if timer then self:CancelTimer(timer); end
        AceGUI:Release(widget);
        activeWindow = nil;
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

        local mainLine = AceGUI:Create("SimpleGroup");
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
        if currentEncounter and currentEncounter.mode == ABP_4H.Modes.live and
           currentEncounter.ticks == 0 and currentEncounter.tickDuration == 0 then
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
            window:SetUserData("role", value);
            window:SetUserData("tick", -1);
            Refresh();
        end);
        container:AddChild(roleSelector);
    end

    if not currentEncounter or currentEncounter.driving then
        local mainLine = AceGUI:Create("SimpleGroup");
        mainLine:SetFullWidth(true);
        mainLine:SetLayout("table");
        mainLine:SetUserData("table", { columns = { 1.0, 1.0 } });
        container:AddChild(mainLine);

        if not currentEncounter or (currentEncounter.mode ~= self.Modes.live or not currentEncounter.started) then
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

        if not currentEncounter or (currentEncounter.mode ~= self.Modes.live or currentEncounter.tickDuration == 0) then
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

        if currentEncounter and currentEncounter.mode ~= self.Modes.live then
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
        if widget.content.height ~= value then
            widget:SetHeight(value);
            local neighborsElt = window:GetUserData("neighborsElt");
            if neighborsElt then
                neighborsElt:SetHeight(neighborsElt:GetStringHeight());
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
    local markTL = AceGUI:Create("ABPN_Label");
    markTL:SetUserData("canvas-fill", true);
    markTL:SetFont("GameFontNormalHuge3Outline");
    markTL:SetWordWrap(true);
    markTL:SetJustifyH("LEFT");
    markTL:SetJustifyV("TOP");
    image:AddChild(markTL);
    markElts[self.Marks.tl] = markTL; -- Blaumeux

    local markTR = AceGUI:Create("ABPN_Label");
    markTR:SetUserData("canvas-fill", true);
    markTR:SetFont("GameFontNormalHuge3Outline");
    markTR:SetWordWrap(true);
    markTR:SetJustifyH("RIGHT");
    markTR:SetJustifyV("TOP");
    image:AddChild(markTR);
    markElts[self.Marks.tr] = markTR; -- Zeliek

    local markBL = AceGUI:Create("ABPN_Label");
    markBL:SetUserData("canvas-fill", true);
    markBL:SetFont("GameFontNormalHuge3Outline");
    markBL:SetWordWrap(true);
    markBL:SetJustifyH("LEFT");
    markBL:SetJustifyV("BOTTOM");
    image:AddChild(markBL);
    markElts[self.Marks.bl] = markBL; -- Korth'azz

    local markBR = AceGUI:Create("ABPN_Label");
    markBR:SetUserData("canvas-fill", true);
    markBR:SetFont("GameFontNormalHuge3Outline");
    markBR:SetWordWrap(true);
    markBR:SetJustifyH("RIGHT");
    markBR:SetJustifyV("BOTTOM");
    image:AddChild(markBR);
    markElts[self.Marks.br] = markBR; -- Mograine

    if currentEncounter then
        local raiders = ABP_4H:GetRaiderSlots();

        if self:Get("showTanks") then
            local currentTanks, upcomingTanks = {}, {};
            for _, raider in pairs(raiders) do
                local role = currentEncounter.roles[raider.name];
                if self.RoleCategories[role] == self.Categories.tank then
                    local pos, _, nextDiff = GetPositions(role, currentEncounter.ticks, true);
                    local playerText = (raider.fake or (UnitIsConnected(raider.name) and not UnitIsDeadOrGhost(raider.name)))
                        and raider.name
                        or ("|cffff0000%s|r"):format(raider.name);
                    local icon = GetRaidTargetIndex(raider.name);
                    local iconText = icon and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s.blp:0|t"):format(icon);
                    if pos == self.MapPositions.safe then
                        upcomingTanks[nextDiff] = { text = playerText, icon = iconText };
                    else
                        currentTanks[pos] = { text = playerText, icon = iconText };
                    end
                end
            end

            if not currentEncounter.bossDeaths[self.Marks.tl] then
                local current = currentTanks[self.MapPositions.tankdpsTL];
                local upcoming = upcomingTanks[self.MapPositions.tankdpsTL];
                local tankTL = AceGUI:Create("ABPN_Label");
                tankTL:SetUserData("canvas-fill", true);
                tankTL:SetUserData("canvas-left", 30);
                tankTL:SetFont("GameFontHighlightOutline");
                tankTL:SetWordWrap(true);
                tankTL:SetJustifyH("LEFT");
                tankTL:SetJustifyV("TOP");
                tankTL:SetText(("%s|cff00ff00%s|r\n%s|cffcccccc%s|r"):format(
                    current and current.icon or "",
                    current and current.text or "",
                    upcoming and upcoming.icon or "",
                    upcoming and upcoming.text or ""));
                image:AddChild(tankTL);
            end

            if not currentEncounter.bossDeaths[self.Marks.tr] then
                local current = currentTanks[self.MapPositions.tankdpsTR];
                local upcoming = upcomingTanks[self.MapPositions.tankdpsTR];
                local tankTR = AceGUI:Create("ABPN_Label");
                tankTR:SetUserData("canvas-fill", true);
                tankTR:SetUserData("canvas-right", -30);
                tankTR:SetFont("GameFontHighlightOutline");
                tankTR:SetWordWrap(true);
                tankTR:SetJustifyH("RIGHT");
                tankTR:SetJustifyV("TOP");
                tankTR:SetText(("|cff00ff00%s|r%s\n|cffcccccc%s|r%s"):format(
                    current and current.text or "",
                    current and current.icon or "",
                    upcoming and upcoming.text or "",
                    upcoming and upcoming.icon or ""));
                image:AddChild(tankTR);
            end

            if not currentEncounter.bossDeaths[self.Marks.bl] then
                local current = currentTanks[self.MapPositions.tankdpsBL];
                local upcoming = upcomingTanks[self.MapPositions.tankdpsBL];
                local tankBL = AceGUI:Create("ABPN_Label");
                tankBL:SetUserData("canvas-fill", true);
                tankBL:SetUserData("canvas-left", 30);
                tankBL:SetFont("GameFontHighlightOutline");
                tankBL:SetWordWrap(true);
                tankBL:SetJustifyH("LEFT");
                tankBL:SetJustifyV("BOTTOM");
                tankBL:SetText(("%s|cffcccccc%s|r\n%s|cff00ff00%s|r"):format(
                    upcoming and upcoming.icon or "",
                    upcoming and upcoming.text or "",
                    current and current.icon or "",
                    current and current.text or ""));
                image:AddChild(tankBL);
            end

            if not currentEncounter.bossDeaths[self.Marks.br] then
                local current = currentTanks[self.MapPositions.tankdpsBR];
                local upcoming = upcomingTanks[self.MapPositions.tankdpsBR];
                local tankBR = AceGUI:Create("ABPN_Label");
                tankBR:SetUserData("canvas-fill", true);
                tankBR:SetUserData("canvas-right", -30);
                tankBR:SetFont("GameFontHighlightOutline");
                tankBR:SetWordWrap(true);
                tankBR:SetJustifyH("RIGHT");
                tankBR:SetJustifyV("BOTTOM");
                tankBR:SetText(("|cffcccccc%s|r%s\n|cff00ff00%s|r%s"):format(
                    upcoming and upcoming.text or "",
                    upcoming and upcoming.icon or "",
                    current and current.text or "",
                    current and current.icon or ""));
                image:AddChild(tankBR);
            end
        end

        if self:Get("showNeighbors") then
            local neighbors = GetNeighbors(window, raiders);
            local neighborsElt = AceGUI:Create("ABPN_Label");
            container:AddChild(neighborsElt);
            neighborsElt:SetFont("GameFontHighlightOutline");
            neighborsElt:SetFullWidth(true);
            neighborsElt:SetWordWrap(true);
            neighborsElt:SetJustifyH("LEFT");
            neighborsElt:SetJustifyV("TOP");
            neighborsElt:SetText(table.concat(neighbors, " "));
            neighborsElt:SetHeight(neighborsElt:GetStringHeight());
            window:SetUserData("neighborsElt", neighborsElt);
            window:SetUserData("timer", self:ScheduleRepeatingTimer(self.OnUITimer, 0.5, self));
        end
    else
        -- local neighborsElt = AceGUI:Create("ABPN_Label");
        -- container:AddChild(neighborsElt);
        -- neighborsElt:SetFont("GameFontHighlightOutline");
        -- neighborsElt:SetFullWidth(true);
        -- neighborsElt:SetWordWrap(true);
        -- neighborsElt:SetJustifyH("LEFT");
        -- neighborsElt:SetJustifyV("TOP");
        -- neighborsElt:SetText("");
        -- neighborsElt:SetHeight(neighborsElt:GetStringHeight());
        -- window:SetUserData("neighborsElt", neighborsElt);
    end

    image.content.height = 0;
    container:DoLayout();
    local height = container.frame:GetHeight() + 50;
    self:BeginWindowManagement(window, "main", {
        version = 1,
        defaultWidth = windowWidth,
        minWidth = windowWidth - 200,
        maxWidth = windowWidth + 200,
        defaultHeight = height,
    });

    window.frame:Raise();
    return window;
end

function ABP_4H:ShowMainWindow()
    if activeWindow then
        activeWindow:Hide();
        return;
    end

    activeWindow = self:CreateMainWindow();
    Refresh();
end
