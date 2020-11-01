local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;

local debugOpts = {
    -- If set, extra debug messages will be printed.
    -- Verbose = true,

    -- If set, "BROADCAST" will get rerouted to "WHISPER" even in a group.
    -- PrivateComms = true,

    -- If set, some extra logging will be printed for comms.
    -- DebugComms = true,
};

function ABP_Naxx:GetDebugOpt(key)
    return self:Get("debug") and (not key or debugOpts[key]);
end

function ABP_Naxx:SetDebug(enable)
    self:Set("debug", enable);
end

ABP_Naxx.VersionOverride = "0.1.0";
ABP_Naxx.VersionCmpOverride = "0.1.0";
