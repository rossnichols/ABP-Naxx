local _G = _G;
local AceGUI = _G.LibStub("AceGUI-3.0");
local AceGUI = _G.LibStub("AceGUI-3.0");

local CreateFrame = CreateFrame;
local pairs = pairs;

do
    local Type, Version = "ABP_Naxx_Image", 1;

    --[[-----------------------------------------------------------------------------
    Methods
    -------------------------------------------------------------------------------]]

    local methods = {
        ["OnAcquire"] = function(self)
            self:SetImage(nil);
        end,

        ["SetImage"] = function(self, image)
            self.image:SetTexture(image);
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local frame = CreateFrame("Frame");

        local image = frame:CreateTexture(nil, "ARTWORK");
        image:SetAllPoints();

        -- create widget
        local widget = {
            frame = frame,
            type  = Type,

            image = image,
        }
        for method, func in pairs(methods) do
            widget[method] = func
        end

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
