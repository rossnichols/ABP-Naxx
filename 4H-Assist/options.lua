local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceConfig = _G.LibStub("AceConfig-3.0");
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0");
local AceDB = _G.LibStub("AceDB-3.0");

local pairs = pairs;

function ABP_4H:InitOptions()
    local defaults = {
        char = {
            debug = false,
            showAlert = true,
            showMoveAlert = true,
            showMarkAlert = true,
            showTanks = true,
            showNeighbors = true,
            nonHealers = "",
            alpha = 0.9,
            raidLayout = nil,
            healerCCW = false,
        }
    };
    self.db = AceDB:New("ABP_4H_DB", defaults);

    local addonText = "4H Assist";
    local version = self:GetVersion();
    if self:ParseVersion(version) then
        addonText = "4H Assist v" .. version;
    end
    local options = {
        show = {
            name = "Show",
            desc = "shows the main window",
            type = "execute",
            func = function() self:ShowMainWindow(); end
        },
        start = {
            name = "Start",
            desc = "shows the start window",
            type = "execute",
            func = function() self:ShowStartWindow(); end
        },
        options = {
            name = "Options",
            desc = "opens the options window (alias: config/opt)",
            type = "execute",
            func = function() self:ShowOptionsWindow(); end
        },
        versioncheck = {
            name = "Version Check",
            desc = "checks the raid for an outdated or missing addon versions (alias: vc)",
            type = "execute",
            func = function() self:PerformVersionCheck(); end
        },
    };

    local function setupAlias(existing, alias)
        options[alias] = {};
        for k, v in pairs(options[existing]) do options[alias][k] = v; end
        options[alias].hidden = true;
        options[alias].cmdHidden = nil;
    end
    setupAlias("options", "opt");
    setupAlias("options", "config");
    setupAlias("versioncheck", "vc");

    AceConfig:RegisterOptionsTable(self:ColorizeText(addonText), {
        type = "group",
        args = options,
    }, { "fh", "fourh" });

    local guiOptions = {
        general = {
            name = "",
            type = "group",
            inline = true,
            order = 1,
            args = {
                header = {
                    order = 1,
                    type = "header",
                    name = "General",
                },
                settings = {
                    name = " ",
                    type = "group",
                    inline = true,
                    order = 2,
                    args = {
                        show = {
                            name = "Show Map",
                            order = 1,
                            desc = "Show the map window to browse the roles and their positions.",
                            type = "execute",
                            func = function() _G.InterfaceOptionsFrame:Hide(); self:ShowMainWindow(); end
                        },
                        start = {
                            name = "Start Encounter",
                            order = 2,
                            desc = "Show the window to start a synchronized encounter.",
                            type = "execute",
                            func = function() _G.InterfaceOptionsFrame:Hide(); self:ShowStartWindow(); end
                        },
                        alerts = {
                            name = "Alert pending move",
                            order = 3,
                            desc = "Show a DBM alert when you're supposed to move after the next mark.",
                            type = "toggle",
                            get = function(info) return self.db.char.showAlert; end,
                            set = function(info, v) self.db.char.showAlert = v; end,
                        },
                        moveAlerts = {
                            name = "Alert immediate move",
                            order = 4,
                            desc = "Show a DBM alert when you're supposed to move on the current mark.",
                            type = "toggle",
                            get = function(info) return self.db.char.showMoveAlert; end,
                            set = function(info, v) self.db.char.showMoveAlert = v; end,
                        },
                        markAlerts = {
                            name = "Alert 4+ marks",
                            order = 5,
                            desc = "Show a DBM alert when you have four or more stacks on a mark.",
                            type = "toggle",
                            get = function(info) return self.db.char.showMarkAlert; end,
                            set = function(info, v) self.db.char.showMarkAlert = v; end,
                        },
                        tanks = {
                            name = "Show tanks",
                            order = 6,
                            desc = "Show the current/upcoming tanks for each corner on the map.",
                            type = "toggle",
                            get = function(info) return self.db.char.showTanks; end,
                            set = function(info, v) self.db.char.showTanks = v; self:RefreshMainWindow(); end,
                        },
                        neighbors = {
                            name = "Show neighbors",
                            order = 7,
                            desc = "Show a list of players under the map who are supposed to be at your location, colored by range.",
                            type = "toggle",
                            get = function(info) return self.db.char.showNeighbors; end,
                            set = function(info, v) self.db.char.showNeighbors = v; self:RefreshMainWindow(); end,
                        },
                        ccw = {
                            name = "CCW Healers",
                            order = 8,
                            desc = "If checked, healers will rotate counterclockwise instead of clockwise.",
                            type = "toggle",
                            get = function(info) return self.db.char.healerCCW; end,
                            set = function(info, v) self.db.char.healerCCW = v; self:RefreshMainWindow(); end,
                        },
                        alpha = {
                            name = "Map Alpha",
                            order = 9,
                            desc = "Controls the alpha of the map.",
                            type = "range",
                            min = 0,
                            max = 1,
                            step = 0.05,
                            get = function(info) return self.db.char.alpha; end,
                            set = function(info, v) self.db.char.alpha = v; self:RefreshMainWindow(); end,
                        },
                    },
                },
            },
        },
        -- officer = {
        --     name = "",
        --     type = "group",
        --     inline = true,
        --     order = 5,
        --     hidden = function() return not self:CanEditOfficerNotes(); end,
        --     args = {
        --         header = {
        --             order = 1,
        --             type = "header",
        --             name = "Officer",
        --         },
        --         desc = {
        --             order = 2,
        --             type = "description",
        --             name = "Special settings for officers.",
        --         },
        --         settings = {
        --             name = " ",
        --             type = "group",
        --             inline = true,
        --             order = 3,
        --             args = {
        --             },
        --         },
        --     },
        -- },
    };
    AceConfig:RegisterOptionsTable("4H Assist", {
        name = self:ColorizeText(addonText) .. " Options",
        type = "group",
        args = guiOptions,
    });
    self.OptionsFrame = AceConfigDialog:AddToBlizOptions("4H Assist");
end

function ABP_4H:ShowOptionsWindow()
    _G.InterfaceOptionsFrame_Show();
    _G.InterfaceOptionsFrame_OpenToCategory(self.OptionsFrame);
end

function ABP_4H:Get(k)
    return self.db.char[k];
end

function ABP_4H:Set(k, v)
    self.db.char[k] = v;
end

function ABP_4H:RefreshOptionsWindow()
    if self.OptionsFrame:IsVisible() then
        AceConfigDialog:Open("ABP_4H", self.OptionsFrame.obj);
    end
end
