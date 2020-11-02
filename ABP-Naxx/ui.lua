local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;
local AceGUI = _G.LibStub("AceGUI-3.0");

local table = table;
local pairs = pairs;

local activeWindow;

local pos = {
    healerTL = { 40, 25 },
    healerTR = { 65, 25 },
    healerBL = { 40, 60 },
    healerBR = { 65, 60 },

    tankdpsTL = { 29, 28 },
    tankdpsTR = { 76, 28 },
    tankdpsBL = { 29, 69 },
    tankdpsBR = { 76, 69 },

    safe = { 52, 52 },
};

local rotations = {
    tankdps1 = { name = "Tank/DPS 1", rotation = { [0] = pos.tankdpsBL, [3] = pos.safe, [6] = pos.tankdpsBR, [9] = pos.safe, [12] = pos.tankdpsBL } },
    tankdps2 = { name = "Tank/DPS 2", rotation = { [0] = pos.tankdpsBR, [3] = pos.safe, [6] = pos.tankdpsBL, [9] = pos.safe, [12] = pos.tankdpsBR } },
    tankdps3 = { name = "Tank/DPS 3", rotation = { [0] = pos.safe, [3] = pos.tankdpsBR, [6] = pos.safe, [9] = pos.tankdpsBL, [12] = pos.safe } },
    tankdps4 = { name = "Tank/DPS 4", rotation = { [0] = pos.safe, [3] = pos.tankdpsBL, [6] = pos.safe, [9] = pos.tankdpsBR, [12] = pos.safe } },

    ot1 = { name = "Off Tank 1", rotation = { [0] = pos.tankdpsTL, [3] = pos.safe, [6] = pos.tankdpsTR, [9] = pos.safe, [12] = pos.tankdpsTL } },
    ot2 = { name = "Off Tank 2", rotation = { [0] = pos.tankdpsTR, [3] = pos.safe, [6] = pos.tankdpsTL, [9] = pos.safe, [12] = pos.tankdpsTR } },
    ot3 = { name = "Off Tank 3", rotation = { [0] = pos.safe, [3] = pos.tankdpsTR, [6] = pos.safe, [9] = pos.tankdpsTL, [12] = pos.safe } },
    ot4 = { name = "Off Tank 4", rotation = { [0] = pos.safe, [3] = pos.tankdpsTL, [6] = pos.safe, [9] = pos.tankdpsTR, [12] = pos.safe } },

    healer1 = { name = "Healer 1-1", rotation = { [0] = pos.healerBL, [1] = pos.healerTL, [4] = pos.healerTR, [7] = pos.healerBR, [10] = pos.healerBL } },
    healer2 = { name = "Healer 1-2", rotation = { [0] = pos.healerBL, [2] = pos.healerTL, [5] = pos.healerTR, [8] = pos.healerBR, [11] = pos.healerBL } },
    healer3 = { name = "Healer 1-3", rotation = { [0] = pos.healerBL, [3] = pos.healerTL, [6] = pos.healerTR, [9] = pos.healerBR, [12] = pos.healerBL } },

    healer4 = { name = "Healer 2-1", rotation = { [0] = pos.healerTL, [1] = pos.healerTR, [4] = pos.healerBR, [7] = pos.healerBL, [10] = pos.healerTL } },
    healer5 = { name = "Healer 2-2", rotation = { [0] = pos.healerTL, [2] = pos.healerTR, [5] = pos.healerBR, [8] = pos.healerBL, [11] = pos.healerTL } },
    healer6 = { name = "Healer 2-3", rotation = { [0] = pos.healerTL, [3] = pos.healerTR, [6] = pos.healerBR, [9] = pos.healerBL, [12] = pos.healerTL } },

    healer7 = { name = "Healer 3-1", rotation = { [0] = pos.healerTR, [1] = pos.healerBR, [4] = pos.healerBL, [7] = pos.healerTL, [10] = pos.healerTR } },
    healer8 = { name = "Healer 3-2", rotation = { [0] = pos.healerTR, [2] = pos.healerBR, [5] = pos.healerBL, [8] = pos.healerTL, [11] = pos.healerTR } },
    healer9 = { name = "Healer 3-3", rotation = { [0] = pos.healerTR, [3] = pos.healerBR, [6] = pos.healerBL, [9] = pos.healerTL, [12] = pos.healerTR } },

    healer10 = { name = "Healer 4-1", rotation = { [0] = pos.healerBR, [1] = pos.healerBL, [4] = pos.healerTL, [7] = pos.healerTR, [10] = pos.healerBR } },
    healer11 = { name = "Healer 4-2", rotation = { [0] = pos.healerBR, [2] = pos.healerBL, [5] = pos.healerTL, [8] = pos.healerTR, [11] = pos.healerBR } },
    healer12 = { name = "Healer 4-3", rotation = { [0] = pos.healerBR, [3] = pos.healerBL, [6] = pos.healerTL, [9] = pos.healerTR, [12] = pos.healerBR } },
};

local roles = {};
local rolesSorted = {};
for key, data in pairs(rotations) do
    roles[key] = data.name;
    table.insert(rolesSorted, key);
    local pos = data.rotation[0];
    for i = 1, 12 do
        if not data.rotation[i] then
            data.rotation[i] = pos;
        end
        pos = data.rotation[i];
    end
end

table.sort(rolesSorted, function(a, b) return rotations[a].name < rotations[b].name end);

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

    local data = rotations[role];
    reset:SetDisabled(tick == -1);
    tickTrigger:SetDisabled(false);
    tickTrigger:SetText(tick == -1 and "Start" or ("Ticks: %d"):format(tick));
    current.frame:Show();

    local currentPos, nextPos;
    if tick == -1 then
        currentPos = data.rotation[0];
        nextPos = currentPos;
    else
        tick = tick % 12;
        currentPos = data.rotation[tick];
        nextPos = data.rotation[tick + 1];
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
    roleSelector:SetList(roles, rolesSorted);
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
