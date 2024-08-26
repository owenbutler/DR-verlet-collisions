
$sub_steps = 2
$all_objects = []
$frame_elapsed_time = 0.0
$spawn_timer = 0
$spawn_rate = 3
$spawn_counter = 0

$c_create_time = 0
$c_resolve_time = 0
$sqrt_time = 0

$debug = true

# $size = 60.0
# $use_saved_colors = true
# $spawn_limit = 276
$size = 15.0
$use_saved_colors = false
$spawn_limit = 1000
$fps_limiter = false

$field_width = 1280
$field_height = 720

def tick args
  frame_start_time = Time.now

  args.outputs.background_color = [0, 0, 0]

  if args.tick_count == 0
    setup args
  end

  delta_time = 16.to_f / $sub_steps.to_f / 1000.0
  collision_time_total = 0
  update_time_total = 0
  $c_create_time = 0
  $c_resolve_time = 0
  $sqrt_time = 0

  $sub_steps.times do

    t = Time.now
    collisions
    collision_time_total += Time.now - t

    t = Time.now
    update_all delta_time
    update_time_total += Time.now - t
  end

  collision_time_total = (collision_time_total * 1000).to_i
  update_time_total = (update_time_total * 1000).to_i
  $c_create_time = ($c_create_time * 1000).to_i
  $c_resolve_time = ($c_resolve_time * 1000).to_i
  $sqrt_time = ($sqrt_time * 1000).to_i

  if ($frame_elapsed_time < 0.014 || !$fps_limiter) && $spawn_timer.elapsed? && $all_objects.length < $spawn_limit
    $all_objects << new_object(20, 650, 7.9, 2.1)
    $all_objects << new_object(1240, 650 + $size + 3, -7.0, 1.3)
    $all_objects << new_object(20, 620, 7.9, 2.1)
    $all_objects << new_object(1240, 620 + $size + 3, -7.0, 1.3)
    $spawn_timer = args.tick_count + $spawn_rate
  end

  if click = args.inputs.mouse.click
    # spawn an object
    $all_objects << new_object(click.x, click.y, 0.0, 0.0)
  end

  render args

  if $debug
    args.outputs.labels  << {
      x: 520,
      y: 700,
      text: "s:#{args.gtk.current_framerate_calc} n:#{$all_objects.size} c:#{collision_time_total} u:#{update_time_total} t:#{($frame_elapsed_time * 1000).to_i}",
      text: sprintf('s:%02d n:%04d c:%02d-%02d-%02d-%02d u:%02d t:%02d', args.gtk.current_framerate_calc, $all_objects.size, collision_time_total, $c_create_time, $c_resolve_time, $sqrt_time, update_time_total, $frame_elapsed_time * 1000),
      size_enum: 1,
      vertical_alignment_enum: 1,
      r: 100, g: 100, b: 100,
    }
  end

  if args.inputs.keyboard.key_down.p
    save_positions args
  end
  if args.inputs.keyboard.key_down.backspace
    $debug = !$debug
  end

  $frame_elapsed_time = Time.now - frame_start_time
end

def save_positions args

  logo_pixels = args.gtk.get_pixels 'sprites/logo.png'
  putz logo_pixels

  color_data = {}

  Fn.each $all_objects do |obj|

    objx = (obj[0] / $size).to_i
    objy = (obj[1] / $size).to_i

    # 35 width - 36x20
    pixel = logo_pixels.pixels[(objy+1) * -37 + objx]
    color_data[obj[6]] = {
      r: pixel & 0xFF,
      g: (pixel >> 8) & 0xFF,
      b: (pixel >> 16) & 0xFF,
      a: (pixel >> 24) & 0xFF,
    }

    obj[7] = color_data[obj[6]].r
    obj[8] = color_data[obj[6]].g
    obj[9] = color_data[obj[6]].b
    obj[10] = color_data[obj[6]].a
  end

  putz color_data
end

def new_object x, y, xvel, yvel
  $spawn_counter += 1

  saved_colors = {}
  saved_colors.r = Math::sin($gtk.args.tick_count / 47).remap(-1, 1, 70, 255)
  saved_colors.g = Math::cos($gtk.args.tick_count / 17).remap(-1, 1, 80, 255)
  saved_colors.b = Math::sin($gtk.args.tick_count / 22).remap(-1, 1, 60, 255)
  saved_colors.a = 255

  if $use_saved_colors
    saved_colors = $color_data[$spawn_counter]
  end

  obj = [
    x, y,               # posx, posy - 0, 1
    x - xvel, y - yvel, # last_posx, last_posy - 2, 3
    0, 0,               # accelx, accely - 4, 5
    $spawn_counter,     # id - 6
    saved_colors.r, saved_colors.g, saved_colors.b, saved_colors.a == 0 ? 255 : saved_colors.a # r, g, b, a - 7, 8, 9, 10
  ]

  return obj
end

def render args

  sprites = $all_objects.map do |sprite_arr|
    {
      x: sprite_arr[0], y: sprite_arr[1],
      w: $size, h: $size,
      anchor_x: 0.5, anchor_y: 0.5,
      path: 'sprites/circle/white.png',
      r: sprite_arr[7],
      g: sprite_arr[8],
      b: sprite_arr[9],
      a: sprite_arr[10],
    }
  end
  args.outputs.sprites << sprites
end

def setup args
end

def collisions
  collisions_grid
end

def check_cells col1, col2
  return if col2 == nil || col2.empty?

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  i = 0
  col1_length = col1.length
  while i < col1_length
    object_to_check = col1[i]

    potential_outer_collisions = col2

    collision_index = 0
    potential_collisions_length = potential_outer_collisions.length
    while collision_index < potential_collisions_length
      potential_collision = potential_outer_collisions[collision_index]

      if object_to_check != potential_collision
        ox = object_to_check[0]
        oy = object_to_check[1]
        ix = potential_collision[0]
        iy = potential_collision[1]

        dx = ox - ix
        dy = oy - iy
        d2 = dx * dx + dy * dy
        if d2 < quick_check

          distance = Math::sqrt(d2)

          delta = ($size - distance) * 0.5
          hx = (dx / distance) * delta
          hy = (dy / distance) * delta

          object_to_check[0] = ox + hx
          object_to_check[1] = oy + hy
          potential_collision[0] = ix - hx
          potential_collision[1] = iy - hy
        end

      end

      collision_index += 1
    end

    i += 1
  end
end

def collisions_grid

  grid_width = (1280/$size).to_i + 2
  grid_height = (720/$size).to_i + 2
  grid = Array.new(grid_height * grid_width) {Array.new}

  Fn.each $all_objects do |object|
    grid_index_x = (object[0].to_i / $size.to_i).to_i + 1
    grid_index_y = (object[1].to_i / $size.to_i).to_i + 1
    grid[grid_index_y * grid_width + grid_index_x].push(object)
  end

  row = 0
  while row < grid_height
    col = 0
    while col < grid_width

      center_col = grid[row * grid_width + col]
      if center_col.empty?
        col += 1
        next
      end

      check_cells(center_col, center_col)

      check_cells(center_col, grid[(row + 1) * grid_width + col])     # n
      check_cells(center_col, grid[(row + 1) * grid_width + col + 1]) # ne
      check_cells(center_col, grid[row * grid_width + col + 1])       # e
      check_cells(center_col, grid[(row - 1) * grid_width + col + 1]) # se
      check_cells(center_col, grid[(row - 1) * grid_width + col])     # s
      check_cells(center_col, grid[(row - 1) * grid_width + col - 1]) # sw
      check_cells(center_col, grid[row * grid_width + col - 1])       # w
      check_cells(center_col, grid[(row + 1) * grid_width + col - 1]) # nw
      col += 1
    end
    row += 1
  end
end

  # return [
    # x, y,               # posx, posy - 0, 1
    # x - xvel, y - yvel, # last_posx, last_posy - 2, 3
    # 0, 0,               # accelx, accely - 4, 5
    # $spawn_counter,     # id - 6
    # saved_colors.r, saved_colors.g, saved_colors.b. saved_colors.a == 0 ? 255 : saved_colors.a # r, g, b, a - 7, 8, 9, 10
  # ]
def update_all delta_time

  dts = delta_time * delta_time

  Fn.each $all_objects do |obj|

    # apply gravity
    # obj[:acceleration].add!($gravity)
    accelx = obj[4] + 0
    accely = obj[5] + -1000.0

    # calculate the last move
    # last_move = obj[:position] - obj[:last_position]
    posx = obj[0]
    posy = obj[1]
    last_posx = obj[2]
    last_posy = obj[3]
    last_x = posx - last_posx
    last_y = posy - last_posy

    # find the new position using verlet
    # new_position = obj[:position] + last_move + obj[:acceleration].mul_scalar(dts)
    new_x = posx + last_x + (accelx * dts)
    new_y = posy + last_y + (accely * dts)


    # save the last position for next time
    # obj[:last_position] = obj[:position]
    obj[2] = posx
    obj[3] = posy

    # clamp the position to the bounds of a box (screen)
    # new_position.max!(Vec2.new($size / 2.0, $size / 2.0)).min!(Vec2.new($field_width - ($size / 2), $field_height - ($size / 2)))
    half_size = $size / 2.0
    new_x = new_x > half_size ? new_x : half_size
    new_y = new_y > half_size ? new_y : half_size
    new_x = new_x < $field_width - half_size ? new_x : $field_width - half_size
    new_y = new_y < $field_height - half_size ? new_y : $field_height - half_size

    # save the new position
    # obj[:position] = new_position
    obj[0] = new_x
    obj[1] = new_y

    # reset any forces (gravity etc)
    # obj[:acceleration].set!(0.0, 0.0)
    obj[4] = 0.0
    obj[5] = 0.0

    # set to screen space
    # obj[:x] = new_position.x + (1280 - $field_width) / 2
    # obj[:y] = new_position.y + (720 - $field_height) / 2
  end

end
