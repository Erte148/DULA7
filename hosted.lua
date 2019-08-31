-- Part of info-beamer hosted
--
-- Copyright (c) 2014, Florian Wesch <fw@dividuum.de>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--
--     Redistributions of source code must retain the above copyright
--     notice, this list of conditions and the following disclaimer. 
--
--     Redistributions in binary form must reproduce the above copyright
--     notice, this list of conditions and the following disclaimer in the
--     documentation and/or other materials provided with the
--     distribution.  
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
-- IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
-- CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
-- PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
-- LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

local resource_types = {
    ["image"] = function(value)
        return function()
            local surface
            local file
            local image = {
                asset_name = value.asset_name,
                filename = value.filename,
                type = value.type,
            }
            function image.grab()
                if file then
                    return true
                end
                local ok, openfile = pcall(resource.open_file, value.asset_name)
                if not ok then
                    return false
                else
                    file = openfile
                    return true
                end
            end
            function image.load()
                if not surface then
                    surface = resource.load_image(file)
                end
            end
            function image.state()
                local state = surface:state()
                if state == "loading" then
                    return "loading"
                elseif state == "loaded" then
                    return "ready"
                elseif state == "error" then
                    return "error"
                end
            end
            function image.start()
            end
            function image.get_surface()
                return surface, function() end
            end
            function image.unload()
                if file then
                    file:dispose()
                    file = nil
                end
                if surface then
                    surface:dispose()
                    surface = nil
                end
            end
            return image
        end
    end;
    ["video"] = function(value)
        return function()
            local surface
            local file
            local video = {
                asset_name = value.asset_name,
                filename = value.filename,
                type = value.type,
            }
            function video.grab()
                if file then
                    return true
                end
                local ok, openfile = pcall(resource.open_file, value.asset_name)
                if not ok then
                    return false
                else
                    file = openfile
                    return true
                end
            end
            function video.load(opt)
                if not surface then
                    surface = resource.load_video{
                        file = file,
                        paused = true,
                    }
                end
            end
            function video.state()
                local state = surface:state()
                if state == "loading" then
                    return "loading"
                elseif state == "paused" then
                    return "ready"
                elseif state == "error" then
                    return "error"
                end
            end
            function video.start()
                surface:start()
            end
            function video.get_surface()
                return surface, function() end
            end
            function video.unload()
                if file then
                    file:dispose()
                    file = nil
                end
                if surface then
                    surface:dispose()
                    surface = nil
                end
            end
            return video
        end
    end;
    ["child"] = function(value)
        return function()
            local child = {
                asset_name = value.asset_name,
                filename = value.filename,
                type = value.type,
            }
            function child.grab()
                return true
            end
            function child.load()
            end
            function child.state()
                return "ready"
            end
            function child.start()
            end
            function child.get_surface()
                local surface = resource.render_child(value.asset_name)
                return surface, function()
                    surface:dispose()
                end
            end
            function child.unload()
            end
            return child
        end
    end;
}

local types = {
    ["string"] = function(value)
        return value
    end;
    ["integer"] = function(value)
        return value
    end;
    ["select"] = function(value)
        return value
    end;
    ["boolean"] = function(value)
        return value
    end;
    ["duration"] = function(value)
        return value
    end;
    ["color"] = function(value)
        local color = {}
        color.r = value.r
        color.g = value.g
        color.b = value.b
        color.a = value.a
        color.rgba_table = {color.r, color.g, color.b, color.a}
        color.rgba = function()
            return color.r, color.g, color.b, color.a
        end
        color.clear = function()
            gl.clear(color.r, color.g, color.b, color.a)
        end
        return color
    end;
    ["resource"] = function(value)
        return resource_types[value.type](value)
    end;
    ["font"] = function(value)
        return resource.load_font(value.asset_name)
    end;
}

local function parse_config(options, config)
    local function parse_recursive(options, config, target)
        for _, option in ipairs(options) do
            local name = option.name
            if name then
                if option.type == "list" then
                    local list = {}
                    for _, child_config in ipairs(config[name]) do
                        local child = {}
                        parse_recursive(option.items, child_config, child)
                        list[#list + 1] = child
                    end
                    target[name] = list
                else
                    target[name] = types[option.type](config[name])
                end
            end
        end
    end
    local current_config = {}
    parse_recursive(options, config, current_config)
    return current_config
end

return {
    parse_config = parse_config;
}
