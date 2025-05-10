-- Animated Digital Clock for Conky (zonder Flip en Gradient)
-- Versie: vereenvoudigd

require 'cairo'
local status, cairo_xlib = pcall(require, 'cairo_xlib')
if not status then
    cairo_xlib = setmetatable({}, { __index = function(_, k) return _G[k] end })
end

-- SETTINGS --
local settings = {
    font_name = "zekton",
    font_size = 64,
    animation_type = "slide", -- slide or none
    animation_duration = 0.08,

    center_horizontally = true,
    center_vertically = false,
    text_align = "center",
    text_valign = "center",

    draw_shadow = true,
    shadow_color = 0xff981d,
    shadow_alpha = 1,
    shadow_offset = {x = 2, y = 2},

    draw_stroke = true,
    stroke_color = 0x000000,
    stroke_width = 1,

    draw_glow = true,
    glow_color = 0xff0000,
    glow_alpha = 0.25,
    glow_offset = {x = 4, y = 4},

    text_color = 0xFFFFFF,
    text_alpha = 0.3

}

-- STATE --
local digits = {}
local last_time = ""

-- HELPERS --
local function hex_to_rgb(colour)
    return ((colour >> 16) & 0xFF) / 255,
           ((colour >> 8) & 0xFF) / 255,
           (colour & 0xFF) / 255
end

local function draw_styled_char(cr, char, x, y)
    cairo_save(cr)
    cairo_translate(cr, x, y)

    cairo_set_font_size(cr, settings.font_size)
    cairo_select_font_face(cr, settings.font_name, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)

    -- Glow (simpele diffuse gloed door herhaling)
    if settings.draw_glow then
        local r, g, b = hex_to_rgb(settings.glow_color)
        cairo_set_source_rgba(cr, r, g, b, settings.glow_alpha)
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    cairo_move_to(cr, dx + settings.glow_offset.x, dy + settings.glow_offset.y)
                    cairo_show_text(cr, char)
                end
            end
        end
    end

    -- Schaduw
    if settings.draw_shadow then
        local r, g, b = hex_to_rgb(settings.shadow_color)
        cairo_set_source_rgba(cr, r, g, b, settings.shadow_alpha)
        cairo_move_to(cr, settings.shadow_offset.x, settings.shadow_offset.y)
        cairo_show_text(cr, char)
    end

    -- Rand (stroke)
    if settings.draw_stroke then
        local r, g, b = hex_to_rgb(settings.stroke_color)
        cairo_set_source_rgba(cr, r, g, b, 1)
        cairo_set_line_width(cr, settings.stroke_width)
        cairo_move_to(cr, 0, 0)
        cairo_text_path(cr, char)
        cairo_stroke_preserve(cr)
    end

    -- Tekstkleur met alpha
    local r, g, b = hex_to_rgb(settings.text_color)
    cairo_set_source_rgba(cr, r, g, b, settings.text_alpha)
    cairo_move_to(cr, 0, 0)
    cairo_show_text(cr, char)

    cairo_restore(cr)
end


local function interpolate(a, b, t)
    return a + (b - a) * t
end

local function draw_digit(cr, old_char, new_char, x, y, elapsed)
    local progress = math.min(elapsed / settings.animation_duration, 1)

    if old_char ~= new_char and progress < 1 then
        local dy_old = interpolate(0, settings.font_size, progress)
        local dy_new = interpolate(-settings.font_size, 0, progress)
        draw_styled_char(cr, old_char, x, y + dy_old)
        draw_styled_char(cr, new_char, x, y + dy_new)
    else
        draw_styled_char(cr, new_char, x, y)
    end
end

function conky_draw_digital_clock()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height)
    local cr = cairo_create(cs)

    cairo_select_font_face(cr, settings.font_name, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, settings.font_size)

    local time_string = os.date("%H:%M")

    if last_time == "" then
        for i = 1, #time_string do
            local ch = time_string:sub(i, i)
            table.insert(digits, {
                char = ch,
                last_char = ch,
                start_time = os.clock()
            })
        end
    end

    local total_width = 0
    local extents = {}
    for i = 1, #time_string do
        local ch = time_string:sub(i, i)
        local ext = cairo_text_extents_t:create()
        cairo_text_extents(cr, ch, ext)
        extents[i] = ext
        total_width = total_width + ext.x_advance
    end

    local win_w, win_h = conky_window.width, conky_window.height
    local x_ref = settings.center_horizontally and (win_w - total_width) / 2 or 0
    local y_ref = settings.center_vertically and win_h / 2 or settings.font_size

    local x = x_ref
    for i = 1, #time_string do
        local ch = time_string:sub(i, i)
        local d = digits[i]
        local ext = extents[i]

        if d.char ~= ch then
            d.last_char = d.char
            d.char = ch
            d.start_time = os.clock()
        end

        local clip_margin = 5
        local clip_height = settings.font_size + 2 * clip_margin
        local clip_y = y_ref - settings.font_size + clip_margin

        cairo_rectangle(cr, 0, clip_y, win_w, clip_height)
        cairo_clip(cr)

        draw_digit(cr, d.last_char, d.char, x, y_ref, os.clock() - d.start_time)
        x = x + ext.x_advance
    end

    last_time = time_string
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

_G.conky_draw_digital_clock = conky_draw_digital_clock
