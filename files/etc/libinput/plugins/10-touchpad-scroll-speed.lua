-- Slow down two-finger touchpad scrolling.
-- While exactly two fingers are down, finger movement is scaled by FACTOR.
-- One-finger pointer motion and 3/4-finger gestures are not changed.

local FACTOR = 0.3 -- 1.0 = stock speed, lower = slower scroll

libinput:register({1})

libinput:connect("new-evdev-device", function(device)
    local props = device:udev_properties()
    if props["ID_INPUT_TOUCHPAD"] ~= "1" then
        return
    end

    local absinfos = device:absinfos()
    local range = {
        [evdev.ABS_MT_POSITION_X] = absinfos[evdev.ABS_MT_POSITION_X],
        [evdev.ABS_MT_POSITION_Y] = absinfos[evdev.ABS_MT_POSITION_Y],
    }

    local slot = 0
    local active = {}  -- slot -> true while a finger is down
    local fresh = {}   -- slot -> true if the touch started in this frame
    local raw = {}     -- slot -> { [usage] = last real value }
    local virt = {}    -- slot -> { [usage] = value we report }

    local function count()
        local n = 0
        for _ in pairs(active) do n = n + 1 end
        return n
    end

    device:connect("evdev-frame", function(_, frame, _)
        fresh = {}
        local changed = false
        for _, e in ipairs(frame) do
            local u = e.usage
            if u == evdev.ABS_MT_SLOT then
                slot = e.value
            elseif u == evdev.ABS_MT_TRACKING_ID then
                if e.value >= 0 then
                    active[slot] = true
                    fresh[slot] = true
                    raw[slot] = {}
                    virt[slot] = {}
                else
                    active[slot] = nil
                    raw[slot] = nil
                    virt[slot] = nil
                end
            elseif (u == evdev.ABS_MT_POSITION_X or u == evdev.ABS_MT_POSITION_Y) and raw[slot] ~= nil then
                local r, v = raw[slot], virt[slot]
                if fresh[slot] or r[u] == nil then
                    r[u] = e.value
                    v[u] = e.value
                else
                    local scale = (count() == 2) and FACTOR or 1.0
                    v[u] = v[u] + (e.value - r[u]) * scale
                    r[u] = e.value
                    local info = range[u] or {}
                    if info.minimum and v[u] < info.minimum then v[u] = info.minimum end
                    if info.maximum and v[u] > info.maximum then v[u] = info.maximum end
                    local out = math.floor(v[u] + 0.5)
                    if out ~= e.value then
                        e.value = out
                        changed = true
                    end
                end
            end
        end
        if changed then
            return frame
        end
    end)
end)
