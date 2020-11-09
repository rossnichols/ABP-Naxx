local _G = _G;
local ABP_4H = _G.ABP_4H;

local pos = {
    healerTL = { 40, 25 },
    healerTR = { 65, 25 },
    healerBL = { 40, 60 },
    healerBR = { 65, 60 },

    tankdpsTL = { 29, 28 },
    tankdpsTR = { 76, 28 },
    tankdpsBL = { 29, 69 },
    tankdpsBR = { 76, 69 },

    safe = { 52, 52 },
};

local roles = {
    tankdps1 = "tankdps1",
    tankdps2 = "tankdps2",
    tankdps3 = "tankdps3",
    tankdps4 = "tankdps4",

    ot1 = "ot1",
    ot2 = "ot2",
    ot3 = "ot3",
    ot4 = "ot4",

    healer1 = "healer1",
    healer2 = "healer2",
    healer3 = "healer3",
    healer4 = "healer4",
    healer5 = "healer5",
    healer6 = "healer6",
    healer7 = "healer7",
    healer8 = "healer8",
    healer9 = "healer9",
    healer10 = "healer10",
    healer11 = "healer11",
    healer12 = "healer12",
};

local rolesSorted = {
    roles.tankdps1,
    roles.tankdps2,
    roles.tankdps3,
    roles.tankdps4,
    roles.ot1,
    roles.ot2,
    roles.ot3,
    roles.ot4,
    roles.healer1,
    roles.healer2,
    roles.healer3,
    roles.healer4,
    roles.healer5,
    roles.healer6,
    roles.healer7,
    roles.healer8,
    roles.healer9,
    roles.healer10,
    roles.healer11,
    roles.healer12,
};

local rolesSortedStatus = {
    roles.tankdps1,
    roles.tankdps2,
    roles.tankdps3,
    roles.tankdps4,
    roles.ot1,
    roles.ot2,
    roles.ot3,
    roles.ot4,
    roles.healer1,
    roles.healer4,
    roles.healer7,
    roles.healer10,
    roles.healer2,
    roles.healer5,
    roles.healer8,
    roles.healer11,
    roles.healer3,
    roles.healer6,
    roles.healer9,
    roles.healer12,
};

local raidRoles = {
    -- Group 1
    roles.tankdps1,
    roles.tankdps1,
    roles.tankdps1,
    roles.tankdps1,
    roles.tankdps1,

    -- Group 2
    roles.tankdps2,
    roles.tankdps2,
    roles.tankdps2,
    roles.tankdps2,
    roles.tankdps2,

    -- Group 3
    roles.tankdps3,
    roles.tankdps3,
    roles.tankdps3,
    roles.tankdps3,
    roles.tankdps3,

    -- Group 4
    roles.tankdps4,
    roles.tankdps4,
    roles.tankdps4,
    roles.tankdps4,
    roles.tankdps4,

    -- Group 5
    roles.tankdps1,
    roles.ot1,
    roles.healer1,
    roles.healer2,
    roles.healer3,

    -- Group 6
    roles.tankdps2,
    roles.ot2,
    roles.healer4,
    roles.healer5,
    roles.healer6,

    -- Group 7
    roles.tankdps3,
    roles.ot3,
    roles.healer7,
    roles.healer8,
    roles.healer9,

    -- Group 8
    roles.tankdps4,
    roles.ot4,
    roles.healer10,
    roles.healer11,
    roles.healer12,
};

local roleNames = {
    [roles.tankdps1] = "Tank/DPS BL Start",
    [roles.tankdps2] = "Tank/DPS BL Safe",
    [roles.tankdps3] = "Tank/DPS BR Start",
    [roles.tankdps4] = "Tank/DPS BR Safe",
    [roles.ot1] = "Off Tank TL Safe",
    [roles.ot2] = "Off Tank TL Start",
    [roles.ot3] = "Off Tank TR Safe",
    [roles.ot4] = "Off Tank TR Start",
    [roles.healer1] = "Healer BL 1",
    [roles.healer2] = "Healer BL 2",
    [roles.healer3] = "Healer BL 3",
    [roles.healer4] = "Healer TL 1",
    [roles.healer5] = "Healer TL 2",
    [roles.healer6] = "Healer TL 3",
    [roles.healer7] = "Healer BR 1",
    [roles.healer8] = "Healer BR 2",
    [roles.healer9] = "Healer BR 3",
    [roles.healer10] = "Healer TR 1",
    [roles.healer11] = "Healer TR 2",
    [roles.healer12] = "Healer TR 3",
};

local roleColors = {
    [roles.tankdps1] = "0099cc",
    [roles.tankdps2] = "0099cc",
    [roles.tankdps3] = "0099cc",
    [roles.tankdps4] = "0099cc",
    [roles.ot1] = "00cc00",
    [roles.ot2] = "00cc00",
    [roles.ot3] = "00cc00",
    [roles.ot4] = "00cc00",
    [roles.healer1] = "ffff66",
    [roles.healer2] = "ffff66",
    [roles.healer3] = "ffff66",
    [roles.healer4] = "ffff66",
    [roles.healer5] = "ffff66",
    [roles.healer6] = "ffff66",
    [roles.healer7] = "ffff66",
    [roles.healer8] = "ffff66",
    [roles.healer9] = "ffff66",
    [roles.healer10] = "ffff66",
    [roles.healer11] = "ffff66",
    [roles.healer12] = "ffff66",
};

for role, name in pairs(roleNames) do
    roleNames[role] = ("|cff%s%s|r"):format(roleColors[role], name);
end

local rotations = {
    [roles.tankdps1] = { [0] = pos.tankdpsBL, [3] = pos.safe, [6] = pos.tankdpsBR, [9] = pos.safe, [12] = pos.tankdpsBL },
    [roles.tankdps2] = { [0] = pos.safe, [3] = pos.tankdpsBL, [6] = pos.safe, [9] = pos.tankdpsBR, [12] = pos.safe },
    [roles.tankdps3] = { [0] = pos.tankdpsBR, [3] = pos.safe, [6] = pos.tankdpsBL, [9] = pos.safe, [12] = pos.tankdpsBR },
    [roles.tankdps4] = { [0] = pos.safe, [3] = pos.tankdpsBR, [6] = pos.safe, [9] = pos.tankdpsBL, [12] = pos.safe },

    [roles.ot1] = { [0] = pos.safe, [3] = pos.tankdpsTL, [6] = pos.safe, [9] = pos.tankdpsTR, [12] = pos.safe },
    [roles.ot2] = { [0] = pos.tankdpsTL, [3] = pos.safe, [6] = pos.tankdpsTR, [9] = pos.safe, [12] = pos.tankdpsTL },
    [roles.ot3] = { [0] = pos.safe, [3] = pos.tankdpsTR, [6] = pos.safe, [9] = pos.tankdpsTL, [12] = pos.safe },
    [roles.ot4] = { [0] = pos.tankdpsTR, [3] = pos.safe, [6] = pos.tankdpsTL, [9] = pos.safe, [12] = pos.tankdpsTR },

    [roles.healer1] = { [0] = pos.healerBL, [1] = pos.healerTL, [4] = pos.healerTR, [7] = pos.healerBR, [10] = pos.healerBL },
    [roles.healer2] = { [0] = pos.healerBL, [2] = pos.healerTL, [5] = pos.healerTR, [8] = pos.healerBR, [11] = pos.healerBL },
    [roles.healer3] = { [0] = pos.healerBL, [3] = pos.healerTL, [6] = pos.healerTR, [9] = pos.healerBR, [12] = pos.healerBL },

    [roles.healer4] = { [0] = pos.healerTL, [1] = pos.healerTR, [4] = pos.healerBR, [7] = pos.healerBL, [10] = pos.healerTL },
    [roles.healer5] = { [0] = pos.healerTL, [2] = pos.healerTR, [5] = pos.healerBR, [8] = pos.healerBL, [11] = pos.healerTL },
    [roles.healer6] = { [0] = pos.healerTL, [3] = pos.healerTR, [6] = pos.healerBR, [9] = pos.healerBL, [12] = pos.healerTL },

    [roles.healer7] = { [0] = pos.healerBR, [1] = pos.healerBL, [4] = pos.healerTL, [7] = pos.healerTR, [10] = pos.healerBR },
    [roles.healer8] = { [0] = pos.healerBR, [2] = pos.healerBL, [5] = pos.healerTL, [8] = pos.healerTR, [11] = pos.healerBR },
    [roles.healer9] = { [0] = pos.healerBR, [3] = pos.healerBL, [6] = pos.healerTL, [9] = pos.healerTR, [12] = pos.healerBR },

    [roles.healer10] = { [0] = pos.healerTR, [1] = pos.healerBR, [4] = pos.healerBL, [7] = pos.healerTL, [10] = pos.healerTR },
    [roles.healer11] = { [0] = pos.healerTR, [2] = pos.healerBR, [5] = pos.healerBL, [8] = pos.healerTL, [11] = pos.healerTR },
    [roles.healer12] = { [0] = pos.healerTR, [3] = pos.healerBR, [6] = pos.healerBL, [9] = pos.healerTL, [12] = pos.healerTR },
};
for _, rotation in pairs(rotations) do
    local pos = rotation[0];
    for i = 1, 12 do
        if not rotation[i] then
            rotation[i] = pos;
        end
        pos = rotation[i];
    end
end

local modes = {
    manual = "manual",
    timer = "timer",
    live = "live",
};

local modeNames = {
    [modes.live] = "Live",
    [modes.manual] = "Manual",
    [modes.timer] = "Timed",
};

ABP_4H.Roles = roles;
ABP_4H.RolesSorted = rolesSorted;
ABP_4H.RolesSortedStatus = rolesSortedStatus;
ABP_4H.RaidRoles = raidRoles;
ABP_4H.RoleNames = roleNames;
ABP_4H.MapPositions = pos;
ABP_4H.Rotations = rotations;
ABP_4H.Modes = modes;
ABP_4H.ModeNames = modeNames;
