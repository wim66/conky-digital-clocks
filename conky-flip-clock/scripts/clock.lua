-- clock.lua
-- by @wim66
-- v1 May 7, 2025

require 'cairo'

-- Attempt to safely require 'cairo_xlib'
local status, cairo_xlib = pcall(require, 'cairo_xlib')
if not status then
    cairo_xlib = setmetatable({}, { __index = _G })
end

function clock(cr, x, y)
    -- Retrieve data from the OS
    local hours = os.date("%H")
    local mins = os.date("%M")

    -- Load images
    local image_bg = cairo_image_surface_create_from_png("clock/BG.png")
    local digits = {}
    for i = 0, 9 do
        digits[i] = cairo_image_surface_create_from_png(string.format("clock/%d.png", i))
    end

    -- Retrieve width and height of background
    local w = cairo_image_surface_get_width(image_bg)
    local h = cairo_image_surface_get_height(image_bg)

    -- Translate and scale background (252px width)
    cairo_translate(cr, x, y)
    cairo_scale(cr, 252/w, 175/h)

    -- Display background
    cairo_set_source_surface(cr, image_bg, 0, 0)
    cairo_paint(cr)
    cairo_surface_destroy(image_bg)

    -- Display hour tens
    local hour_tens = tonumber(hours) >= 20 and 2 or (tonumber(hours) >= 10 and 1 or 0)
    local image_a = digits[hour_tens]

    w = cairo_image_surface_get_width(image_a)
    h = cairo_image_surface_get_height(image_a)

    cairo_translate(cr, 30, 32)
    cairo_scale(cr, 27/w, 62/h)

    cairo_set_source_surface(cr, image_a, 0, 0)
    cairo_paint(cr)

    -- Display hour units
    local hour_units = tonumber(hours) % 10
    local image_b = digits[hour_units]

    w = cairo_image_surface_get_width(image_b)
    h = cairo_image_surface_get_height(image_b)

    cairo_translate(cr, 25, 0)
    cairo_scale(cr, 27/w, 62/h)

    cairo_set_source_surface(cr, image_b, 0, 0)
    cairo_paint(cr)

    -- Display minute tens
    local min_tens = tonumber(mins) >= 50 and 5 or
                     tonumber(mins) >= 40 and 4 or
                     tonumber(mins) >= 30 and 3 or
                     tonumber(mins) >= 20 and 2 or
                     tonumber(mins) >= 10 and 1 or 0
    local image_c = digits[min_tens]

    w = cairo_image_surface_get_width(image_c)
    h = cairo_image_surface_get_height(image_c)

    cairo_translate(cr, 55, 0)
    cairo_scale(cr, 27/w, 62/h)

    cairo_set_source_surface(cr, image_c, 0, 0)
    cairo_paint(cr)

    -- Display minute units
    local min_units = tonumber(mins) % 10
    local image_d = digits[min_units]

    w = cairo_image_surface_get_width(image_d)
    h = cairo_image_surface_get_height(image_d)

    cairo_translate(cr, 30, 0)
    cairo_scale(cr, 27/w, 62/h)

    cairo_set_source_surface(cr, image_d, 0, 0)
    cairo_paint(cr)

    -- Clean up digit images
    for i = 0, 9 do
        cairo_surface_destroy(digits[i])
    end
end

function conky_clock()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    clock(cr, -21, -20)
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end