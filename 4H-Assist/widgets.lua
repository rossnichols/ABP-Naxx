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
local ceil = ceil;
local unpack = unpack;
local wipe = table.wipe;
local min = min;
local max = max;
local type = type;

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
        if elt.frame.SetBackdropBorderColor then
            elt.frame:SetBackdropBorderColor(0, 0, 0, 0);
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

local function pickfirstset(...)
    for i=1,select("#",...) do
        if select(i,...)~=nil then
            return select(i,...)
        end
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
        local canvas = child:GetUserData("canvas");
        if canvas == "fill" or child:GetUserData("canvas-fill") then
            frame:SetPoint("LEFT", content, "LEFT", child:GetUserData("canvas-left") or 0, 0);
            frame:SetPoint("TOP", content, "TOP", 0, child:GetUserData("canvas-top") or 0);
            frame:SetPoint("RIGHT", content, "RIGHT", child:GetUserData("canvas-right") or 0, 0);
            frame:SetPoint("BOTTOM", content, "BOTTOM", 0, child:GetUserData("canvas-bottom") or 0);
        elseif canvas == "outside-left" or child:GetUserData("canvas-outside-left") then
            frame:SetPoint("LEFT", _G.UIParent, "LEFT", 0, 0);
            frame:SetPoint("TOP", content, "TOP", 0, child:GetUserData("canvas-top") or 0);
            frame:SetPoint("RIGHT", content, "LEFT", child:GetUserData("canvas-right") or 0, 0);
            frame:SetPoint("BOTTOM", content, "BOTTOM", 0, child:GetUserData("canvas-bottom") or 0);
        elseif canvas == "outside-right" or child:GetUserData("canvas-outside-right") then
            frame:SetPoint("LEFT", content, "RIGHT", child:GetUserData("canvas-left") or 0, 0);
            frame:SetPoint("TOP", content, "TOP", 0, child:GetUserData("canvas-top") or 0);
            frame:SetPoint("RIGHT", _G.UIParent, "RIGHT", 0, 0);
            frame:SetPoint("BOTTOM", content, "BOTTOM", 0, child:GetUserData("canvas-bottom") or 0);
        elseif canvas == "fill-scaled" or child:GetUserData("canvas-fill-scaled") then
            frame:SetPoint("LEFT", content, "LEFT", (child:GetUserData("canvas-left") or 0) * totalH / 100, 0);
            frame:SetPoint("TOP", content, "TOP", 0, (child:GetUserData("canvas-top") or 0) * totalV / 100);
            frame:SetPoint("RIGHT", content, "RIGHT", (child:GetUserData("canvas-right") or 0) * totalH / 100, 0);
            frame:SetPoint("BOTTOM", content, "BOTTOM", 0, (child:GetUserData("canvas-bottom") * totalV / 100 or 0));
        elseif child:GetUserData("canvas-X") or child:GetUserData("canvas-Y") then
            local x, y = child:GetUserData("canvas-X") or 0, child:GetUserData("canvas-Y") or 0;
            frame:SetPoint("CENTER", content, "TOPLEFT", x * totalH / 100 / scale, -y * totalV / 100 / scale);
            frame:SetScale(scale);
        end
    end

    safecall(obj.LayoutFinished, obj, totalH, totalV);
    obj:ResumeLayout();
end);

-- Get alignment method and value. Possible alignment methods are a callback, a number, "start", "middle", "end", "fill" or "TOPLEFT", "BOTTOMRIGHT" etc.
local GetCellAlign = function (dir, tableObj, colObj, cellObj, cell, child)
    local fn = cellObj and (cellObj["align" .. dir] or cellObj.align)
            or colObj and (colObj["align" .. dir] or colObj.align)
            or tableObj["align" .. dir] or tableObj.align
            or "CENTERLEFT"
    local child, cell, val = child or 0, cell or 0, nil

    if type(fn) == "string" then
        fn = fn:lower()
        fn = dir == "V" and (fn:sub(1, 3) == "top" and "start" or fn:sub(1, 6) == "bottom" and "end" or fn:sub(1, 6) == "center" and "middle")
          or dir == "H" and (fn:sub(-4) == "left" and "start" or fn:sub(-5) == "right" and "end" or fn:sub(-6) == "center" and "middle")
          or fn
        val = (fn == "start" or fn == "fill") and 0 or fn == "end" and cell - child or (cell - child) / 2
    elseif type(fn) == "function" then
        val = fn(child or 0, cell, dir)
    else
        val = fn
    end

    return fn, max(0, min(val, cell))
end

-- Get width or height for multiple cells combined
local GetCellDimension = function(_, laneDim, from, to, space)
    local dim = 0
    for cell=from,to do
        dim = dim + (laneDim[cell] or 0)
    end
    return dim + max(0, to - from) * (space or 0)
end

--[[ Options
============
Container:
 - columns ({col, col, ...}): Column settings. "col" can be a number (<= 0: content width, <1: rel. width, <10: weight, >=10: abs. width) or a table with column setting.
 - rows ({row, row, ...}): Row settings. "row" can be a number (<= 0: content height, <1: rel. height, <10: weight, >=10: abs. height) or a table with row setting.
 - space, spaceH, spaceV: Overall, horizontal and vertical spacing between cells.
 - align, alignH, alignV: Overall, horizontal and vertical cell alignment. See GetCellAlign() for possible values.
Columns:
 - width: Fixed column width (nil or <=0: content width, <1: rel. width, >=1: abs. width).
 - min or 1: Min width for content based width
 - max or 2: Max width for content based width
 - weight: Flexible column width. The leftover width after accounting for fixed-width columns is distributed to weighted columns according to their weights.
 - align, alignH, alignV: Overwrites the container setting for alignment.
Rows:
 - height: Fixed column height (nil or <=0: content height, <1: rel. height, >=1: abs. height).
 - weight: Flexible column height. The leftover height after accounting for fixed-height rows is distributed to weighted rows according to their weights.
Cell:
 - colspan: Makes a cell span multiple columns.
 - rowspan: Makes a cell span multiple rows.
 - align, alignH, alignV: Overwrites the container and column setting for alignment.
 - paddingLeft, paddingTop, paddingRight, paddingBottom, paddingH, paddingV, padding: Adds padding for an individual cell
]]
AceGUI:RegisterLayout("ABPN_Table", function (content, children)
    local obj = content.obj
    obj:PauseLayout()

    local tableObj = obj:GetUserData("table")
    local cols = tableObj.columns
    local rowObjs = tableObj.rows or {};
    local spaceH = tableObj.spaceH or tableObj.space or 0
    local spaceV = tableObj.spaceV or tableObj.space or 0
    local totalH = (content:GetWidth() or content.width or 0) - spaceH * (#cols - 1)

    -- We need to reuse these because layout events can come in very frequently
    local layoutCache = obj:GetUserData("layoutCache")
    if not layoutCache then
        layoutCache = {{}, {}, {}, {}, {}, {}}
        obj:SetUserData("layoutCache", layoutCache)
    end
    local t, laneH, laneV, rowspans, rowStart, colStart = unpack(layoutCache)

    -- Create the grid
    local n, slotFound = 0
    for i,child in ipairs(children) do
        if child:IsShown() then
            repeat
                n = n + 1
                local col = (n - 1) % #cols + 1
                local row = ceil(n / #cols)
                local rowspan = rowspans[col]
                local cell = rowspan and rowspan.child or child
                local cellObj = cell:GetUserData("cell")
                slotFound = not rowspan

                -- Rowspan
                if not rowspan and cellObj and cellObj.rowspan then
                    rowspan = {child = child, from = row, to = row + cellObj.rowspan - 1}
                    rowspans[col] = rowspan
                end
                if rowspan and i == #children then
                    rowspan.to = row
                end

                -- Colspan
                local colspan = max(0, min((cellObj and cellObj.colspan or 1) - 1, #cols - col))
                n = n + colspan

                -- Place the cell
                if not rowspan or rowspan.to == row then
                    t[n] = cell
                    rowStart[cell] = rowspan and rowspan.from or row
                    colStart[cell] = col

                    if rowspan then
                        rowspans[col] = nil
                    end
                end
            until slotFound
        end
    end

    local rows = ceil(n / #cols)
    local totalV = (content:GetHeight() or content.height or 0) - spaceV * (rows - 1)

    -- Determine fixed size cols and collect weights
    local extantH, totalWeight = totalH, 0
    for col,colObj in ipairs(cols) do
        laneH[col] = 0

        if type(colObj) == "number" then
            colObj = {[colObj >= 1 and colObj < 10 and "weight" or "width"] = colObj}
            cols[col] = colObj
        end

        if colObj.weight then
            -- Weight
            totalWeight = totalWeight + (colObj.weight or 1)
        else
            if not colObj.width or colObj.width <= 0 then
                -- Content width
                for row=1,rows do
                    local child = t[(row - 1) * #cols + col]
                    if child then
                        local f = child.frame
                        f:ClearAllPoints()
                        local childH = f:GetWidth() or 0

                        laneH[col] = max(laneH[col], childH - GetCellDimension("H", laneH, colStart[child], col - 1, spaceH))
                    end
                end

                laneH[col] = max(colObj.min or colObj[1] or 0, min(laneH[col], colObj.max or colObj[2] or laneH[col]))
            else
                -- Rel./Abs. width
                laneH[col] = colObj.width < 1 and colObj.width * totalH or colObj.width
            end
            extantH = max(0, extantH - laneH[col])
        end
    end

    -- Determine sizes based on weight
    local scale = totalWeight > 0 and extantH / totalWeight or 0
    for col,colObj in pairs(cols) do
        if colObj.weight then
            laneH[col] = scale * colObj.weight
        end
    end

    local extantV, totalWeight = totalV, 0
    for row,rowObj in pairs(rowObjs) do
        if type(rowObj) == "number" then
            rowObj = {[rowObj >= 1 and rowObj < 10 and "weight" or "height"] = rowObj}
            rowObjs[row] = rowObj;
        end
    end

    -- Arrange children
    for row=1,rows do
        local rowV = 0

        local rowObj = rowObjs[row];
        if not rowObj then
            rowObj = { height = 0 };
            rowObjs[row] = rowObj;
        end

        if rowObj.weight then
            -- Weight
            totalWeight = totalWeight + (rowObj.weight or 1)
        end

        -- Horizontal placement and sizing
        for col=1,#cols do
            local child = t[(row - 1) * #cols + col]
            if child then
                local colObj = cols[colStart[child]]
                local cellObj = child:GetUserData("cell")
                local offsetH = GetCellDimension("H", laneH, 1, colStart[child] - 1, spaceH) + (colStart[child] == 1 and 0 or spaceH)
                local cellH = GetCellDimension("H", laneH, colStart[child], col, spaceH)
                local paddingLeft, paddingRight = 0, 0
                if cellObj then
                    paddingLeft = pickfirstset(cellObj.paddingLeft, cellObj.paddingH, cellObj.padding, 0)
                    paddingRight = pickfirstset(cellObj.paddingRight, cellObj.paddingH, cellObj.padding, 0)
                end
                cellH = cellH - paddingLeft - paddingRight

                local f = child.frame
                f:ClearAllPoints()
                local childH = f:GetWidth() or 0

                local alignFn, align = GetCellAlign("H", tableObj, colObj, cellObj, cellH, childH)
                f:SetPoint("LEFT", content, offsetH + align + paddingLeft, 0)
                if child:IsFullWidth() or alignFn == "fill" or childH > cellH then
                    f:SetPoint("RIGHT", content, "LEFT", offsetH + align + paddingLeft + cellH, 0)
                end

                if child.DoLayout then
                    child:DoLayout()
                end

                if not rowObj.weight then
                    if not rowObj.height or rowObj.height <= 0 then
                        -- Content height
                        rowV = max(rowV, (f:GetHeight() or 0) - GetCellDimension("V", laneV, rowStart[child], row - 1, spaceV))
                    else
                        -- Rel./Abs. height
                        rowV = rowObj.height < 1 and rowObj.height * totalV or rowObj.height
                    end
                end
            end
        end

        laneV[row] = rowV
        extantV = max(0, extantV - laneV[row])
    end

    local scale = totalWeight > 0 and extantV / totalWeight or 0
    for row,rowObj in pairs(rowObjs) do
        if rowObj.weight then
            laneV[row] = scale * rowObj.weight
        end
    end

    for row=1,rows do
        -- Vertical placement and sizing
        for col=1,#cols do
            local child = t[(row - 1) * #cols + col]
            if child then
                local colObj = cols[colStart[child]]
                local cellObj = child:GetUserData("cell")
                local offsetV = GetCellDimension("V", laneV, 1, rowStart[child] - 1, spaceV) + (rowStart[child] == 1 and 0 or spaceV)
                local cellV = GetCellDimension("V", laneV, rowStart[child], row, spaceV)
                local paddingTop, paddingBottom = 0, 0
                if cellObj then
                    paddingTop = pickfirstset(cellObj.paddingTop, cellObj.paddingV, cellObj.padding, 0)
                    paddingBottom = pickfirstset(cellObj.paddingBottom, cellObj.paddingV, cellObj.padding, 0)
                end
                cellV = cellV - paddingTop - paddingBottom

                local f = child.frame
                local childV = f:GetHeight() or 0

                local alignFn, align = GetCellAlign("V", tableObj, colObj, cellObj, cellV, childV)
                if child:IsFullHeight() or alignFn == "fill" then
                    f:SetPoint("BOTTOM", content, "TOP", 0, -(offsetV + align + paddingTop + cellV))
                end
                f:SetPoint("TOP", content, 0, -(offsetV + align + paddingTop))
            end
        end
    end

    -- Calculate total height
    local totalV = GetCellDimension("V", laneV, 1, #laneV, spaceV)

    -- Cleanup
    for _,v in pairs(layoutCache) do wipe(v) end

    safecall(obj.LayoutFinished, obj, nil, totalV)
    obj:ResumeLayout()
end)
