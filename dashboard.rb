
require 'json'
require 'csv'
require 'FileUtils'

require_relative 'aggregate_stats'

# indices in vms.csv
VM_NAME = 0
VM_CPU = 1
VM_RAM = 2
VM_SPACE = 3
VM_HOST = 4
VM_OS = 5
VM_OWNER = 6

ENVIRONMENTS = {
    :live => /^L/i,
    :kfall => /^L.*K\d\d\d$/i,
    :ref => /^R/i,
    :stable => /^D/i,
    :ci => /^C/i,
    :other => /^[^LRDC]/i
}

def get_vms(folder)
  CSV.read(File.join(folder, 'vms_mappvcv003.csv'), 'r:bom|utf-8')[1..-1] +
  CSV.read(File.join(folder, 'vms_mappvck003.csv'), 'r:bom|utf-8')[1..-1]
end

def select_env_vms(env, vms)
  env_pattern = ENVIRONMENTS[env]
  vms.select{|vm| vm[VM_NAME] =~ env_pattern}
end

def get_cpu(vms)
  {
      used: nil,
      total: vms.reduce(0){|cpu, vm| cpu + vm[VM_CPU].to_i},
      data: []
  }
end

def get_ram(vms)
  {
    used: nil,
    total: vms.reduce(0){|ram, vm| ram + vm[VM_RAM].to_i} / vms.count / 1024
  }
end

def get_env(environments)
  result = []
  %i(live ref stable ci other).select{|key| environments[key]}.each do |key|
    count = cpu = ram = kcount = kcpu = kram = 0
    environments[key].each do |vm|
      if vm[VM_NAME] =~ /^L.*K\d\d\d$/i # KFALL
        kcount += 1
        kcpu += vm[VM_CPU].to_i
        kram += vm[VM_RAM].to_i
      else
        count += 1
        cpu += vm[VM_CPU].to_i
        ram += vm[VM_RAM].to_i
      end
    end
    if count > 0
      cpu = (cpu / count).round(1)
      ram = (ram / count / 1024).round(1)
      if key == :live && kcount > 0
        kcpu = (kcpu / kcount).round(1)
        kram = (kram / kcount / 1024).round(1)
        count = "#{count}-#{environments[:kfall].size}"
        cpu = "#{'%g' % cpu}(#{'%g' % kcpu})" if cpu != kcpu
        ram = "#{'%g' % ram}(#{'%g' % kram})" if ram != kram
      end
      result << [key.to_s.upcase, count, cpu, ram]
    end
  end
  result
end

def calc_stats(folder, vms, start)
  folder = FileUtils.chdir(File.join(__dir__, 'data')) unless folder

  vms.each do |vm|
    stats = get_stats(File.join(folder, 'stats', vm[VM_NAME] + '.csv'), start)

    puts "#{vm[VM_NAME]} #{stats.size}"
  end
end

json = {}
FileUtils.chdir(File.join(__dir__, 'data'))

data = Dir.glob('*').select{|e|File.directory?(e) && e =~ /^\d{4}-\d{2}-\d{2}$/}.sort
data = data.last

# go back 10 days and round to INTERVAL
start = Time.now - 3 * 24 * 60 * 60
start = start - start.to_i % (INTERVAL)
puts start


# read data from both v-centers
vms = get_vms(data)

json[:total] = {
    count: vms.size,
    cpu: vms.reduce(0){|count, vm| count + vm[VM_CPU].to_i},
    ram: vms.reduce(0){|count, vm| count + vm[VM_RAM].to_i} / 1024
}

# cluster vms by naming convention
# a group is detected if there are at least two servers where one is an live server
groups = vms.group_by{|vm| (vm[VM_NAME][/\w(\w*)\w\d\d\d$/, 1] || 'other').upcase}.to_a  # [key, [vm1, vm2, ...]]
            .select{|group| group[0] != 'OTHER' && group[1].any?{|vm| vm[VM_NAME] =~ /^L/i } && group[1].size > 1}

#groups = groups[0..5]


json[:groups] = groups.map do |group, gvms|
  env = {}
  ENVIRONMENTS.keys.each{|key| env[key] = select_env_vms(key, gvms)}
  live = env[:live]

  calc_stats('.', live, start)

  owner = live.group_by{|vm| vm[VM_OWNER]}.to_a.sort_by{|item| -item[1].size}.first[0]
  owner = 'unknown' if owner == ''
  {
      group: group,
      owner: owner,
      name: 'nyi',
      cpu: get_cpu(live),
      ram: get_ram(live),
      disk: {read: 0, write:0},
      net: {read:0, write:0},
      env: get_env(env)
  }
end


json[:groups].sort_by!{|group| -group[:cpu][:total]}
File.write(File.join(__dir__, 'data', 'dashboard.json'), json.to_json)