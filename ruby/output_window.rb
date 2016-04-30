require 'gosu'

include Gosu

class OuputWindow < Gosu::Window
  def initialize(swapper)
    @swapper = swapper
    output = swapper.output
    super(output.width, output.height, false, 100.0)
    @ready_to_draw = false
  end

  def needs_cursor?
    true
  end

  def needs_redraw?
    @ready_to_draw
  end

  def draw
    frame = @swapper.output.to_rmagick
    image = Gosu::Image.new(self, frame, false)
    image.draw(0, 0, 0)

    @ready_to_draw = false
  end

  def update
    @swapper.perform_once(10_000)
    @ready_to_draw = true
  end
end
