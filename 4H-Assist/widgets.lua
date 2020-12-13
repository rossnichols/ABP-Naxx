local _G = _G;
local AceGUI = _G.LibStub("AceGUI-3.0");

local CreateFrame = CreateFrame;
local ResetCursor = ResetCursor;
local IsModifiedClick = IsModifiedClick;
local GetItemInfo = GetItemInfo;
local CursorUpdate = CursorUpdate;
local select = select;
local pairs = pairs;
local ipairs = ipairs;
local geterrorhandler = geterrorhandler;
local xpcall = xpcall;

function ABP_4H:AddWidgetTooltip(widget, text)
    widget:SetCallback("OnEnter", function(widget)
        _G.GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT");
        _G.GameTooltip:SetText(text, nil, nil, nil, nil, true);
    end);
    widget:SetCallback("OnLeave", function(widget)
        _G.GameTooltip:Hide();
    end);
end

local function CreateFontString(frame, y)
    local fontstr = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal");
    fontstr:SetJustifyH("LEFT");
    if y then
        fontstr:SetPoint("LEFT", frame, 2, y);
        fontstr:SetPoint("RIGHT", frame, -2, y);
    else
        fontstr:SetPoint("LEFT", frame, 2, 1);
        fontstr:SetPoint("RIGHT", frame, -2, 1);
    end
    fontstr:SetWordWrap(false);

    return fontstr;
end

do
    local Type, Version = "ABPN_Label", 1;

    --[[-----------------------------------------------------------------------------
    Methods
    -------------------------------------------------------------------------------]]
    local methods = {
        ["OnAcquire"] = function(self)
            self.text:SetText("");
            self.frame:SetWidth(100);
            self.frame:SetHeight(16);
            self.text:SetJustifyH("LEFT");
            self.text:SetJustifyV("CENTER");
            self.text:SetPoint("LEFT", self.frame, 2, 1);
            self.text:SetPoint("RIGHT", self.frame, -2, 1);
            self.text:SetPoint("TOP", self.frame, 0, -2);
            self.text:SetPoint("BOTTOM", self.frame, 0, 2);
            self.text:SetWordWrap(false);
            self.highlight:Hide();

            self:SetFont(_G.GameFontHighlight);
            self:EnableMouse(false);
        end,

        ["EnableHighlight"] = function(self, enable)
            self.highlight[enable and "Show" or "Hide"](self.highlight);
        end,

        ["SetFont"] = function(self, font)
            self.text:SetFontObject(font);
        end,

        ["SetText"] = function(self, text)
            self.text:SetText(text);
        end,

        ["SetJustifyH"] = function(self, justify)
            self.text:SetJustifyH(justify);
        end,

        ["SetJustifyV"] = function(self, justify)
            self.text:SetJustifyV(justify);
        end,

        ["SetPadding"] = function(self, left, right)
            self.text:SetPoint("LEFT", self.frame, left, 1);
            self.text:SetPoint("RIGHT", self.frame, right, 1);
        end,

        ["SetWordWrap"] = function(self, enable)
            self.text:SetWordWrap(enable);
        end,

        ["EnableMouse"] = function(self, enable)
            self.frame:EnableMouse(enable);
        end,

        ["GetStringHeight"] = function(self)
            return self.text:GetStringHeight() + 4;
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local frame = CreateFrame("Button", nil, _G.UIParent);
        frame:SetHeight(16);
        frame:Hide();

        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp");
        frame:SetScript("OnClick", function(self, ...)
            self.obj:Fire("OnClick", ...);
        end);
        frame:SetScript("OnEnter", function(self, ...)
            self.obj:Fire("OnEnter", ...);
        end);
        frame:SetScript("OnLeave", function(self, ...)
            self.obj:Fire("OnLeave", ...);
        end);
        frame:SetHyperlinksEnabled(true);
        frame:SetScript("OnHyperlinkEnter", function(self, itemLink)
            _G.ShowUIPanel(_G.GameTooltip);
            _G.GameTooltip:SetOwner(self, "ANCHOR_NONE");
            _G.GameTooltip:ClearAllPoints();
            _G.GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT");
            _G.GameTooltip:SetHyperlink(itemLink);
            _G.GameTooltip:Show();
            self.hasItem = itemLink;
            CursorUpdate(self);
        end);
        frame:SetScript("OnHyperlinkLeave", function(self)
            _G.GameTooltip:Hide();
            self.hasItem = nil;
            ResetCursor();
        end);
        frame:SetScript("OnHyperlinkClick", function(self, itemLink, _, ...)
            if IsModifiedClick() then
                _G.HandleModifiedItemClick(select(2, GetItemInfo(itemLink)));
            else
                self:GetParent().obj:Fire("OnClick", ...);
            end
        end);
        frame:SetScript("OnUpdate", function(self)
            if _G.GameTooltip:IsOwned(self) and self.hasItem then
                _G.GameTooltip:SetOwner(self, "ANCHOR_NONE");
                _G.GameTooltip:ClearAllPoints();
                _G.GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT");
                _G.GameTooltip:SetHyperlink(self.hasItem);
                CursorUpdate(self);
            end
        end);

        local text = CreateFontString(frame);

        local highlight = frame:CreateTexture(nil, "HIGHLIGHT");
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight");
        highlight:SetAllPoints();
        highlight:SetBlendMode("ADD");
        highlight:SetTexCoord(0, 1, 0, 0.578125);

        -- create widget
        local widget = {
            text = text,
            highlight = highlight,

            frame = frame,
            type  = Type
        }
        for method, func in pairs(methods) do
            widget[method] = func
        end

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

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

        ["SetVisible"] = function(self, visible)
            if visible then
                self.frame:Show();
            else
                self.frame:Hide();
            end
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local frame = CreateFrame("Frame", nil, _G.UIParent);

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
    local Type, Version = "ABPN_TransparentGroup", 1;

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local elt = AceGUI:Create("SimpleGroup");
        if elt.frame.SetBackdropColor then
            elt.frame:SetBackdropColor(0, 0, 0, 0);
        end

        elt.type = Type;
        return elt;
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
            self:SetImageAlpha(1);
        end,

        ["SetImage"] = function(self, image)
            self.image:SetTexture(image);
        end,

        ["SetImageAlpha"] = function(self, alpha)
            self.image:SetAlpha(alpha);
        end,

        ["OnWidthSet"] = function(self, width)
            self:SimpleGroupOnWidthSet(width);
            self:Fire("OnWidthSet", width);
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local elt = AceGUI:Create("ABPN_TransparentGroup");
        if elt.frame.SetBackdropColor then
            elt.frame:SetBackdropColor(0, 0, 0, 0);
        end
        local image = elt.content:CreateTexture(nil, "ARTWORK");
        image:SetAllPoints();

        elt.type = Type;
        elt.SimpleGroupOnAcquire = elt.OnAcquire;
        elt.SimpleGroupOnWidthSet = elt.OnWidthSet;
        for method, func in pairs(methods) do
            elt[method] = func;
        end

        elt.image = image;

        return elt;
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

do
    local Type, Version = "ABPN_StatusBar", 1;

    local function Frame_OnUpdate(frame, elapsed)
        local self = frame.obj;
        self.elapsed = self.elapsed + elapsed;

        frame:SetValue(self.duration - self.elapsed);
        if self.elapsed >= self.duration then
            frame:SetScript("OnUpdate", nil);
        end
    end

    --[[-----------------------------------------------------------------------------
    Methods
    -------------------------------------------------------------------------------]]

    local methods = {
        ["OnAcquire"] = function(self)
            self:SetDuration(0);
        end,

        ["OnRelease"] = function(self)
            self:SetDuration(0);
        end,

        ["SetDuration"] = function(self, duration)
            local onUpdate;
            if duration > 0 then
                self.duration = duration;
                self.elapsed = 0;
                self.frame:SetMinMaxValues(0, duration);
                self.frame:SetValue(duration);
                onUpdate = Frame_OnUpdate;
            end

            self.frame:SetScript("OnUpdate", onUpdate);
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local frame = CreateFrame("StatusBar", nil, _G.UIParent);
        frame:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Resource-Fill", "ARTWORK");
        frame:SetStatusBarColor(1, 1, 1);

        -- create widget
        local widget = {
            frame = frame,
            type  = Type,
        }
        for method, func in pairs(methods) do
            widget[method] = func
        end

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

do
    local Type, Version = "ABPN_Button", 1;

    --[[-----------------------------------------------------------------------------
    Methods
    -------------------------------------------------------------------------------]]

    local methods = {
        ["OnAcquire"] = function(self)
            self:ButtonOnAcquire();
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local elt = AceGUI:Create("Button");

        elt.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp");

        elt.type = Type;
        elt.ButtonOnAcquire = elt.OnAcquire;
        for method, func in pairs(methods) do
            elt[method] = func;
        end

        return elt;
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

do
    local Type, Version = "ABPN_TransparentWindow", 1;

    --[[-----------------------------------------------------------------------------
    Methods
    -------------------------------------------------------------------------------]]

    local methods = {
        ["OnAcquire"] = function(self)
            self:WindowOnAcquire();
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local elt = AceGUI:Create("Window");
        elt.frame:SetClampedToScreen(true);
        if elt.frame.SetBackdropColor then
            elt.frame:SetBackdropColor(0, 0, 0, 0.25);
        end

        for i = 1, select("#", elt.frame:GetRegions()) do
            local region = select(i, elt.frame:GetRegions());
            if region and region:GetObjectType() == "Texture" and region:GetTexture() == "Interface/Tooltips/UI-Tooltip-Background" then
                region:SetVertexColor(0, 0, 0, 0.25);
            end
        end

        elt.type = Type;
        elt.WindowOnAcquire = elt.OnAcquire;
        for method, func in pairs(methods) do
            elt[method] = func;
        end

        return elt;
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

do
    local Type, Version = "ABPN_Window", 1;

    --[[-----------------------------------------------------------------------------
    Methods
    -------------------------------------------------------------------------------]]

    local methods = {
        ["OnAcquire"] = function(self)
            self:WindowOnAcquire();
        end,

        ["OnWidthSet"] = function(self, width)
            local oldContentWidth = self.content.width;
            self:WindowOnWidthSet(width);
            if self.content.width ~= oldContentWidth then
                self:Fire("OnWidthSet");
            end
        end,
    }

    --[[-----------------------------------------------------------------------------
    Constructor
    -------------------------------------------------------------------------------]]
    local function Constructor()
        local elt = AceGUI:Create("Window");

        elt.type = Type;
        elt.WindowOnAcquire = elt.OnAcquire;
        elt.WindowOnWidthSet = elt.OnWidthSet;
        for method, func in pairs(methods) do
            elt[method] = func;
        end

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
        local frame = child.frame;
        frame:ClearAllPoints();
        if child:GetUserData("canvas-fill") then
            frame:SetPoint("LEFT", content, "LEFT", child:GetUserData("canvas-left") or 0, 0);
            frame:SetPoint("TOP", content, "TOP", 0, child:GetUserData("canvas-top") or 0);
            frame:SetPoint("RIGHT", content, "RIGHT", child:GetUserData("canvas-right") or 0, 0);
            frame:SetPoint("BOTTOM", content, "BOTTOM", 0, child:GetUserData("canvas-bottom") or 0);
        elseif child:GetUserData("canvas-fill-scaled") then
            frame:SetPoint("LEFT", content, "LEFT", (child:GetUserData("canvas-left") or 0) * totalH / 100, 0);
            frame:SetPoint("TOP", content, "TOP", 0, (child:GetUserData("canvas-top") or 0) * totalV / 100);
            frame:SetPoint("RIGHT", content, "RIGHT", (child:GetUserData("canvas-right") or 0) * totalH / 100, 0);
            frame:SetPoint("BOTTOM", content, "BOTTOM", 0, (child:GetUserData("canvas-bottom") * totalV / 100 or 0));
        else
            local x, y = child:GetUserData("canvas-X") or 0, child:GetUserData("canvas-Y") or 0;
            frame:SetPoint("CENTER", content, "TOPLEFT", x * totalH / 100 / scale, -y * totalV / 100 / scale);
            frame:SetScale(scale);
        end
    end

    safecall(obj.LayoutFinished, obj, totalH, totalV);
    obj:ResumeLayout();
end);
