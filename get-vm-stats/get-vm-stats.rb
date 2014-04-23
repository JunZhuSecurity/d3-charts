#coding: utf-8

require 'as24_build_tools'

require_relative 'aggregate_stats'
require_relative 'dashboard'
require_relative 'timeline'

puts "\nGet-VM-Stats #{Time.now}"

threads = %w(S:\VMWare\collect-data-mappvcv003.ps1 S:\VMWare\collect-data-mappvck003.ps1).map do |script|
  sleep 1
  Thread.new{Run.powershell("invoke-command -scriptblock{#{script}}")}
end
threads.each do |thread|
	result = thread.value
	puts result.command_line
	puts result.output
	puts
end

data = File.join(__dir__, 'data')
kpi = File.join(__dir__, '../apps/d3-charts')

puts 'Aggregate Stats'
aggregate_newest(data)

puts 'Generate timeline.json'
json = generate_timeline_json(data)
File.write(File.join(kpi, 'timeline.json'), json)

puts 'Generate appgroups.json'
json = generate_dashboard_json(data)
File.write(File.join(kpi, 'dashboard.json'), json)

puts 'Export AppOwner.csv'
export_app_info(File.join(kpi, 'AppOwner.csv'))

puts "Done\n"