local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceGUI = _G.LibStub("AceGUI-3.0");

local dbmMoveAlert, dbmTickAlert;

local UnitName = UnitName;
local UnitIsUnit = UnitIsUnit;
local IsItemInRange = IsItemInRange;
local IsMouseButtonDown = IsMouseButtonDown;
local table = table;
local pairs = pairs;
local math = math;

local activeWindow;

local currentEncounter;

local function GetPositions(role, tick)
    local rotation = ABP_4H.Rotations[role];
    local currentPos, nextPos;
    if tick == -1 then
        currentPos = rotation[0];
        nextPos = currentPos;
    else
        tick = tick % 12;
        currentPos = rotation[tick];
        nextPos = rotation[tick + 1];
    end

    return currentPos, nextPos;
end

local function GetNeighbors(window)
    if not currentEncounter then return; end

    local neighbors = {};
    local tick = window:GetUserData("tick");
    local myPos = GetPositions(window:GetUserData("role"), tick);

    local raiders = ABP_4H:GetRaiderSlots();
    local roles = currentEncounter.roles;
    for slot, player in pairs(raiders) do
        if not UnitIsUnit(player, "player") then
            local role = roles[slot];
            local currentPos = GetPositions(role, tick);
            if currentPos == myPos then
                local formatStr = IsItemInRange(21519, player)
                    and "|cff00ff00%s|r"
                    or "|cffff0000%s|r";

                -- for i = 1, math.random(1, 15) do
                    table.insert(neighbors, formatStr:format(player));
                -- end
            end
        end
    end

    return neighbors;
end

local function Refresh()
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

    current:SetVisible(true);
    current:SetUserData("canvas-X", currentPos[1]);
    current:SetUserData("canvas-Y", currentPos[2]);

    if nextPos ~= currentPos then
        upcoming:SetVisible(true);
        upcoming:SetUserData("canvas-X", nextPos[1]);
        upcoming:SetUserData("canvas-Y", nextPos[2]);

        if currentEncounter and dbmMoveAlert and ABP_4H:Get("showAlert") then
            dbmMoveAlert:Show("Move after next mark!");
        end
    end
    image:DoLayout();
end

function ABP_4H:UIOnGroupJoined()
    self:SendComm(self.CommTypes.STATE_SYNC_REQUEST, {}, "BROADCAST");
end

function ABP_4H:UIOnGroupLeft()
    currentEncounter = nil;
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

        currentEncounter = {
            roles = data.roles,
            mode = data.mode,
            tickDuration = data.tickDuration,
            role = role,
            driving = (sender == player),
            started = data.started,
            ticks = data.ticks,
        };
    else
        currentEncounter = nil;
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
    end
end

function ABP_4H:RefreshMainWindow()
    if activeWindow then
        activeWindow:Hide();
        self:ShowMainWindow();
    end
end

function ABP_4H:OnUITimer()
    if activeWindow and not activeWindow:GetUserData("moveSize") then
        self:RefreshMainWindow();
    end
end

function ABP_4H:CreateMainWindow()
    if not dbmMoveAlert and _G.DBM and _G.DBM.NewMod then
        local mod = _G.DBM:NewMod("4H Assist");
        _G.DBM:GetModLocalization("4H Assist"):SetGeneralLocalization{ name = "4H Assist" }
        dbmMoveAlert = mod:NewSpecialWarning("%s", nil, nil, nil, 1, 2);
        dbmTickAlert = mod:NewAnnounce("%s", 1, "136172");
    end

    local window = AceGUI:Create("ABPN_TransparentWindow");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("4H Assist"), self:GetVersion()));
    window:SetLayout("Flow");
    self:BeginWindowManagement(window, "main", {
        version = 1,
        defaultWidth = 400,
        minWidth = 200,
        maxWidth = 600,
        defaultHeight = 400,
    });
    window:SetCallback("OnClose", function(widget)
        self:EndWindowManagement(widget);
        local timer = widget:GetUserData("timer");
        if timer then self:CancelTimer(timer); end

        self:Unhook(widget.frame, "StartMoving");
        self:Unhook(widget.frame, "StartSizing");
        self:Unhook(widget.frame, "StopMovingOrSizing");

        AceGUI:Release(widget);
        activeWindow = nil;
    end);

    self:SecureHook(window.frame, "StartMoving", function(self) self.obj:SetUserData("moveSize", true); end);
    self:SecureHook(window.frame, "StartSizing", function(self) self.obj:SetUserData("moveSize", true); end);
    self:SecureHook(window.frame, "StopMovingOrSizing", function(self) self.obj:SetUserData("moveSize", false); end);

    local container = AceGUI:Create("ABPN_TransparentGroup");
    container:SetFullWidth(true);
    container:SetLayout("Flow");
    window:AddChild(container);

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
        roleElt:SetText(self.RoleNames[role]);
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
        roleSelector:SetList(self.RoleNames, self.RolesSorted);
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
                neighborsElt:SetHeight(neighborsElt.text:GetStringHeight());
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

    if currentEncounter then
        local neighbors = GetNeighbors(window);
        if neighbors then
            if #neighbors > 0 then
                local neighborsElt = AceGUI:Create("ABPN_Label");
                container:AddChild(neighborsElt);
                neighborsElt:SetFont("GameFontHighlightOutline");
                neighborsElt:SetFullWidth(true);
                neighborsElt:SetWordWrap(true);
                neighborsElt:SetJustifyH("LEFT");
                neighborsElt:SetJustifyV("TOP");
                neighborsElt:SetText(table.concat(neighbors, " "));
                container:DoLayout();
                neighborsElt:SetHeight(neighborsElt.text:GetStringHeight());
                window:SetUserData("neighborsElt", neighborsElt);
            end
            window:SetUserData("timer", self:ScheduleRepeatingTimer(self.OnUITimer, 0.5, self));
        end
    end

    image.content.height = 0;
    container:DoLayout();

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
