#coding: utf-8

require 'as24_build_tools'

require_relative 'aggregate_stats'
require_relative 'dashboard'

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
puts 'Aggregate Stats'
aggregate_newest(data)
puts 'Generate dashboard.json'
json = generate_dashboard_json(data)
File.write(File.join(__dir__, '../apps/d3-charts/dashboard.json'), json)

puts "Done\n"