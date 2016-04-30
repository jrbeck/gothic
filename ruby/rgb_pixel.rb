require 'rmagick'


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

  def pivot_rgb(value)
    if value > 0.04045
      ((value + 0.055) / 1.055) ** 2.4
    else
      value / 12.92
    end
  end

  def pivot_xyz(value)
    # epsilon = 0.008856  # 216 / 24389
    # kappa = 903.3       # 24389 / 27
    if value > 0.008856
      value ** (1.0 / 3.0)
    else
      # (7.787 * value) + (16.0 / 116.0)
      (903.3 * value + 16) / 116.0
    end
  end

  def to_xyz
    p_r = pivot_rgb(self.r_float) * 100.0
    p_g = pivot_rgb(self.g_float) * 100.0
    p_b = pivot_rgb(self.b_float) * 100.0

    # Observer = 2deg, Illuminant = D65
    x = p_r * 0.4124 + p_g * 0.3576 + p_b * 0.1805
    y = p_r * 0.2126 + p_g * 0.7152 + p_b * 0.0722
    z = p_r * 0.0193 + p_g * 0.1192 + p_b * 0.9505

    [x, y, z]
  end

  def to_cie_lab
    xyz = to_xyz

    p_x = pivot_xyz(xyz[0] / 95.047)  # ref_X =  95.047
    p_y = pivot_xyz(xyz[1] / 100.000) # ref_Y = 100.000
    p_z = pivot_xyz(xyz[2] / 108.883) # ref_Z = 108.883

    l = (116.0 * p_y) - 16.0
    a = 500.0 * (p_x - p_y)
    b = 200.0 * (p_y - p_z)

    [l, a, b]
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
