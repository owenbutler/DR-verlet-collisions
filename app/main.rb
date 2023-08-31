require "xenobrain/ruby_vectormath/vectormath_2d.rb"

$sub_steps = 2
$all_objects = []
$frame_elapsed_time = 0.0
$gravity = Vec2.new(0.0, -1000.0)
$size = 60.0
$spawn_timer = 0
$spawn_rate = 3

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

  if $frame_elapsed_time < 0.014 && $spawn_timer.elapsed? && $all_objects.length < 275
    $all_objects << new_object(20, 450, 8.9, 2.1)
    $all_objects << new_object(1240, 450 + $size + 3, -9.0, 1.3)
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

  # args.outputs.primitives << args.gtk.current_framerate_primitives

  $frame_elapsed_time = Time.now - frame_start_time
end


def new_object x, y, xvel, yvel
  {
    position: Vec2.new(x, y),
    last_position: Vec2.new(x - xvel, y - yvel),
    acceleration: Vec2.new,
    x: x + (1280 - $field_width) / 2, y: y + (720 - $field_height) / 2,
    w: $size, h: $size,
    anchor_x: 0.5, anchor_y: 0.5,
    path: 'sprites/circle.png',
    r: Math::sin($gtk.args.tick_count / 47).remap(-1, 1, 0, 255),
    g: Math::cos($gtk.args.tick_count / 17).remap(-1, 1, 0, 255),
    b: Math::sin($gtk.args.tick_count / 22).remap(-1, 1, 0, 255),
  }
end

def render args
  args.outputs.sprites << $all_objects
  # args.outputs.borders << {
    # x: (1280 - $field_width) / 2,
    # y: (720 - $field_width) / 2,
    # w: $field_width,
    # h: $field_height,
    # r: 255,
  # }
end

def setup args
end

def collisions
  collisions_vertical_grid_with_find_intersect
end

def collisions_vertical_grid_with_find_intersect

  grid_size = ($field_width / $size).to_i
  grid = Array.new($field_width / $size) { Array.new }

  Fn.each $all_objects do |object|
    grid_index = (object[:position].x / $size).to_i
    grid[grid_index].push(object)
  end

  grid.each_with_index do |col, index|
    next if col.empty?

    if index == 0
      check_columns(col, grid[index+1])
    elsif index == grid_size - 1
      check_columns(col, grid[index-1])
    else
      check_columns(col, grid[index+1])
      check_columns(col, grid[index-1])
    end

    check_columns(col, col)
  end
end

def check_columns col1, col2
  return if col2.empty?

  r = $size / 2.0
  quick_check = (r + r) * (r + r)

  i = 0
  col1_length = col1.length
  while i < col1_length
    object_to_check = col1[i]

    potential_outer_collisions = GTK::Geometry.find_all_intersect_rect object_to_check, col2

    collision_index = 0
    potential_collisions_length = potential_outer_collisions.length
    while collision_index < potential_collisions_length
      potential_collision = potential_outer_collisions[collision_index]

      if object_to_check != potential_collision
        outer_position = object_to_check[:position]
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
    new_position.max!(Vec2.new($size / 2.0, $size / 2.0)).min!(Vec2.new($field_width - ($size / 2), $field_height - ($size / 2)))

    # save the new position
    obj[:position] = new_position

    # reset any forces (gravity etc)
    obj[:acceleration].set!(0.0, 0.0)

    # set to screen space
    obj[:x] = new_position.x + (1280 - $field_width) / 2
    obj[:y] = new_position.y + (720 - $field_height) / 2
  end

end