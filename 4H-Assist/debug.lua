local _G = _G;
local ABP_4H = _G.ABP_4H;

local debugOpts = {
    -- If set, extra debug messages will be printed.
    -- Verbose = true,

    -- If set, "BROADCAST" will get rerouted to "WHISPER" even in a group.
    -- PrivateComms = true,

    -- If set, some extra logging will be printed for comms.
    -- DebugComms = true,
};

function ABP_4H:GetDebugOpt(key)
    return self:Get("debug") and (not key or debugOpts[key]);
end

function ABP_4H:SetDebug(enable)
    self:Set("debug", enable);
end

ABP_4H.VersionOverride = "0.3.1";
ABP_4H.VersionCmpOverride = "0.3.1";
