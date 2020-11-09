local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;

local IsInGroup = IsInGroup;
local GetNumGroupMembers = GetNumGroupMembers;
local IsInRaid = IsInRaid;
local UnitName = UnitName;
local UnitIsConnected = UnitIsConnected;
local GetAddOnMetadata = GetAddOnMetadata;
local tonumber = tonumber;

local versionCheckData;
local showedNagPopup = false;
local checkedGuild = false;

function ABP_Naxx:GetVersion()
    local version = GetAddOnMetadata("4H-Assist", "Version");
    if version == "${ADDON_VERSION}" then
        return self.VersionOverride;
    end
    return version;
end

function ABP_Naxx:GetCompareVersion()
    local version = GetAddOnMetadata("4H-Assist", "Version");
    if version == "${ADDON_VERSION}" then
        return self.VersionCmpOverride;
    end
    return version;
end

function ABP_Naxx:ParseVersion(version)
    local major, minor, patch, prerelType, prerelVersion = version:match("^(%d+)%.(%d+)%.(%d+)%-?(%a*)(%d*)$");
    if not (major and minor and patch) then return; end
    if prerelType == "" then prerelType = nil; end
    if prerelVersion == "" then prerelVersion = nil; end

    return tonumber(major), tonumber(minor), tonumber(patch), prerelType, tonumber(prerelVersion);
end

function ABP_Naxx:VersionIsNewer(versionCmp, version, allowPrerelease)
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
    local version = ABP_Naxx:GetCompareVersion();
    if versionCmp == version then return; end

    -- Make sure the version strings are valid
    if not (ABP_Naxx:ParseVersion(version) and ABP_Naxx:ParseVersion(versionCmp)) then return; end

    if ABP_Naxx:VersionIsNewer(versionCmp, version) then
        _G.StaticPopup_Show("ABP_NAXX_OUTDATED_VERSION",
            ("You're running an outdated version of %s! Newer version %s discovered from %s, yours is %s. Please upgrade!"):format(
            ABP_Naxx:ColorizeText("4H Assist"), ABP_Naxx:ColorizeText(versionCmp), ABP_Naxx:ColorizeName(sender), ABP_Naxx:ColorizeText(version)));
        showedNagPopup = true;
    end
end

function ABP_Naxx:NotifyVersionMismatch()
    _G.StaticPopup_Show("ABP_NAXX_OUTDATED_VERSION",
        ("You've installed a new version of %s! All functionality is disabled until you restart your game client."):format(
        self:ColorizeText("4H Assist")));
end

function ABP_Naxx:OnVersionRequest(data, distribution, sender)
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

function ABP_Naxx:OnVersionResponse(data, distribution, sender)
    if versionCheckData and not versionCheckData.players[sender] then
        versionCheckData.players[sender] = data.version;
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
    local groupSize = GetNumGroupMembers();
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

function ABP_Naxx:PerformVersionCheck()
    if versionCheckData then
        self:Error("Already performing version check!");
        return;
    end
    if not IsInGroup() then
        self:Error("Not in a group!");
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

function ABP_Naxx:VersionCheckCallback()
    if not versionCheckData then return; end
    local version = self:GetCompareVersion();

    local allUpToDate = true;
    local groupSize = GetNumGroupMembers();
    for i = 1, groupSize do
        local unit = "player";
        if IsInRaid() then
            unit = "raid" .. i;
        elseif i ~= groupSize then
            unit = "party" .. i;
        end
        local player = UnitName(unit);
        if player then
            if UnitIsConnected(unit) then
                local versionCmp = versionCheckData.players[player];
                if versionCmp then
                    if self:VersionIsNewer(version, versionCmp, true) then
                        self:Notify("%s running an outdated version (%s)!", self:ColorizeName(player), ABP_Naxx:ColorizeText(versionCmp));
                        _G.SendChatMessage(
                            ("You don't have the latest 4H Assist version installed! Please update it from Curse/Twitch. The latest version is %s, you have %s."):format(version, versionCmp),
                            "WHISPER", nil, player);
                        allUpToDate = false;
                    end
                else
                    self:Notify("%s is missing the addon!", self:ColorizeName(player));
                    _G.SendChatMessage(
                        "You don't have the 4H Assist addon installed! Please install it from Curse/Twitch.",
                        "WHISPER", nil, player);
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

function ABP_Naxx:VersionOnGroupJoined()
    self:SendComm(self.CommTypes.VERSION_REQUEST, {
        version = self:GetVersion()
    }, "BROADCAST");
end

function ABP_Naxx:VersionOnEnteringWorld(isInitialLogin)
    -- Only check version on the initial login.
    if not isInitialLogin then checkedGuild = true; end
end

function ABP_Naxx:VersionOnGuildRosterUpdate()
    if not checkedGuild then
        checkedGuild = true;
        self:ScheduleTimer(function(self)
            self:SendComm(self.CommTypes.VERSION_REQUEST, {
                version = self:GetVersion()
            }, "GUILD");
        end, 30, self);
    end
end

StaticPopupDialogs["ABP_NAXX_OUTDATED_VERSION"] = ABP_Naxx:StaticDialogTemplate(ABP_Naxx.StaticDialogTemplates.JUST_BUTTONS, {
    text = "%s",
    button1 = "Ok",
    showAlert = true,
});
