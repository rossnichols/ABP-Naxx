local _G = _G;
_G.ABP_Naxx = _G.LibStub("AceAddon-3.0"):NewAddon("ABP_Naxx", "AceConsole-3.0", "AceComm-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0");
local ABP_Naxx = _G.ABP_Naxx;
local AceGUI = _G.LibStub("AceGUI-3.0");

local UnitExists = UnitExists;
local UnitClass = UnitClass;
local UnitGUID = UnitGUID;
local UnitName = UnitName;
local GuildRoster = GuildRoster;
local GetChatWindowInfo = GetChatWindowInfo;
local UnitAffectingCombat = UnitAffectingCombat;
local CreateFrame = CreateFrame;
local GetItemInfo = GetItemInfo;
local IsInGroup = IsInGroup;
local GetInstanceInfo = GetInstanceInfo;
local IsInGuild = IsInGuild;
local C_GuildInfo = C_GuildInfo;
local GetAddOnMetadata = GetAddOnMetadata;
local GetServerTime = GetServerTime;
local UnitIsGroupLeader = UnitIsGroupLeader;
local IsEquippableItem = IsEquippableItem;
local IsAltKeyDown = IsAltKeyDown;
local GetClassColor = GetClassColor;
local EasyMenu = EasyMenu;
local ToggleDropDownMenu = ToggleDropDownMenu;
local select = select;
local pairs = pairs;
local ipairs = ipairs;
local tonumber = tonumber;
local table = table;
local tostring = tostring;
local min = min;
local max = max;
local date = date;
local type = type;

local version = "${ADDON_VERSION}";

_G.BINDING_HEADER_ABP_NAXX = "ABP Naxx Helper";
_G.BINDING_NAME_ABP_NAXX_OPENMAINWINDOW = "Open the main window";
_G.BINDING_NAME_ABP_NAXX_OPENSTARTWINDOW = "Open the start window";

local function OnGroupJoined(self)
    self:VersionOnGroupJoined();
    self:UIOnGroupJoined();
end

function ABP_Naxx:OnEnable()
    if GetAddOnMetadata("ABP-Naxx", "Version") ~= version then
        self:NotifyVersionMismatch();
        self:RegisterChatCommand("ABP_Naxx", function()
            self:Error("Please restart your game client!");
        end);
        return;
    end

    self:RegisterComm("ABPN");
    self:RegisterComm(self:GetCommPrefix());
    self:InitOptions();

    -- Trigger a guild roster update to refresh priorities.
    GuildRoster();

    self:SetCallback(self.CommTypes.STATE_SYNC.name, function(self, event, data, distribution, sender, version)
        self:UIOnStateSync(data, distribution, sender, version);
    end, self);
    self:SetCallback(self.CommTypes.STATE_SYNC_ACK.name, function(self, event, data, distribution, sender, version)
        self:DriverOnStateSyncAck(data, distribution, sender, version);
    end, self);
    self:SetCallback(self.CommTypes.STATE_SYNC_REQUEST.name, function(self, event, data, distribution, sender, version)
        self:DriverOnStateSyncRequest(data, distribution, sender, version);
    end, self);

    self:RegisterEvent("GUILD_ROSTER_UPDATE", function(self, event, ...)
        self:RebuildGuildInfo();
        self:VersionOnGuildRosterUpdate();
    end, self);
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(self, event, ...)
        self:VersionOnEnteringWorld(...);
    end, self);
    self:RegisterEvent("GROUP_JOINED", function(self, event, ...)
        OnGroupJoined(self);
    end, self);
    self:RegisterEvent("GROUP_LEFT", function(self, event, ...)
        self:UIOnGroupLeft();
    end, self);
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function(self, event, ...)
        self:DriverOnGroupUpdate();
    end, self);
    self:RegisterEvent("PLAYER_LOGOUT", function(self, event, ...)
        self:DriverOnLogout();
    end, self);
    self:RegisterEvent("ENCOUNTER_START", function(self, event, ...)
        self:DriverOnEncounterStart(...);
    end, self);
    self:RegisterEvent("ENCOUNTER_END", function(self, event, ...)
        self:DriverOnEncounterEnd(...);
    end, self);
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(self, event, ...)
        self:DriverOnSpellCast(...);
    end, self);

    -- Precreate frames to avoid issues generating them during combat.
    if not UnitAffectingCombat("player") then
        AceGUI:Release(self:CreateMainWindow());
    end

    if IsInGroup() then
        OnGroupJoined(self);
    end
end


--
-- Helpers for chat messages and colorization
--

local function GetSystemFrame()
    for i = 1, _G.NUM_CHAT_WINDOWS do
        local shown = select(7, GetChatWindowInfo(i));
        if shown then
            local frame = _G["ChatFrame" .. i];
            for _, type in ipairs(frame.messageTypeList) do
                if type == "SYSTEM" then
                    return frame;
                end
            end
        end
    end

    return _G.DEFAULT_CHAT_FRAME;
end

ABP_Naxx.Color = "|cFF94E4FF";
ABP_Naxx.ColorTable = { 0.58, 0.89, 1, r = 0.58, g = 0.89, b = 1 };
function ABP_Naxx:Notify(str, ...)
    local msg = ("%s: %s"):format(self:ColorizeText("ABP-Naxx"), tostring(str):format(...));
    GetSystemFrame():AddMessage(msg, 1, 1, 1);
end

function ABP_Naxx:LogDebug(str, ...)
    if self:GetDebugOpt() then
        self:Notify(str, ...);
    end
end

function ABP_Naxx:LogVerbose(str, ...)
    if self:GetDebugOpt("Verbose") then
        self:Notify(str, ...);
    end
end

function ABP_Naxx:Error(str, ...)
    self:Notify("|cffff0000ERROR:|r " .. str, ...);
end

function ABP_Naxx:Alert(str, ...)
    local msg = ("%s: %s"):format(self:ColorizeText("ABP-Naxx"), tostring(str):format(...));
    _G.RaidNotice_AddMessage(_G.RaidWarningFrame, msg, { r = 1, g = 1, b = 1 });
    self:Notify(str, ...);
end

function ABP_Naxx:ColorizeText(text)
    return ("%s%s|r"):format(ABP_Naxx.Color, text);
end

function ABP_Naxx:ColorizeName(name, class)
    if not class then
        if UnitExists(name) then
            local _, className = UnitClass(name);
            class = className;
        end
    end
    if not class then
        local guildInfo = self:GetGuildInfo(name);
        if guildInfo then
            class = guildInfo[11];
        end
    end
    if not class then return name; end
    local color = select(4, GetClassColor(class));
    return ("|c%s%s|r"):format(color, name);
end


--
-- Helpers for privilege checks
--

function ABP_Naxx:IsPrivileged()
    -- Check officer status by looking for the privilege to speak in officer chat.
    local isOfficer = C_GuildInfo.GuildControlGetRankFlags(C_GuildInfo.GetGuildRankOrder(UnitGUID("player")))[4];
    return isOfficer or self:GetDebugOpt();
end

function ABP_Naxx:CanEditPublicNotes()
    return C_GuildInfo.GuildControlGetRankFlags(C_GuildInfo.GetGuildRankOrder(UnitGUID("player")))[10];
end

function ABP_Naxx:CanEditOfficerNotes(player)
    local guid = UnitGUID("player");
    if player then
        local guildInfo = self:GetGuildInfo(player);
        if not guildInfo then return false; end
        guid = guildInfo[17];
    end
    return C_GuildInfo.GuildControlGetRankFlags(C_GuildInfo.GetGuildRankOrder(guid))[12];
end


--
-- Hook for CloseSpecialWindows to allow our UI windows to close on Escape.
--

local openWindows = {};
local openPopups = {};
local function CloseABP_NaxxWindows(t)
    local found = false;
    for window in pairs(t) do
        found = true;
        window:Hide();
    end
    return found;
end

function ABP_Naxx:CloseSpecialWindows()
    local found = self.hooks.CloseSpecialWindows();
    return CloseABP_NaxxWindows(openWindows) or found;
end
ABP_Naxx:RawHook("CloseSpecialWindows", true);

function ABP_Naxx:StaticPopup_EscapePressed()
    local found = self.hooks.StaticPopup_EscapePressed();
    return CloseABP_NaxxWindows(openPopups) or found;
end
ABP_Naxx:RawHook("StaticPopup_EscapePressed", true);

function ABP_Naxx:OpenWindow(window)
    openWindows[window] = true;
end

function ABP_Naxx:CloseWindow(window)
    openWindows[window] = nil;
end

function ABP_Naxx:OpenPopup(window)
    openPopups[window] = true;
end

function ABP_Naxx:ClosePopup(window)
    openPopups[window] = nil;
end


--
-- Support for maintaining window positions/sizes across reloads/relogs
--

_G.ABP_Naxx_WindowManagement = {};

function ABP_Naxx:BeginWindowManagement(window, name, defaults)
    _G.ABP_Naxx_WindowManagement[name] = _G.ABP_Naxx_WindowManagement[name] or {};
    local saved = _G.ABP_Naxx_WindowManagement[name];
    if not defaults.version or saved.version ~= defaults.version then
        table.wipe(saved);
        saved.version = defaults.version;
    end

    defaults.minWidth = defaults.minWidth or defaults.defaultWidth;
    defaults.maxWidth = defaults.maxWidth or defaults.defaultWidth;
    defaults.minHeight = defaults.minHeight or defaults.defaultHeight;
    defaults.maxHeight = defaults.maxHeight or defaults.defaultHeight;

    local management = { name = name, defaults = defaults };
    window:SetUserData("windowManagement", management);

    saved.width = min(max(defaults.minWidth, saved.width or defaults.defaultWidth), defaults.maxWidth);
    saved.height = min(max(defaults.minHeight, saved.height or defaults.defaultHeight), defaults.maxHeight);
    window:SetStatusTable(saved);

    management.oldMinW, management.oldMinH = window.frame:GetMinResize();
    management.oldMaxW, management.oldMaxH = window.frame:GetMaxResize();
    window.frame:SetMinResize(defaults.minWidth, defaults.minHeight);
    window.frame:SetMaxResize(defaults.maxWidth, defaults.maxHeight);

    if defaults.minWidth == defaults.maxWidth and defaults.minHeight == defaults.maxHeight then
        window.line1:Hide();
        window.line2:Hide();
    end
end

function ABP_Naxx:EndWindowManagement(window)
    local management = window:GetUserData("windowManagement");
    local name = management.name;
    _G.ABP_Naxx_WindowManagement[name] = _G.ABP_Naxx_WindowManagement[name] or {};
    local saved = _G.ABP_Naxx_WindowManagement[name];

    saved.left = window.frame:GetLeft();
    saved.top = window.frame:GetTop();
    saved.width = window.frame:GetWidth();
    saved.height = window.frame:GetHeight();
    window.frame:SetMinResize(management.oldMinW, management.oldMinH);
    window.frame:SetMaxResize(management.oldMaxW, management.oldMaxH);
    window.line1:Show();
    window.line2:Show();

    self:HideContextMenu();
end


--
-- Context Menu support (https://wow.gamepedia.com/UI_Object_UIDropDownMenu)
--

local contextFrame = CreateFrame("Frame", "ABP_NaxxContextMenu", _G.UIParent, "UIDropDownMenuTemplate");
contextFrame.relativePoint = "BOTTOMRIGHT";
function ABP_Naxx:ShowContextMenu(context, frame)
    if self:IsContextMenuOpen() then
        self:HideContextMenu();
    else
        EasyMenu(context, contextFrame, frame or "cursor", 3, -3, "MENU");
    end
end

function ABP_Naxx:IsContextMenuOpen()
    return (_G.UIDROPDOWNMENU_OPEN_MENU == contextFrame);
end

function ABP_Naxx:HideContextMenu()
    if self:IsContextMenuOpen() then
        ToggleDropDownMenu(nil, nil, contextFrame);
    end
end


--
-- Util
--

ABP_Naxx.tCompare = function(lhsTable, rhsTable, depth)
    depth = depth or 1;
    for key, value in pairs(lhsTable) do
        if type(value) == "table" then
            local rhsValue = rhsTable[key];
            if type(rhsValue) ~= "table" then
                return false;
            end
            if depth > 1 then
                if not ABP_Naxx.tCompare(value, rhsValue, depth - 1) then
                    return false;
                end
            end
        elseif value ~= rhsTable[key] then
            -- print("mismatched value: " .. key .. ": " .. tostring(value) .. ", " .. tostring(rhsTable[key]));
            return false;
        end
    end
    -- Check for any keys that are in rhsTable and not lhsTable.
    for key in pairs(rhsTable) do
        if lhsTable[key] == nil then
            -- print("mismatched key: " .. key);
            return false;
        end
    end
    return true;
end

ABP_Naxx.tCopy = function(t)
    local copy = {};
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = ABP_Naxx.tCopy(v)
        else
            copy[k] = v;
        end
    end
    return copy;
end

ABP_Naxx.reverse = function(arr)
    local i, j = 1, #arr;
    while i < j do
        arr[i], arr[j] = arr[j], arr[i];
        i = i + 1;
        j = j - 1;
    end
end


--
-- Static dialog templates
--

ABP_Naxx.StaticDialogTemplates = {
    JUST_BUTTONS = "JUST_BUTTONS",
    EDIT_BOX = "EDIT_BOX",
};

function ABP_Naxx:StaticDialogTemplate(template, t)
    t.timeout = 0;
    t.whileDead = true;
    t.hideOnEscape = true;
    if t.exclusive == nil then
        t.exclusive = true;
    end
    t.OnHyperlinkEnter = function(self, itemLink)
        _G.ShowUIPanel(_G.GameTooltip);
        _G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOM");
        _G.GameTooltip:SetHyperlink(itemLink);
        _G.GameTooltip:Show();
    end;
    t.OnHyperlinkLeave = function(self)
        _G.GameTooltip:Hide();
    end;

    if template == ABP_Naxx.StaticDialogTemplates.JUST_BUTTONS then
        return t;
    elseif template == ABP_Naxx.StaticDialogTemplates.EDIT_BOX then
        t.hasEditBox = true;
        t.countInvisibleLetters = true;
        t.OnAccept = function(self, data)
            local text = self.editBox:GetText();
            if t.Validate then
                text = t.Validate(text, data);
                if text then
                    t.Commit(text, data);
                end
            else
                t.Commit(text, data);
            end
        end;
        t.OnShow = function(self, data)
            self.editBox:SetAutoFocus(false);
            if t.Validate then
                self.button1:Disable();
            end
            if t.notFocused then
                self.editBox:ClearFocus();
            end
        end;
        t.EditBoxOnTextChanged = function(self, data)
            if t.Validate then
                local parent = self:GetParent();
                local text = self:GetText();
                if t.Validate(text, data) then
                    parent.button1:Enable();
                else
                    parent.button1:Disable();
                end
            end
        end;
        t.EditBoxOnEnterPressed = function(self, data)
            if t.suppressEnterCommit then return; end

            local parent = self:GetParent();
            local text = self:GetText();
            if t.Validate then
                if parent.button1:IsEnabled() then
                    parent.button1:Click();
                else
                    local _, errorText = t.Validate(text, data);
                    if errorText then ABP_Naxx:Error("Invalid input! %s.", errorText); end
                end
            else
                parent.button1:Click();
            end
        end;
        t.EditBoxOnEscapePressed = function(self)
            self:ClearFocus();
        end;
        t.OnHide = function(self, data)
            self.editBox:SetAutoFocus(true);
        end;
        return t;
    end
end

StaticPopupDialogs["ABP_NAXX_PROMPT_RELOAD"] = ABP_Naxx:StaticDialogTemplate(ABP_Naxx.StaticDialogTemplates.JUST_BUTTONS, {
    text = "%s",
    button1 = "Reload",
    button2 = "Close",
    showAlert = true,
    OnAccept = ReloadUI,
});
