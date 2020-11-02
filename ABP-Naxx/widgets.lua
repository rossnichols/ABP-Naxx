local _G = _G;
local AceGUI = _G.LibStub("AceGUI-3.0");
local AceGUI = _G.LibStub("AceGUI-3.0");

local CreateFrame = CreateFrame;
local pairs = pairs;
local ipairs = ipairs;
local geterrorhandler = geterrorhandler;
local xpcall = xpcall;

do
    local Type, Version = "ABPN_Icon", 1;

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

do
    local Type, Version = "ABPN_ImageGroup", 1;

    --[[-----------------------------------------------------------------------------
    Methods
    -------------------------------------------------------------------------------]]

    local methods = {
        ["OnAcquire"] = function(self)
            self:SimpleGroupOnAcquire();
        end,

        ["SetImage"] = function(self, image)
            self.image:SetTexture(image);
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local elt = AceGUI:Create("SimpleGroup");

        local image = elt.content:CreateTexture(nil, "ARTWORK");
        image:SetAllPoints();
        -- background:SetPoint("TOPLEFT", 8, -24);
        -- background:SetPoint("BOTTOMRIGHT", -6, 8);

        elt.type = Type;
        elt.SimpleGroupOnAcquire = elt.OnAcquire;
        for method, func in pairs(methods) do
            elt[method] = func;
        end

        elt.image = image;

        return elt;
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

local function errorhandler(err)
    return geterrorhandler()(err)
end

local function safecall(func, ...)
    if func then
        return xpcall(func, errorhandler, ...)
    end
end

AceGUI:RegisterLayout("ABPN_Canvas", function (content, children)
    local obj = content.obj;
    obj:PauseLayout();

    local totalH = content:GetWidth() or content.width or 0;
    local totalV = content:GetHeight() or content.height or 0;
    local baseline = obj:GetUserData("canvas-baseline");
    local scale = ((totalH + totalV) / 2) / baseline;

    for i, child in ipairs(children) do
        local x, y = child:GetUserData("canvas-X") or 0, child:GetUserData("canvas-Y") or 0;
        local frame = child.frame;
        frame:ClearAllPoints();
        frame:SetPoint("CENTER", content, "TOPLEFT", x * totalH / 100 / scale, -y * totalV / 100 / scale);
        frame:SetScale(scale);
    end

    safecall(obj.LayoutFinished, obj, totalH, totalV);
    obj:ResumeLayout();
end);
