local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceGUI = _G.LibStub("AceGUI-3.0");

local dbmAlert;
if _G.DBM then
    local mod = _G.DBM:NewMod("4H Assist");
    _G.DBM:GetModLocalization("4H Assist"):SetGeneralLocalization{ name = "4H Assist" }
    dbmAlert = mod:NewSpecialWarning("%s", nil, nil, nil, 1, 2);
end

local UnitName = UnitName;
local table = table;
local pairs = pairs;
local math = math;

local activeWindow;

local currentEncounter;

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
    local currentPos, nextPos;
    if tick == -1 then
        currentPos = rotation[0];
        nextPos = currentPos;
    else
        tick = tick % 12;
        currentPos = rotation[tick];
        nextPos = rotation[tick + 1];
    end

    current:SetVisible(true);
    current:SetUserData("canvas-X", currentPos[1]);
    current:SetUserData("canvas-Y", currentPos[2]);

    if nextPos ~= currentPos then
        upcoming:SetVisible(true);
        upcoming:SetUserData("canvas-X", nextPos[1]);
        upcoming:SetUserData("canvas-Y", nextPos[2]);

        if currentEncounter and dbmAlert and ABP_4H:Get("showAlert") then
            dbmAlert:Show("Move after next mark!");
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

        if not data.started then
            self:SendComm(self.CommTypes.STATE_SYNC_ACK, {
                role = role,
            }, "WHISPER", sender);
        end

        currentEncounter = {
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
    if activeWindow then
        activeWindow:Hide();
        if currentEncounter and currentEncounter.started then
            self:ShowMainWindow();
        else
            currentEncounter = nil;
        end
    end
end

function ABP_4H:CreateMainWindow()
    local window = AceGUI:Create("Window");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("4H Assist"), self:GetVersion()));
    window:SetLayout("Flow");
    self:BeginWindowManagement(window, "main", {
        version = 1,
        defaultWidth = 400,
        minWidth = 200,
        maxWidth = 600,
        defaultHeight = 400,
        minHeight = 200,
        maxHeight = 600
    });
    window:SetCallback("OnClose", function(widget)
        self:EndWindowManagement(widget);
        AceGUI:Release(widget);
        activeWindow = nil;
    end);

    if currentEncounter then
        local role = currentEncounter.role;
        window:SetUserData("role", role);
        window:SetUserData("tick", currentEncounter.started and currentEncounter.ticks or -1);

        local mainLine = AceGUI:Create("SimpleGroup");
        mainLine:SetFullWidth(true);
        mainLine:SetLayout("table");
        mainLine:SetUserData("table", { columns = { 1.0, 1.0 } });
        window:AddChild(mainLine);

        local roleElt = AceGUI:Create("ABPN_Label");
        roleElt:SetFullWidth(true);
        roleElt:SetText(self.RoleNames[role]);
        mainLine:AddChild(roleElt);

        local tickElt = AceGUI:Create("ABPN_Label");
        tickElt:SetFullWidth(true);
        local tickText = currentEncounter.started and ("Ticks: %d"):format(currentEncounter.ticks) or "Not Started";
        if currentEncounter and currentEncounter.mode == ABP_4H.Modes.live and
           currentEncounter.ticks == 0 and currentEncounter.tickDuration == 0 then
            tickText = "Waiting";
        end
        tickElt:SetText(tickText);
        tickElt:SetJustifyH("RIGHT");
        mainLine:AddChild(tickElt);

        if currentEncounter.started and currentEncounter.tickDuration > 0 and
           (currentEncounter.mode == self.Modes.timer or currentEncounter.mode == self.Modes.live) then
            local statusbar = AceGUI:Create("ABPN_StatusBar");
            statusbar:SetFullWidth(true);
            statusbar:SetHeight(5);
            statusbar:SetDuration(currentEncounter.tickDuration);
            window:AddChild(statusbar);
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
        window:AddChild(roleSelector);
    end

    if not currentEncounter or currentEncounter.driving then
        local mainLine = AceGUI:Create("SimpleGroup");
        mainLine:SetFullWidth(true);
        mainLine:SetLayout("table");
        mainLine:SetUserData("table", { columns = { 1.0, 1.0 } });
        window:AddChild(mainLine);

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
            reset:SetFullHeight(true);
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
    image:SetFullHeight(true);
    image:SetLayout("ABPN_Canvas");
    image:SetUserData("canvas-baseline", 225)
    image:SetImage("Interface\\AddOns\\4H-Assist\\Assets\\map.tga");
    window:AddChild(image);
    window:SetUserData("image", image);

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
