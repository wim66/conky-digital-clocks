-- clock.lua: Lua-script voor Conky flipklok met halve cijfers (*T.png en *B.png)
-- Afbeeldingen: 27x31 pixels per helft, gelegen in ./images/
-- Animatie: Bovenste helft klapt omlaag met onderste helft van nieuw cijfer op achterkant, zoals een roterende rol

-- === Required Cairo Modules ===
require 'cairo'
-- Attempt to safely require the 'cairo_xlib' module
local status, cairo_xlib = pcall(require, 'cairo_xlib')

if not status then
    -- If not found, fall back to a dummy table
    -- Redirects unknown keys to the global namespace (_G)
    -- Allows use of global Cairo functions like cairo_xlib_surface_create
    cairo_xlib = setmetatable({}, {
        __index = function(_, key)
            return _G[key]
        end
    })
end

-- Pad naar afbeeldingen (relatief vanaf de locatie van conky.conf)
local digit_path = "images/"

-- Configureerbare animatiesnelheid (graden per frame)
local anim_speed = 2 -- Standaard: 10 graden per frame (0.45s voor 90° met update_interval=0.05)
                      -- Verlaag naar 5 voor langzamer, verhoog naar 15 voor sneller

-- Cache voor afbeeldingssurfaces
local digit_surfaces = digit_surfaces or {}
function load_digit_surface(digit, part)
    local key = digit .. "_" .. part
    if not digit_surfaces[key] then
        local file = string.format("%s%d%s.png", digit_path, digit, part)
        digit_surfaces[key] = cairo_image_surface_create_from_png(file)
    end
    return digit_surfaces[key]
end

-- Lua-functies
function conky_draw_flipclock()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Huidige tijd ophalen
    local hours = tonumber(os.date("%H"))
    local minutes = tonumber(os.date("%M"))

    -- Splits uren en minuten in tientallen en eenheden
    local hour_tens = math.floor(hours / 10)
    local hour_units = hours % 10
    local minute_tens = math.floor(minutes / 10)
    local minute_units = minutes % 10

    -- Animatie-status bijhouden (alleen voor minute_units)
    local anim_state = anim_state or { minute_units = minute_units, angle = 0, flipping = false }
    -- Controleer of minute_units zijn veranderd om flip te starten
    if minute_units ~= anim_state.minute_units and not anim_state.flipping then
        anim_state.flipping = true
        anim_state.angle = 0
        anim_state.old_minute_units = anim_state.minute_units
        anim_state.minute_units = minute_units
    end

    -- Teken vier cijfers: uren (tientallen, eenheden), minuten (tientallen, eenheden)
    draw_digit_pair(cr, 20, 20, hour_tens, false, 0) -- Uren tientallen
    draw_digit_pair(cr, 57, 20, hour_units, false, 0) -- Uren eenheden
    draw_digit_pair(cr, 94, 20, minute_tens, false, 0) -- Minuten tientallen
    draw_digit_pair(cr, 131, 20, anim_state.old_minute_units or anim_state.minute_units, anim_state.flipping, anim_state.angle, anim_state.minute_units) -- Minuten eenheden

    -- Animatie bijwerken
    if anim_state.flipping then
        anim_state.angle = anim_state.angle + anim_speed
        if anim_state.angle >= 90 then -- Volledige flip na 90 graden
            anim_state.flipping = false
            anim_state.angle = 0
            anim_state.old_minute_units = nil
        end
    end

    -- Schoon opruimen
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
    return ""
end

function draw_digit_pair(cr, x, y, digit, flipping, angle, next_digit)
    -- Instelbare offset voor uitlijning (pas aan als helften niet aansluiten)
    local bottom_offset = 31 -- Standaard: hoogte van bovenste helft

    -- Teken bovenste en onderste helft van het cijfer
    local top_surface = load_digit_surface(digit, "T")
    local bottom_surface = load_digit_surface(digit, "B")

    -- Foutafhandeling
    if cairo_surface_status(top_surface) ~= 0 or cairo_surface_status(bottom_surface) ~= 0 then
        cairo_set_source_rgb(cr, 1, 0, 0) -- Rode achtergrond als fout
        cairo_rectangle(cr, x, y, 27, 62) -- Volledige cijfergrootte: 27x62
        cairo_fill(cr)
        return
    end

    if flipping and next_digit then
        -- Teken onderste helft van het nieuwe cijfer (direct vervangen)
        local next_bottom_surface = load_digit_surface(next_digit, "B")
        if cairo_surface_status(next_bottom_surface) == 0 then
            cairo_set_source_surface(cr, next_bottom_surface, x, y + bottom_offset)
            cairo_paint(cr)
        end

        -- Teken nieuwe bovenste helft (klapt omhoog van 90° naar 0°)
        local next_top_surface = load_digit_surface(next_digit, "T")
        if cairo_surface_status(next_top_surface) == 0 then
            cairo_save(cr)
            cairo_translate(cr, x + 13.5, y + bottom_offset) -- Rotatiepunt: midden breedte, onderkant bovenste helft
            cairo_rotate(cr, math.rad(90 - angle)) -- Roteer omhoog
            cairo_translate(cr, -13.5, -bottom_offset)
            cairo_set_source_surface(cr, next_top_surface, x, y)
            cairo_paint(cr)
            cairo_restore(cr)
        end

        -- Teken schaduw voor de flap (omlaag klappen)
        cairo_save(cr)
        cairo_translate(cr, x + 13.5, y + bottom_offset)
        cairo_rotate(cr, math.rad(angle)) -- Roteer omlaag
        cairo_translate(cr, -13.5, -bottom_offset)
        cairo_set_source_rgba(cr, 0, 0, 0, 0.3) -- Zwarte schaduw
        cairo_rectangle(cr, x + 2, y + 2, 27, 31)
        cairo_fill(cr)
        cairo_restore(cr)

        -- Teken oude bovenste helft (voorzijde, klapt omlaag)
        cairo_save(cr)
        cairo_translate(cr, x + 13.5, y + bottom_offset)
        cairo_rotate(cr, math.rad(angle)) -- Roteer omlaag (0° naar 90°)
        cairo_translate(cr, -13.5, -bottom_offset)
        cairo_set_source_surface(cr, top_surface, x, y)
        cairo_paint(cr)
        cairo_restore(cr)

        -- Teken achterkant van de flap (onderste helft van nieuw cijfer)
        if angle > 0 then -- Alleen tonen als de flap draait
            cairo_save(cr)
            cairo_translate(cr, x + 13.5, y + bottom_offset)
            cairo_rotate(cr, math.rad(angle)) -- Achterkant draait mee
            cairo_scale(cr, 1, -1) -- Spiegel verticaal voor achterkant
            cairo_translate(cr, -13.5, -bottom_offset)
            cairo_set_source_surface(cr, next_bottom_surface, x, y)
            cairo_paint(cr)
            cairo_restore(cr)
        end
    else
        -- Normale weergave: bovenste en onderste helft van hetzelfde cijfer
        cairo_set_source_surface(cr, top_surface, x, y)
        cairo_paint(cr)
        cairo_set_source_surface(cr, bottom_surface, x, y + bottom_offset)
        cairo_paint(cr)
    end
end