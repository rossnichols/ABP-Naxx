local _G = _G;
local ABP_4H = _G.ABP_4H;
local AceConfig = _G.LibStub("AceConfig-3.0");
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0");
local AceDB = _G.LibStub("AceDB-3.0");

local pairs = pairs;
local type = type;

function ABP_4H:InitOptions()
    local defaults = {
        char = {
            showAlert = true,
            showMoveAlert = true,
            showMarkAlert = true,
            showTanks = true,
            showNeighbors = true,
            nonHealers = "",
            alpha = 0.9,
            raidLayout = nil,
            selectedRaidLayout = 2,
            healerCCW = false,
            healerZeliak = true,
            windowManagement = {},
            confirmClose = true,
            previousRoles = {},
            previousRolesFake = {},
        },
        global = {
            outdatedVersion = "popup",
            debug = false,
            raidLayouts = {},
        },
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
            desc = "shows the map window",
            type = "execute",
            func = function() self:ShowMainWindow(); end
        },
        start = {
            name = "Start",
            desc = "shows the raid config window",
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
    setupAlias("versioncheck", "v");
    setupAlias("versioncheck", "vc");
    setupAlias("versioncheck", "version");

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
                desc = {
                    order = 2,
                    type = "description",
                    name = ("Brought to you by %s of <%s>, %s!"):format(
                        self:ColorizeText("Xanido"), self:ColorizeText("Always Be Pulling"), self:ColorizeText("US-Atiesh (Alliance)")),
                },
                desc2 = {
                    order = 3,
                    type = "description",
                    name = ("%s: leave a comment on CurseForge/WoWInterface, or reach out to %s on reddit."):format(
                        self:ColorizeText("Feedback/support"), self:ColorizeText("ross456")),
                },
                settings = {
                    name = " ",
                    type = "group",
                    inline = true,
                    order = 4,
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
                        neighbors = {
                            name = "Confirm map close",
                            order = 8,
                            desc = "If enabled, you'll be prompted when closing the map while an encounter is in progress, unless you're holding the shift key.",
                            type = "toggle",
                            get = function(info) return self.db.char.confirmClose; end,
                            set = function(info, v) self.db.char.confirmClose = v; end,
                        },
                        ccw = {
                            name = "Healer Opts",
                            order = 9,
                            desc = "|cff00ff00Counter-clockwise|r: If checked, healers will rotate counterclockwise instead of clockwise.\n\n" ..
                                   "|cff00ff00Staggered Zeliak|r: If checked, healer positions in Zeliak's corner will be staggered, with the healer moving each mark.",
                            type = "multiselect",
                            values = { healerCCW = "Counter-clockwise", healerZeliak = "Staggered Zeliak" },
                            get = function(info, k) return self.db.char[k]; end,
                            set = function(info, k, v) self.db.char[k] = v; self:RefreshMainWindow(); end,
                        },
                        alpha = {
                            name = "Map Alpha",
                            order = 10,
                            desc = "Controls the alpha of the map.",
                            type = "range",
                            min = 0,
                            max = 1,
                            step = 0.05,
                            get = function(info) return self.db.char.alpha; end,
                            set = function(info, v) self.db.char.alpha = v; self:RefreshMainWindow(); end,
                        },
                        outdatedversion = {
                            name = "Version Warning",
                            order = 11,
                            desc = "Choose how you'll be notified about newer versions of the addon.",
                            type = "select",
                            values = {
                                popup = "Popup",
                                msg = "Chat Message"
                            },
                            style = "dropdown",
                            get = function(info) return self.db.global.outdatedVersion; end,
                            set = function(info, v) self.db.global.outdatedVersion = v; end,
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

function ABP_4H:GetGlobal(k)
    return self.db.global[k];
end

function ABP_4H:SetGlobal(k, v)
    self.db.global[k] = v;
end

function ABP_4H:RefreshOptionsWindow()
    if self.OptionsFrame:IsVisible() then
        AceConfigDialog:Open("ABP_4H", self.OptionsFrame.obj);
    end
end

function ABP_4H:GetCurrentLayout()
    local setting = self:Get("selectedRaidLayout");
    local layouts = self:GetGlobal("raidLayouts");
    if type(setting) == "string" and not layouts[setting] then
        setting = 1;
    elseif setting == 2 and not self:Get("raidLayout") then
        setting = 1;
    end

    return setting;
end

function ABP_4H:GetLayouts()
    local layouts = { [1] = "|cff00ff00Default|r" };
    if self:Get("raidLayout") then
        layouts[2] = "|cff00ff00Legacy Saved (Per-Char)";
    end

    local saved = self:GetGlobal("raidLayouts");
    for name in pairs(saved) do
        layouts[name] = name;
    end

    return layouts;
end

function ABP_4H:LoadCurrentLayout()
    local setting = self:GetCurrentLayout();
    local layout;

    if setting == 1 then
        layout = self.RaidRoles;
    elseif setting == 2 then
        layout = self:Get("raidLayout");
    else
        local layouts = self:GetGlobal("raidLayouts");
        layout = layouts[setting];
    end

    return layout and self.tCopy(layout);
end

function ABP_4H:DeleteLayout(name)
    if name == 2 then
        self:Set("raidLayout", nil);
    elseif type(name) == "string" then
        local layouts = self:GetGlobal("raidLayouts");
        layouts[name] = nil;
    end
end

function ABP_4H:SaveLayout(name, layout)
    local layouts = self:GetGlobal("raidLayouts");
    layouts[name] = layout;
end

function ABP_4H:GetHealerSetup()
    -- 0: no zeliak breakout, clockwise
    -- 1: zeliak breakout, clockwise
    -- 2: no zeliak breakout, counterclockwise
    -- 3: zeliak breakout, counterclockwise

    local ccw = ABP_4H:Get("healerCCW") and 2 or 0;
    local z = ABP_4H:Get("healerZeliak") and 1 or 0;

    return ccw + z;
end
