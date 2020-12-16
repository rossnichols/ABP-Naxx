local _G = _G;
local ABP_4H = _G.ABP_4H;

local pos = {
    healerTL = { 40, 25 },
    healerTR = { 65, 25 },
    healerTR1 = { 67, 20 },
    healerTR2 = { 64, 30 },
    healerTR3 = { 67, 40 },
    healerBL = { 40, 60 },
    healerBR = { 65, 60 },

    tankdpsTL = { 29, 28 },
    tankdpsTR = { 76, 28 },
    tankdpsBL = { 29, 69 },
    tankdpsBR = { 76, 69 },

    safe = { 52, 52 },
};

local marks = {
    tl = 28833,
    tr = 28835,
    bl = 28832,
    br = 28834,
};

local smallPos = {
    [pos.healerTR1] = true,
    [pos.healerTR2] = true,
    [pos.healerTR3] = true
};

local markPositions = {
    [marks.tl] = { [pos.tankdpsTL] = true, [pos.healerTL] = true },
    [marks.tr] = { [pos.tankdpsTR] = true, [pos.healerTR1] = true, [pos.healerTR2] = true, [pos.healerTR3] = true },
    [marks.bl] = { [pos.tankdpsBL] = true, [pos.healerBL] = true },
    [marks.br] = { [pos.tankdpsBR] = true, [pos.healerBR] = true },
};

local bosses = {
    korthazz = 16064,
    blaumeux = 16065,
    mograine = 16062,
    zeliek = 16063,
    rivendare = 30549, -- retail only (replacement for mograine)
};

local bossMarks = {
    [bosses.korthazz] = marks.bl,
    [bosses.blaumeux] = marks.tl,
    [bosses.mograine] = marks.br,
    [bosses.rivendare] = marks.br,
    [bosses.zeliek] = marks.tr,
};

local roles = {
    dps1 = "dps1",
    dps2 = "dps2",
    dps3 = "dps3",
    dps4 = "dps4",

    tank1 = "tank1",
    tank2 = "tank2",
    tank3 = "tank3",
    tank4 = "tank4",

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

    healerccw1 = "healerccw1",
    healerccw2 = "healerccw2",
    healerccw3 = "healerccw3",
    healerccw4 = "healerccw4",
    healerccw5 = "healerccw5",
    healerccw6 = "healerccw6",
    healerccw7 = "healerccw7",
    healerccw8 = "healerccw8",
    healerccw9 = "healerccw9",
    healerccw10 = "healerccw10",
    healerccw11 = "healerccw11",
    healerccw12 = "healerccw12",

    healerz1 = "healerz1",
    healerz2 = "healerz2",
    healerz3 = "healerz3",
    healerz4 = "healerz4",
    healerz5 = "healerz5",
    healerz6 = "healerz6",
    healerz7 = "healerz7",
    healerz8 = "healerz8",
    healerz9 = "healerz9",
    healerz10 = "healerz10",
    healerz11 = "healerz11",
    healerz12 = "healerz12",

    healerzccw1 = "healerzccw1",
    healerzccw2 = "healerzccw2",
    healerzccw3 = "healerzccw3",
    healerzccw4 = "healerzccw4",
    healerzccw5 = "healerzccw5",
    healerzccw6 = "healerzccw6",
    healerzccw7 = "healerzccw7",
    healerzccw8 = "healerzccw8",
    healerzccw9 = "healerzccw9",
    healerzccw10 = "healerzccw10",
    healerzccw11 = "healerzccw11",
    healerzccw12 = "healerzccw12",

    independent = "independent",
};

local healerMap = {
    -- 0: no zeliak breakout, clockwise
    [0] = {
        [roles.healer1] = roles.healer1,
        [roles.healer2] = roles.healer2,
        [roles.healer3] = roles.healer3,
        [roles.healer4] = roles.healer4,
        [roles.healer5] = roles.healer5,
        [roles.healer6] = roles.healer6,
        [roles.healer7] = roles.healer7,
        [roles.healer8] = roles.healer8,
        [roles.healer9] = roles.healer9,
        [roles.healer10] = roles.healer10,
        [roles.healer11] = roles.healer11,
        [roles.healer12] = roles.healer12,
    },
    -- 1: zeliak breakout, clockwise
    [1] = {
        [roles.healer1] = roles.healerz1,
        [roles.healer2] = roles.healerz2,
        [roles.healer3] = roles.healerz3,
        [roles.healer4] = roles.healerz4,
        [roles.healer5] = roles.healerz5,
        [roles.healer6] = roles.healerz6,
        [roles.healer7] = roles.healerz7,
        [roles.healer8] = roles.healerz8,
        [roles.healer9] = roles.healerz9,
        [roles.healer10] = roles.healerz10,
        [roles.healer11] = roles.healerz11,
        [roles.healer12] = roles.healerz12,
    },
    -- 2: no zeliak breakout, counterclockwise
    [2] = {
        [roles.healer1] = roles.healerccw1,
        [roles.healer2] = roles.healerccw2,
        [roles.healer3] = roles.healerccw3,
        [roles.healer4] = roles.healerccw4,
        [roles.healer5] = roles.healerccw5,
        [roles.healer6] = roles.healerccw6,
        [roles.healer7] = roles.healerccw7,
        [roles.healer8] = roles.healerccw8,
        [roles.healer9] = roles.healerccw9,
        [roles.healer10] = roles.healerccw10,
        [roles.healer11] = roles.healerccw11,
        [roles.healer12] = roles.healerccw12,
    },
    -- 3: zeliak breakout, counterclockwise
    [3] = {
        [roles.healer1] = roles.healerzccw1,
        [roles.healer2] = roles.healerzccw2,
        [roles.healer3] = roles.healerzccw3,
        [roles.healer4] = roles.healerzccw4,
        [roles.healer5] = roles.healerzccw5,
        [roles.healer6] = roles.healerzccw6,
        [roles.healer7] = roles.healerzccw7,
        [roles.healer8] = roles.healerzccw8,
        [roles.healer9] = roles.healerzccw9,
        [roles.healer10] = roles.healerzccw10,
        [roles.healer11] = roles.healerzccw11,
        [roles.healer12] = roles.healerzccw12,
    },
};

local rolesSorted = {
    roles.independent,
    roles.dps1,
    roles.dps2,
    roles.dps3,
    roles.dps4,
    roles.tank1,
    roles.tank2,
    roles.tank3,
    roles.tank4,
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
    roles.tank1,
    roles.tank3,
    roles.ot1,
    roles.ot3,
    roles.tank2,
    roles.tank4,
    roles.ot2,
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
    roles.dps1,
    roles.dps2,
    roles.dps3,
    roles.dps4,
    roles.independent,
};

local categories = {
    healer = "healer",
    tank = "tank",
    dps = "dps",
    none = "none",
};

local roleCategories = {
    [roles.independent] = categories.none,
    [roles.dps1] = categories.dps,
    [roles.dps2] = categories.dps,
    [roles.dps3] = categories.dps,
    [roles.dps4] = categories.dps,
    [roles.tank1] = categories.tank,
    [roles.tank2] = categories.tank,
    [roles.tank3] = categories.tank,
    [roles.tank4] = categories.tank,
    [roles.ot1] = categories.tank,
    [roles.ot2] = categories.tank,
    [roles.ot3] = categories.tank,
    [roles.ot4] = categories.tank,
    [roles.healer1] = categories.healer,
    [roles.healer2] = categories.healer,
    [roles.healer3] = categories.healer,
    [roles.healer4] = categories.healer,
    [roles.healer5] = categories.healer,
    [roles.healer6] = categories.healer,
    [roles.healer7] = categories.healer,
    [roles.healer8] = categories.healer,
    [roles.healer9] = categories.healer,
    [roles.healer10] = categories.healer,
    [roles.healer11] = categories.healer,
    [roles.healer12] = categories.healer,
};

local topRoles = {
    [roles.ot1] = true,
    [roles.ot2] = true,
    [roles.ot3] = true,
    [roles.ot4] = true,
    [roles.healer1] = true,
    [roles.healer2] = true,
    [roles.healer3] = true,
    [roles.healer4] = true,
    [roles.healer5] = true,
    [roles.healer6] = true,
    [roles.healer7] = true,
    [roles.healer8] = true,
    [roles.healer9] = true,
    [roles.healer10] = true,
    [roles.healer11] = true,
    [roles.healer12] = true,
    [roles.healerccw1] = true,
    [roles.healerccw2] = true,
    [roles.healerccw3] = true,
    [roles.healerccw4] = true,
    [roles.healerccw5] = true,
    [roles.healerccw6] = true,
    [roles.healerccw7] = true,
    [roles.healerccw8] = true,
    [roles.healerccw9] = true,
    [roles.healerccw10] = true,
    [roles.healerccw11] = true,
    [roles.healerccw12] = true,
    [roles.healerz1] = true,
    [roles.healerz2] = true,
    [roles.healerz3] = true,
    [roles.healerz4] = true,
    [roles.healerz5] = true,
    [roles.healerz6] = true,
    [roles.healerz7] = true,
    [roles.healerz8] = true,
    [roles.healerz9] = true,
    [roles.healerz10] = true,
    [roles.healerz11] = true,
    [roles.healerz12] = true,
    [roles.healerzccw1] = true,
    [roles.healerzccw2] = true,
    [roles.healerzccw3] = true,
    [roles.healerzccw4] = true,
    [roles.healerzccw5] = true,
    [roles.healerzccw6] = true,
    [roles.healerzccw7] = true,
    [roles.healerzccw8] = true,
    [roles.healerzccw9] = true,
    [roles.healerzccw10] = true,
    [roles.healerzccw11] = true,
    [roles.healerzccw12] = true,
};

local raidRoles = {
    -- Group 1
    roles.tank1,
    roles.tank2,
    roles.healer1,
    roles.healer2,
    roles.healer3,

    -- Group 2
    roles.tank3,
    roles.tank4,
    roles.healer4,
    roles.healer5,
    roles.healer6,

    -- Group 3
    roles.ot1,
    roles.ot2,
    roles.healer7,
    roles.healer8,
    roles.healer9,

    -- Group 4
    roles.ot3,
    roles.ot4,
    roles.healer10,
    roles.healer11,
    roles.healer12,

    -- Group 5
    roles.dps1,
    roles.dps1,
    roles.dps1,
    roles.dps1,
    roles.dps1,

    -- Group 6
    roles.dps2,
    roles.dps2,
    roles.dps2,
    roles.dps2,
    roles.dps2,

    -- Group 7
    roles.dps3,
    roles.dps3,
    roles.dps3,
    roles.dps3,
    roles.dps3,

    -- Group 8
    roles.dps4,
    roles.dps4,
    roles.dps4,
    roles.dps4,
    roles.dps4,
};

local roleNames = {
    [roles.independent] = "Independent",
    [roles.dps1] = "DPS BL Start",
    [roles.dps2] = "DPS BR Start",
    [roles.dps3] = "DPS BL Safe",
    [roles.dps4] = "DPS BR Safe",
    [roles.tank1] = "Tank BL Start",
    [roles.tank2] = "Tank BL Safe",
    [roles.tank3] = "Tank BR Start",
    [roles.tank4] = "Tank BR Safe",
    [roles.ot1] = "Off Tank TL Start",
    [roles.ot2] = "Off Tank TL Safe",
    [roles.ot3] = "Off Tank TR Start",
    [roles.ot4] = "Off Tank TR Safe",
    [roles.healer1] = "Healer BL 1",
    [roles.healer2] = "Healer BL 2",
    [roles.healer3] = "Healer BL 3",
    [roles.healer4] = "Healer BR 1",
    [roles.healer5] = "Healer BR 2",
    [roles.healer6] = "Healer BR 3",
    [roles.healer7] = "Healer TL 1",
    [roles.healer8] = "Healer TL 2",
    [roles.healer9] = "Healer TL 3",
    [roles.healer10] = "Healer TR 1",
    [roles.healer11] = "Healer TR 2",
    [roles.healer12] = "Healer TR 3",
    [roles.healerccw1] = "Healer BL 1",
    [roles.healerccw2] = "Healer BL 2",
    [roles.healerccw3] = "Healer BL 3",
    [roles.healerccw4] = "Healer BR 1",
    [roles.healerccw5] = "Healer BR 2",
    [roles.healerccw6] = "Healer BR 3",
    [roles.healerccw7] = "Healer TL 1",
    [roles.healerccw8] = "Healer TL 2",
    [roles.healerccw9] = "Healer TL 3",
    [roles.healerccw10] = "Healer TR 1",
    [roles.healerccw11] = "Healer TR 2",
    [roles.healerccw12] = "Healer TR 3",
    [roles.healerz1] = "Healer BL 1",
    [roles.healerz2] = "Healer BL 2",
    [roles.healerz3] = "Healer BL 3",
    [roles.healerz4] = "Healer BR 1",
    [roles.healerz5] = "Healer BR 2",
    [roles.healerz6] = "Healer BR 3",
    [roles.healerz7] = "Healer TL 1",
    [roles.healerz8] = "Healer TL 2",
    [roles.healerz9] = "Healer TL 3",
    [roles.healerz10] = "Healer TR 1",
    [roles.healerz11] = "Healer TR 2",
    [roles.healerz12] = "Healer TR 3",
    [roles.healerzccw1] = "Healer BL 1",
    [roles.healerzccw2] = "Healer BL 2",
    [roles.healerzccw3] = "Healer BL 3",
    [roles.healerzccw4] = "Healer BR 1",
    [roles.healerzccw5] = "Healer BR 2",
    [roles.healerzccw6] = "Healer BR 3",
    [roles.healerzccw7] = "Healer TL 1",
    [roles.healerzccw8] = "Healer TL 2",
    [roles.healerzccw9] = "Healer TL 3",
    [roles.healerzccw10] = "Healer TR 1",
    [roles.healerzccw11] = "Healer TR 2",
    [roles.healerzccw12] = "Healer TR 3",
};

local roleColors = {
    [roles.independent] = "ffffff",
    [roles.dps1] = "0099cc",
    [roles.dps2] = "0099cc",
    [roles.dps3] = "0099cc",
    [roles.dps4] = "0099cc",
    [roles.tank1] = "00cc00",
    [roles.tank2] = "00cc00",
    [roles.tank3] = "00cc00",
    [roles.tank4] = "00cc00",
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
    [roles.healerccw1] = "ffff66",
    [roles.healerccw2] = "ffff66",
    [roles.healerccw3] = "ffff66",
    [roles.healerccw4] = "ffff66",
    [roles.healerccw5] = "ffff66",
    [roles.healerccw6] = "ffff66",
    [roles.healerccw7] = "ffff66",
    [roles.healerccw8] = "ffff66",
    [roles.healerccw9] = "ffff66",
    [roles.healerccw10] = "ffff66",
    [roles.healerccw11] = "ffff66",
    [roles.healerccw12] = "ffff66",
    [roles.healerz1] = "ffff66",
    [roles.healerz2] = "ffff66",
    [roles.healerz3] = "ffff66",
    [roles.healerz4] = "ffff66",
    [roles.healerz5] = "ffff66",
    [roles.healerz6] = "ffff66",
    [roles.healerz7] = "ffff66",
    [roles.healerz8] = "ffff66",
    [roles.healerz9] = "ffff66",
    [roles.healerz10] = "ffff66",
    [roles.healerz11] = "ffff66",
    [roles.healerz12] = "ffff66",
    [roles.healerzccw1] = "ffff66",
    [roles.healerzccw2] = "ffff66",
    [roles.healerzccw3] = "ffff66",
    [roles.healerzccw4] = "ffff66",
    [roles.healerzccw5] = "ffff66",
    [roles.healerzccw6] = "ffff66",
    [roles.healerzccw7] = "ffff66",
    [roles.healerzccw8] = "ffff66",
    [roles.healerzccw9] = "ffff66",
    [roles.healerzccw10] = "ffff66",
    [roles.healerzccw11] = "ffff66",
    [roles.healerzccw12] = "ffff66",
};

local roleNamesColored = {};
for role, name in pairs(roleNames) do
    roleNamesColored[role] = ("|cff%s%s|r"):format(roleColors[role], name);
end

local rotations = {
    [roles.dps1] = { [0] = pos.tankdpsBL, [3] = pos.safe, [6] = pos.tankdpsBR, [9] = pos.safe, [12] = pos.tankdpsBL },
    [roles.dps2] = { [0] = pos.tankdpsBR, [3] = pos.safe, [6] = pos.tankdpsBL, [9] = pos.safe, [12] = pos.tankdpsBR },
    [roles.dps3] = { [0] = pos.safe, [3] = pos.tankdpsBL, [6] = pos.safe, [9] = pos.tankdpsBR, [12] = pos.safe },
    [roles.dps4] = { [0] = pos.safe, [3] = pos.tankdpsBR, [6] = pos.safe, [9] = pos.tankdpsBL, [12] = pos.safe },

    [roles.tank1] = { [0] = pos.tankdpsBL, [3] = pos.safe, [6] = pos.tankdpsBR, [9] = pos.safe, [12] = pos.tankdpsBL },
    [roles.tank2] = { [0] = pos.safe, [3] = pos.tankdpsBL, [6] = pos.safe, [9] = pos.tankdpsBR, [12] = pos.safe },
    [roles.tank3] = { [0] = pos.tankdpsBR, [3] = pos.safe, [6] = pos.tankdpsBL, [9] = pos.safe, [12] = pos.tankdpsBR },
    [roles.tank4] = { [0] = pos.safe, [3] = pos.tankdpsBR, [6] = pos.safe, [9] = pos.tankdpsBL, [12] = pos.safe },

    [roles.ot1] = { [0] = pos.tankdpsTL, [3] = pos.safe, [6] = pos.tankdpsTR, [9] = pos.safe, [12] = pos.tankdpsTL },
    [roles.ot2] = { [0] = pos.safe, [3] = pos.tankdpsTL, [6] = pos.safe, [9] = pos.tankdpsTR, [12] = pos.safe },
    [roles.ot3] = { [0] = pos.tankdpsTR, [3] = pos.safe, [6] = pos.tankdpsTL, [9] = pos.safe, [12] = pos.tankdpsTR },
    [roles.ot4] = { [0] = pos.safe, [3] = pos.tankdpsTR, [6] = pos.safe, [9] = pos.tankdpsTL, [12] = pos.safe },

    [roles.healer1] = { [0] = pos.healerBL, [1] = pos.healerTL, [4] = pos.healerTR, [7] = pos.healerBR, [10] = pos.healerBL },
    [roles.healer2] = { [0] = pos.healerBL, [2] = pos.healerTL, [5] = pos.healerTR, [8] = pos.healerBR, [11] = pos.healerBL },
    [roles.healer3] = { [0] = pos.healerBL, [3] = pos.healerTL, [6] = pos.healerTR, [9] = pos.healerBR, [12] = pos.healerBL },

    [roles.healer4] = { [0] = pos.healerBR, [1] = pos.healerBL, [4] = pos.healerTL, [7] = pos.healerTR, [10] = pos.healerBR },
    [roles.healer5] = { [0] = pos.healerBR, [2] = pos.healerBL, [5] = pos.healerTL, [8] = pos.healerTR, [11] = pos.healerBR },
    [roles.healer6] = { [0] = pos.healerBR, [3] = pos.healerBL, [6] = pos.healerTL, [9] = pos.healerTR, [12] = pos.healerBR },

    [roles.healer7] = { [0] = pos.healerTL, [1] = pos.healerTR, [4] = pos.healerBR, [7] = pos.healerBL, [10] = pos.healerTL },
    [roles.healer8] = { [0] = pos.healerTL, [2] = pos.healerTR, [5] = pos.healerBR, [8] = pos.healerBL, [11] = pos.healerTL },
    [roles.healer9] = { [0] = pos.healerTL, [3] = pos.healerTR, [6] = pos.healerBR, [9] = pos.healerBL, [12] = pos.healerTL },

    [roles.healer10] = { [0] = pos.healerTR, [1] = pos.healerBR, [4] = pos.healerBL, [7] = pos.healerTL, [10] = pos.healerTR },
    [roles.healer11] = { [0] = pos.healerTR, [2] = pos.healerBR, [5] = pos.healerBL, [8] = pos.healerTL, [11] = pos.healerTR },
    [roles.healer12] = { [0] = pos.healerTR, [3] = pos.healerBR, [6] = pos.healerBL, [9] = pos.healerTL, [12] = pos.healerTR },

    [roles.healerccw1] = { [0] = pos.healerBL, [1] = pos.healerBR, [4] = pos.healerTR, [7] = pos.healerTL, [10] = pos.healerBL },
    [roles.healerccw2] = { [0] = pos.healerBL, [2] = pos.healerBR, [5] = pos.healerTR, [8] = pos.healerTL, [11] = pos.healerBL },
    [roles.healerccw3] = { [0] = pos.healerBL, [3] = pos.healerBR, [6] = pos.healerTR, [9] = pos.healerTL, [12] = pos.healerBL },

    [roles.healerccw4] = { [0] = pos.healerBR, [1] = pos.healerTR, [4] = pos.healerTL, [7] = pos.healerBL, [10] = pos.healerBR },
    [roles.healerccw5] = { [0] = pos.healerBR, [2] = pos.healerTR, [5] = pos.healerTL, [8] = pos.healerBL, [11] = pos.healerBR },
    [roles.healerccw6] = { [0] = pos.healerBR, [3] = pos.healerTR, [6] = pos.healerTL, [9] = pos.healerBL, [12] = pos.healerBR },

    [roles.healerccw7] = { [0] = pos.healerTL, [1] = pos.healerBL, [4] = pos.healerBR, [7] = pos.healerTR, [10] = pos.healerTL },
    [roles.healerccw8] = { [0] = pos.healerTL, [2] = pos.healerBL, [5] = pos.healerBR, [8] = pos.healerTR, [11] = pos.healerTL },
    [roles.healerccw9] = { [0] = pos.healerTL, [3] = pos.healerBL, [6] = pos.healerBR, [9] = pos.healerTR, [12] = pos.healerTL },

    [roles.healerccw10] = { [0] = pos.healerTR, [1] = pos.healerTL, [4] = pos.healerBL, [7] = pos.healerBR, [10] = pos.healerTR },
    [roles.healerccw11] = { [0] = pos.healerTR, [2] = pos.healerTL, [5] = pos.healerBL, [8] = pos.healerBR, [11] = pos.healerTR },
    [roles.healerccw12] = { [0] = pos.healerTR, [3] = pos.healerTL, [6] = pos.healerBL, [9] = pos.healerBR, [12] = pos.healerTR },

    [roles.healerz1] = { [0] = pos.healerBL, [1] = pos.healerTL, [4] = pos.healerTR1, [5] = pos.healerTR2, [6] = pos.healerTR3, [7] = pos.healerBR, [10] = pos.healerBL },
    [roles.healerz2] = { [0] = pos.healerBL, [2] = pos.healerTL, [5] = pos.healerTR1, [6] = pos.healerTR2, [7] = pos.healerTR3, [8] = pos.healerBR, [11] = pos.healerBL },
    [roles.healerz3] = { [0] = pos.healerBL, [3] = pos.healerTL, [6] = pos.healerTR1, [7] = pos.healerTR2, [8] = pos.healerTR3, [9] = pos.healerBR, [12] = pos.healerBL },

    [roles.healerz4] = { [0] = pos.healerBR, [1] = pos.healerBL, [4] = pos.healerTL, [7] = pos.healerTR1, [8] = pos.healerTR2, [9] = pos.healerTR3, [10] = pos.healerBR },
    [roles.healerz5] = { [0] = pos.healerBR, [2] = pos.healerBL, [5] = pos.healerTL, [8] = pos.healerTR1, [9] = pos.healerTR2, [10] = pos.healerTR3, [11] = pos.healerBR },
    [roles.healerz6] = { [0] = pos.healerBR, [3] = pos.healerBL, [6] = pos.healerTL, [9] = pos.healerTR1, [10] = pos.healerTR2, [11] = pos.healerTR3, [12] = pos.healerBR },

    [roles.healerz7] = { [0] = pos.healerTL, [1] = pos.healerTR1, [2] = pos.healerTR2, [3] = pos.healerTR3, [4] = pos.healerBR, [7] = pos.healerBL, [10] = pos.healerTL },
    [roles.healerz8] = { [0] = pos.healerTL, [2] = pos.healerTR1, [3] = pos.healerTR2, [4] = pos.healerTR3, [5] = pos.healerBR, [8] = pos.healerBL, [11] = pos.healerTL },
    [roles.healerz9] = { [0] = pos.healerTL, [3] = pos.healerTR1, [4] = pos.healerTR2, [5] = pos.healerTR3, [6] = pos.healerBR, [9] = pos.healerBL, [12] = pos.healerTL },

    [roles.healerz10] = { [0] = pos.healerTR3, [1] = pos.healerBR, [4] = pos.healerBL, [7] = pos.healerTL, [10] = pos.healerTR1, [11] = pos.healerTR2, [12] = pos.healerTR3 },
    [roles.healerz11] = { [0] = pos.healerTR2, [1] = pos.healerTR3, [2] = pos.healerBR, [5] = pos.healerBL, [8] = pos.healerTL, [11] = pos.healerTR1, [12] = pos.healerTR2 },
    [roles.healerz12] = { [0] = pos.healerTR1, [1] = pos.healerTR2, [2] = pos.healerTR3, [3] = pos.healerBR, [6] = pos.healerBL, [9] = pos.healerTL, [12] = pos.healerTR1 },

    [roles.healerzccw1] = { [0] = pos.healerBL, [1] = pos.healerBR, [4] = pos.healerTR3, [5] = pos.healerTR2, [6] = pos.healerTR1, [7] = pos.healerTL, [10] = pos.healerBL },
    [roles.healerzccw2] = { [0] = pos.healerBL, [2] = pos.healerBR, [5] = pos.healerTR3, [6] = pos.healerTR2, [7] = pos.healerTR1, [8] = pos.healerTL, [11] = pos.healerBL },
    [roles.healerzccw3] = { [0] = pos.healerBL, [3] = pos.healerBR, [6] = pos.healerTR3, [7] = pos.healerTR2, [8] = pos.healerTR1, [9] = pos.healerTL, [12] = pos.healerBL },

    [roles.healerzccw4] = { [0] = pos.healerBR, [1] = pos.healerTR3, [2] = pos.healerTR2, [3] = pos.healerTR1, [4] = pos.healerTL, [7] = pos.healerBL, [10] = pos.healerBR },
    [roles.healerzccw5] = { [0] = pos.healerBR, [2] = pos.healerTR3, [3] = pos.healerTR2, [4] = pos.healerTR1, [5] = pos.healerTL, [8] = pos.healerBL, [11] = pos.healerBR },
    [roles.healerzccw6] = { [0] = pos.healerBR, [3] = pos.healerTR3, [4] = pos.healerTR2, [5] = pos.healerTR1, [6] = pos.healerTL, [9] = pos.healerBL, [12] = pos.healerBR },

    [roles.healerzccw7] = { [0] = pos.healerTL, [1] = pos.healerBL, [4] = pos.healerBR, [7] = pos.healerTR3, [8] = pos.healerTR2, [9] = pos.healerTR1, [10] = pos.healerTL },
    [roles.healerzccw8] = { [0] = pos.healerTL, [2] = pos.healerBL, [5] = pos.healerBR, [8] = pos.healerTR3, [9] = pos.healerTR2, [10] = pos.healerTR1, [11] = pos.healerTL },
    [roles.healerzccw9] = { [0] = pos.healerTL, [3] = pos.healerBL, [6] = pos.healerBR, [9] = pos.healerTR3, [10] = pos.healerTR2, [11] = pos.healerTR1, [12] = pos.healerTL },

    [roles.healerzccw10] = { [0] = pos.healerTR1, [1] = pos.healerTL, [4] = pos.healerBL, [7] = pos.healerBR, [10] = pos.healerTR3, [11] = pos.healerTR2, [12] = pos.healerTR1 },
    [roles.healerzccw11] = { [0] = pos.healerTR2, [1] = pos.healerTR1, [2] = pos.healerTL, [5] = pos.healerBL, [8] = pos.healerBR, [11] = pos.healerTR3, [12] = pos.healerTR2 },
    [roles.healerzccw12] = { [0] = pos.healerTR3, [1] = pos.healerTR2, [2] = pos.healerTR1, [3] = pos.healerTL, [6] = pos.healerBL, [9] = pos.healerBR, [12] = pos.healerTR3 },
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
ABP_4H.RoleNamesColored = roleNamesColored;
ABP_4H.MapPositions = pos;
ABP_4H.SmallPositions = smallPos;
ABP_4H.Rotations = rotations;
ABP_4H.Modes = modes;
ABP_4H.ModeNames = modeNames;
ABP_4H.Categories = categories;
ABP_4H.RoleCategories = roleCategories;
ABP_4H.Marks = marks;
ABP_4H.MarkPositions = markPositions;
ABP_4H.Bosses = bosses;
ABP_4H.BossMarks = bossMarks;
ABP_4H.HealerMap = healerMap;
ABP_4H.TopRoles = topRoles;