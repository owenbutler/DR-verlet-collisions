require "xenobrain/ruby_vectormath/vectormath_2d.rb"

$sub_steps = 2

$all_objects = []

$frame_elapsed_time = 0.0

$gravity = Vec2.new(0.0, -1000.0)

$size = 20.0

$spawn_timer = 0
$spawn_rate = 1

def tick args
  frame_start_time = Time.now

  args.outputs.background_color = [0, 0, 0]

  if args.tick_count == 0
    setup args
  end

  delta_time = 16.to_f / $sub_steps.to_f / 1000.0
  collision_time_total = 0
  update_time_total = 0
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

  if $frame_elapsed_time < 0.014 && $spawn_timer.elapsed?
    $all_objects << new_object(20, 450, 8.9, 2.1)
    $all_objects << new_object(35, 450 + $size + 3, 8.8, 2.3)
    $spawn_timer = args.tick_count + $spawn_rate
  end

  if click = args.inputs.mouse.click
    # spawn an object
    $all_objects << new_object(click.x, click.y, 0, 0)
  end

  render args

  args.outputs.labels  << {
    x: 520,
    y: 700,
    text: "s:#{args.gtk.current_framerate_calc} n:#{$all_objects.size} c:#{collision_time_total} u:#{update_time_total} t:#{($frame_elapsed_time * 1000).to_i}",
    size_enum: 1,
    vertical_alignment_enum: 1,
    r: 255, g: 255, b: 255
  }

  args.outputs.primitives << args.gtk.current_framerate_primitives

  $frame_elapsed_time = Time.now - frame_start_time
end


def new_object x, y, xvel, yvel
  {
    position: Vec2.new(x, y),
    last_position: Vec2.new(x - xvel, y - yvel),
    acceleration: Vec2.new,
    x: x,
    y: y,
    w: $size,
    h: $size,
    anchor_x: 0.5,
    anchor_y: 0.5,
    path: 'sprites/circle.png',
    r: Math::sin($gtk.args.tick_count / 47).remap(-1, 1, 0, 255),
    g: Math::cos($gtk.args.tick_count / 17).remap(-1, 1, 0, 255),
    b: Math::sin($gtk.args.tick_count / 22).remap(-1, 1, 0, 255),
  }
end

def render args

  args.outputs.sprites << $all_objects

end

def setup args
end

def collisions
  # collisions_n2
  # collisions_vertical_grid
  collisions_vertical_grid_with_find_intersect
  # collisions_find_collisions
  # collisions_grid
  # collisions_find_intersect
end

def collisions_find_intersect

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  return if $all_objects.size < 1

  Fn.each $all_objects do |obj|

    collisions = GTK::Geometry.find_all_intersect_rect obj, $all_objects
    Fn.each collisions do |collision|
      if obj != collision
        outer_position = obj[:position]
        inner_position = collision[:position]
        diff = outer_position - inner_position
        d2 = diff.length_sq
        # d2 = diff.x * diff.x + diff.y * diff.y
        if d2 < quick_check
          distance = Math.sqrt(d2)
          n = diff.div_scalar!(distance)
          delta = ($size - distance) * 0.5
          outer_position.add!(n.mul_scalar(delta))
          inner_position.sub!(n.mul_scalar(delta))
        end
      end
    end
  end
end

def collisions_find_collisions

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  return if $all_objects.size < 1
  square_collisions = GTK::Geometry.find_collisions $all_objects

  square_collisions.each do |c1, c2|
    if c1 != c2
      outer_position = c1[:position]
      inner_position = c2[:position]
      diff = outer_position - inner_position
      d2 = diff.length_sq
      # d2 = diff.x * diff.x + diff.y * diff.y
      if d2 < quick_check
        distance = Math.sqrt(d2)
        n = diff.div_scalar!(distance)
        delta = ($size - distance) * 0.5
        outer_position.add!(n.mul_scalar(delta))
        inner_position.sub!(n.mul_scalar(delta))
      end
    end
  end
end

def collisions_n2

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  Fn.each $all_objects do |outer|
    Fn.each $all_objects do |inner|
      if outer != inner
        outer_position = outer[:position]
        inner_position = inner[:position]
        diff = outer_position - inner_position
        d2 = diff.length_sq
        # d2 = diff.x * diff.x + diff.y * diff.y
        if d2 < quick_check
          distance = Math.sqrt(d2)
          n = diff.div_scalar!(distance)
          delta = ($size - distance) * 0.5
          outer_position.add!(n.mul_scalar(delta))
          inner_position.sub!(n.mul_scalar(delta))
        end
      end
    end
  end
end

def check_cols_intersect_while col1, col2
  return if col2.empty?

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  i = 0
  col_length = col1.length
  while i < col_length
    outer = col1[i]

    potential_outer_collisions = GTK::Geometry.find_all_intersect_rect outer, col2

    collision_index = 0
    potential_collisions_length = potential_outer_collisions.length
    while collision_index < potential_collisions_length
      potential_collision = potential_outer_collisions[collision_index]

      if outer != potential_collision
        outer_position = outer[:position]
        inner_position = potential_collision[:position]
        diff = outer_position - inner_position
        d2 = diff.length_sq
        # d2 = diff.x * diff.x + diff.y * diff.y
        if d2 < quick_check
          distance = Math.sqrt(d2)
          delta = ($size - distance) * 0.5
          half_distance = diff.div_scalar!(distance).mul_scalar!(delta)
          # half_distance = n.mul_scalar(delta)
          outer_position.add!(half_distance)
          inner_position.sub!(half_distance)
        end
      end

      collision_index += 1
    end

    i += 1
  end
end

def check_cols_intersect col1, col2
  return if col2.empty?

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  Fn.each col1 do |outer|

    potential_outer_collisions = GTK::Geometry.find_all_intersect_rect outer, col2
    Fn.each potential_outer_collisions do |potential_collision|

      if outer != potential_collision
        outer_position = outer[:position]
        inner_position = potential_collision[:position]
        diff = outer_position - inner_position
        d2 = diff.length_sq
        # d2 = diff.x * diff.x + diff.y * diff.y
        if d2 < quick_check
          distance = Math.sqrt(d2)
          delta = ($size - distance) * 0.5
          half_distance = diff.div_scalar!(distance).mul_scalar!(delta)
          # half_distance = n.mul_scalar(delta)
          outer_position.add!(half_distance)
          inner_position.sub!(half_distance)
        end
      end
    end
  end
end

def check_cols col1, col2
  return if col2.empty?

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  Fn.each col1 do |outer|
    Fn.each col2 do |inner|
      if outer != inner
        outer_position = outer[:position]
        inner_position = inner[:position]
        diff = outer_position - inner_position
        d2 = diff.length_sq
        # d2 = diff.x * diff.x + diff.y * diff.y
        if d2 < quick_check
          distance = Math.sqrt(d2)
          n = diff.div_scalar!(distance)
          delta = ($size - distance) * 0.5
          outer_position.add!(n.mul_scalar(delta))
          inner_position.sub!(n.mul_scalar(delta))
        end
      end
    end
  end
end

def collisions_vertical_grid_with_find_intersect

  grid_size = (1280/$size).to_i
  grid = Array.new(1280/$size) {Array.new}

  Fn.each $all_objects do |object|
    grid_index = (object[:position].x / $size).to_i
    grid[grid_index].push(object)
  end

  grid.each_with_index do |col, index|
    next if col.empty?

    if index == 0
      check_cols_intersect_while(col, grid[index+1])
    elsif index == grid_size - 1
      check_cols_intersect_while(col, grid[index-1])
    else
      check_cols_intersect_while(col, grid[index+1])
      check_cols_intersect_while(col, grid[index-1])
    end

    check_cols_intersect_while(col, col)
  end
end

def collisions_vertical_grid

  grid_size = (1280/$size).to_i
  grid = Array.new(1280/$size) {Array.new}

  Fn.each $all_objects do |object|
    grid_index = (object[:position].x / $size).to_i
    grid[grid_index].push(object)
  end

  grid.each_with_index do |col, index|
    next if col.empty?

    if index == 0
      check_cols(col, grid[index+1])
    elsif index == grid_size - 1
      check_cols(col, grid[index-1])
    else
      check_cols(col, grid[index+1])
      check_cols(col, grid[index-1])
    end

    check_cols(col, col)
  end
end

def collisions_grid

  grid_width = (1280/$size).to_i
  grid_height = (720/$size).to_i
  grid = Array.new(grid_height * grid_width) {Array.new}

  Fn.each $all_objects do |object|
    grid_index_x = (object[:position].x.to_i / $size.to_i).to_i
    grid_index_y = (object[:position].y.to_i / $size.to_i).to_i
    grid[grid_index_y * grid_width + grid_index_x].push(object)
  end

  row = 1.to_i
  while row < grid_height - 2
    col = 1.to_i
    while col < grid_width - 2

      center_col = grid[row * grid_width + col]
      if center_col.empty?
        col += 1
        next
      end

      check_cols_intersect(center_col, center_col)

      check_cols_intersect(center_col, grid[row * (grid_width+1) + col])     # n
      check_cols_intersect(center_col, grid[row * (grid_width+1) + col + 1]) # ne
      check_cols_intersect(center_col, grid[row * grid_width + col + 1])     # e
      check_cols_intersect(center_col, grid[row * (grid_width-1) + col + 1]) # se
      check_cols_intersect(center_col, grid[row * (grid_width-1) + col])     # s
      check_cols_intersect(center_col, grid[row * (grid_width-1) + col - 1]) # sw
      check_cols_intersect(center_col, grid[row * grid_width + col - 1])     # w
      check_cols_intersect(center_col, grid[row * (grid_width-1) + col - 1]) # nw
      col += 1
    end
    row += 1
  end
end


def update_all delta_time

  dts = delta_time * delta_time

  Fn.each $all_objects do |obj|

    # apply gravity
    obj[:acceleration].add!($gravity)

    # calculate the last move
    last_move = obj[:position] - obj[:last_position]

    # find the new position using verlet
    new_position = obj[:position] + last_move + obj[:acceleration].mul_scalar(dts)

    # save the last position for next time
    obj[:last_position] = obj[:position]

    # clamp the position to the bounds of a box (screen)
    new_position.max!(Vec2.new($size / 2.0, $size / 2.0)).min!(Vec2.new(1280 - ($size / 2), 720 - ($size / 2)))

    # save the new position
    obj[:position] = new_position

    # reset any forces (gravity etc)
    obj[:acceleration].set!(0.0, 0.0)

    # set to screen space
    obj[:x] = new_position.x
    obj[:y] = new_position.y
  end

end