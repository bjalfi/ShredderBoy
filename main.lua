local player_speed = 1 / 16
local player_map_position = {10,10}
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
local document_space_x = 1
local document_space_y = 15
local document_space_w = 2
local game_running = true
local object_map = {}
local garbage_space_x = 25
local garbage_space_y =  5
local garbage_space_w = 2
local computer_position_x = 0
local computer_position_y = 0


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
  print("map_x = " .. map_x .. " map_y = " .. map_y)
end

local function object_map_get(map_x, map_y)
  return object_map[map_y * 60 + map_x]
end


local function collide_with_object(player_x, player_y, object_x, object_y)
  local treshold = 7
  local player_screen_x = player_x * 8
  local player_screen_y = player_y * 8
  local object_screen_x = object_x * 8
  local object_screen_y = object_y * 8

  return math.abs((player_screen_x + 4)  - (object_screen_x + 4)) < treshold and
  math.abs((player_screen_y + 4)  - (object_screen_y + 4)) < treshold

end

local function player_can_move(map_x, map_y, direction)
  local floor_x = math.floor(map_x)
  local floor_y = math.floor(map_y)
  local ceil_x = math.ceil(map_x)
  local ceil_y = math.ceil(map_y)
  if mget(floor_x, floor_y) < 192 or object_map_get(floor_x, floor_y) and collide_with_object(map_x, map_y, floor_x, floor_y)then
    return false
  elseif  mget(floor_x, ceil_y) < 192 or object_map_get(floor_x, ceil_y) and collide_with_object(map_x, map_y, floor_x, ceil_y)then
    return false
  elseif mget(ceil_x, floor_y) < 192 or object_map_get(ceil_x, floor_y) and collide_with_object(map_x, map_y, ceil_x, floor_y)then
    return false
  elseif mget(ceil_x, ceil_y) < 192 or object_map_get(ceil_x, ceil_y) and collide_with_object(map_x, map_y, ceil_x, ceil_y) then
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

local function player_looking_at()
  local x, y = player_get_align_position()
  if player_tile == 16 then
    -- down
    return x, y + 1
  elseif player_tile == 17 then
    -- up
    return x, y - 1
  elseif player_tile == 18 then
    -- left
    return x -1, y
  elseif player_tile == 19 then
    --right
    return x + 1, y
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
    object_map_put_shredder(384)
    local object = nil
    if not object then
      object = object_map_take(shredder_position_x, shredder_position_y)
    end
    if not object then
      object = object_map_take(shredder_position_x + 1, shredder_position_y)
    end
    if not object then
      object = object_map_take(shredder_position_x, shredder_position_y + 1)
    end
    if not object then
      object = object_map_take(shredder_position_x + 1, shredder_position_y + 1)
    end

    if object then
      shredder_is_running = 60 * 10 -- 10 sek
    end
  end
end

function update_computer()
  for y = computer_position_y, computer_position_y + 2 do
    for x = computer_position_x, computer_position_x + 2 do

    end
  end
end

object_map_put_shredder(384, 10, 5)
object_map_put_computer(464, 15, 5)

object_map_put(5,9,{256})
object_map_put(5,8,{257})
object_map_put(5,7,{258})
object_map_put(5,7,{259})

local function my_sort(a, b)
  return a[1] < b[1]
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
  local map_x, map_y = player_looking_at()
  if object_map_put(map_x, map_y, player_carries_object) then
    player_carries_object = nil
  end
  if not player_can_move(table.unpack(player_map_position)) then
    -- player stock in object ... align
    local new_x, new_y = player_get_align_position()
    player_map_position[1] = new_x
    player_map_position[2] = new_y
  end
end

local function player_action_get_object()
  local map_x, map_y = player_looking_at()
  local obj = object_map_take(map_x, map_y)

  if obj then
    player_carries_object = obj
  end
end

local function free_document_space()
end

local function new_documents_arrive(cnt)
  local max_rounds = 5
  while cnt > 0 and max_rounds > 0 do
    max_rounds = max_rounds - 1
    for x = document_space_x, document_space_x + document_space_w do
      for y = document_space_y, document_space_y + document_space_w do
        if(cnt > 0 and not collide_with_object(player_map_position[1], player_map_position[2], x, y)) then
          if (object_map_put(x, y, {256})) then
            cnt = cnt - 1
          end
        end
      end
    end
  end
  return max_rounds > 0
end

local function run_garbage_collection()
  for x = garbage_space_x, garbage_space_x + garbage_space_w do
    for y = garbage_space_y, garbage_space_y + garbage_space_w do
      while true do
        local obj = object_map_take(x, y)
        if (obj == nil or obj[1] ~= 264) then
          break
        end
      end
    end
  end
end

local function do_game()
  -- get user input
  tick = tick + 1
  player_move = 0

  if tick % 500 == 0 then
    if not new_documents_arrive(4) then
      return "game over"
    end
    run_garbage_collection()
  end

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
  elseif (btn(4)) then
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

  -- draw viewpoint this for debug ...
  --local l_x, l_y = player_looking_at()
  --l_x = l_x * 8
  --l_y = l_y * 8
  --spr(192, l_x, l_y)
  -- draw viewpoint end

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

  update_shredder()

  draw_objects()

  --draw_player(table.unpack(player_map_position))
  --spr(256 + player_tile + player_animation, x, y, 15)
  --spr(256 + player_tile + 16 + player_animation, x, y + 8, 15)
end

function TIC()
    if game_running then
     if do_game() then
       game_running = false;
     end
   else
    print ("Game over", 50, 50)

  end
end
