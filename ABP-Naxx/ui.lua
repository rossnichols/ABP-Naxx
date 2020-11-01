local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;
local AceGUI = _G.LibStub("AceGUI-3.0");

local UnitName = UnitName;
local UnitExists = UnitExists;
local IsInGroup = IsInGroup;
local GetAutoCompleteResults = GetAutoCompleteResults;
local SecondsToTime = SecondsToTime;
local AUTOCOMPLETE_FLAG_IN_GUILD = AUTOCOMPLETE_FLAG_IN_GUILD;
local AUTOCOMPLETE_FLAG_NONE = AUTOCOMPLETE_FLAG_NONE;
local date = date;
local table = table;
local ipairs = ipairs;
local pairs = pairs;
local unpack = unpack;
local select = select;
local type = type;

local activeWindow;

function ABP_Naxx:CreateMainWindow(command)
    local window = AceGUI:Create("Window");
    window.frame:SetFrameStrata("MEDIUM");
    window:SetTitle(("%s v%s"):format(self:ColorizeText("ABP Naxx Helper"), self:GetVersion()));
    window:SetLayout("Flow");
    self:BeginWindowManagement(window, "main", {
        version = 1,
        defaultWidth = 350,
        minWidth = 200,
        maxWidth = 650,
        defaultHeight = 320,
        minHeight = 200,
        maxHeight = 600
    });
    -- self:OpenWindow(window);
    window:SetCallback("OnClose", function(widget)
        self:EndWindowManagement(widget);
        -- self:CloseWindow(widget);
        AceGUI:Release(widget);
        activeWindow = nil;
    end);

    local image = AceGUI:Create("ABP_Naxx_Image");
    image:SetFullWidth(true);
    image:SetFullHeight(true);
    image:SetImage("Interface\\AddOns\\ABP-Naxx\\Assets\\map.tga");
    window:AddChild(image);

    window.frame:Raise();
    return window;
end

function ABP_Naxx:ShowMainWindow()
    if activeWindow then
        activeWindow:Hide();
        return;
    end

    activeWindow = self:CreateMainWindow();
end
