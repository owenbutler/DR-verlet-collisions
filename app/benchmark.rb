require "xenobrain/ruby_vectormath/vectormath_2d.rb"

$size = 60

r = $size / 2.0
quick_check = (r + r) * (r + r)

object_to_check = {
  position: Vec2.new(100, 100)
}
potential_collision = {
  position: Vec2.new(120, 120)
}

input_array = [100, 100, 120, 120]
output_array = [100, 100, 120, 120]


puts "running benchmark"
result = $gtk.benchmark iterations: 1000000,
using_vec2d_in_hash: -> () {

  outer_position = object_to_check[:position]
  inner_position = potential_collision[:position]

  # if dy > $size
    # collision_index += 1
    # next
  # end

  diff = outer_position - inner_position
  d2 = diff.length_sq
  # d2 = diff.x * diff.x + diff.y * diff.y
  if d2 < quick_check

    distance = Math::sqrt(d2)

    delta = ($size - distance) * 0.5
    half_distance = diff.div_scalar!(distance).mul_scalar!(delta)
    # half_distance = n.mul_scalar(delta)
    updated_outer_position = outer_position.add(half_distance)
    updated_inner_position = inner_position.sub(half_distance)
  end

},
using_vals_still_in_vecs: -> () {

  outer_position = object_to_check[:position]
  ox = outer_position.x
  oy = outer_position.y
  inner_position = potential_collision[:position]
  ix = inner_position.x
  iy = inner_position.y

  dx = ox - ix
  dy = oy - iy
  d2 = dx * dx + dy * dy
  if d2 < quick_check

    distance = Math::sqrt(d2)

    delta = ($size - distance) * 0.5
    hx = (dx / distance) * delta
    hy = (dy / distance) * delta

    updated_outer_position = Vec2.new(ox + hx, oy + hy)
    updated_inner_position = Vec2.new(ix - hx, iy - hy)
  end

},
using_vals_from_arrays: -> () {

  ox = input_array[0]
  oy = input_array[1]
  ix = input_array[2]
  iy = input_array[3]

  dx = ox - ix
  dy = oy - iy
  d2 = dx * dx + dy * dy
  if d2 < quick_check

    distance = Math::sqrt(d2)

    delta = ($size - distance) * 0.5
    hx = (dx / distance) * delta
    hy = (dy / distance) * delta

    output_array[0] = ox + hx
    output_array[1] = oy + hy
    output_array[2] = ix - hx
    output_array[3] = iy - hy
  end

},
using_vals_from_arrays_dot_at: -> () {

  ox = input_array.at(0)
  oy = input_array.at(1)
  ix = input_array.at(2)
  iy = input_array.at(3)

  dx = ox - ix
  dy = oy - iy
  d2 = dx * dx + dy * dy
  if d2 < quick_check

    distance = Math::sqrt(d2)

    delta = ($size - distance) * 0.5
    hx = (dx / distance) * delta
    hy = (dy / distance) * delta

    output_array[0] = ox + hx
    output_array[1] = oy + hy
    output_array[2] = ix - hx
    output_array[3] = iy - hy
  end

}

$gtk.console.toggle