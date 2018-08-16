-- title:  Shredder Boy
-- author: ShaggyFox
-- desc:   Try to get not out of space by using the shredder
-- script: lua

local player_speed_slow = 1 / 16
local player_speed_fast = 1 / 12
local player_map_position = {10,5}
local player_move = 0
local player_tile = 16
local player_carries_object = nil
local cnt = 0
local tick = 0
local player_move_last_tick = 0
local player_animation = 0
local last_button = -1
local shredder_position_x = 0
local shredder_position_y = 0
local shredder_is_running = 0
local document_space_x = 0
local document_space_y = 5
local document_space_w = 3
local game_running = false
local object_map = {}
local garbage_space_x = 28
local garbage_space_y =  5
local garbage_space_w = 2
local computer_position_x = 0
local computer_position_y = 0
local player_score = 0
local collision_treshold = 6

local document_delay = 60
local document_amount = 4
local document_next_tick = 0

local garbage_delay = 120

local game_over_tick = 0


local function get_player_map_index()
  return player_map_position[1] + player_map_position[2] * 60
end

local function draw_player()
  local map_x, map_y = table.unpack(player_map_position)
  local x = map_x * 8
  local y = map_y * 8

  if player_carries_object then
    if player_tile == 17 then
      spr(player_carries_object[1], x, y - 4, 0)
    end
  end

  spr(256 + player_tile + player_animation, x, y - 8, 15)
  spr(256 + player_tile + 16 + player_animation, x, y, 15)

  if player_carries_object then
    if player_tile == 16 then
      spr(player_carries_object[1], x, y - 4, 0)
      spr(256 + player_tile + 96, x, y - 4, 0)
    elseif player_tile == 17 then
      spr(256 + player_tile + 96, x, y - 4, 0)
    elseif player_tile == 18 then
      spr(player_carries_object[1], x - 4, y - 4, 0)
      spr(256 + player_tile + 96, x - 3, y -4, 0)
    elseif player_tile == 19 then
      spr(player_carries_object[1], x + 4, y - 4, 0)
      spr(256 + player_tile + 96, x + 3, y -4, 0)
    end
  end
end

local function object_map_get(map_x, map_y)
  return object_map[map_y * 60 + map_x]
end


local function collide_with_object(player_x, player_y, object_x, object_y)
  local player_screen_x = player_x * 8
  local player_screen_y = player_y * 8
  local object_screen_x = object_x * 8
  local object_screen_y = object_y * 8

  return math.abs((player_screen_x + 4)  - (object_screen_x + 4)) < collision_treshold and
  math.abs((player_screen_y + 4)  - (object_screen_y + 4)) < collision_treshold

end

local function player_can_move(map_x, map_y, direction)
  local floor_x = math.floor(map_x)
  local floor_y = math.floor(map_y)
  local ceil_x = math.ceil(map_x)
  local ceil_y = math.ceil(map_y)
  if (mget(floor_x, floor_y) < 192 or object_map_get(floor_x, floor_y)) and
                                      collide_with_object(map_x, map_y, floor_x, floor_y) then
    return false
  elseif (mget(floor_x, ceil_y) < 192 or object_map_get(floor_x, ceil_y)) and
                                         collide_with_object(map_x, map_y, floor_x, ceil_y) then
    return false
  elseif (mget(ceil_x, floor_y) < 192 or object_map_get(ceil_x, floor_y)) and
                                         collide_with_object(map_x, map_y, ceil_x, floor_y)then
    return false
  elseif (mget(ceil_x, ceil_y) < 192 or object_map_get(ceil_x, ceil_y)) and
                                        collide_with_object(map_x, map_y, ceil_x, ceil_y) then
    return false
  end

  -- check for objects


  return true
end

local function player_get_align_position()
  local x = math.floor(player_map_position[1] + 0.5)
  local y = math.floor(player_map_position[2] + 0.5)
  return x, y
end

-- returns x, y, alternate_x, alternate_y
local function player_looking_at()
  local x_real, y_real = table.unpack(player_map_position)
  local x, y = player_get_align_position()
  local x_diff = x_real - x
  local y_diff = y_real - y
  if player_tile == 16 then
    -- down
    return x, y + 1, (x_diff > 0) and (x + 1) or (x - 1), y + 1
  elseif player_tile == 17 then
    -- up
    return x, y - 1, (x_diff > 0) and (x + 1) or (x - 1), y - 1
  elseif player_tile == 18 then
    -- left
    return x -1, y, x - 1, (y_diff > 0) and (y + 1) or (y - 1)
  elseif player_tile == 19 then
    --right
    return x + 1, y, x + 1, (y_diff > 0) and (y + 1) or (y - 1)
  end
end

local function player_behind_position()
  local x, y = table.unpack(player_map_position)
  if player_tile == 16 then
    return x, math.floor(y + 0.5) - 1
  elseif player_tile == 17 then
    return x, math.floor(y + 0.5) + 1
  elseif player_tile == 18 then
    return math.floor(x + 0.5) + 1, y
  elseif player_tile == 19 then
    return math.floor(x + 0.5) - 1, y
  end
end


local function object_map_take(map_x, map_y)
  local obj = object_map[map_y * 60 + map_x]
  local ret = nil
  if (obj) then
    ret = obj[#obj]
    if (ret[1] > 271) then
      return nil
    end
    table.remove(obj, #obj)
    if #obj == 0 then
      object_map[map_y * 60 + map_x] = nil
    end
  end
  return ret
end

local function object_map_put(map_x, map_y, object)
  local ground_tile = mget(map_x, map_y)
  if ground_tile < 192 then
    return false
  end
  local obj_array = object_map[map_y * 60 + map_x]
  if (obj_array == nil) then
    obj_array = {}
    object_map[map_y * 60 + map_x] = obj_array
  end
  if #obj_array < 3 then
    obj_array[#obj_array + 1] = object
    return true
  end
  return false
end

local function object_map_replace(map_x, map_y, object)
  local map = object_map[map_y * 60 + map_x]
  if not map then
    map = {}
    object_map[map_y * 60 + map_x] = map
  end
  map[1] = object
end

local function object_map_put_shredder(id, map_x, map_y)
  if map_x then
    shredder_position_x = map_x
  else
    map_x = shredder_position_x
  end
  if map_y then
    shredder_position_y = map_y
  else
    map_y = shredder_position_y
  end
  object_map_replace(map_x, map_y, {id})
  object_map_replace(map_x + 1, map_y, {id + 1})
  object_map_replace(map_x, map_y +1, {id + 16})
  object_map_replace(map_x + 1, map_y +1, {id + 16 + 1})
end

local function object_map_put_computer(id, map_x, map_y)
  if map_x then
    computer_position_x = map_x
  else
    map_x = computer_position_x
  end
  if map_y then
    computer_position_y = map_y
  else
    map_y = computer_position_y
  end
  object_map_replace(map_x, map_y, {id})
  object_map_replace(map_x + 1, map_y, {id + 1})
  object_map_replace(map_x, map_y +1, {id + 16})
  object_map_replace(map_x + 1, map_y +1, {id + 16 + 1})
end

local shredder_old_id = 0
local shredder_new_id = 0
function update_shredder()
  if shredder_is_running > 0 then
    sfx(1, 0, -1, 1, 7)
    shredder_is_running = shredder_is_running - 1
    if (shredder_is_running <= 210) then
      shredder_new_id = 32 + (math.floor((210 - shredder_is_running) / 30) % 7) * 2
    else
      shredder_new_id = (math.floor(shredder_is_running / 30) % 2) * 2
    end
    if shredder_new_id ~= shredder_old_id then
      shredder_old_id = shredder_new_id
      object_map_put_shredder(384 + shredder_new_id)
    end
    if shredder_is_running == 0 then
      local player_x, player_y = player_get_align_position()
      if (shredder_position_x ~= player_x or shredder_position_y + 2~= player_y) and object_map_put(shredder_position_x, shredder_position_y + 2, {264}) then
        if not player_can_move(player_map_position[1], player_map_position[2]) then
          player_map_position[1], player_map_position[2] = player_get_align_position()
        end
      elseif (shredder_positionx ~= player_x + 1 or shredder_position_y + 2 ~= player_y) and object_map_put(shredder_position_x + 1, shredder_position_y + 2, {264}) then
        if not player_can_move(player_map_position[1], player_map_position[2]) then
          player_map_position[1], player_map_position[2] = player_get_align_position()
        end
        --
      else
        shredder_is_running = 210
      end
    end
  else
    sfx(1, 0, 0, 1, 7)
    object_map_put_shredder(384)
    local object = nil
    if not object then
      object = object_map_take(shredder_position_x, shredder_position_y)
      if object and object[1] ~= 256 then
        object_map_put(shredder_position_x, shredder_position_y, object)
        object = nil
      end
    end
    if not object then
      object = object_map_take(shredder_position_x + 1, shredder_position_y)
      if object and object[1] ~= 256 then
        object_map_put(shredder_position_x + 1, shredder_position_y, object)
        object = nil
      end
    end
    if not object then
      object = object_map_take(shredder_position_x, shredder_position_y + 1)
      if object and object[1] ~= 256 then
        object_map_put(shredder_position_x, shredder_position_y + 1, object)
        object = nil
      end
    end
    if not object then
      object = object_map_take(shredder_position_x + 1, shredder_position_y + 1)
      if object and object[1] ~= 256 then
        object_map_put(shredder_position_x + 1, shredder_position_y + 1, object)
        object = nil
      end
    end

    if object then
      shredder_is_running = 60 * 10 -- 10 sek
    end
  end
end

function update_computer()
  local ret = false
  for y = computer_position_y, computer_position_y + 1 do
    for x = computer_position_x, computer_position_x + 1 do
      local array = object_map_get(x, y)
      if (array) then
        for i = 1, #array do
          if array[i][1] < 260 then
            if nil == array[i][2] then
              array[i][2] = {}
            end
            if array[i][2].scanned ~= true then
              array[i][2].scanned = true
              player_score = player_score + 5
              ret = true
            end
          end
        end
      end
    end
  end
  if ret then
    sfx(0, 60, 30)
  end
  return ret
end



local function my_sort(a, b)
  return a[1] < b[1]
end

local function draw_map_walls()
  map(0, 8, 3, 2, 0, 8 * 8)
  map(2, 10, 24, 1, 2 * 8, 10 * 8)
  map(25, 7, 5, 2, 25 * 8, 7 * 8)
  map(25, 9, 1, 2, 25 * 8, 9 * 8)
end

local function draw_objects()
  local player_was_drawn = false
  local player_index = get_player_map_index()
  local object_list = {}
  for idx, obj_array in next,object_map do
    object_list[#object_list + 1] = {idx, obj_array}
  end
  table.sort(object_list, my_sort)
  local object_cnt = #object_list
  for i = 1, object_cnt do
    local idx = object_list[i][1]
    local obj_array = object_list[i][2]
    local cnt = #obj_array
    local map_x = math.floor(idx % 60)
    local map_y = math.floor(idx / 60)
    if not player_was_drawn and idx > player_index then
      draw_player()
      player_was_drawn = true
    end
    for i = 1, cnt do
      spr(obj_array[i][1], map_x * 8, map_y * 8 - ((i - 1) * 4 ), 0)
    end
  end
  if not player_was_drawn then
    draw_player()
  end
end


local function player_action_move(x_move, y_move)
  local player_map_x, player_map_y = table.unpack(player_map_position)
  if player_can_move(player_map_x + x_move, player_map_y + y_move) then
    player_map_position[1] = player_map_x + x_move
    player_map_position[2] = player_map_y + y_move
    return true
  end
  return false
end

local function player_action_put_object()
  local map_x, map_y, alt_x, alt_y = player_looking_at()
  if object_map_put(map_x, map_y, player_carries_object) or
     object_map_put(alt_x, alt_y, player_carries_object) then
    player_carries_object = nil
    sfx(0, 10, 30)
  else
    local new_x, new_y = player_behind_position()
    local old_x, old_y = player_get_align_position()
    -- push player back and put packet on the players old position
    -- when it is possible
    if (player_can_move(new_x, new_y)) then
      player_map_position[1] = new_x
      player_map_position[2] = new_y
      if object_map_put(old_x, old_y, player_carries_object) then
        player_carries_object = nil
        sfx(0, 10, 30)
      end
    end

  end
  if not player_can_move(table.unpack(player_map_position)) then
    -- player stock in object ... align
    local new_x, new_y = player_get_align_position()
    if (player_tile == 16 or player_tile == 17) then
      player_map_position[2] = new_y
    else
      player_map_position[1] = new_x
    end

  end
end

local function player_action_get_object()
  local map_x, map_y, alt_x, alt_y = player_looking_at()
  local obj = object_map_take(map_x, map_y)

  if (obj == nil) then
    obj = object_map_take(alt_x, alt_y)
  end

  if obj then
    player_carries_object = obj
    sfx(0, 10, 30)
  end
end

local function free_document_space()
  local ret = document_space_w * document_space_w * 3
  for x = document_space_x, document_space_x + document_space_w  - 1 do
    for y = document_space_y, document_space_y + document_space_w - 1 do
      local array = object_map_get(x,y)
      if array then
        for i = 1, #array do
          ret = ret - 1
        end
      end
    end
  end
  return ret
end

local function new_documents_arrive(cnt)
  local max_rounds = 5
  while cnt > 0 and max_rounds > 0 do
    max_rounds = max_rounds - 1
    for x = document_space_x, document_space_x + document_space_w - 1 do
      for y = document_space_y, document_space_y + document_space_w - 1 do
        if(cnt > 0 and not collide_with_object(player_map_position[1], player_map_position[2], x, y)) then
          if (object_map_put(x, y, {259, {scanned=false, expiration=tick + 60 * 60 + 60 * 60 * 10 * math.random() }})) then
            player_score = player_score + 10
            cnt = cnt - 1
          end
        end
      end
    end
  end
  return max_rounds > 0
end

local function run_garbage_collection()
  for x = garbage_space_x, garbage_space_x + garbage_space_w - 1 do
    for y = garbage_space_y, garbage_space_y + garbage_space_w -1 do
      while true do
        local obj = object_map_take(x, y)
        if (obj == nil or obj[1] ~= 264) then
          break
        else
          player_score = player_score + 20
        end
      end
    end
  end
end

local function update_objects()
  for idx, val in next,object_map do
    if val then
      for i = 1, #val do
        if val[i][2] then
          if val[i][2].scanned == true then
            if (val[i][2].expiration) then
              local time_left = val[i][2].expiration - tick
              if (time_left > 60 * 60 * 2) then
                val[i][1] = 258 -- green
              elseif (time_left > 0) then
                val[i][1] = 257 -- yellow
              else
                val[i][1] = 256 -- red
              end
            end
          end
        end
      end
    end
  end
end


local function game_init()
  game_running = true
  tick = 0
  player_move_last_tick = 0
  document_next_tick = 0
  game_over_tick = 0
  player_score = 0
  player_map_position = {10, 5}
  player_tile = 16
  layer_carries_object = nil
  shredder_is_running = 0
  document_delay = 60
  object_map = {}
  object_map_put_shredder(384, 21, 2)
  object_map_put_computer(464, 10, 2)

  for i = 6, 20, 1 do
    for c = 1, 1 + math.random(2) do
      object_map_put(i,9,{259, {scanned = math.random(2) == 1, expiration = 60 * 60 * 10 * math.random()}})
    end
  end
  for i = 6, 20, 2 do
    for c = 1, 1 + math.random(2) do
      object_map_put(i,8,{259, {scanned = math.random(2) == 1, expiration = 60 * 60 * 10 * math.random()}})
    end
  end
end


local function do_game()
  -- get user input
  tick = tick + 1
  player_move = 0

  if tick >= document_next_tick then
    if not new_documents_arrive(document_amount) then
      return "game over"
    end
    document_amount = 1 + math.floor(math.random() * 15)
    document_delay = document_delay * 0.99
    document_next_tick = tick + document_delay * 60
  end

  if tick % (garbage_delay * 60) == 0 then
    run_garbage_collection()
  end

  local player_speed = player_carries_object and player_speed_slow or player_speed_fast

  if btn(0) then
    -- up
    if player_action_move(0, -player_speed) then
      player_move = 1
    end
    player_tile = 17
  elseif btn(1) then
    if player_action_move(0, player_speed) then
      player_move = 1
    end
    player_tile = 16
  elseif (btn(2)) then
    if player_action_move(-player_speed, 0) then
      player_move = 1
    end
    player_tile = 18
  elseif (btn(3)) then
    if player_action_move(player_speed, 0) then
      player_move = 1
    end
    player_tile = 19
  end

  if (btn(4)) then
    if last_button ~= 4 then
      last_button = 4;
      if player_carries_object then
        player_action_put_object()
      else
        player_action_get_object()
      end
    end
  else
    last_button = -1
  end

  -- draw map
  map(0, 0, 60, 17, 0, 0)


  -- draw player
  local x,y = table.unpack(player_map_position)
  if (player_move == 1) then
    if ((tick - player_move_last_tick) > 10 ) then
      player_move_last_tick = tick
      cnt = cnt + 1
      player_animation = 32 + 32 * ( cnt % 2)
    end
  else
    player_animation = 0
  end

  update_computer()

  update_objects()

  update_shredder()

  draw_objects()

  -- post wall drawing (player may hide some of the front wall and that would
  -- look bad
  draw_map_walls()

  --[[ draw viewpoint this for debug ...
  local l_x, l_y, alt_x, alt_y = player_looking_at()
  l_x = l_x * 8
  l_y = l_y * 8
  spr(192, l_x, l_y)
  if (alt_x and alt_y) then
    spr(195, alt_x * 8, alt_y * 8)
  end
  -- draw viewpoint end --]]
  local free_space = free_document_space()
  local color = 11
  if (free_space - document_amount > document_amount) then
    color = 11
  elseif (free_space - document_amount > 0 ) then
    color = 14
  else
    color = 6
  end
  print ("" .. document_amount .. " Documents in ".. math.floor((document_next_tick - tick) / 60)
  .. "\nSpace: " .. free_space, 0 , 0, color)

  print ("Score: " .. player_score, 140, 0, 11)

  print ("Clear\nin " .. math.floor((garbage_delay * 60 - tick % (garbage_delay * 60)) / 60),
  205, 75, 5)

  --draw_player(table.unpack(player_map_position))
  --spr(256 + player_tile + player_animation, x, y, 15)
  --spr(256 + player_tile + 16 + player_animation, x, y + 8, 15)
end

local function put_comp(x, y, scale)
  spr(464, x, y, 0, scale)
  spr(465, x + 8 * scale, y, 0, scale)
  spr(480, x, y + 8 *scale, 0, scale)
  spr(481, x + 8 * scale, y + 8 * scale, 0, scale)
  print("SHREDDER", 25, 0, 6, true, 4)
  print("Boy", 85, 25, 6, true, 4)
end

local function do_title()
  cls(2)
  spr(272, 50, 50, 15, 4)
  spr(288, 50, 50 + 8 * 4, 15, 4)

  put_comp(100,50, 4)

end

local function do_game_over()
  local bg_color = 5
  local fg_color = 11
    rect (0, 15, 240, 70, bg_color)
    print ("Game Over", 70, 20, fg_color, false, 2)
    print ("No Space Left For Documents", 40, 32, fg_color, false, 1)
    print (string.format("your score was: %d", player_score), 5, 50, fg_color, false, 1)
    print (string.format("you have survived %d minutes and %d seconds", math.floor(tick / (60 * 60)), math.floor((tick % (60 * 60)) / 60)), 5, 60, fg_color, false, 1)
end
local first_start = true
function TIC()
  if first_start then
    do_title()
    if btn(4) or btn(1) or btn(0) or btn(2) or btn(3) then
      first_start = false
      game_init()
    end
  elseif game_running then
    if do_game() then
      game_running = false;
    end
  else
    do_game_over()
    game_over_tick = game_over_tick + 1
    if game_over_tick > 60 * 10 and (btn(4) or btn(1) or btn(0) or btn(2) or btn(3)) then
      game_init()

    end
  end
end


-- <TILES>
-- 001:0000007700000073000000730000007300000073000000730000007300000073
-- 002:7777777733333333aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 003:7700000037000000370000003700000037000000370000003700000037000000
-- 005:0000007700000073000000730000007300000073000000730000007300000073
-- 006:7777777733333333aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 007:7700000037000000370000003700000037000000370000003700000037000000
-- 016:7777777733333333ffffffffffffffffffffffffffffffffffffffffffffffff
-- 017:0000007300000073000000730000007300000073000000730000007300000073
-- 018:aaaaaaaaaaaaaaaafaafffaaffffffffffffffffffffffffffffffffffffffff
-- 019:3700000037000000370000003700000037000000370000003700000037000000
-- 021:0000007300000073000000730000007300000073000000730000007300000073
-- 022:aaaaaaaaaaaaaaaafaafffaaffffffffffffffffffffffffffffffffffffffff
-- 023:3700000037000000370000003700000037000000370000003700000037000000
-- 032:ffffffffffffffff7ff777ff7777777777777777777777777777777777777777
-- 033:0000007300000073000000730000007300000073000000730000007300000073
-- 034:28228d88228288888d8828228888228228228d88228288888d88282288882282
-- 035:3700000037000000370000003700000037000000370000003700000037000000
-- 036:7777777733333333aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 037:7777777333333333aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 038:28228d88228288888d8828228888228228228d88228288888d88282288882282
-- 039:3777777733333333aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 040:7777777733333333aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 049:0000007300000077000000aa000000aa000000aa000000aa000000aa000000aa
-- 050:3333333377777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 051:3700000077000000aa000000aa000000aa000000aa000000aa000000aa000000
-- 053:3333333377777773aaaaaa73aaaaaa73aaaaaa73aaaaaa73aaaaaa73aaaaaa73
-- 054:28228d88228288888d8828228888228228228d88228288888d88282288882282
-- 055:333333333777777737aaaaaa37aaaaaa37aaaaaa37aaaaaa37aaaaaa37aaaaaa
-- 065:000000aa000000aa000000aa000000fa000000ff000000ff000000ff000000ff
-- 066:aaaaaaaaaaaaaaaafaafffaaffffffffffffffffffffffffffffffffffffffff
-- 067:aa000000aa000000af000000ff000000ff000000ff000000ff000000ff000000
-- 068:aaaaaa73aaaaaa73faafff73ffffff73ffffff73ffffff73ffffff73ffffff73
-- 069:aaaaaa73aaaaaa77faafffaaffffffaaffffffaaffffffaaffffffaaffffffaa
-- 070:3333333377777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 071:37aaaaaa77aaaaaaaaafffaaaaffffffaaffffffaaffffffaaffffffaaffffff
-- 072:37aaaaaa37aaaaaa37afffaa37ffffff37ffffff37ffffff37ffffff37ffffff
-- 085:000000aa000000aa000000aa000000fa000000ff000000ff000000ff000000ff
-- 086:aaaaaaaaaaaaaaaafaafffaaffffffffffffffffffffffffffffffffffffffff
-- 087:aa000000aa000000af000000ff000000ff000000ff000000ff000000ff000000
-- 137:0000000000000000000000000000000000000000000000000000000000050000
-- 140:00777777037bb555037555550375555503755555037555550077777700003737
-- 141:7777770055555730555557305555573055555730555557307777770037300000
-- 142:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 143:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 152:0000000005555555000555550000055500055555055555550000000000000000
-- 153:0005500055555500555555505555555555555550555555000005500000050000
-- 156:1113737344444444441100004411000044110000441100004411000044000000
-- 157:7373111144444444000011440000114400001144000011440000114400000044
-- 158:fa777777fa711111fa744444fa711111fa744444fa711111fa744444fa711111
-- 159:777a7333117a7333447a7333117a7333447a7333117a7333447a7330117a7300
-- 174:0cccc440bbbbbb55555555555b5b5b555b5b5b555b5b5b555b5b5b55bbbbbb55
-- 175:0114111111411111449444114494441144aaa41499aaa9414494441144944410
-- 190:0114111111411111449444114494441144eee41499eee9414494441144944410
-- 191:0114111111411111449444114494441144666414996669414494441144944410
-- 192:9999444444449999999944444444999999994444444499999999444444449999
-- 193:77777777aff7faaaaaf7ffaaaaa7fffa77777777faaaaff7ffaaaaf7fffaaaa7
-- 194:aaaaaaeeaaaeeeaaafeeaaaaeeeaffaeffafafeefafaeeafafeeeafaeeeffffa
-- 195:28228d88228288888d8828228888228228228d88228288888d88282288882282
-- 196:77777777aff7faaaaaf75555aaa7555575555555f5aa5ff5f555aaf5fff555a5
-- 197:77777777aff7faaa5a55ffaaaaa5fffa55755557f5a5af57f5aaa557f5fa5aa7
-- 207:0114111111411111449444114494441144bbb41499bbb9414494441144944410
-- 209:77777777f7777fffff7777fffff7777f777777777ffff77777ffff77777ffff7
-- 212:77755575aff55aa5aaf5ffa5aaa55ff577755777faaa55a5ffaaaaf7fffaaaa7
-- 213:75575777a5575aaaa5f75faaa5a75ffa77555777a555aff7ffaaaaf7fffaaaa7
-- 225:77777777f7777ffaff7777aafff77ffa777777777ffaaff777aaaaf77ffaaaa7
-- </TILES>

-- <SPRITES>
-- 000:0114111111411111449444114494441144666414996669414494441144944410
-- 001:0114111111411111449444114494441144eee41499eee9414494441144944410
-- 002:0114111111411111449444114494441144bbb41499bbb9414494441144944410
-- 003:0114111111411111449444114494441144aaa41499aaa9414494441144944410
-- 008:0cccc440bbbbbb55555555555b5b5b555b5b5b555b5b5b555b5b5b55bbbbbb55
-- 016:fff00fffff0000ffff0cccffff0cccffff6cccfff446c64ff444644ff444644f
-- 017:fff00fffff0000ffff0000ffff0000ffff6006fff440044ff440044ff440444f
-- 018:fff00fffff0000ffffcc00ffffccc0ffffccc00ffff6400ffff6440ffff644ff
-- 019:fff00fffff0000ffff00ccffff0cccfff00cccfff0046ffff0446fffff446fff
-- 020:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 032:f444644ffc4444cffc5555cfff5555ffff5ff5ffff5ff5ffff5ff5fff44ff44f
-- 033:f444444ff444444ffc5555cfff5555ffff5ff5ffff5ff5ffff5ff5fff44ff44f
-- 034:fff444fffff4c4fffff5c5fffff55ffffff55ffffff55ffffff44fffff444fff
-- 035:ff444fffff4c4fffff5c5ffffff55ffffff55ffffff55ffffff44ffffff444ff
-- 036:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 048:fff00fffff0000ffff0cccffff0cccffff6cccfff446c64ff444644ff444644f
-- 049:fff00fffff0000ffff0000ffff0000ffff6006fff440044ff440044ff440444f
-- 050:fff00fffff0000ffffcc00ffffccc0ffffccc00ffff6400ffff6440ffff644ff
-- 051:fff00fffff0000ffff00ccffff0cccfff00cccfff0046ffff0446fffff446fff
-- 064:f44464cffc4444cffc5555ffff5555ffff55f5ffff5ff5ffff4ff5fffffff44f
-- 065:f444444ffc44444fff5555cfff5555ffff5f55ffff5ff4ffff5ff4fff44fffff
-- 066:fff4c4fffff4c4fffff555fffff555ffff55554fff55554ffff44f4fff444fff
-- 067:ff4c4fffff4c4fffff555fffff555ffff45555fff45555fff4f44ffffff444ff
-- 080:fff00fffff0000ffff0cccffff0cccffff6cccfff446c64ff444644ff444644f
-- 081:fff00fffff0000ffff0000ffff0000ffff6006fff440044ff440044ff440444f
-- 082:fff00fffff0000ffffcc00ffffccc0ffffccc00ffff6400ffff6440ffff644ff
-- 083:fff00fffff0000ffff00ccffff0cccfff00cccfff0046ffff0446fffff446fff
-- 096:fc44644ffc4444cfff5555cfff5555ffff5f55ffff5ff5ffff5ff4fff44fffff
-- 097:f444444ff44444cffc5555ffff5555ffff55f5ffff4ff5ffff4ff5fffffff44f
-- 098:fffc44fffffc44fffff555fffff555fffff555fffff555ffffff44fffff444ff
-- 099:ff44cfffff44cfffff555fffff555fffff555fffff555fffff44ffffff444fff
-- 112:0000000000000000000000000000000000000000c000000cc000000c00000000
-- 113:00000000000000000000000000000000c440044cc440044c0400004000000000
-- 114:000000000000000000000000000000000000000400000c4400000c4400000000
-- 115:000000000000000000000000000000004000000044c0000044c0000000000000
-- 128:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 129:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 130:0000aaaa000aa33d00aa33d80aa33d8daa33d8ddaaaaaaaafffffffffaaaaaaa
-- 131:aaaaaaaa8dd8d8aadd8d8aa7d8d8aa738daaa733aaaa7333ffff7333aaaa7333
-- 144:fa777777fa711111fa744444fa711111fa744444fa711111fa744444fa711111
-- 145:777a7333117a7333447a7333117a7333447a7333117a7333447a7330117a7300
-- 146:fa777777fa711111fa744444fa711111fa744444fa711111fa744444fa711111
-- 147:777a7333117a7333447a7333117a7333447a7333117a7333447a7330117a7300
-- 160:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 161:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 162:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 163:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 164:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 165:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 166:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 167:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 168:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 169:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 170:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 171:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 172:0000aaaa000aa33800aa338d0aa338d8aa338d8daaaaaaaafffffffffaaaaaaa
-- 173:aaaaaaaad8dd8daa8dd8daa7dd8daa73d8aaa733aaaa7333ffff7333aaaa7333
-- 176:fa777777fa744444fa711111fa744444fa711111fa744444fa711111fa7bbbbb
-- 177:777a7333447a7333117a7333447a7333117a7333447a7333117a7330b57a7300
-- 178:fa777777fa711111fa744444fa711111fa744444fa711111fa75b5b5fa7bbbbb
-- 179:777a7333117a7333447a7333117a7333447a7333117a7333b57a7330b57a7300
-- 180:fa777777fa744444fa711111fa744444fa711111fa75b5b5fa75b5b5fa7bbbbb
-- 181:777a7333447a7333117a7333447a7333117a7333b57a7333b57a7330b57a7300
-- 182:fa777777fa711111fa744444fa711111fa75b5b5fa75b5b5fa75b5b5fa7bbbbb
-- 183:777a7333117a7333447a7333117a7333b57a7333b57a7333b57a7330b57a7300
-- 184:fa777777fa744444fa711111fa75b5b5fa75b5b5fa75b5b5fa75b5b5fa7bbbbb
-- 185:777a7333447a7333117a7333b57a7333b57a7333b57a7333b57a7330b57a7300
-- 186:fa777777fa711111fa755555fa75b5b5fa75b5b5fa75b5b5fa75b5b5fa7bbbbb
-- 187:777a7333117a7333557a7333b57a7333b57a7333b57a7333b57a7330b57a7300
-- 188:fa777777fa7bbbbbfa755555fa75b5b5fa75b5b5fa75b5b5fa75b5b5fa7bbbbb
-- 189:777a7333b57a7333557a7333b57a7333b57a7333b57a7333b57a7330b57a7300
-- 208:00777777037bb555037555550375555503755555037555550077777700003737
-- 209:7777770055555730555557305555573055555730555557307777770037300000
-- 224:1113737344444444441100004411000044110000441100004411000044000000
-- 225:7373111144444444000011440000114400001144000011440000114400000044
-- </SPRITES>

-- <MAP>
-- 000:000000000000000000000000000000000000000000000000000000000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626200626262
-- 001:000000000000001001012020206030000000500101202020203000000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 002:000000000000001102022121212131000000510202212121213100000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 003:20202020202020521d1e1c1c1c1c72606060521d1e1c1c1c1c7260606060626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 004:21212121212121241e1c1c1c1c1c24242424211e1c1c1c1c1c6121212121626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 005:2c2c2c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c4c5c626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 006:2c2c2c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c4d5d626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 007:2c2c2c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c7364646464626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 008:2323531c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c8465656565626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 009:2424441c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c3200000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 010:000013232323232323232323232323232323232323232323233300000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 011:000014242424242424242424242424242424242424242424243400000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 012:00000078889800007888980000c8d8008898001515001515150000000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 013:00002c79899900fa7989990000c9d900899900fbebfc1515150000000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 014:00000000000000000088980000e8f8788898000000788898154c5c000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 015:00000000000000fb0089990000e9f97989991515ea798999154d5d000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 016:000000000000000015151515151500000000001515151515150000000000626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 017:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 018:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 019:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 020:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 021:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 022:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 023:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 024:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 025:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 026:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 027:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 028:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 029:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 030:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 031:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 032:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 033:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 034:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 035:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 036:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 037:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 038:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 039:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 040:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 041:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 042:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 043:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 044:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 045:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 046:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 047:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 048:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 049:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 050:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 051:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 052:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 053:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 054:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 055:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 056:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 057:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 058:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 059:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 060:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 061:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 062:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 063:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 064:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 065:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 066:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 067:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 068:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 069:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 070:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 071:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 072:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 073:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 074:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 075:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 076:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 077:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 078:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 079:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 080:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 081:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 082:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 083:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 084:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 085:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 086:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 087:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 088:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 089:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 090:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 091:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 092:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 093:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 094:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 095:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 096:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 097:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 098:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 099:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 100:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 101:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 102:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 103:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 104:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 105:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 106:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 107:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 108:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 109:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 110:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 111:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 112:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 113:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 114:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 115:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 116:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 117:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 118:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 119:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 120:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 121:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 122:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 123:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 124:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 125:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 126:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 127:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 128:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 129:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 130:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 131:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 132:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 133:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 134:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- 135:626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262626262
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- 003:de5df0f2bad36c854f758c92db420c88
-- </WAVES>

-- <SFX>
-- 000:00000000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000f000308000000000
-- 001:030003000300030003000300030003000300030003000300030003000300030003000300030003000300030003000300030003000300030003000300000000000000
-- </SFX>

-- <PALETTE>
-- 000:140c1c59242430346d50555d854c30346524d04648657579597dcebe91598595a16daa2cd2aa996dc2cadad45e798999
-- </PALETTE>

