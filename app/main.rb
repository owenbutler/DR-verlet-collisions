require "xenobrain/ruby_vectormath/vectormath_2d.rb"

$sub_steps = 2
$all_objects = []
$frame_elapsed_time = 0.0
$gravity = Vec2.new(0.0, -1000.0)
$size = 60.0
$spawn_timer = 0
$spawn_rate = 3
$spawn_limit = 276
$spawn_counter = 0

$c_create_time = 0
$c_resolve_time = 0

$debug = false

$use_saved_colors = false

$field_width = 1280
$field_height = 720

def tick args
  frame_start_time = Time.now

  args.outputs.background_color = [255, 255, 255]

  if args.tick_count == 0
    setup args
  end

  delta_time = 16.to_f / $sub_steps.to_f / 1000.0
  collision_time_total = 0
  update_time_total = 0
  $c_create_time = 0
  $c_resolve_time = 0
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

  if $frame_elapsed_time < 0.014 && $spawn_timer.elapsed? && $all_objects.length < $spawn_limit
    $all_objects << new_object(20, 450, 8.9, 2.1)
    $all_objects << new_object(1240, 450 + $size + 3, -9.0, 1.3)
    $spawn_timer = args.tick_count + $spawn_rate
  end

  if click = args.inputs.mouse.click
    # spawn an object
    $all_objects << new_object(click.x, click.y, 0, 0)
  end

  render args

  if $debug
    args.outputs.labels  << {
      x: 520,
      y: 700,
      text: "s:#{args.gtk.current_framerate_calc} n:#{$all_objects.size} c:#{collision_time_total} u:#{update_time_total} t:#{($frame_elapsed_time * 1000).to_i}",
      text: sprintf('s:%02d n:%04d c:%02d-%02d-%02d u:%02d t:%02d', args.gtk.current_framerate_calc, $all_objects.size, collision_time_total, $c_create_time, $c_resolve_time, update_time_total, $frame_elapsed_time * 1000),
      size_enum: 1,
      vertical_alignment_enum: 1,
      r: 0, g: 0, b: 0,
    }
  end

  if args.inputs.keyboard.key_down.p
    save_positions args
  end
  if args.inputs.keyboard.key_down.backspace
    $debug = !$debug
  end

  # args.outputs.primitives << args.gtk.current_framerate_primitives

  $frame_elapsed_time = Time.now - frame_start_time
end

def save_positions args

  logo_pixels = args.gtk.get_pixels 'sprites/logo.png'
  putz logo_pixels

  color_data = {}

  Fn.each $all_objects do |obj|

    objx = (obj.x / $size).to_i
    objy = (obj.y / $size).to_i

    pixel = logo_pixels.pixels[(objy+1) * -21 + objx]
    color_data[obj.id] = {
      r: pixel & 0xFF,
      g: (pixel >> 8) & 0xFF,
      b: (pixel >> 16) & 0xFF,
      a: (pixel >> 24) & 0xFF,
    }

    obj.r = color_data[obj.id].r
    obj.g = color_data[obj.id].g
    obj.b = color_data[obj.id].b
    obj.a = color_data[obj.id].a
  end

  putz color_data
end

def new_object x, y, xvel, yvel
  $spawn_counter += 1

  saved_colors = {}
  saved_colors.r = Math::sin($gtk.args.tick_count / 47).remap(-1, 1, 70, 255),
  saved_colors.g = Math::cos($gtk.args.tick_count / 17).remap(-1, 1, 80, 255),
  saved_colors.b = Math::sin($gtk.args.tick_count / 22).remap(-1, 1, 60, 255),
  saved_colors.a = 255

  if $use_saved_colors
    saved_colors = $color_data[$spawn_counter]
  end

  {
    position: Vec2.new(x, y),
    last_position: Vec2.new(x - xvel, y - yvel),
    acceleration: Vec2.new,
    x: x + (1280 - $field_width) / 2, y: y + (720 - $field_height) / 2,
    w: $size, h: $size,
    anchor_x: 0.5, anchor_y: 0.5,
    path: 'sprites/circle.png',
    id: $spawn_counter,
    r: saved_colors.r,
    g: saved_colors.g,
    b: saved_colors.b,
    a: saved_colors.a == 0 ? 255 : saved_colors.a,
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

  t = Time.now
  grid_size = ($field_width / $size).to_i
  grid = Array.new($field_width / $size) { Array.new }

  Fn.each $all_objects do |object|
    grid_index = (object[:position].x / $size).to_i
    grid[grid_index].push(object)
  end

  $c_create_time += Time.now - t


  t = Time.now
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

  $c_resolve_time += Time.now - t
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
          distance = Math::sqrt(d2)
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

$color_data = {1=>{:r=>0, :g=>0, :b=>0, :a=>0}, 2=>{:r=>0, :g=>0, :b=>0, :a=>0}, 3=>{:r=>227, :g=>19, :b=>0, :a=>223}, 4=>{:r=>0, :g=>0, :b=>0, :a=>0}, 5=>{:r=>0, :g=>0, :b=>0, :a=>0}, 6=>{:r=>0, :g=>0, :b=>0, :a=>0}, 7=>{:r=>0, :g=>0, :b=>0, :a=>0}, 8=>{:r=>0, :g=>0, :b=>0, :a=>0}, 9=>{:r=>0, :g=>0, :b=>0, :a=>0}, 10=>{:r=>0, :g=>0, :b=>0, :a=>0}, 11=>{:r=>0, :g=>0, :b=>0, :a=>0}, 12=>{:r=>0, :g=>0, :b=>0, :a=>0}, 13=>{:r=>0, :g=>0, :b=>0, :a=>0}, 14=>{:r=>229, :g=>19, :b=>0, :a=>60}, 15=>{:r=>227, :g=>19, :b=>0, :a=>148}, 16=>{:r=>0, :g=>0, :b=>0, :a=>0}, 17=>{:r=>0, :g=>0, :b=>0, :a=>0}, 18=>{:r=>227, :g=>19, :b=>0, :a=>153}, 19=>{:r=>0, :g=>0, :b=>0, :a=>0}, 20=>{:r=>0, :g=>0, :b=>0, :a=>0}, 21=>{:r=>0, :g=>0, :b=>0, :a=>0}, 22=>{:r=>227, :g=>19, :b=>0, :a=>230}, 23=>{:r=>0, :g=>0, :b=>0, :a=>0}, 24=>{:r=>0, :g=>0, :b=>0, :a=>0}, 25=>{:r=>0, :g=>0, :b=>0, :a=>0}, 26=>{:r=>0, :g=>0, :b=>0, :a=>0}, 27=>{:r=>0, :g=>0, :b=>0, :a=>0}, 28=>{:r=>0, :g=>0, :b=>0, :a=>0}, 29=>{:r=>0, :g=>0, :b=>0, :a=>0}, 30=>{:r=>229, :g=>19, :b=>0, :a=>39}, 31=>{:r=>228, :g=>19, :b=>0, :a=>87}, 32=>{:r=>0, :g=>0, :b=>0, :a=>0}, 33=>{:r=>0, :g=>0, :b=>0, :a=>0}, 34=>{:r=>0, :g=>0, :b=>0, :a=>0}, 35=>{:r=>0, :g=>0, :b=>0, :a=>0}, 36=>{:r=>0, :g=>0, :b=>0, :a=>0}, 37=>{:r=>0, :g=>0, :b=>0, :a=>0}, 38=>{:r=>0, :g=>0, :b=>0, :a=>0}, 39=>{:r=>0, :g=>0, :b=>0, :a=>0}, 40=>{:r=>0, :g=>0, :b=>0, :a=>0}, 41=>{:r=>0, :g=>0, :b=>0, :a=>0}, 42=>{:r=>0, :g=>0, :b=>0, :a=>0}, 43=>{:r=>0, :g=>0, :b=>0, :a=>0}, 44=>{:r=>227, :g=>19, :b=>0, :a=>223}, 45=>{:r=>0, :g=>0, :b=>0, :a=>0}, 46=>{:r=>0, :g=>0, :b=>0, :a=>0}, 47=>{:r=>0, :g=>0, :b=>0, :a=>0}, 48=>{:r=>0, :g=>0, :b=>0, :a=>0}, 49=>{:r=>0, :g=>0, :b=>0, :a=>0}, 50=>{:r=>0, :g=>0, :b=>0, :a=>0}, 51=>{:r=>0, :g=>0, :b=>0, :a=>0}, 52=>{:r=>0, :g=>0, :b=>0, :a=>0}, 53=>{:r=>0, :g=>0, :b=>0, :a=>0}, 54=>{:r=>0, :g=>0, :b=>0, :a=>0}, 55=>{:r=>0, :g=>0, :b=>0, :a=>0}, 56=>{:r=>227, :g=>19, :b=>0, :a=>193}, 57=>{:r=>0, :g=>0, :b=>0, :a=>0}, 58=>{:r=>0, :g=>0, :b=>0, :a=>0}, 59=>{:r=>0, :g=>0, :b=>0, :a=>0}, 60=>{:r=>0, :g=>0, :b=>0, :a=>0}, 61=>{:r=>0, :g=>0, :b=>0, :a=>0}, 62=>{:r=>227, :g=>19, :b=>0, :a=>33}, 63=>{:r=>228, :g=>19, :b=>0, :a=>20}, 64=>{:r=>0, :g=>0, :b=>0, :a=>0}, 65=>{:r=>0, :g=>0, :b=>0, :a=>0}, 66=>{:r=>227, :g=>19, :b=>0, :a=>197}, 67=>{:r=>0, :g=>0, :b=>0, :a=>0}, 68=>{:r=>0, :g=>0, :b=>0, :a=>0}, 69=>{:r=>0, :g=>0, :b=>0, :a=>0}, 70=>{:r=>0, :g=>0, :b=>0, :a=>0}, 71=>{:r=>0, :g=>0, :b=>0, :a=>0}, 72=>{:r=>0, :g=>0, :b=>0, :a=>0}, 73=>{:r=>0, :g=>0, :b=>0, :a=>0}, 74=>{:r=>0, :g=>0, :b=>0, :a=>0}, 75=>{:r=>227, :g=>19, :b=>0, :a=>61}, 76=>{:r=>228, :g=>19, :b=>0, :a=>19}, 77=>{:r=>0, :g=>0, :b=>0, :a=>0}, 78=>{:r=>0, :g=>0, :b=>0, :a=>0}, 79=>{:r=>227, :g=>19, :b=>0, :a=>153}, 80=>{:r=>227, :g=>19, :b=>0, :a=>164}, 81=>{:r=>0, :g=>0, :b=>0, :a=>0}, 82=>{:r=>227, :g=>19, :b=>0, :a=>175}, 83=>{:r=>0, :g=>0, :b=>0, :a=>0}, 84=>{:r=>229, :g=>19, :b=>0, :a=>6}, 85=>{:r=>0, :g=>0, :b=>0, :a=>0}, 86=>{:r=>227, :g=>19, :b=>0, :a=>163}, 87=>{:r=>227, :g=>19, :b=>0, :a=>10}, 88=>{:r=>0, :g=>0, :b=>0, :a=>0}, 89=>{:r=>227, :g=>19, :b=>0, :a=>10}, 90=>{:r=>0, :g=>0, :b=>0, :a=>0}, 91=>{:r=>233, :g=>19, :b=>0, :a=>9}, 92=>{:r=>0, :g=>0, :b=>0, :a=>0}, 93=>{:r=>0, :g=>0, :b=>0, :a=>0}, 94=>{:r=>0, :g=>0, :b=>0, :a=>0}, 95=>{:r=>227, :g=>19, :b=>0, :a=>183}, 96=>{:r=>0, :g=>0, :b=>0, :a=>0}, 97=>{:r=>227, :g=>19, :b=>0, :a=>31}, 98=>{:r=>227, :g=>19, :b=>0, :a=>35}, 99=>{:r=>0, :g=>0, :b=>0, :a=>0}, 100=>{:r=>0, :g=>0, :b=>0, :a=>0}, 101=>{:r=>227, :g=>19, :b=>0, :a=>61}, 102=>{:r=>227, :g=>19, :b=>0, :a=>35}, 103=>{:r=>227, :g=>19, :b=>0, :a=>245}, 104=>{:r=>0, :g=>0, :b=>0, :a=>0}, 105=>{:r=>0, :g=>0, :b=>0, :a=>0}, 106=>{:r=>227, :g=>19, :b=>0, :a=>154}, 107=>{:r=>0, :g=>0, :b=>0, :a=>0}, 108=>{:r=>228, :g=>19, :b=>0, :a=>149}, 109=>{:r=>0, :g=>0, :b=>0, :a=>0}, 110=>{:r=>0, :g=>0, :b=>0, :a=>0}, 111=>{:r=>229, :g=>19, :b=>0, :a=>63}, 112=>{:r=>228, :g=>19, :b=>0, :a=>149}, 113=>{:r=>227, :g=>19, :b=>0, :a=>148}, 114=>{:r=>0, :g=>0, :b=>0, :a=>0}, 115=>{:r=>0, :g=>0, :b=>0, :a=>0}, 116=>{:r=>227, :g=>19, :b=>0, :a=>188}, 117=>{:r=>227, :g=>19, :b=>0, :a=>152}, 118=>{:r=>0, :g=>0, :b=>0, :a=>0}, 119=>{:r=>0, :g=>0, :b=>0, :a=>0}, 120=>{:r=>0, :g=>0, :b=>0, :a=>0}, 121=>{:r=>227, :g=>19, :b=>0, :a=>61}, 122=>{:r=>0, :g=>0, :b=>0, :a=>0}, 123=>{:r=>0, :g=>0, :b=>0, :a=>0}, 124=>{:r=>227, :g=>19, :b=>0, :a=>255}, 125=>{:r=>227, :g=>19, :b=>0, :a=>204}, 126=>{:r=>0, :g=>0, :b=>0, :a=>0}, 127=>{:r=>227, :g=>19, :b=>0, :a=>245}, 128=>{:r=>0, :g=>0, :b=>0, :a=>0}, 129=>{:r=>227, :g=>19, :b=>0, :a=>255}, 130=>{:r=>0, :g=>0, :b=>0, :a=>0}, 131=>{:r=>0, :g=>0, :b=>0, :a=>0}, 132=>{:r=>228, :g=>19, :b=>0, :a=>147}, 133=>{:r=>0, :g=>0, :b=>0, :a=>0}, 134=>{:r=>0, :g=>0, :b=>0, :a=>0}, 135=>{:r=>229, :g=>19, :b=>0, :a=>43}, 136=>{:r=>227, :g=>19, :b=>0, :a=>154}, 137=>{:r=>230, :g=>19, :b=>0, :a=>30}, 138=>{:r=>227, :g=>19, :b=>0, :a=>164}, 139=>{:r=>227, :g=>19, :b=>0, :a=>145}, 140=>{:r=>0, :g=>0, :b=>0, :a=>0}, 141=>{:r=>227, :g=>19, :b=>0, :a=>136}, 142=>{:r=>0, :g=>0, :b=>0, :a=>0}, 143=>{:r=>227, :g=>19, :b=>0, :a=>61}, 144=>{:r=>0, :g=>0, :b=>0, :a=>0}, 145=>{:r=>228, :g=>19, :b=>0, :a=>138}, 146=>{:r=>229, :g=>19, :b=>0, :a=>48}, 147=>{:r=>228, :g=>19, :b=>0, :a=>97}, 148=>{:r=>228, :g=>19, :b=>0, :a=>81}, 149=>{:r=>227, :g=>19, :b=>0, :a=>110}, 150=>{:r=>228, :g=>19, :b=>0, :a=>31}, 151=>{:r=>228, :g=>19, :b=>0, :a=>120}, 152=>{:r=>227, :g=>19, :b=>0, :a=>118}, 153=>{:r=>227, :g=>19, :b=>0, :a=>22}, 154=>{:r=>228, :g=>19, :b=>0, :a=>82}, 155=>{:r=>228, :g=>19, :b=>0, :a=>126}, 156=>{:r=>0, :g=>0, :b=>0, :a=>0}, 157=>{:r=>227, :g=>19, :b=>0, :a=>255}, 158=>{:r=>0, :g=>0, :b=>0, :a=>0}, 159=>{:r=>227, :g=>19, :b=>0, :a=>174}, 160=>{:r=>228, :g=>19, :b=>0, :a=>122}, 161=>{:r=>227, :g=>19, :b=>0, :a=>169}, 162=>{:r=>228, :g=>19, :b=>0, :a=>48}, 163=>{:r=>227, :g=>19, :b=>0, :a=>102}, 164=>{:r=>227, :g=>19, :b=>0, :a=>153}, 165=>{:r=>227, :g=>19, :b=>0, :a=>255}, 166=>{:r=>228, :g=>19, :b=>0, :a=>163}, 167=>{:r=>227, :g=>19, :b=>0, :a=>22}, 168=>{:r=>228, :g=>19, :b=>0, :a=>138}, 169=>{:r=>227, :g=>19, :b=>0, :a=>255}, 170=>{:r=>231, :g=>19, :b=>0, :a=>10}, 171=>{:r=>228, :g=>19, :b=>0, :a=>14}, 172=>{:r=>228, :g=>19, :b=>0, :a=>139}, 173=>{:r=>228, :g=>19, :b=>0, :a=>35}, 174=>{:r=>231, :g=>19, :b=>0, :a=>10}, 175=>{:r=>227, :g=>19, :b=>0, :a=>255}, 176=>{:r=>227, :g=>19, :b=>0, :a=>225}, 177=>{:r=>228, :g=>19, :b=>0, :a=>58}, 178=>{:r=>227, :g=>19, :b=>0, :a=>255}, 179=>{:r=>227, :g=>19, :b=>0, :a=>176}, 180=>{:r=>227, :g=>19, :b=>0, :a=>89}, 181=>{:r=>227, :g=>19, :b=>0, :a=>187}, 182=>{:r=>228, :g=>19, :b=>0, :a=>143}, 183=>{:r=>227, :g=>19, :b=>0, :a=>255}, 184=>{:r=>228, :g=>19, :b=>0, :a=>106}, 185=>{:r=>228, :g=>19, :b=>0, :a=>58}, 186=>{:r=>227, :g=>19, :b=>0, :a=>255}, 187=>{:r=>228, :g=>19, :b=>0, :a=>76}, 188=>{:r=>230, :g=>19, :b=>0, :a=>10}, 189=>{:r=>227, :g=>19, :b=>0, :a=>122}, 190=>{:r=>227, :g=>19, :b=>0, :a=>246}, 191=>{:r=>227, :g=>19, :b=>0, :a=>240}, 192=>{:r=>227, :g=>19, :b=>0, :a=>255}, 193=>{:r=>227, :g=>19, :b=>0, :a=>255}, 194=>{:r=>227, :g=>19, :b=>0, :a=>255}, 195=>{:r=>227, :g=>19, :b=>0, :a=>153}, 196=>{:r=>227, :g=>19, :b=>0, :a=>194}, 197=>{:r=>227, :g=>19, :b=>0, :a=>102}, 198=>{:r=>0, :g=>0, :b=>0, :a=>0}, 199=>{:r=>0, :g=>0, :b=>0, :a=>0}, 200=>{:r=>227, :g=>19, :b=>0, :a=>255}, 201=>{:r=>228, :g=>19, :b=>0, :a=>126}, 202=>{:r=>230, :g=>19, :b=>0, :a=>10}, 203=>{:r=>228, :g=>19, :b=>0, :a=>57}, 204=>{:r=>227, :g=>19, :b=>0, :a=>10}, 205=>{:r=>0, :g=>0, :b=>0, :a=>0}, 206=>{:r=>227, :g=>19, :b=>0, :a=>255}, 207=>{:r=>227, :g=>19, :b=>0, :a=>204}, 208=>{:r=>237, :g=>20, :b=>0, :a=>8}, 209=>{:r=>227, :g=>19, :b=>0, :a=>75}, 210=>{:r=>227, :g=>19, :b=>0, :a=>255}, 211=>{:r=>227, :g=>19, :b=>0, :a=>194}, 212=>{:r=>227, :g=>19, :b=>0, :a=>184}, 213=>{:r=>227, :g=>19, :b=>0, :a=>10}, 214=>{:r=>227, :g=>19, :b=>0, :a=>184}, 215=>{:r=>227, :g=>19, :b=>0, :a=>135}, 216=>{:r=>227, :g=>19, :b=>0, :a=>185}, 217=>{:r=>227, :g=>19, :b=>0, :a=>194}, 218=>{:r=>227, :g=>19, :b=>0, :a=>102}, 219=>{:r=>0, :g=>0, :b=>0, :a=>0}, 220=>{:r=>227, :g=>19, :b=>0, :a=>66}, 221=>{:r=>0, :g=>0, :b=>0, :a=>0}, 222=>{:r=>227, :g=>19, :b=>0, :a=>107}, 223=>{:r=>227, :g=>19, :b=>0, :a=>79}, 224=>{:r=>0, :g=>0, :b=>0, :a=>0}, 225=>{:r=>0, :g=>0, :b=>0, :a=>0}, 226=>{:r=>0, :g=>0, :b=>0, :a=>0}, 227=>{:r=>227, :g=>19, :b=>0, :a=>255}, 228=>{:r=>227, :g=>19, :b=>0, :a=>255}, 229=>{:r=>0, :g=>0, :b=>0, :a=>0}, 230=>{:r=>0, :g=>0, :b=>0, :a=>0}, 231=>{:r=>0, :g=>0, :b=>0, :a=>0}, 232=>{:r=>0, :g=>0, :b=>0, :a=>0}, 233=>{:r=>227, :g=>19, :b=>0, :a=>243}, 234=>{:r=>227, :g=>19, :b=>0, :a=>253}, 235=>{:r=>227, :g=>19, :b=>0, :a=>193}, 236=>{:r=>227, :g=>19, :b=>0, :a=>165}, 237=>{:r=>228, :g=>19, :b=>0, :a=>84}, 238=>{:r=>0, :g=>0, :b=>0, :a=>0}, 239=>{:r=>228, :g=>19, :b=>0, :a=>142}, 240=>{:r=>227, :g=>19, :b=>0, :a=>232}, 241=>{:r=>0, :g=>0, :b=>0, :a=>0}, 242=>{:r=>227, :g=>19, :b=>0, :a=>255}, 243=>{:r=>227, :g=>19, :b=>0, :a=>193}, 244=>{:r=>227, :g=>19, :b=>0, :a=>255}, 245=>{:r=>0, :g=>0, :b=>0, :a=>0}, 246=>{:r=>227, :g=>19, :b=>0, :a=>255}, 247=>{:r=>0, :g=>0, :b=>0, :a=>0}, 248=>{:r=>0, :g=>0, :b=>0, :a=>0}, 249=>{:r=>0, :g=>0, :b=>0, :a=>0}, 250=>{:r=>227, :g=>19, :b=>0, :a=>197}, 251=>{:r=>0, :g=>0, :b=>0, :a=>0}, 252=>{:r=>227, :g=>19, :b=>0, :a=>165}, 253=>{:r=>0, :g=>0, :b=>0, :a=>0}, 254=>{:r=>227, :g=>19, :b=>0, :a=>137}, 255=>{:r=>0, :g=>0, :b=>0, :a=>0}, 256=>{:r=>227, :g=>19, :b=>0, :a=>255}, 257=>{:r=>0, :g=>0, :b=>0, :a=>0}, 258=>{:r=>228, :g=>19, :b=>0, :a=>50}, 259=>{:r=>0, :g=>0, :b=>0, :a=>0}, 260=>{:r=>0, :g=>0, :b=>0, :a=>0}, 261=>{:r=>0, :g=>0, :b=>0, :a=>0}, 262=>{:r=>0, :g=>0, :b=>0, :a=>0}, 263=>{:r=>0, :g=>0, :b=>0, :a=>0}, 264=>{:r=>0, :g=>0, :b=>0, :a=>0}, 265=>{:r=>0, :g=>0, :b=>0, :a=>0}, 266=>{:r=>0, :g=>0, :b=>0, :a=>0}, 267=>{:r=>0, :g=>0, :b=>0, :a=>0}, 268=>{:r=>227, :g=>19, :b=>0, :a=>197}, 269=>{:r=>0, :g=>0, :b=>0, :a=>0}, 270=>{:r=>0, :g=>0, :b=>0, :a=>0}, 271=>{:r=>0, :g=>0, :b=>0, :a=>0}, 272=>{:r=>0, :g=>0, :b=>0, :a=>0}, 273=>{:r=>0, :g=>0, :b=>0, :a=>0}, 274=>{:r=>0, :g=>0, :b=>0, :a=>0}, 275=>{:r=>0, :g=>0, :b=>0, :a=>0}, 276=>{:r=>0, :g=>0, :b=>0, :a=>0}}