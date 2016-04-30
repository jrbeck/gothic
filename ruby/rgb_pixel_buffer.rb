require 'rmagick'
load 'rgb_pixel.rb'

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
