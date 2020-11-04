local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;
local AceGUI = _G.LibStub("AceGUI-3.0");

local table = table;
local pairs = pairs;

local activeWindow;

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
        reset:SetDisabled(true);
        tickTrigger:SetDisabled(true);
        tickTrigger:SetText("Ticks");
        return;
    end

    local rotation = ABP_Naxx.Rotations[role];
    reset:SetDisabled(tick == -1);
    tickTrigger:SetDisabled(false);
    tickTrigger:SetText(tick == -1 and "Start" or ("Ticks: %d"):format(tick));
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

    local roleSelector = AceGUI:Create("Dropdown");
    roleSelector:SetText("Choose a Role");
    roleSelector:SetWidth(160);
    roleSelector:SetList(self.RoleNames, self.RolesSorted);
    roleSelector:SetCallback("OnValueChanged", function(widget, event, value)
        window:SetUserData("role", value);
        window:SetUserData("tick", -1);
        Refresh();
    end);
    window:AddChild(roleSelector);

    local tickTrigger = AceGUI:Create("Button");
    tickTrigger:SetWidth(100);
    tickTrigger:SetCallback("OnClick", function(widget)
        window:SetUserData("tick", window:GetUserData("tick") + 1);
        Refresh();
    end);
    window:AddChild(tickTrigger);
    window:SetUserData("tickTrigger", tickTrigger);

    local reset = AceGUI:Create("Button");
    reset:SetText("Reset");
    reset:SetWidth(100);
    reset:SetCallback("OnClick", function(widget)
        window:SetUserData("tick", -1);
        Refresh();
    end);
    window:AddChild(reset);
    window:SetUserData("reset", reset);

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
