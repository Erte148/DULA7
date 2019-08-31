gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)


local font2 = resource.load_font "font2.ttf"
local count = 0
local num=0
--util.noglobals()

util.data_mapper{
    counter = function(counter)
        count = tonumber(counter)
    end,
}

--local video2 =util.videoplayer("Gold.mp4")


local video2 = resource.load_video{
    file = "Gold.mp4";
    looped = true;
    paused = true;
	
	
    }


local video3 = resource.load_video{
    file = "Blue.mp4";
    looped = true;
	paused = true;
    }


-- We need to access files in playlist/
node.make_nested()

-- Start preloading images this many second before
-- they are displayed.
local PREPARE_TIME = 1 -- seconds



-- must be enough time to load a video and have it
-- ready in the paused state. Normally 500ms should
-- be enough.
local VIDEO_PRELOAD_TIME = .5 -- seconds


local json = require "json"
local font = resource.load_font "silkscreen.ttf"
local serial = sys.get_env "SERIAL"
local min = math.min
local assigned = false

local function msg(str, ...)
    font:write(10, HEIGHT-30, str:format(...), 24, 1,1,1,.5)
  end

local function Screen()
    local screen_x, screen_y, screen_rot
    local content_w, content_h

    local function update(screen, unscaled_w, unscaled_h)
        local diagonal_pixels = math.sqrt(math.pow(screen.width, 2) + math.pow(screen.height, 2))
        local cm_per_pixel = (screen.inches * 2.54) / diagonal_pixels

        gl.setup(screen.width, screen.height)
        screen_x = screen.x / cm_per_pixel
        screen_y = screen.y / cm_per_pixel
        screen_rot = screen.rotation
        print(('initialized %d" screen (%dx%d)'):format(screen.inches, screen.width, screen.height))

        content_w = unscaled_w / cm_per_pixel
        content_h = unscaled_h / cm_per_pixel
    end

    local function draw(obj)
        gl.rotate(-screen_rot, 0, 0, 1)
        gl.translate(-screen_x, -screen_y)
        util.draw_correct(obj, 0, 0, content_w, content_h)
    end

    local function drawq(obj)
        --gl.rotate(-screen_rot, 0, 0, 1)
        --gl.translate(-screen_x, -screen_y)
        util.draw_correct(obj, 0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
    end
	 local function drawqw(obj)
        --gl.rotate(-screen_rot, 0, 0, 1)
        --gl.translate(-screen_x, -screen_y)
        util.draw_correct(obj, 0, 0, NATIVE_WIDTH, NATIVE_HEIGHT)
    end
    
    return {
        update = update;
        draw = draw;
        drawq= drawq;
	drawqw= drawqw;
    }
end

local screen = Screen()

local Image = {
    slot_time = function(self)
        return self.duration
    end;
    prepare = function(self)
        self.obj = resource.load_image(self.file:copy())
    end;
    tick = function(self, now)
        local state, w, h = self.obj:state()
        screen.draw(self.obj)
    end;
    tickq = function(self, now)
        local state, w, h = self.obj:state()
        screen.drawq(self.obj)
    end;
	tickqw = function(self, now)
        local state, w, h = self.obj:state()
        screen.drawqw(self.obj)
    end;
	
    stop = function(self)
        if self.obj then
            self.obj:dispose()
            self.obj = nil
        end
    end;
}

local Video = {
    slot_time = function(self)
        return VIDEO_PRELOAD_TIME + self.duration
    end;
    prepare = function(self)
    end;
    tick = function(self, now)
        if not self.obj then
            self.obj = resource.load_video{
                file = self.file:copy();
                paused = true;
            }
        end

        if now < self.t_start + VIDEO_PRELOAD_TIME then
            return
        end

        self.obj:start()
        local state, w, h = self.obj:state()

        if state ~= "loaded" and state ~= "finished" then
            print[[

.--------------------------------------------.
  WARNING:
  lost video frame. video is most likely out
  of sync. increase VIDEO_PRELOAD_TIME (on all
  devices)
'--------------------------------------------'
]]
        else
            screen.draw(self.obj)
        end
    end;
    
    tickq = function(self, now)
        if not self.obj then
            self.obj = resource.load_video{
                file = self.file:copy();
                paused = true;
		looped = true;		
            }
        end       

        self.obj:start()
        local state, w, h = self.obj:state()
	screen.drawq(self.obj)	 
        
    
     end;
	
    tickqw = function(self, now)
        if not self.obj then
            self.obj = resource.load_video{
                file = self.file:copy();
                paused = true;
		looped = true;		
            }
        end       

        self.obj:start()
        local state, w, h = self.obj:state()
	screen.drawqw(self.obj)	 
        
    
     end;
    
    stop = function(self)
        if self.obj then
            self.obj:dispose()
            self.obj = nil
        end
    end;
}

local function Playlist()
    local items = {}
    local total_duration = 0

    local function calc_start(idx, now)
        local item = items[idx]
        local epoch_offset = now % total_duration
        local epoch_start = now - epoch_offset

        item.t_start = epoch_start + item.epoch_offset
        if item.t_start - PREPARE_TIME < now then
            item.t_start = item.t_start + total_duration
        end
        item.t_prepare = item.t_start - PREPARE_TIME
        item.t_end = item.t_start + item:slot_time()
        -- pp(item)
    end

    local function tick(now)
        local num_running = 0
        local next_running = 99999999999999

        if not assigned then
            msg("[%s] screen not configured for this setup", serial)
            return
        end
        
        if #items == 0 then
            msg("[%s] no playlist configured", serial)
            return
        end

        for idx = 1, #items do
            local item = items[idx]
            if item.t_prepare <= now and item.state == "waiting" then
                print(now, "preparing ", item.file)
                item:prepare()
                item.state = "prepared"
            elseif item.t_start <= now and item.state == "prepared" then
                print(now, "running ", item.file)
                item.state = "running"
            elseif item.t_end <= now and item.state == "running" then
                print(now, "resetting ", item.file)
                item:stop()
                calc_start(idx, now)
                item.state = "waiting"
            end

            next_running = min(next_running, item.t_start)

            if item.state == "running" then
                item:tick(now)
                num_running = num_running + 1
            end
        end

        if num_running == 0 then
            local wait = next_running - now
            msg("[%s] waiting for sync %.1f", serial, wait)
        end
    end
    
    
     local function tickq(now)
        local num_running = 0
        local next_running = 99999999999999

        

       	for idx = 1, #items do
            local item = items[idx]
           
                item.state = "running"
          

            

            if item.state == "running" then
                item:tickq(now)
                num_running = num_running + 1
            end
	end
			
        

        if num_running == 0 then
            local wait = next_running - now
            msg("[%s] waiting for sync %.1f", serial, wait)
        end
    end
    
    local function tickqw(now)
        local num_running = 0
        local next_running = 99999999999999

        

       	for idx = 1, #items do
            local item = items[idx]
           
                item.state = "running"
          

            

            if item.state == "running" then
                item:tickqw(now)
                num_running = num_running + 1
            end
	end
			
        

        if num_running == 0 then
            local wait = next_running - now
            msg("[%s] waiting for sync %.1f", serial, wait)
        end
    end

    local function stop_all()
        for idx = 1, #items do
            local item = items[idx]
            item:stop()
        end
    end

    local function set(new_items)
        local now = os.time()

        total_duration = 0
        for idx = 1, #new_items do
            local item = new_items[idx]
            if item.type == "image" then
                setmetatable(item, {__index = Image})
            elseif item.type == "video" then
                setmetatable(item, {__index = Video})
            else
                return error("unsupported type" .. item.type)
            end
            item.epoch_offset = total_duration
            item.state = "waiting"
            total_duration = total_duration + item:slot_time()
        end

        stop_all()

        items = new_items
        for idx = 1, #new_items do
            calc_start(idx, now)
        end
    end

    return {
        set = set;
        tick = tick;
        tickq = tickq;	
	 tickqw = tickqw;	
    }
end

local playlist = Playlist()
local playlist2 = Playlist()
local playlist3 = Playlist()

local function prepare_playlist(playlist)
    if #playlist >= 2 then
        return playlist
    elseif #playlist == 1 then
        -- only a single item? Copy it
        local item = playlist[1]
        playlist[#playlist+1] = {
            file = item.file,
            type = item.type,
            duration = item.duration,
        }
    end
    return playlist
end

util.file_watch("config.json", function(raw)
    local config = json.decode(raw)

    for idx = 1, #config.screens do
        local screen_config = config.screens[idx]
        if screen_config.serial == serial then
            screen.update(screen_config, config.width, config.height)
            assigned = true
            return
        end
    end

    assigned = false
end)

util.file_watch("playlist/config.json", function(raw)
    local config = json.decode(raw)
    local items = {}
    for idx = 1, #config.playlist do
        local item = config.playlist[idx]
        items[#items+1] = {
            file = resource.open_file('playlist/' .. item.file.asset_name),
            type = item.file.type,
            duration = item.duration,
        }
    end
    playlist.set(prepare_playlist(items))
    node.gc()
end)

util.file_watch("playlist/config.json", function(raw)
    local config = json.decode(raw)
    local items = {}
    for idx = 1, #config.playlist2 do
            --idx = idp
        local item = config.playlist2[idx]
        items[#items+1] = {
            file = resource.open_file('playlist/' .. item.file.asset_name),
            type = item.file.type,
            duration = item.duration,
        }
       
    end
    playlist2.set(prepare_playlist(items))
    node.gc()
end)


util.file_watch("playlist/config.json", function(raw)
    local config = json.decode(raw)
    local items = {}
    for idx = 1, #config.playlist3 do
            --idx = idp
        local item = config.playlist3[idx]
        items[#items+1] = {
            file = resource.open_file('playlist/' .. item.file.asset_name),
            type = item.file.type,
            duration = item.duration,
        }
       
    end
    playlist3.set(prepare_playlist(items))
    node.gc()
end)



function node.render()
 if count==0 then  
gl.clear(0,0,0,1)
		
		
--playlist:start()			
video2:stop()
video3:stop()		
playlist.tick(os.time())
  end 
	
if count==18 then
--playlist:stop()
gl.clear(0,0,0,1)
--gl.rotate (180, 960, 500, 0)	
--gl.rotate (-180, 0, 0, 1)
--gl.translate(-screen_x, -screen_y)		
video3:stop()	
video2:start()
video2:draw(0, 0, WIDTH, HEIGHT)
 
  end
if count==27 then
		
--gl.clear(0,0,0,1)		
--playlist2.tickq(os.time())
  end		
  if count==23 then
gl.clear(0,0,0,1)		
--playlist:stop()		
video2:stop()
video3:start()		
video3:draw(0, 0, WIDTH, HEIGHT)
		
--playlist2.tickq(os.time())
--gl.clear(0,0,0,1)		
    --font2:write(30, 10, "GPIO Detected", 100, .5,.5,.5,1)
   --countStr = tostring(count)
   --font2:write(250, 300, countStr, 64, 1,1,1,1)		
  end
if count==25 then
--gl.clear(0,0,0,1)		
--playlist2.tickq(os.time())
  end		
  
    
  --if count ==23 then   
   -- gl.clear(0,0,0,1)		
   -- font2:write(30, 10, "GPIO Detected", 100, .5,.5,.5,1)
   -- countStr = tostring(num)
   -- font2:write(250, 300, countStr, 64, 1,1,1,1)
 --  end 
    
end


--function node.render()
  --  gl.clear(0,0,0,1)
  --  playlist.tick(os.time())
    -- screen.draw(test)
--end
