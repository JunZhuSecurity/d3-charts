
require 'csv'

NAME=0

vms = CSV.read('data/2014-04-07/vms_mappvcv003.csv', 'r:bom|utf-8')[1..-1]

#vms = vms.select{|vm| vm[NAME] =~ /\w+\d\d\d$/}

vms = vms.map{|vm|vm[NAME].downcase}
         .group_by{|vm| vm[/\w(\w*)\w\d\d\d$/, 1]}.to_a
         .sort_by{|group| -group[1].length}
         .select{|vm| vm[0] && vm[1].any?{|n| n =~ /^L/i } && vm[1].size > 1}

vms.map{|vm| vm[0]}.sort.each do |vm|
  puts "#{vm}: {owner: '', alias: ''},"
end
