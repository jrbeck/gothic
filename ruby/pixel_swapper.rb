load 'rgb_pixel_buffer.rb'

class PixelSwapper
  attr_accessor :output

  def initialize(color_source_path, image_source_path)
    color_source = Magick::Image.read(color_source_path).first
    image_source = Magick::Image.read(image_source_path).first

    @image_source = RgbPixelBuffer.new(image_source)
    @width = image_source.columns
    @height = image_source.rows

    @output = RgbPixelBuffer.new(color_source, @width, @height)

    @total_swaps = 0
    @total_iterations = 0
  end

  def checkswap_dither(x1, y1, x2, y2, distance = 1)
    max_mult = 1 + (2 * distance)

    source_accum_1 = RgbPixel.new
    source_accum_2 = RgbPixel.new
    output_accum_1 = RgbPixel.new
    output_accum_2 = RgbPixel.new

    (-distance..distance).each do |j|
      v1 = (y1 + j) # % @height
      v2 = (y2 + j) # % @height
      next if v1 < 0 || v1 >= @height || v2 < 0 || v2 >= @height
      (-distance..distance).each do |i|
        next if i == 0 && j == 0
        u1 = (x1 + i) # % @width
        u2 = (x2 + i) # % @width
        next if u1 < 0 || u1 >= @width || u2 < 0 || u2 >= @width

        mult = max_mult - (i.abs + j.abs)

        pixel = @output.get_pixel(u1, v1)
        output_accum_1.add!(pixel.scale!(mult))

        pixel = @image_source.get_pixel(u1, v1)
        source_accum_1.add!(pixel.scale!(mult))

        pixel = @output.get_pixel(u2, v2)
        output_accum_2.add!(pixel.scale!(mult))

        pixel = @image_source.get_pixel(u2, v2)
        source_accum_2.add!(pixel.scale!(mult))
      end
    end

    swap_accum_1 = output_accum_1.clone
    swap_accum_2 = output_accum_2.clone

    pixel_1 = @output.get_pixel(x1, y1).scale!(max_mult)
    pixel_2 = @output.get_pixel(x2, y2).scale!(max_mult)

    output_accum_1.add!(pixel_1)
    output_accum_2.add!(pixel_2)

    swap_accum_1.add!(pixel_2)
    swap_accum_2.add!(pixel_1)

    # swap_accum_1.r += max_mult * (pixel_2.r - pixel_1.r)
    # swap_accum_1.g += max_mult * (pixel_2.g - pixel_1.g)
    # swap_accum_1.b += max_mult * (pixel_2.b - pixel_1.b)

    # swap_accum_2.r += max_mult * (pixel_1.r - pixel_2.r)
    # swap_accum_2.g += max_mult * (pixel_1.g - pixel_2.g)
    # swap_accum_2.b += max_mult * (pixel_1.b - pixel_2.b)

    cur_delta = delta(output_accum_1, source_accum_1) + delta(output_accum_2, source_accum_2);
    new_delta = delta(swap_accum_1, source_accum_1) + delta(swap_accum_2, source_accum_2);

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
    # delta_r = (a.r - b.r)
    # delta_g = (a.g - b.g)
    # delta_b = (a.b - b.b)
    # delta_l = (a.luma - b.luma)
    # (delta_r * delta_r) + (delta_g * delta_g) + (delta_b * delta_b) + (2 * delta_l * delta_l)

    a.update_float_and_luma
    b.update_float_and_luma

    # a_lab = a.to_xyz
    # b_lab = b.to_xyz

    a_lab = a.to_cie_lab
    b_lab = b.to_cie_lab

    delta_l = a_lab[0] - b_lab[0]
    delta_a = a_lab[1] - b_lab[1]
    delta_b = a_lab[2] - b_lab[2]

    4.0 * (delta_l * delta_l) + (delta_a * delta_a) + (delta_b * delta_b)
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

    error
  end

  def checkswap_exact(x1, y1, x2, y2)
    output_pixel_1 = @output.get_pixel(x1, y1)
    output_pixel_2 = @output.get_pixel(x2, y2)

    source_pixel_1 = @image_source.get_pixel(x1, y1)
    source_pixel_2 = @image_source.get_pixel(x2, y2)

    initial_error_1 = get_error(x1, y1, output_pixel_1)
    initial_error_2 = get_error(x2, y2, output_pixel_2)

    swap_error_1 = get_error(x1, y1, output_pixel_2)
    swap_error_2 = get_error(x2, y2, output_pixel_1)

    if (initial_error_1 + initial_error_2) > (swap_error_1 + swap_error_2)
      @output.set_pixel(x1, y1, output_pixel_2)
      @output.set_pixel(x2, y2, output_pixel_1)
      return 1
    end
    0
  end

  def checkswap_single(x1, y1, x2, y2)
    output_pixel_1 = @output.get_pixel(x1, y1)
    output_pixel_2 = @output.get_pixel(x2, y2)

    source_pixel_1 = @image_source.get_pixel(x1, y1)
    source_pixel_2 = @image_source.get_pixel(x2, y2)

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

  def perform(iterations, options = {})
    puts "Beginning processing..."

    update_on = (iterations / 10).to_i
    start_time = output_start_time = Time.now

    swaps = 0
    @total_swaps = 0

    frames = [] if options[:generate_animation]

    work_units = 100000
    iterations.times do |i|
      work_units.times do
        x1 = rand(@width)
        y1 = rand(@height)
        x2 = rand(@width)
        y2 = rand(@height)

        swaps += checkswap_dither(x1, y1, x2, y2)
        # swaps += checkswap_exact(x1, y1, x2, y2)
        # swaps += checkswap_single(x1, y1, x2, y2)
      end

      frames << @output.to_rmagick if options[:generate_animation]

      puts "%#{(100.0 * ((i + 1).to_f / iterations.to_f)).to_i}: #{i + 1} of #{iterations} complete. Swaps: #{swaps} of #{work_units}. Time: #{Time.now - output_start_time}"
      output_start_time = Time.now
      @total_swaps += swaps
      swaps = 0
    end

    puts "IRS complete. Swaps: #{@total_swaps} Time: #{Time.now - start_time}"

    create_animation(frames) if options[:generate_animation]

    @output.to_rmagick.write('test7.png')
  end

  def perform_once(work_units = 1000)
    start_time = Time.now
    swaps = 0

    work_units.times do
      x1 = rand(@width)
      y1 = rand(@height)
      x2 = rand(@width)
      y2 = rand(@height)

      # swaps += checkswap_dither(x1, y1, x2, y2, 1)
      swaps += checkswap_single(x1, y1, x2, y2)
      # swaps += checkswap_exact(x1, y1, x2, y2)
    end

    @total_iterations += work_units
    @total_swaps += swaps
    puts "#{progress_string('swaps', swaps, work_units)}. #{progress_string('total_swaps', @total_swaps, @total_iterations)}, Time: #{Time.now - start_time}"
    output_start_time = Time.now
    swaps = 0
  end

  def progress_string(label, numerator, denominator)
    "#{label}: %#{(100.0 * (numerator.to_f / denominator.to_f)).to_i}: #{numerator} / #{denominator}"
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
    puts "Done creating animation. Time: #{Time.now - start_time}"
  end
end
