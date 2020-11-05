local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;
local LibSerialize = _G.LibStub("LibSerialize");
local AceSerializer = _G.LibStub("AceSerializer-3.0");
local LibDeflate = _G.LibStub("LibDeflate");
local LibCompress = _G.LibStub("LibCompress");
local AddonEncodeTable = LibCompress:GetAddonEncodeTable();

local IsInGroup = IsInGroup;
local GetNumGroupMembers = GetNumGroupMembers;
local IsInRaid = IsInRaid;
local UnitName = UnitName;
local GetTime = GetTime;
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE;
local pairs = pairs;
local type = type;
local table = table;
local tostring = tostring;
local strlen = strlen;
local ipairs = ipairs;
local mod = mod;

local synchronousCheck = false;
local events = {};

function ABP_Naxx:GetBroadcastChannel()
    if self:GetDebugOpt("PrivateComms") then return "WHISPER", UnitName("player"); end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT";
    elseif GetNumGroupMembers() > 0 and IsInRaid() then
        return "RAID";
    elseif IsInGroup() then
        return "PARTY";
    else
        return "WHISPER", UnitName("player");
    end
end

function ABP_Naxx:SetCallback(name, fn)
    events[name] = fn;
end

function ABP_Naxx:Fire(name, ...)
    local fn = events[name];
    if fn then fn(self, name, ...); end
end

-- The prefix can be revved to create a backwards-incompatible version.
function ABP_Naxx:GetCommPrefix()
    return "ABPN1";
end

-- Highest ID: 3
ABP_Naxx.CommTypes = {
    STATE_SYNC = { name = "STATE_SYNC", id = 1, priority = "INSTANT", fireLocally = true },

    STATE_SYNC_ACK = { name = "STATE_SYNC_ACK", id = 2, priority = "INSTANT", fireLocally = true },

    STATE_SYNC_REQUEST = { name = "STATE_SYNC_REQUEST", id = 3, priority = "ALERT" },

    -- NOTE: these aren't versioned and use legacy encoding so they can continue to function across major changes.
    VERSION_REQUEST = { name = "ABPN_VERSION_REQUEST", priority = "BULK", legacy = true },
    -- reset: bool or nil
    -- version: from ABP_Naxx:GetVersion()
    VERSION_RESPONSE = { name = "ABPN_VERSION_RESPONSE", priority = "BULK", legacy = true },
    -- version: from ABP_Naxx:GetVersion()
};
local commIdMap = {};
for _, typ in pairs(ABP_Naxx.CommTypes) do
    if typ.id then commIdMap[typ.id] = typ.name; end
end

ABP_Naxx.InternalEvents = {
    ENCOUNTER_UPDATE = "ENCOUNTER_UPDATE",
};

function ABP_Naxx:CommCallback(sent, total, logInCallback)
    if logInCallback and self:GetDebugOpt("DebugComms") then
        self:LogDebug("COMM-CB: sent=%d total=%d", sent, total);
    end
    if sent == total then
        synchronousCheck = true;
    end
end

function ABP_Naxx:Serialize(typ, data, legacy)
    if legacy then
        data.type = typ.name;
        _G.assert(data.version);
        local serialized = AceSerializer:Serialize(data);
        local compressed = LibCompress:Compress(serialized);
        return (AddonEncodeTable:Encode(compressed)), "ABPN";
    else
        local serialized = LibSerialize:Serialize(typ.id, self:GetVersion(), data);
        local compressed = LibDeflate:CompressDeflate(serialized);
        local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed);

        if #encoded > #serialized + 10 then
            self:LogDebug("WARNING: compressing payload for %s increased size from %d to %d (%d before encoding)!",
                data.type, #serialized, #encoded, #compressed);
        elseif self:GetDebugOpt("DebugComms") then
            self:LogDebug("Serialized payload len %d (compressed %d, encoded %d).", #serialized, #compressed, #encoded);
        end

        if self:GetDebugOpt() then
            local success, _, _, dataTest = LibSerialize:Deserialize(serialized);
            if not success or type(dataTest) ~= "table" or not self.tCompare(data, dataTest) then
                _G.error("Serialization failed!");
            end
        end

        return (LibDeflate:EncodeForWoWAddonChannel(compressed)), self:GetCommPrefix();
    end
end

function ABP_Naxx:Deserialize(payload, legacy)
    if legacy then
        local compressed = AddonEncodeTable:Decode(payload);
        if not compressed then return false; end

        local serialized = LibCompress:Decompress(compressed);
        if not serialized then return false; end

        local typ, version;
        local success, data = AceSerializer:Deserialize(serialized);
        if success then
            typ = data.type;
            version = data.version;
        end
        return success, typ, version, data;
    else
        local compressed = LibDeflate:DecodeForWoWAddonChannel(payload);
        if not compressed then return false; end

        local serialized = LibDeflate:DecompressDeflate(compressed);
        if not serialized then return false; end

        local typ;
        local success, id, version, data = LibSerialize:Deserialize(serialized);
        if success then
            typ = commIdMap[id];
        end
        return success, typ, version, data;
    end
end

function ABP_Naxx:SendComm(typ, data, distribution, target)
    local priority = typ.priority;
    local payload, prefix = self:Serialize(typ, data, typ.legacy);

    if distribution == "BROADCAST" then
        distribution, target = self:GetBroadcastChannel();
    end
    if not distribution then return; end

    if priority == "INSTANT" and strlen(payload) > 250 then
        priority = "ALERT";
    end

    local logInCallback = false;
    if self:GetDebugOpt("Verbose") then
        self:LogVerbose("COMM-SEND >>>");
        self:LogVerbose("%s pri=%s dist=%s prefix=%s len=%d",
            typ.name,
            priority,
            target and ("%s:%s"):format(distribution, target) or distribution,
            prefix,
            strlen(payload));
        for k, v in pairs(data) do
            if k ~= "type" then self:LogVerbose("%s: %s", k, tostring(v)); end
        end
        self:LogVerbose("<<< COMM");
    elseif not typ.name:find("VERSION") and self:GetDebugOpt("DebugComms") then
        logInCallback = true;
        self:LogDebug("COMM-SEND: %s pri=%s dist=%s prefix=%s len=%d",
            typ.name,
            priority,
            target and ("%s:%s"):format(distribution, target) or distribution,
            prefix,
            strlen(payload));
    end

    if priority == "INSTANT" then
        -- The \004 prefix is AceComm's "escape" control. Prepend it so that the
        -- payload is properly interpreted when received.
        _G.C_ChatInfo.SendAddonMessage(prefix, "\004" .. payload, distribution, target);
        synchronousCheck = true;
    else
        synchronousCheck = false;
        local time = GetTime();
        local commCallback = function(self, sent, total)
            self:CommCallback(sent, total, logInCallback);
        end
        self:SendCommMessage(prefix, payload, distribution, target, priority, commCallback, self);
    end

    if typ.fireLocally then
        -- self:LogDebug("Firing comm [%s] locally.", typ.name);
        self:Fire(typ.name, data, distribution, UnitName("player"), self:GetVersion());
    end

    return synchronousCheck;
end

function ABP_Naxx:OnCommReceived(prefix, payload, distribution, sender)
    local legacy = (prefix == "ABPN");
    local success, typ, version, data = self:Deserialize(payload, legacy);
    if not success or type(data) ~= "table" then
        self:Error("Received an invalid addon comm from %s!", self:ColorizeName(sender));
        return;
    end

    if self:GetDebugOpt("Verbose") then
        self:LogVerbose("COMM-RECV >>>");
        self:LogVerbose("%s dist=%s sender=%s prefix=%s len=%s", typ, distribution, sender, prefix, payload:len());
        for k, v in pairs(data) do
            self:LogVerbose("%s: %s", k, tostring(v));
        end
        self:LogVerbose("<<< COMM");
    elseif sender ~= UnitName("player") and not typ:find("VERSION") and self:GetDebugOpt("DebugComms") then
        self:LogDebug("COMM-RECV: %s dist=%s sender=%s prefix=%s len=%s", typ, distribution, sender, prefix, payload:len());
    end

    if self.CommTypes[typ] and self.CommTypes[typ].fireLocally and sender == UnitName("player") then
        -- self:LogDebug("Received comm [%s], skipping fire (local).", typ);
        return;
    end

    self:Fire(typ, data, distribution, sender, version);
end
