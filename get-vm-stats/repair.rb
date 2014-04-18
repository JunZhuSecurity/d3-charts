#coding: utf-8

require 'as24_build_tools'

require_relative 'aggregate_stats'
require_relative 'dashboard'
require_relative 'timeline'

data = File.join(__dir__, 'data')
puts 'Aggregate Stats'
aggregate_newest(data)

puts 'Generate timeline.json'
json = generate_timeline_json(data)
File.write(File.join(__dir__, '../apps/d3-charts/timeline.json'), json)

puts 'Generate appgroups.json'
json = generate_dashboard_json(data)
File.write(File.join(__dir__, '../apps/d3-charts/appgroups.json'), json)

puts "Done\n"