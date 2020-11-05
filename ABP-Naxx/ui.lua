local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;
local AceGUI = _G.LibStub("AceGUI-3.0");

local UnitName = UnitName;
local table = table;
local pairs = pairs;

local activeWindow;

local currentEncounter;

local function Refresh()
    local current = activeWindow:GetUserData("current");
    local upcoming = activeWindow:GetUserData("upcoming");
    local image = activeWindow:GetUserData("image");
    local role = activeWindow:GetUserData("role");
    local tick = activeWindow:GetUserData("tick");
    local tickTrigger = activeWindow:GetUserData("tickTrigger");
    local reset = activeWindow:GetUserData("reset");

    current.frame:Hide();
    upcoming.frame:Hide();

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

    local rotation = ABP_Naxx.Rotations[role];
    if reset then
        reset:SetDisabled(tick == -1);
    end
    if tickTrigger then
        tickTrigger:SetDisabled(false);
        tickTrigger:SetText(tick == -1 and "Start" or ("Tick (%d)"):format(tick));
    end
    current.frame:Show();

    local currentPos, nextPos;
    if tick == -1 then
        currentPos = rotation[0];
        nextPos = currentPos;
    else
        tick = tick % 12;
        currentPos = rotation[tick];
        nextPos = rotation[tick + 1];
    end

    current:SetUserData("canvas-X", currentPos[1]);
    current:SetUserData("canvas-Y", currentPos[2]);

    if nextPos ~= currentPos then
        upcoming.frame:Show();
        upcoming:SetUserData("canvas-X", nextPos[1]);
        upcoming:SetUserData("canvas-Y", nextPos[2]);
    end
    image:DoLayout();
end

function ABP_Naxx:UIOnGroupJoined()
    self:SendComm(self.CommTypes.STATE_SYNC_REQUEST, {}, "BROADCAST");
end

function ABP_Naxx:UIOnStateSync(data, distribution, sender, version)
    if data.active then
        local player = UnitName("player");
        local _, map = self:GetRaiderSlots();
        local slot = map[player];
        local role = self.RaidRoles[data.roles[slot]];

        self:SendComm(self.CommTypes.STATE_SYNC_ACK, {
            role = role,
        }, "WHISPER", sender);

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

function ABP_Naxx:CreateMainWindow()
    local window = AceGUI:Create("Window");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("ABP Naxx Helper"), self:GetVersion()));
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
        tickElt:SetText(currentEncounter.started and ("Ticks: %d"):format(currentEncounter.ticks) or "Not Started");
        tickElt:SetJustifyH("RIGHT");
        mainLine:AddChild(tickElt);
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

        local tickTrigger = AceGUI:Create("Button");
        tickTrigger:SetFullWidth(true);
        tickTrigger:SetCallback("OnClick", function(widget)
            if currentEncounter then
                self:AdvanceEncounter();
            else
                window:SetUserData("tick", window:GetUserData("tick") + 1);
                Refresh();
            end
        end);
        mainLine:AddChild(tickTrigger);
        window:SetUserData("tickTrigger", tickTrigger);

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

    local image = AceGUI:Create("ABPN_ImageGroup");
    image:SetFullWidth(true);
    image:SetFullHeight(true);
    image:SetLayout("ABPN_Canvas");
    image:SetUserData("canvas-baseline", 225)
    image:SetImage("Interface\\AddOns\\ABP-Naxx\\Assets\\map.tga");
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

function ABP_Naxx:ShowMainWindow()
    if activeWindow then
        activeWindow:Hide();
        return;
    end

    activeWindow = self:CreateMainWindow();
    Refresh();
end
