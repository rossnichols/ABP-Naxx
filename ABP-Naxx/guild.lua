local _G = _G;
local ABP_Naxx = _G.ABP_Naxx;

local GetNumGuildMembers = GetNumGuildMembers;
local GetGuildRosterInfo = GetGuildRosterInfo;
local GuildRoster = GuildRoster;
local Ambiguate = Ambiguate;
local table = table;

local guildInfo = {};

function ABP_Naxx:RebuildGuildInfo()
    table.wipe(guildInfo);
    for i = 1, GetNumGuildMembers() do
        local data = { GetGuildRosterInfo(i) };
        if data[1] then
            data.player = Ambiguate(data[1], "short");
            data.index = i;
            guildInfo[data.player] = data;
        else
            -- Seen this API fail before. If that happens,
            -- request another guild roster update.
            GuildRoster();
        end
    end
end

function ABP_Naxx:GetGuildInfo(player)
    if player then return guildInfo[player]; end
    return guildInfo;
end
