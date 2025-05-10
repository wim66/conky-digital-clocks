require 'cairo'
local status, cairo_xlib = pcall(require, 'cairo_xlib')

if not status then
    cairo_xlib = setmetatable({}, {
        __index = function(_, k)
            return _G[k]
        end
    })
end

-- Configuratie
local settings = {
    font_name = "zekton",
    font_size = 64,

    x_start = 106,             -- wordt overschreven als center_horizontally true is
    y_start = 53,              -- idem bij center_vertically

    center_horizontally = true,
    center_vertically = true,

    text_align = "center",     -- "left", "center", "right"
    text_valign = "center",    -- "top", "center", "bottom"

    draw_shadow = true,
    shadow_color = 0x00ff00,
    shadow_alpha = 1,
    shadow_offset = {x = 2, y = 2},

    draw_stroke = true,        -- Voeg rand toe
    stroke_color = 0x000000,   -- Zwart voor de rand
    stroke_width = 1,          -- Dikte van de rand

    draw_glow = true,          -- Voeg glow toe
    glow_color = 0xffff00,     -- Gele gloed
    glow_alpha = 0.4,          -- Gloed-transparantie
    glow_offset = {x = 4, y = 4}, -- Gloedverplaatsing

    linear_gradient = {0, 0, 0, 200},
    colours = {
        {0,    0xFFFFFF, 0.5},
        {0.5, 0x000000, 0.75},
        {1,    0x000000, 0.9}
    }
}

-- Hulpfunctie: hex naar RGB (0–1)
local function hex_to_rgb(colour)
    return ((colour >> 16) & 0xFF) / 255,
           ((colour >> 8) & 0xFF) / 255,
           (colour & 0xFF) / 255
end

-- Gradient toepassen
local function apply_text_gradient(cr)
    local grad = cairo_pattern_create_linear(table.unpack(settings.linear_gradient))
    for _, stop in ipairs(settings.colours) do
        local pos, col, alpha = stop[1], stop[2], stop[3]
        local r, g, b = hex_to_rgb(col)
        cairo_pattern_add_color_stop_rgba(grad, pos, r, g, b, alpha)
    end
    cairo_set_source(cr, grad)
end

-- Bereken uitlijning
local function get_aligned_position(cr, text, win_w, win_h)
    local extents = cairo_text_extents_t:create()
    cairo_text_extents(cr, text, extents)

    -- x_start en y_start herberekenen als centreren aanstaat
    local x_ref = settings.center_horizontally and win_w / 2 or settings.x_start
    local y_ref = settings.center_vertically and win_h / 2 or settings.y_start

    -- Horizontale uitlijning
    local x
    if settings.text_align == "center" then
        x = x_ref - (extents.width / 2 + extents.x_bearing)
    elseif settings.text_align == "right" then
        x = x_ref - (extents.width + extents.x_bearing)
    else -- "left"
        x = x_ref
    end

    -- Verticale uitlijning
    local y
    if settings.text_valign == "center" then
        y = y_ref - (extents.height / 2 + extents.y_bearing)
    elseif settings.text_valign == "bottom" then
        y = y_ref - (extents.height + extents.y_bearing)
    else -- "top"
        y = y_ref
    end

    return x, y
end

-- Hoofdfunctie
function conky_draw_digital_clock()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cs)

    cairo_select_font_face(cr, settings.font_name, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, settings.font_size)

    local time_string = os.date("%H:%M")
    local base_x, base_y = get_aligned_position(cr, time_string, conky_window.width, conky_window.height)

    -- Glow-effect toevoegen
    if settings.draw_glow then
        local r, g, b = hex_to_rgb(settings.glow_color or 0xFFFF00)
        local a = settings.glow_alpha or 0.4
        cairo_set_source_rgba(cr, r, g, b, a)
        cairo_move_to(cr, base_x + settings.glow_offset.x, base_y + settings.glow_offset.y)
        cairo_text_path(cr, time_string)
        cairo_fill(cr)
    end

    -- Schaduw
    if settings.draw_shadow then
        local offset = settings.shadow_offset or {x = 2, y = 2}
        local r, g, b = hex_to_rgb(settings.shadow_color or 0x000000)
        local a = settings.shadow_alpha or 0.5
        cairo_move_to(cr, base_x + offset.x, base_y + offset.y)
        cairo_text_path(cr, time_string)
        cairo_set_source_rgba(cr, r, g, b, a)
        cairo_fill(cr)
    end

    -- Rand (stroke)
    if settings.draw_stroke then
        local r, g, b = hex_to_rgb(settings.stroke_color or 0x000000)
        cairo_set_source_rgba(cr, r, g, b, 1)
        cairo_set_line_width(cr, settings.stroke_width or 4)
        cairo_move_to(cr, base_x, base_y)
        cairo_text_path(cr, time_string)
        cairo_stroke(cr)
    end

    -- Gradient toepassen
    apply_text_gradient(cr)

    -- Tekst vullen
    cairo_move_to(cr, base_x, base_y)
    cairo_show_text(cr, time_string)

    -- Opruimen
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
