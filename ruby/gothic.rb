load 'pixel_swapper.rb'
load 'output_window.rb'

program_start_time = Time.now

input_base_path = '../input/'
output_base_path = '../output/'

gothic_path = "#{input_base_path}a_gothic.png"
mona_path = "#{input_base_path}a_mona.png"
balls_path = "#{input_base_path}a_balls.png"
river_path = "#{input_base_path}a_river.png"
starry_path = "#{input_base_path}a_starry.png"
scream_path = "#{input_base_path}a_scream.png"

mona_balls = "#{output_base_path}mona_balls.png"

swapper = PixelSwapper.new(gothic_path, mona_path)
window = OuputWindow.new(swapper)
window.show
swapper.output.to_rmagick.write('output/output_001.png')

puts("Conversion complete. Total time: #{Time.now - program_start_time}")
