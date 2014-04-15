
require 'json'
require 'csv'

require_relative 'aggregate_stats'

def generate_vm_timeline_json(root)
  days = File.readlines(File.join(root, 'stats/vms/vms.csv')).map{|line| line.split(',')}

  json = {
      start: days.first[VMS_DATE],
      stop: days.last[VMS_DATE],
      vm_count: days.map{|day| day[VMS_VM]},
      vm_added: days.map{|day| day[VMS_VM_ADDED]},
      vm_removed: days.map{|day| day[VMS_VM_REMOVED]},
      cpu_count: days.map{|day| day[VMS_CPU]},
      ram_count: days.map{|day| day[VMS_RAM]},
      storage: days.map{|day| day[VMS_STORAGE]},
  }

  json.to_json
end

if $0 == __FILE__
  json = generate_vm_timeline_json(File.join(__dir__, 'data'))
  File.write(File.join(__dir__, 'timeline.json'), json)
end