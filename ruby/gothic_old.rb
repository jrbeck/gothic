require "rmagick"

class RgbPixel

  attr_accessor :r, :g, :b
  attr_accessor :r_float, :b_float, :g_float
  attr_accessor :luma

  def initialize(options = {})
    if options[:rmagick_pixel]
      rmagick_pixel = options[:rmagick_pixel]
      self.r = rmagick_pixel.red & 255
      self.g = rmagick_pixel.green & 255
      self.b = rmagick_pixel.blue & 255
    elsif options[:rgb]
      rgb = options[:rgb]
      self.r = rgb[0]
      self.g = rgb[1]
      self.b = rgb[2]
    else
      self.r = 0
      self.g = 0
      self.b = 0
    end

    update_float_and_luma
  end

  def update_float_and_luma
    self.r_float = self.r.to_f / 255.0
    self.g_float = self.g.to_f / 255.0
    self.b_float = self.b.to_f / 255.0

    self.luma = (0.30 * self.r_float) + (0.59 * self.g_float) + (0.11 * self.b_float)
  end

  def to_rmagick
    Magick::Pixel.new((self.r << 8) | self.r, (self.g << 8) | self.g, (self.b << 8) | self.b)
  end

  def self.distance(a, b)
    delta_r = (a.r_float - b.r_float).abs #** 2.0
    delta_g = (a.g_float - b.g_float).abs #** 2.0
    delta_b = (a.b_float - b.b_float).abs #** 2.0

    # (2.0 * Math.sqrt(delta_r + delta_g + delta_b)) + (a.luma - b.luma).abs
    # Math.sqrt(delta_r + delta_g + delta_b)
    delta_r + delta_g + delta_b
  end

  def scale!(scalar)
    self.r *= scalar
    self.g *= scalar
    self.b *= scalar
    update_float_and_luma
    self
  end

  def add!(other)
    self.r += other.r
    self.g += other.g
    self.b += other.b
    update_float_and_luma
  end

  def copy(other)
    self.r = other.r
    self.g = other.g
    self.b = other.b
    update_float_and_luma
  end

end

def find_within_range(pixels, target, target_range)
  num_pixels = pixels.length
  return nil if num_pixels == 0

  best_range = RgbPixel.distance(target, pixels[0])
  return pixels.shift if best_range <= target_range
  best_index = 0

  (1...num_pixels).each do |index|
    range = RgbPixel.distance(target, pixels[index])
    if range <= target_range
      pixels[0], pixels[index] = pixels[index], pixels[0]
      return pixels.shift
    end

    if range < best_range
      best_range = range
      best_index = index
    end
  end

  pixels[0], pixels[best_index] = pixels[best_index], pixels[0]
  pixels.shift
end


def create_ouput_from_existing(existing)
  width = existing.columns
  height = existing.rows

  output = Magick::Image.new(width, height)

  (0...height).each do |y|
    (0...width).each do |x|
      output.pixel_color(x, y, existing.pixel_color(x, y))
    end
  end

  output
end


def naive_conversion(color_source, image_source, target_distance = 0.5)
  raw_pixels = []
  (0...color_source.rows).each do |y|
    (0...color_source.columns).each do |x|
      raw_pixels << RgbPixel.new(rmagick_pixel: color_source.pixel_color(x, y))
    end
  end

  width = image_source.columns
  height = image_source.rows

  output = Magick::Image.new(width, height)

  puts "Starting: (#{width}, #{height})"
  start_time = Time.now

  (0...height).each do |y|
    row_start_time = Time.now
    (0...width).each do |x|
      pixel = find_within_range(raw_pixels, RgbPixel.new(rmagick_pixel: image_source.pixel_color(x, y)), target_distance)
      output.pixel_color(x, y, pixel.to_rmagick)
    end
    puts "Row: #{y} of #{height} complete, pixels remaining #{raw_pixels.length}, time spent: #{Time.now - row_start_time}"
  end

  puts "Complete"
  puts "Total time: #{Time.now - start_time}"

  output
end

def naive_shuffled_conversion(color_source, image_source, target_distance = 0.5)
  raw_pixels = []
  (0...color_source.rows).each do |y|
    (0...color_source.columns).each do |x|
      raw_pixels << RgbPixel.new(rmagick_pixel: color_source.pixel_color(x, y))
    end
  end

  width = image_source.columns
  height = image_source.rows

  output = Magick::Image.new(width, height)

  coords = []
  (0...height).each do |y|
    (0...width).each do |x|
      coords << [x, y]
    end
  end
  coords.shuffle!

  puts "Starting: (#{width}, #{height})"
  start_time = Time.now
  counter_start_time = Time.now

  counter = 1

  coords.each do |coord|
    x, y = coord[0], coord[1]
    pixel = find_within_range(raw_pixels, RgbPixel.new(rmagick_pixel: image_source.pixel_color(x, y)), target_distance)
    output.pixel_color(x, y, pixel.to_rmagick)

    if counter % 1000 == 0
      puts "#{counter} complete, pixels remaining #{raw_pixels.length}, time spent: #{Time.now - counter_start_time}"
      counter_start_time = Time.now
    end
    counter += 1
  end

  puts "Complete"
  puts "Total time: #{Time.now - start_time}"

  output
end

def neighbor_swap(x, y, output, image_source)
  distance = 2

  output_subject = RgbPixel.new(rmagick_pixel: output.pixel_color(x, y))
  destination_subject = RgbPixel.new(rmagick_pixel: image_source.pixel_color(x, y))

  min_error = 2 * RgbPixel.distance(output_subject, destination_subject)
  min_x = x
  min_y = y

  width = output.columns
  height = output.rows

  (-distance..distance).each do |j|
    row = []
    (-distance..distance).each do |i|
      other_x = (x + i) % width
      other_y = (y + j) % height

      output_other = RgbPixel.new(rmagick_pixel: output.pixel_color(other_x, other_y))
      destination_other = RgbPixel.new(rmagick_pixel: image_source.pixel_color(other_x, other_y))

      error_from_subject = RgbPixel.distance(output_other, destination_subject)
      error_from_source = RgbPixel.distance(output_subject, destination_other)

      if error_from_subject + error_from_source < min_error
        min_error = error_from_subject + error_from_source
        min_x = other_x
        min_y = other_y
      end
    end
  end

  swap_occurred = false

  if min_x != x && min_y != y
    source = output.pixel_color(x, y)
    other = output.pixel_color(min_x, min_y)

    output.pixel_color(x, y, other)
    output.pixel_color(min_x, min_y, source)

    swap_occurred = true
  end

  swap_occurred
end

def reduce_error(output, image_source)
  puts "Reducing error: begin"

  width = output.columns
  height = output.rows

  start_time = Time.now

  num_swaps = 0

  (0...height).each do |y|
    row_start_time = Time.now
    (0...width).each do |x|
      swap_occurred = neighbor_swap(x, y, output, image_source)
      num_swaps += 1 if swap_occurred
    end
    puts "Row: #{y} of #{height} complete, time spent: #{Time.now - row_start_time}, swaps: #{num_swaps}"
  end

  puts "Reduce error done. Total time: #{Time.now - start_time}, total swaps: #{num_swaps}"

  output
end

class RgbPixelBuffer

  attr_accessor :width, :height

  def initialize(source, width = nil, height = nil)
    build_pixel_buffer(source, width, height)
  end

  def build_pixel_buffer(source, width = nil, height = nil)
    source_width = source.columns
    source_height = source.rows
    self.width = width || source_width
    self.height = height || source_height
    @buffer = []
    source_height.times do |y|
      source_width.times do |x|
        @buffer << RgbPixel.new(rmagick_pixel: source.pixel_color(x, y))
      end
    end
  end

  def get_pixel(x, y)
    @buffer[x + (y * self.width)].clone
  end

  def set_pixel(x, y, pixel)
    @buffer[x + (y * self.width)].copy(pixel)
  end

  def to_rmagick
    Magick::Image.new(self.width, self.height).tap do |output|
      (0...self.height).each do |y|
        (0...self.width).each do |x|
          output.pixel_color(x, y, @buffer[x + (y * self.width)].to_rmagick)
        end
      end
    end
  end

end


class IterativeRandomSwapper

  def initialize(color_source, image_source)
    @image_source = RgbPixelBuffer.new(image_source)
    @width = image_source.columns
    @height = image_source.rows

    @output = RgbPixelBuffer.new(color_source, @width, @height)
  end

  def get_error(x, y, pixel)
    distance = 1
    max_mult = 1 + (2 * distance)

    error = 0
    count = 0
    (-distance..distance).each do |j|
      v = (y + j) % @height
      # next if v < 0 || v >= @height
      (-distance..distance).each do |i|
        u = (x + i) % @width
        # next if u < 0 || u >= @width

        mult = (max_mult - (i.abs + j.abs)).to_f

        source_other = @image_source.get_pixel(u, v)
        if u == x && v == y
          error += mult * RgbPixel.distance(pixel, source_other)
        else
          output_other = @output.get_pixel(u, v)
          error += mult * RgbPixel.distance(output_other, source_other)
        end

        count += mult
      end
    end

    # error / count

    error
  end

  def checkswap_dither(x1, y1, x2, y2)
    distance = 1
    max_mult = 1 + (2 * distance)

    s_accum_1 = RgbPixel.new
    s_accum_2 = RgbPixel.new
    o_accum_1 = RgbPixel.new
    o_accum_2 = RgbPixel.new

    error = 0
    swap_error = 0

    (-distance..distance).each do |j|
      v1 = (y1 + j) % @height
      v2 = (y2 + j) % @height
      (-distance..distance).each do |i|
        next if i == 0 && j == 0
        u1 = (x1 + i) % @width
        u2 = (x2 + i) % @width

        mult = max_mult - (i.abs + j.abs)

        pixel = @output.get_pixel(u1, v1)
        o_accum_1.add!(pixel.scale!(mult))

        pixel = @image_source.get_pixel(u1, v1)
        s_accum_1.add!(pixel.scale!(mult))

        pixel = @output.get_pixel(u2, v2)
        o_accum_2.add!(pixel.scale!(mult))

        pixel = @image_source.get_pixel(u2, v2)
        s_accum_2.add!(pixel.scale!(mult))
      end
    end

    meh_1 = o_accum_1.clone
    meh_2 = o_accum_2.clone

    pixel_1 = @output.get_pixel(x1, y1).scale!(max_mult)
    pixel_2 = @output.get_pixel(x2, y2).scale!(max_mult)

    # meh_1.r += max_mult * (pixel_2.r - pixel_1.r)
    # meh_1.g += max_mult * (pixel_2.g - pixel_1.g)
    # meh_1.b += max_mult * (pixel_2.b - pixel_1.b)

    # meh_2.r += max_mult * (pixel_1.r - pixel_2.r)
    # meh_2.g += max_mult * (pixel_1.g - pixel_2.g)
    # meh_2.b += max_mult * (pixel_1.b - pixel_2.b)

    o_accum_1.add!(pixel_1)
    o_accum_2.add!(pixel_2)

    meh_1.add!(pixel_2)
    meh_2.add!(pixel_1)

    # cur_delta = delta(o_accum_1, s_accum_1) + delta(o_accum_2, s_accum_2);
    # new_delta = delta(meh_1, s_accum_1) + delta(meh_2, s_accum_2);

    cur_delta = delta(o_accum_1, s_accum_1) + delta(o_accum_2, s_accum_2);
    new_delta = delta(meh_1, s_accum_1) + delta(meh_2, s_accum_2);

    if new_delta < cur_delta
      source_pixel = @output.get_pixel(x1, y1)
      dest_pixel = @output.get_pixel(x2, y2)
      @output.set_pixel(x1, y1, dest_pixel)
      @output.set_pixel(x2, y2, source_pixel)
      return 1
    end
    return 0
  end

  def delta(a, b)
    delta_r = (a.r - b.r)
    delta_g = (a.g - b.g)
    delta_b = (a.b - b.b)
    (delta_r * delta_r) + (delta_g * delta_g) + (delta_b * delta_b)
  end

  def checkswap_exact(x1, y1, x2, y2)
    output_pixel_1 = @output.get_pixel(x1, y1)
    output_pixel_2 = @output.get_pixel(x2, y2)

    source_pixel_1 = @image_source.get_pixel(x1, y1)
    source_pixel_2 = @image_source.get_pixel(x2, y2)

    # initial_error_1 = get_error(x1, y1, output_pixel_1)
    # initial_error_2 = get_error(x2, y2, output_pixel_2)

    # swap_error_1 = get_error(x1, y1, output_pixel_2)
    # swap_error_2 = get_error(x2, y2, output_pixel_1)

    initial_error_1 = RgbPixel.distance(output_pixel_1, source_pixel_1)
    initial_error_2 = RgbPixel.distance(output_pixel_2, source_pixel_2)

    swap_error_1 = RgbPixel.distance(output_pixel_2, source_pixel_1)
    swap_error_2 = RgbPixel.distance(output_pixel_1, source_pixel_2)

    if (initial_error_1 + initial_error_2) > (swap_error_1 + swap_error_2)
      @output.set_pixel(x1, y1, output_pixel_2)
      @output.set_pixel(x2, y2, output_pixel_1)
      return 1
    end
    0
  end

  def perform(iterations)
    puts "Beginning processing..."

    update_on = (iterations / 10).to_i
    start_time = output_start_time = Time.now

    swaps = 0
    total_swaps = 0

    frames = []

    work_unit = 10000
    iterations.times do |i|
      work_unit.times do
        x1 = rand(@width)
        y1 = rand(@height)
        x2 = rand(@width)
        y2 = rand(@height)

        swaps += checkswap_dither(x1, y1, x2, y2)
        swaps += checkswap_exact(x1, y1, x2, y2)
      end

      frames << @output.to_rmagick

      puts "%#{(100.0 * ((i + 1).to_f / iterations.to_f)).to_i}: #{i + 1} of #{iterations} complete. Swaps: #{swaps} of #{work_unit}. Time: #{Time.now - output_start_time}"
      output_start_time = Time.now
      total_swaps += swaps
      swaps = 0
    end

    create_animation(frames)

    puts "IRS complete. Swaps: #{total_swaps} Time: #{Time.now - start_time}"

    @output.to_rmagick
  end

  def create_animation(frames)
    puts "Creating animation. Total frames: #{frames.length}"
    start_time = Time.now
    names = []
    frames.each_with_index do |frame, i|
      names << name = "temp_frame_#{i}.gif"
      frame.write(name)
    end

    animation = Magick::ImageList.new(*names)
    animation.write('anim.gif')

    names.each do |name|
      File.delete(name)
    end
    puts "Done creating animation.Time: #{Time.now - start_time}"
  end

end




# actual program ----------------------------------------------------------------------------------------

program_start_time = Time.now

gothic_path = 'input/a_gothic.png'
mona_path = 'input/a_mona.png'
balls_path = 'input/a_balls.png'
river_path = 'input/a_river.png'
starry_path = 'input/a_starry.png'
scream_path = 'input/a_scream.png'

mona_balls = 'output/mona_balls.png'


color_source = Magick::Image.read(balls_path).first
image_source = Magick::Image.read(mona_path).first

# output = create_ouput_from_existing(Magick::Image.read(gothic_path).first)
# output = naive_conversion(color_source, image_source, 0.5)
# output = naive_shuffled_conversion(color_source, image_source, 0.1)

# dither_passes = 5
# dither_passes.times do |i|
#   puts "Reducing error. Pass: #{i + 1} of #{dither_passes}"
#   output = reduce_error(output, image_source)
# end

output = IterativeRandomSwapper.new(color_source, image_source).perform(500)

output.write('output/test001.png')

puts("Conversion complete. Total time: #{Time.now - program_start_time}")
