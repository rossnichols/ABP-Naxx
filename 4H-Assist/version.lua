local _G = _G;
local ABP_4H = _G.ABP_4H;

local IsInGroup = IsInGroup;
local GetNumGroupMembers = GetNumGroupMembers;
local IsInRaid = IsInRaid;
local UnitName = UnitName;
local UnitIsConnected = UnitIsConnected;
local GetAddOnMetadata = GetAddOnMetadata;
local Ambiguate = Ambiguate;
local tonumber = tonumber;
local math = math;

local versionCheckData;
local showedNagPopup = false;
local checkedGuild = false;

function ABP_4H:GetVersion()
    local version = GetAddOnMetadata("4H-Assist", "Version");
    if version == "${ADDON_VERSION}" then
        return self.VersionOverride;
    end
    return version;
end

function ABP_4H:GetCompareVersion()
    local version = GetAddOnMetadata("4H-Assist", "Version");
    if version == "${ADDON_VERSION}" then
        return self.VersionCmpOverride;
    end
    return version;
end

function ABP_4H:ParseVersion(version)
    local major, minor, patch, prerelType, prerelVersion = version:match("^(%d+)%.(%d+)%.(%d+)%-?(%a*)(%d*)$");
    if not (major and minor and patch) then return; end
    if prerelType == "" then prerelType = nil; end
    if prerelVersion == "" then prerelVersion = nil; end

    return tonumber(major), tonumber(minor), tonumber(patch), prerelType, tonumber(prerelVersion);
end

function ABP_4H:VersionIsNewer(versionCmp, version, allowPrerelease)
    if versionCmp == version then return false; end

    local major, minor, patch, prerelType, prerelVersion = self:ParseVersion(version);
    local majorCmp, minorCmp, patchCmp, prerelTypeCmp, prerelVersionCmp = self:ParseVersion(versionCmp);
    -- print(major, minor, patch, prerel, majorCmp, minorCmp, patchCmp, prerelCmp);
    if not (major and minor and patch and majorCmp and minorCmp and patchCmp) then return false; end

    if not allowPrerelease then
        -- if the compared version is prerelease, the current one must be as well.
        if prerelTypeCmp and not prerelType then return false; end
    end

    if majorCmp ~= major then
        return majorCmp > major;
    elseif minorCmp ~= minor then
        return minorCmp > minor;
    elseif patchCmp ~= patch then
        return patchCmp > patch;
    elseif (prerelTypeCmp ~= nil) ~= (prerelType ~= nil) then
        return prerelTypeCmp == nil;
    elseif prerelTypeCmp ~= prerelType then
        return prerelTypeCmp > prerelType;
    elseif prerelVersionCmp ~= prerelVersion then
        return prerelVersionCmp > prerelVersion;
    else
        return false;
    end
end

local function CompareVersion(versionCmp, sender)
    -- See if we've already told the user to upgrade
    if showedNagPopup then return; end

    -- See if we're already running this version
    local version = ABP_4H:GetCompareVersion();
    if versionCmp == version then return; end

    -- Make sure the version strings are valid
    if not (ABP_4H:ParseVersion(version) and ABP_4H:ParseVersion(versionCmp)) then return; end

    if ABP_4H:VersionIsNewer(versionCmp, version) then
        if ABP_4H:Get("outdatedVersion") == "popup" then
            _G.StaticPopup_Show("ABP_4H_OUTDATED_VERSION",
                ("You're running an outdated version of %s! Newer version %s discovered from %s, yours is %s. Please upgrade!"):format(
                ABP_4H:ColorizeText("4H Assist"), ABP_4H:ColorizeText(versionCmp), ABP_4H:ColorizeName(sender), ABP_4H:ColorizeText(version)));
        else
            ABP_4H:Notify("Version "..versionCmp.." has been released! You are currently using v"..version..". Please update this addon from Curse/WoWInterface.");
        end

        showedNagPopup = true;
    end
end

function ABP_4H:NotifyVersionMismatch()
    _G.StaticPopup_Show("ABP_4H_OUTDATED_VERSION",
        ("You've installed a new version of %s! All functionality is disabled until you restart your game client."):format(
        self:ColorizeText("4H Assist")));
end

function ABP_4H:OnVersionRequest(data, distribution, sender)
    if data.reset then
        -- Reset the announced version if the sender requested so that the message will print again.
        showedNagPopup = false;
        self:SendComm(self.CommTypes.VERSION_RESPONSE, {
            version = self:GetVersion()
        }, "WHISPER", sender);
    elseif self:VersionIsNewer(self:GetCompareVersion(), data.version) then
        self:SendComm(self.CommTypes.VERSION_RESPONSE, {
            version = self:GetVersion()
        }, "WHISPER", sender);
    end

    CompareVersion(data.version, sender);
end

function ABP_4H:OnVersionResponse(data, distribution, sender)
    if versionCheckData and not versionCheckData.players[sender] then
        versionCheckData.players[Ambiguate(sender, "short")] = data.version;
        versionCheckData.received = versionCheckData.received + 1;

        -- See if we can end the timer early if everyone has responded.
        if versionCheckData.received == versionCheckData.total then
            self:CancelTimer(versionCheckData.timer);
            self:VersionCheckCallback();
        end
    end

    CompareVersion(data.version, sender);
end

local function GetNumOnlineGroupMembers()
    local count = 0;
    local groupSize = math.max(GetNumGroupMembers(), 1);
    for i = 1, groupSize do
        local unit = "player";
        if IsInRaid() then
            unit = "raid" .. i;
        elseif i ~= groupSize then
            unit = "party" .. i;
        end
        if UnitIsConnected(unit) then
            count = count + 1;
        end
    end

    return count;
end

function ABP_4H:PerformVersionCheck()
    if versionCheckData then
        self:Error("Already performing version check!");
        return;
    end

    local major, _, _, prerelType = self:ParseVersion(self:GetVersion());
    if not major then
        self:Error("Unable to parse your version!");
        return;
    end
    if prerelType then
        self:Notify("You're using a prerelease version! This check will likely find a lot of 'outdated' versions.");
    end

    -- Reset showedNagPopup in case the version check reveals a newer version.
    showedNagPopup = false;

    versionCheckData = {
        total = GetNumOnlineGroupMembers(),
        received = 0,
        players = {},
    };

    self:Notify("Performing version check...");
    self:SendComm(self.CommTypes.VERSION_REQUEST, {
        reset = true,
        version = self:GetVersion()
    }, "BROADCAST");
    versionCheckData.timer = self:ScheduleTimer("VersionCheckCallback", 5);
end

function ABP_4H:VersionCheckCallback()
    if not versionCheckData then return; end
    local version = self:GetCompareVersion();

    local allUpToDate = true;
    local groupSize = math.max(GetNumGroupMembers(), 1);
    for i = 1, groupSize do
        local unit = "player";
        if IsInRaid() then
            unit = "raid" .. i;
        elseif i ~= groupSize then
            unit = "party" .. i;
        end
        local player, realm = UnitName(unit);
        if player then
            if UnitIsConnected(unit) then
                local versionCmp = versionCheckData.players[player];
                if versionCmp then
                    if self:VersionIsNewer(version, versionCmp, true) then
                        self:Notify("%s running an outdated version (%s)!", self:ColorizeName(player), ABP_4H:ColorizeText(versionCmp));
                        _G.SendChatMessage(
                            ("You don't have the latest 4H Assist version installed! Please update it from Curse/WoWInterface. The latest version is %s, you have %s."):format(version, versionCmp),
                            "WHISPER", nil, realm and ("%s-%s"):format(player, realm) or player);
                        allUpToDate = false;
                    end
                else
                    self:Notify("%s is missing the addon!", self:ColorizeName(player));
                    _G.SendChatMessage(
                        "You don't have the 4H Assist addon installed! Please install it from Curse/WoWInterface.",
                        "WHISPER", nil, realm and ("%s-%s"):format(player, realm) or player);
                    allUpToDate = false;
                end
            else
                self:Notify("%s was offline for the version check.", self:ColorizeName(player));
                allUpToDate = false;
            end
        end
    end

    if allUpToDate then
        self:Notify("Everyone is up to date!");
    end

    versionCheckData = nil;
end

function ABP_4H:VersionOnGroupJoined()
    self:SendComm(self.CommTypes.VERSION_REQUEST, {
        version = self:GetVersion()
    }, "BROADCAST");
end

function ABP_4H:VersionOnEnteringWorld(isInitialLogin)
    -- Only check version on the initial login.
    if not isInitialLogin then checkedGuild = true; end
end

function ABP_4H:VersionOnGuildRosterUpdate()
    if not checkedGuild then
        checkedGuild = true;
        self:ScheduleTimer(function(self)
            self:SendComm(self.CommTypes.VERSION_REQUEST, {
                version = self:GetVersion()
            }, "GUILD");
        end, 30, self);
    end
end

StaticPopupDialogs["ABP_4H_OUTDATED_VERSION"] = ABP_4H:StaticDialogTemplate(ABP_4H.StaticDialogTemplates.JUST_BUTTONS, {
    text = "%s",
    button1 = "Ok",
    showAlert = true,
});
