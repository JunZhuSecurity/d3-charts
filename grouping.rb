
require 'csv'

NAME=1
MEMORY=2
NUMCPU=3
VMAPP=4

vms = CSV.read("data/vms.csv")[1..-1]

#vms = vms.select{|vm| vm[NAME] =~ /\w+\d\d\d$/}

vms = vms.map{|vm|vm[NAME]}
         .group_by{|vm| vm[/\w(\w*)\w\d\d\d$/, 1]}.to_a
         .sort_by{|group| -group[1].length}
         .select{|vm| vm[0] && vm[1].any?{|n| n =~ /^L/i } && vm[1].size > 1}

vms.each do |vm|
  puts "L#{vm[0]} #{vm[1].size}"
end
#puts vms[0][NAME]
#puts vms[0][NAME][/.(\w*)\d\d\d$/, 1]