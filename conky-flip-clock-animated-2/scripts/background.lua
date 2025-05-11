-- background.lua
-- by @wim66
-- May 7, 2025

-- === Required Cairo Modules ===
require 'cairo'
local status, cairo_xlib = pcall(require, 'cairo_xlib')

if not status then
    cairo_xlib = setmetatable({}, {
        __index = function(_, key)
            return _G[key]
        end
    })
end

-- === Load settings.lua from parent directory ===
local script_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
local parent_path = script_path:match("^(.*[\\/])resources[\\/].*$") or ""
package.path = package.path .. ";" .. parent_path .. "?.lua"

local status, err = pcall(function() require("settings") end)
if not status then print("Error loading settings.lua: " .. err); return end
if not conky_vars then print("conky_vars function is not defined in settings.lua"); return end
conky_vars()

-- === Utility ===
local unpack = table.unpack or unpack

-- (Bestaande parse-functies ongewijzigd)
local function parse_border_color(border_color_str)
    local gradient = {}
    for position, color, alpha in border_color_str:gmatch("([%d%.]+),0x(%x+),([%d%.]+)") do
        table.insert(gradient, {tonumber(position), tonumber(color, 16), tonumber(alpha)})
    end
    if #gradient == 3 then
        return gradient
    end
    return { {0, 0x003E00, 1}, {0.5, 0x03F404, 1}, {1, 0x003E00, 1} }
end

local function parse_bg_color(bg_color_str)
    local hex, alpha = bg_color_str:match("0x(%x+),([%d%.]+)")
    if hex and alpha then
        return { {1, tonumber(hex, 16), tonumber(alpha)} }
    end
    return { {1, 0x000000, 0.5} }
end

local function parse_layer2_color(layer2_color_str)
    local gradient = {}
    for position, color, alpha in layer2_color_str:gmatch("([%d%.]+),0x(%x+),([%d%.]+)") do
        table.insert(gradient, {tonumber(position), tonumber(color, 16), tonumber(alpha)})
    end
    if #gradient == 3 then
        return gradient
    end
    return { {0, 0x55007f, 0.5}, {0.5, 0xff69ff, 0.5}, {1, 0x55007f, 0.5} }
end

local border_color = parse_border_color(border_COLOR or "0,0x003E00,1,0.5,0x03F404,1,1,0x003E00,1")
local bg_color = parse_bg_color(bg_COLOR or "0x000000,0.5")
local layer2_color = parse_layer2_color(layer_2 or "0,0x55007f,0.5,0.5,0xff69ff,0.5,1,0x55007f,0.5")

-- === All drawable elements ===
local boxes_settings = {

    -- shadow
    {
        type = "image",
        x = 27, y = -5, w = 220, h =180,
        centre_x = false,
        rotation = 0,
        draw_me = true,
        image_path = "clock/clockS.png"
    },
    -- clock image
    {
        type = "image",
        x = 0, y = 0, w = 220, h =180,
        centre_x = true,
        rotation = 0,
        draw_me = true,
        image_path = "clock/clock.png"
    },
    {
        type = "background",
        x = 0, y = 37, w = 192, h = 113,
        centre_x = true,
        corners = {10, 10, 10, 10},
        rotation = 0,
        draw_me = true,
        colour = {{0,0x000000,1}}
    },
    {
        type = "layer2",
        x = 0, y = 37, w = 192, h = 113,
        centre_x = true,
        corners = {10, 10, 10, 10},
        rotation = 0,
        draw_me = true,
        linear_gradient = {0, 0, 0, 172},
        colours = layer2_color,
    },
    {
        type = "layer2",
        x = 0, y = 37, w = 6, h = 113,
        centre_x = true,
        corners = {10, 10, 10, 10},
        rotation = 0,
        draw_me = true,
        linear_gradient = {0, 0, 0, 172},
        colours = { {0,0x000000,1}, {0.5,0xFFFFFF,1}, {1,0x000000,1}},
    },
    {
        type = "border",
        x = 0, y = 37, w = 192, h = 113,
        centre_x = true,
        corners = {10, 10, 10, 10},
        rotation = 0,
        draw_me = true,
        border = 4,
        linear_gradient = {0, 64, 254, 64},
        colour = { {0,0x333333,1}, {0.5,0xFFFFFF,1}, {1,0x333333,1}},
    }
}

-- === Helper: Convert hex to RGBA ===
local function hex_to_rgba(hex, alpha)
    return ((hex >> 16) & 0xFF) / 255, ((hex >> 8) & 0xFF) / 255, (hex & 0xFF) / 255, alpha
end

-- === Helper: Draw custom rounded rectangle ===
local function draw_custom_rounded_rectangle(cr, x, y, w, h, r)
    local tl, tr, br, bl = unpack(r)

    cairo_new_path(cr)
    cairo_move_to(cr, x + tl, y)
    cairo_line_to(cr, x + w - tr, y)
    if tr > 0 then cairo_arc(cr, x + w - tr, y + tr, tr, -math.pi/2, 0) else cairo_line_to(cr, x + w, y) end
    cairo_line_to(cr, x + w, y + h - br)
    if br > 0 then cairo_arc(cr, x + w - br, y + h - br, br, 0, math.pi/2) else cairo_line_to(cr, x + w, y + h) end
    cairo_line_to(cr, x + bl, y + h)
    if bl > 0 then cairo_arc(cr, x + bl, y + h - bl, bl, math.pi/2, math.pi) else cairo_line_to(cr, x, y + h) end
    cairo_line_to(cr, x, y + tl)
    if tl > 0 then cairo_arc(cr, x + tl, y + tl, tl, math.pi, 3*math.pi/2) else cairo_line_to(cr, x, y) end
    cairo_close_path(cr)
end

-- === Helper: Center X position ===
local function get_centered_x(canvas_width, box_width)
    return (canvas_width - box_width) / 2
end

-- === Helper: Draw an image ===
local function draw_image(cr, image_path, x, y, w, h, rotation, centre_x, canvas_width)
    local image_surface = cairo_image_surface_create_from_png(image_path)
    local status = cairo_surface_status(image_surface)
    if status ~= 0 then
--        print("Failed to load image: " .. image_path)
        return
    end

    local img_w = cairo_image_surface_get_width(image_surface)
    local img_h = cairo_image_surface_get_height(image_surface)
--    print("Image loaded: " .. image_path .. ", size: " .. img_w .. "x" .. img_h) -- Debug output

    -- Scale to exact w and h, ignoring aspect ratio
    local scale_x = w / img_w
    local scale_y = h / img_h

    -- Adjust position for centering
    if centre_x then
        x = get_centered_x(canvas_width, w)
  --      print("Centering image at x: " .. x) -- Debug output
    end

    -- Calculate center for rotation
    local cx, cy = x + w / 2, y + h / 2
    local angle = (rotation or 0) * math.pi / 180

    cairo_save(cr)
    cairo_translate(cr, cx, cy)
    cairo_rotate(cr, angle)
    cairo_scale(cr, scale_x, scale_y)
    cairo_translate(cr, -img_w / 2, -img_h / 2)
    cairo_set_source_surface(cr, image_surface, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)
    cairo_surface_destroy(image_surface)
end

-- === Main drawing function ===
function conky_draw_background()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    local canvas_width = conky_window.width

    cairo_save(cr)

    for _, box in ipairs(boxes_settings) do
        if box.draw_me then
            local x, y, w, h = box.x, box.y, box.w, box.h
            if box.centre_x then x = get_centered_x(canvas_width, w) end

            local cx, cy = x + w / 2, y + h / 2
            local angle = (box.rotation or 0) * math.pi / 180

            if box.type == "background" then
                cairo_save(cr)
                cairo_translate(cr, cx, cy)
                cairo_rotate(cr, angle)
                cairo_translate(cr, -cx, -cy)
                cairo_set_source_rgba(cr, hex_to_rgba(box.colour[1][2], box.colour[1][3]))
                draw_custom_rounded_rectangle(cr, x, y, w, h, box.corners)
                cairo_fill(cr)
                cairo_restore(cr)

            elseif box.type == "layer2" then
                local grad = cairo_pattern_create_linear(unpack(box.linear_gradient))
                for _, color in ipairs(box.colours) do
                    cairo_pattern_add_color_stop_rgba(grad, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, grad)
                cairo_save(cr)
                cairo_translate(cr, cx, cy)
                cairo_rotate(cr, angle)
                cairo_translate(cr, -cx, -cy)
                draw_custom_rounded_rectangle(cr, x, y, w, h, box.corners)
                cairo_fill(cr)
                cairo_restore(cr)
                cairo_pattern_destroy(grad)

            elseif box.type == "border" then
                local grad = cairo_pattern_create_linear(unpack(box.linear_gradient))
                for _, color in ipairs(box.colour) do
                    cairo_pattern_add_color_stop_rgba(grad, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, grad)
                cairo_save(cr)
                cairo_translate(cr, cx, cy)
                cairo_rotate(cr, angle)
                cairo_translate(cr, -cx, -cy)
                cairo_set_line_width(cr, box.border)
                draw_custom_rounded_rectangle(
                    cr,
                    x + box.border / 2,
                    y + box.border / 2,
                    w - box.border,
                    h - box.border,
                    {
                        math.max(0, box.corners[1] - box.border / 2),
                        math.max(0, box.corners[2] - box.border / 2),
                        math.max(0, box.corners[3] - box.border / 2),
                        math.max(0, box.corners[4] - box.border / 2)
                    }
                )
                cairo_stroke(cr)
                cairo_restore(cr)
                cairo_pattern_destroy(grad)

            elseif box.type == "image" then
                draw_image(cr, box.image_path, x, y, w, h, box.rotation, box.centre_x, canvas_width)
            end
        end
    end

    cairo_restore(cr)
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end