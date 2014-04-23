
require 'json'
require 'csv'

require_relative 'aggregate_stats'

def get_machines(list)
  list.nil? ? [] : list.split('|')
end

def generate_timeline_json(root)
  days = File.readlines(File.join(root, 'stats/vms/vms.csv')).map{|line| line.strip.split(',')}

  json = {
      start: days.first[VMS_DATE],
      stop: days.last[VMS_DATE],
      vm_count: days.map{|day| day[VMS_VM].to_i},
      vm_added: days.map{|day| get_machines(day[VMS_VM_ADDED])},
      vm_removed: days.map{|day| get_machines(day[VMS_VM_REMOVED])},
      cpu_count: days.map{|day| day[VMS_CPU].to_i},
      ram_count: days.map{|day| day[VMS_RAM].to_i},
      storage: days.map{|day| day[VMS_USED_STORAGE].to_i},
      storage_provisioned: days.map{|day| day[VMS_PROVISIONED_STORAGE].to_i},
      created: Time.now.to_s
  }

  json.to_json
end

if $0 == __FILE__
  json = generate_timeline_json(File.join(__dir__, 'data'))
  puts json
  File.write(File.join(__dir__, 'timeline.json'), json)
end