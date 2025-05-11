-- Animated Digital Clock for Conky (Simplified)
-- Version: 2.6, gradiëntfix, stijlen hersteld, glow vóór shadow

require 'cairo'


-- SETTINGS --
local settings = {
    font_name = "zekton",
    font_size = 64,
    animation_type = "flip", -- flip of none (wijzig naar "flip" voor animatie)
    animation_duration = 0.05,

    center_horizontally = true,
    center_vertically = false,
    text_align = "center",
    text_valign = "center",

    draw_shadow = true,
    shadow_color = 0x00ff00,
    shadow_alpha = 1,
    shadow_offset = {x = 2, y = 2},

    draw_stroke = true,
    stroke_color = 0x000000, -- Zwart
    stroke_alpha = 1,
    stroke_width = 1,

    draw_glow = false,
    glow_color = 0xffff00,
    glow_alpha = 0.1,
    glow_offset = {x = 4, y = 4},

    use_gradient = true,
    linear_gradient = {0, 0, 0, 75}, -- Voor fallback
    gradient_colours = {
        {0,    0xffffff, 0.2}, -- Wit
        {0.5,  0x000000, 0.2}, -- Zwart (midden)
        {1,    0x000000, 0.6}  -- Zwart (onder)
    }
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

local function create_gradient_pattern(x, y, width, height)
--    print("Gradient: x=" .. x .. ", y=" .. y .. ", width=" .. width .. ", height=" .. height)
    local x0, y0, x1, y1 = 0, -height, 0, 0 -- Gradiënt van boven naar beneden
    local pat = cairo_pattern_create_linear(x0, y0, x1, y1)
    for _, stop in ipairs(settings.gradient_colours) do
        local offset, color, alpha = table.unpack(stop)
        local r, g, b = hex_to_rgb(color)
--        print("Color stop: offset=" .. offset .. ", r=" .. r .. ", g=" .. g .. ", b=" .. b .. ", a=" .. alpha)
        cairo_pattern_add_color_stop_rgba(pat, offset, r, g, b, alpha)
    end
    return pat
end

local function draw_styled_char(cr, char, x, y, angle)
    cairo_save(cr)
    cairo_translate(cr, x, y)

    if angle then
        cairo_translate(cr, 0, -settings.font_size / 2)
        local scale_y = -math.cos(angle)
        cairo_scale(cr, 1, scale_y)
        cairo_translate(cr, 0, settings.font_size / 2)
    end

    cairo_select_font_face(cr, settings.font_name, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    cairo_set_font_size(cr, settings.font_size)

    -- Bepaal tekstafmetingen
    local ext = cairo_text_extents_t:create()
    cairo_text_extents(cr, char, ext)
--    print("Text extents: width=" .. ext.width .. ", height=" .. ext.height .. ", x_advance=" .. ext.x_advance)

    -- Glow (eerst getekend)
    if settings.draw_glow then
        local r, g, b = hex_to_rgb(settings.glow_color)
        local a = settings.glow_alpha or 0.4
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    cairo_move_to(cr, dx + settings.glow_offset.x, dy + settings.glow_offset.y)
                    cairo_text_path(cr, char)
                    cairo_set_source_rgba(cr, r, g, b, a)
                    cairo_fill_preserve(cr)
                    cairo_new_path(cr)
                end
            end
        end
    end

    -- Shadow (getekend na glow)
    if settings.draw_shadow then
        local r, g, b = hex_to_rgb(settings.shadow_color)
        local a = settings.shadow_alpha or 1
        cairo_move_to(cr, settings.shadow_offset.x, settings.shadow_offset.y)
        cairo_text_path(cr, char)
        cairo_set_source_rgba(cr, r, g, b, a)
        cairo_fill_preserve(cr)
        cairo_new_path(cr)
    end

    -- Stroke
    if settings.draw_stroke then
        cairo_move_to(cr, 0, 0)
        cairo_text_path(cr, char)
        local r, g, b = hex_to_rgb(settings.stroke_color)
        local a = settings.stroke_alpha or 1
--        print("Stroke color: r=" .. r .. ", g=" .. g .. ", b=" .. b)
        cairo_set_source_rgba(cr, r, g, b, a)
        cairo_set_line_width(cr, settings.stroke_width or 1)
        cairo_stroke_preserve(cr)
    else
        cairo_move_to(cr, 0, 0)
        cairo_text_path(cr, char)
    end

    -- Gradient vullen
    if settings.use_gradient then
        local pattern = create_gradient_pattern(x, y, ext.x_advance, ext.height)
        cairo_set_source(cr, pattern)
    else
        local r, g, b = hex_to_rgb(settings.text_color or 0xFFFFFF)
        local a = settings.text_alpha or 1
        cairo_set_source_rgba(cr, r, g, b, a)
    end

    cairo_fill(cr)
    cairo_restore(cr)
end

local function interpolate(a, b, t)
    return a + (b - a) * t
end

local function draw_digit(cr, old_char, new_char, x, y, elapsed)
    local progress = math.min(elapsed / settings.animation_duration, 1)
    local anim = settings.animation_type

    if anim == "flip" and old_char ~= new_char and progress < 1 then
        local angle = interpolate(0, math.pi, progress)
        local char_to_draw = progress < 0.5 and old_char or new_char
        draw_styled_char(cr, char_to_draw, x, y, angle)
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

        local clip_margin = 50
        local clip_height = settings.font_size + 2 * clip_margin
        local clip_y = y_ref - settings.font_size - clip_margin
        cairo_rectangle(cr, 0, clip_y, win_w, clip_height)
        cairo_clip(cr)

        draw_digit(cr, d.last_char, d.char, x, y_ref, os.clock() - d.start_time)
        x = x + ext.x_advance
        cairo_reset_clip(cr)
    end

    last_time = time_string
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- Register global function for Conky
_G.conky_draw_digital_clock = conky_draw_digital_clock