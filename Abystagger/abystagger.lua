addon.name      = 'abystagger';
addon.author    = 'Laudout';
addon.version   = '3.0.0';


require('common');
local chat = require('chat');
local ffi = require('ffi');
local imgui = require('imgui');

--------------------------------------------------
-- STATE
--------------------------------------------------
local state = {
    open = { false },
    show_all = { false },
    compact = { false },
    target = 'No target',
    vana_hour = 0,
    vana_minute = 0,
    vana_day = 0,
    vana_weekday = 0,
    vana_ok = false,
    pVanaTime = 0,
};

--------------------------------------------------
-- COLORS (modern palette)
--------------------------------------------------
local colors = {
    header      = { 0.95, 0.85, 0.30, 1.0 },
    panel_bg    = { 0.12, 0.12, 0.12, 0.85 },
    panel_border= { 0.35, 0.35, 0.35, 1.0 },
    text_main   = { 0.92, 0.92, 0.92, 1.0 },
    text_dim    = { 0.60, 0.60, 0.60, 1.0 },

    red         = { 1.0, 0.30, 0.25, 1.0 },
    blue        = { 0.35, 0.68, 1.0, 1.0 },
    yellow      = { 1.0, 0.82, 0.18, 1.0 },
    green       = { 0.35, 1.0, 0.45, 1.0 },
};

--------------------------------------------------
-- WEEKDAYS
--------------------------------------------------
local weekdays = {
    'Firesday', 'Earthsday', 'Watersday', 'Windsday',
    'Iceday', 'Lightningday', 'Lightsday', 'Darksday',
};

--------------------------------------------------
-- STAGGER TABLES (unchanged)
--------------------------------------------------
local RED = {
    {'Dagger', 'Cyclone', 125}, {'Dagger', 'Energy Drain', 175},
    {'Sword', 'Red Lotus', 50}, {'Sword', 'Seraph Blade', 125},
    {'Great Sword', 'Freezebite', 100}, {'Scythe', 'Shadow of Death', 70},
    {'Polearm', 'Raiden Thrust', 70}, {'Katana', 'Blade: Ei', 175},
    {'Great Katana', 'Jinpu', 150}, {'Great Katana', 'Koki', 175},
    {'Club', 'Seraph Strike', 40}, {'Staff', 'Earth Crusher', 70},
    {'Staff', 'Sunburst', 150},
};

local BLUE = {
    {'Piercing', 'Dagger', 'Shadowstitch', 70},
    {'Piercing', 'Dagger', 'Dancing Edge', 200},
    {'Piercing', 'Dagger', 'Shark Bite', 225},
    {'Piercing', 'Dagger', 'Evisceration', 230},
    {'Piercing', 'Polearm', 'Skewer', 200},
    {'Piercing', 'Polearm', 'Wheeling Thrust', 225},
    {'Piercing', 'Polearm', 'Impulse Drive', 240},
    {'Piercing', 'Archery', 'Sidewinder', 175},
    {'Piercing', 'Archery', 'Blast Arrow', 200},
    {'Piercing', 'Archery', 'Arching Arrow', 225},
    {'Piercing', 'Archery', 'Empyreal Arrow', 250},

    {'Slashing', 'Sword', 'Vorpal Blade', 200},
    {'Slashing', 'Sword', 'Swift Blade', 225},
    {'Slashing', 'Sword', 'Savage Blade', 240},
    {'Slashing', 'Great Sword', 'Spinning Slash', 225},
    {'Slashing', 'Great Sword', 'Ground Strike', 250},
    {'Slashing', 'Axe', 'Mistral Axe', 225},
    {'Slashing', 'Axe', 'Decimation', 240},
    {'Slashing', 'Great Axe', 'Full Break', 225},
    {'Slashing', 'Great Axe', 'Steel Cyclone', 240},
    {'Slashing', 'Scythe', 'Cross Reaper', 225},
    {'Slashing', 'Scythe', 'Spiral Hell', 240},
    {'Slashing', 'Katana', 'Blade: Ten', 225},
    {'Slashing', 'Katana', 'Blade: Ku', 250},
    {'Slashing', 'Great Katana', 'Gekko', 225},
    {'Slashing', 'Great Katana', 'Kasha', 250},

    {'Blunt', 'Hand-to-Hand', 'Raging Fists', 125},
    {'Blunt', 'Hand-to-Hand', 'Spinning Attack', 150},
    {'Blunt', 'Hand-to-Hand', 'Howling Fist', 200},
    {'Blunt', 'Hand-to-Hand', 'Dragon Kick', 225},
    {'Blunt', 'Hand-to-Hand', 'Asuran Fists', 250},
    {'Blunt', 'Club', 'Skullbreaker', 150},
    {'Blunt', 'Club', 'True Strike', 175},
    {'Blunt', 'Club', 'Judgment', 200},
    {'Blunt', 'Club', 'Hexa Strike', 220},
    {'Blunt', 'Club', 'Black Halo', 230},
};

local YELLOW = {
    {'Firesday', 'Fire', 'Fire III, Fire IV, Firaga III, Flare, Katon: Ni, Ice Threnody, Heat Breath'},
    {'Earthsday', 'Earth', 'Stone III, Stone IV, Stonega III, Quake, Doton: Ni, Lightning Threnody, Magnetite Cloud'},
    {'Watersday', 'Water', 'Water III, Water IV, Waterga III, Flood, Suiton: Ni, Fire Threnody, Maelstrom'},
    {'Windsday', 'Wind', 'Aero III, Aero IV, Aeroga III, Tornado, Huton: Ni, Earth Threnody, Mysterious Light'},
    {'Iceday', 'Ice', 'Blizzard III, Blizzard IV, Blizzaga III, Freeze, Hyoton: Ni, Wind Threnody, Ice Break'},
    {'Lightningday', 'Lightning', 'Thunder III, Thunder IV, Thundaga III, Burst, Raiton: Ni, Water Threnody, Mind Blast'},
    {'Lightsday', 'Light', 'Banish II, Banish III, Banishga III, Holy, Flash, Dark Threnody, Radiant Breath'},
    {'Darksday', 'Dark', 'Drain, Aspir, Dispel, Bio II, Kurayami: Ni, Light Threnody, Eyes On Me'},
};

--------------------------------------------------
-- VANA TIME
--------------------------------------------------
local VANA_EPOCH_OFFSET = 92514960;

local function init_vana_time()
    state.pVanaTime = ashita.memory.find(
        'FFXiMain.dll', 0,
        'B0015EC390518B4C24088D4424005068',
        0x34, 0
    );

    state.vana_ok = state.pVanaTime ~= nil and state.pVanaTime ~= 0;

    if not state.vana_ok then
        print(chat.header(addon.name):append(chat.error(
            'Vana-diel clock signature not found; Blue/Yellow auto-selection disabled.'
        )));
    end
end

local function update_vana_time()
    if not state.vana_ok then return end

    local clock_ptr = ashita.memory.read_uint32(state.pVanaTime);
    if not clock_ptr or clock_ptr == 0 then return end

    local raw = ashita.memory.read_uint32(clock_ptr + 0x0C);
    if not raw then return end

    local ts = (raw + VANA_EPOCH_OFFSET) * 25;
    local day = math.floor(ts / 86400);
    local hour = math.floor(ts / 3600) % 24;
    local minute = math.floor(ts / 60) % 60;
    local weekday = day % 8;

    state.vana_day = day;
    state.vana_hour = hour;
    state.vana_minute = minute;
    state.vana_weekday = weekday;
end

--------------------------------------------------
-- TARGET
--------------------------------------------------
local function update_target()
    local index = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
    local target = GetEntity(index);

    if target and target.Name and target.Name ~= '' then
        state.target = target.Name;
    else
        state.target = 'No target';
    end
end

--------------------------------------------------
-- BLUE WINDOW
--------------------------------------------------
local function blue_window()
    local hour = state.vana_hour;

    if hour >= 6 and hour < 14 then
        return 'Piercing';
    elseif hour >= 14 and hour < 22 then
        return 'Slashing';
    else
        return 'Blunt';
    end
end

local function current_day()
    return weekdays[state.vana_weekday + 1] or 'Unknown day';
end

--------------------------------------------------
-- UI HELPERS
--------------------------------------------------
local function begin_panel(title, color, height)
    imgui.PushStyleColor(ImGuiCol_ChildBg, colors.panel_bg);
    imgui.PushStyleColor(ImGuiCol_Border, colors.panel_border);
    imgui.BeginChild(title, {0, height}, ImGuiChildFlags_Borders);
    imgui.TextColored(color, title);
    imgui.Separator();
end

local function end_panel()
    imgui.EndChild();
    imgui.PopStyleColor(2);
end

--------------------------------------------------
-- HEADER
--------------------------------------------------
local function render_header()
    imgui.PushStyleColor(ImGuiCol_Text, colors.header);
    imgui.Text('ABYSSEA STAGGER LIVE');
    imgui.PopStyleColor();

    imgui.Separator();

    imgui.TextColored(colors.text_main, 'Target: ');
    imgui.SameLine();
    imgui.TextColored(colors.green, state.target);

    imgui.SameLine();
    imgui.TextColored(colors.text_dim, ' | ');

    imgui.SameLine();
    imgui.TextColored(colors.header,
        ("Vana %02d:%02d  %s"):format(state.vana_hour, state.vana_minute, current_day())
    );

    imgui.Separator();
end

--------------------------------------------------
-- RED PANEL
--------------------------------------------------
-- RED PANEL
local function render_red()
    begin_panel('!! RED !!  Elemental WS', colors.red, state.compact[1] and 120 or 185);

    for _, s in ipairs(RED) do
        imgui.TextColored(colors.red, s[1]);
        imgui.SameLine();
        imgui.Text(('%s  (%d)'):format(s[2], s[3]));
    end

    end_panel();
end

-- BLUE PANEL
local function render_blue()
    local active = blue_window();

    begin_panel(('!! BLUE !!  Physical WS  (ACTIVE: %s)'):format(active),
        colors.blue,
        state.compact[1] and 180 or 260
    );

    for _, s in ipairs(BLUE) do
        if state.show_all[1] or s[1] == active then
            imgui.TextColored(colors.blue, s[2]);
            imgui.SameLine();
            imgui.Text(('%-22s (%d)'):format(s[3], s[4]));
        end
    end

    end_panel();
end

-- YELLOW PANEL
local function render_yellow()
    local active = current_day();

    begin_panel(('!! YELLOW !!  Magic  (ACTIVE: %s)'):format(active),
        colors.yellow,
        state.compact[1] and 110 or 145
    );

    for _, s in ipairs(YELLOW) do
        if state.show_all[1] or s[1] == active then
            imgui.TextColored(colors.yellow, s[1]);
            imgui.SameLine();
            imgui.Text(('%s: %s'):format(s[2], s[3]));
        end
    end

    end_panel();
end


--------------------------------------------------
-- COMMANDS
--------------------------------------------------
ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args();
    if #args == 0 then return end

    if args[1] ~= '/abystagger' and args[1] ~= '/as' then return end
    e.blocked = true;

    if args[2] == 'all' then
        state.show_all[1] = not state.show_all[1];
    elseif args[2] == 'compact' then
        state.compact[1] = not state.compact[1];
    elseif args[2] == 'show' then
        state.open[1] = true;
    elseif args[2] == 'hide' then
        state.open[1] = false;
    else
        state.open[1] = not state.open[1];
    end
end);

--------------------------------------------------
-- MAIN DRAW
--------------------------------------------------
ashita.events.register('d3d_present', 'present_cb', function()
    update_vana_time();
    update_target();

    if not state.open[1] then return end

    imgui.SetNextWindowSize({ 780, 780 }, ImGuiCond_FirstUseEver);

    if imgui.Begin('Abyssea Stagger##abystagger_v3', state.open) then
        render_header();

        if imgui.Button(state.show_all[1] and 'SHOW ACTIVE ONLY' or 'SHOW ALL') then
            state.show_all[1] = not state.show_all[1];
        end

        imgui.SameLine();
        if imgui.Button(state.compact[1] and 'FULL MODE' or 'COMPACT MODE') then
            state.compact[1] = not state.compact[1];
        end

        imgui.Separator();

        render_red();
        imgui.Separator();
        render_blue();
        imgui.Separator();
        render_yellow();

        imgui.Separator();

imgui.TextColored(colors.text_dim,
    'Red: elemental WS  |  Blue: time-of-day  |  Yellow: day-of-week'
);

imgui.TextColored(colors.text_dim,
    'Blue proc windows: 06:00-13:59 Piercing  |  14:00-21:59 Slashing  |  22:00-05:59 Blunt'
);

imgui.End();


    end

    imgui.End();
end);

ashita.events.register('load', 'load_cb', function()
    init_vana_time();
end);
