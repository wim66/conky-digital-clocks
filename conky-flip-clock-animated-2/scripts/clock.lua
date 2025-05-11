-- clock.lua – Image-based Clock with Flip Animation (Hours, Minutes)
-- by u/Logansfury (reddit) & @wim66
-- v1 May 10, 2025

require 'cairo'
local status, cairo_xlib = pcall(require, 'cairo_xlib')
if not status then
    cairo_xlib = setmetatable({}, { __index = _G })
end

-- Global animation state
local previous_minute = -1
local animation_frame = 0
local animation_duration = 35
local is_animating = true
local previous_digits = {0, 0, 0, 0}
local current_digits = {0, 0, 0, 0}

-- Load digit surfaces once
local digits = {}
for i = 0, 9 do
    digits[i] = cairo_image_surface_create_from_png("clock/" .. i .. ".png")
end
local image_bg = cairo_image_surface_create_from_png("clock/BG.png")

-- Helper to draw a digit
local function draw_digit(cr, digit, x, y, y_offset, alpha)
    local img = digits[digit]
    local w = cairo_image_surface_get_width(img)
    local h = cairo_image_surface_get_height(img)

    cairo_save(cr)
    cairo_translate(cr, x, y + y_offset)
    cairo_scale(cr, 27 / w, 62 / h)
    cairo_set_source_surface(cr, img, 0, 0)
    cairo_paint_with_alpha(cr, alpha)
    cairo_restore(cr)
end

function conky_clock()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual,
                                         conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Apply 10px mask at top and bottom
    local mask_top = 41
    local mask_bottom = 38
    local clip_y = mask_top
    local clip_height = conky_window.height - mask_top - mask_bottom
    cairo_rectangle(cr, 0, clip_y, conky_window.width, clip_height)
    cairo_clip(cr)

    -- Get current time digits
    local hours = os.date("%H")
    local minutes = os.date("%M")
    local now_minute = tonumber(minutes)

    -- Extract hour + minute digits
    local new_digits = {
        tonumber(hours:sub(1, 1)),
        tonumber(hours:sub(2, 2)),
        tonumber(minutes:sub(1, 1)),
        tonumber(minutes:sub(2, 2))
    }

    -- Animate minutes if changed
    if now_minute ~= previous_minute then
        previous_minute = now_minute
        previous_digits = current_digits
        current_digits = new_digits
        animation_frame = 0
        is_animating = true
    end

    -- Draw background (matched to original clock.lua)
    local w = cairo_image_surface_get_width(image_bg)
    local h = cairo_image_surface_get_height(image_bg)
    cairo_save(cr)
    cairo_translate(cr, 0, 0)
    cairo_scale(cr, 252 / w, 175 / h) -- Changed to match original scaling
    cairo_set_source_surface(cr, image_bg, 4, 11)
    cairo_paint(cr)
    cairo_restore(cr)

    -- Digit positions and layout
    local x_positions = {51, 91, 146, 186} -- HH MM
    local y_base = 60

    -- Animate hours + minutes
    if is_animating then
        animation_frame = animation_frame + 1
        local linear = math.min(animation_frame / animation_duration, 1)
        local progress = linear * linear * (3 - 2 * linear)

        if linear >= 1 then is_animating = false end

        for i = 1, 4 do
            if previous_digits[i] ~= current_digits[i] then
                draw_digit(cr, previous_digits[i], x_positions[i], y_base, progress * 60, 1 - progress)
                draw_digit(cr, current_digits[i], x_positions[i], y_base, -60 * (1 - progress), progress)
            else
                draw_digit(cr, current_digits[i], x_positions[i], y_base, 0, 1)
            end
        end
    else
        for i = 1, 4 do
            draw_digit(cr, current_digits[i], x_positions[i], y_base, 0, 1)
        end
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end