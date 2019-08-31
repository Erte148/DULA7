module("iblib", package.seeall)

function playlist(opt)
    local get_next_item = opt.get_next_item
    local get_switch_time = opt.get_switch_time

    local player_fade = opt.fade
    local player_draw = opt.draw

    local blank = resource.create_colored_texture(0, 0, 0, 0)
    local dummy_item = {
        obj = {
            grab = function()
                return true
            end;
            load = function()
            end;
            state = function()
                return "ready"
            end;
            start = function()
            end;
            get_surface = function()
                return blank, function() end
            end;
            unload = function()
            end;
        },
        duration = 1,
        title = "",
    }

    local current_item = dummy_item
    local next_item


    -- state vars
    local fade_start = sys.now()
    local progress

    local state = "preload_start"

    local function draw(...)
        local now = sys.now()

        if state == "preload_start" then
            next_item = get_next_item()
            if not next_item then
                print "no item. using dummy"
                next_item = dummy_item
            end

            if next_item.obj.grab() then
                next_item.obj.load()
                state = "preload_wait"
            else
                print "oops. cannot grab next item"
            end
        end

        if state == "preload_wait" then
            local load_state = next_item.obj.state()
            if load_state == "ready" then
                state = "preload_idle"
            elseif load_state == "error" then
                -- try next item
                state = "preload_start"
            end
        end

        if state == "preload_idle" then
            if now > fade_start then
                fade_start = now 
                next_item.obj.start()
                state = "crossfade"
            end
        end
        
        if state == "crossfade" then
            local fade_time = now - fade_start
            progress = fade_time / get_switch_time()
            if progress > 1 then
                progress = 1
                state = "switch"
            end
        end

        if state == "switch" then
            current_item.obj.unload()
            current_item = next_item
            fade_start = sys.now() + current_item.duration
            next_item = nil
            state = "preload_start"
        end

        if state == "crossfade" then
            local n, n_dispose = next_item.obj.get_surface()
            local c, c_dispose = current_item.obj.get_surface()
            player_fade(c, n, progress, ...)
            n_dispose()
            c_dispose()
        else
            local c, c_dispose = current_item.obj.get_surface()
            player_draw(c, ...)
            c_dispose()
        end
    end

    return {
        draw = draw;
        get_current_item = function()
            return current_item
        end;
    }
end

