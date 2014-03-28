#coding: utf-8

require 'as24_build_tools'

puts "Get-VM-Stats #{Time.now}"

threads = %w(S:\VMWare\collect-data-mappvcv003.ps1 S:\VMWare\collect-data-mappvck003.ps1).map do |script|
	Thread.new{Run.powershell("invoke-command -scriptblock{#{script}}")}
end
threads.each do |thread|
	result = thread.value
	puts result.command_line
	puts result.output
	puts
end

