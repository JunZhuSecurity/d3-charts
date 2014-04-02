
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
  vms = %w(vms_mappvcv003.csv vms_mappvck003.csv).reduce([]) do |vms, csv|
    vms.concat CSV.read(File.join(folder, csv), 'r:bom|utf-8')[1..-1]
  end
  vms.map do |vm|
    vm[VM_NAME].upcase!
    vm[VM_CPU] = vm[VM_CPU].to_i
    vm[VM_RAM] = vm[VM_RAM].to_f / 1024
    vm[VM_SPACE] = vm[VM_SPACE].to_f
  end
  vms
end

def select_env_vms(env, vms)
  env_pattern = ENVIRONMENTS[env]
  vms.select{|vm| vm[VM_NAME] =~ env_pattern}
end

def get_cpu(vms, stats)
  {
      used: stats.cpu_peak_usage,
      total: vms.reduce(0){|cpu, vm| cpu + vm[VM_CPU]},
      data: stats.cpu_data
  }
end

def get_ram(vms, stats)
  {
    used: stats.ram_peak_usage,
    total: (vms.reduce(0){|ram, vm| ram + vm[VM_RAM]} / vms.count).round(1)
  }
end

def get_env(environments)
  result = []
  %i(live ref stable ci other).select{|key| environments[key]}.each do |key|
    count = cpu = ram = kcount = kcpu = kram = 0
    environments[key].each do |vm|
      if vm[VM_NAME] =~ /^L.*K\d\d\d$/i # KFALL
        kcount += 1
        kcpu += vm[VM_CPU]
        kram += vm[VM_RAM]
      else
        count += 1
        cpu += vm[VM_CPU]
        ram += vm[VM_RAM]
      end
    end
    if count > 0
      cpu = (cpu / count).round(1)
      ram = (ram / count).round(1)
      if key == :live && kcount > 0
        kcpu = (kcpu / kcount).round(1)
        kram = (kram / kcount).round(1)
        count = "#{count}+#{kcount}"
        cpu = "#{'%g' % cpu}(#{'%g' % kcpu})" if cpu != kcpu
        ram = "#{'%g' % ram}(#{'%g' % kram})" if ram != kram
      end
      result << [key.to_s.upcase, count, cpu, ram]
    end
  end
  result
end

class GroupStats

  def initialize(folder, vms, start)
    folder = FileUtils.chdir(File.join(__dir__, 'data')) unless folder

    @stats = []
    vms.each do |vm|
      vm_stats = get_stats(File.join(folder, 'stats', vm[VM_NAME] + '.csv'), start)
      S_CPU_AVG.upto(S_DISK_OUT){|s| @stats[s] = Array.new(vm_stats.size, 0)} unless @stats.size > 0
      vm_stats.each_with_index do |item, i|
        if i < @stats[1].size  # Hack in case different stats counts
          @stats[S_CPU_AVG][i] += item[S_CPU_AVG] * vm[VM_CPU] / 100
          @stats[S_CPU_MAX][i] += item[S_CPU_MAX] * vm[VM_CPU] / 100
          @stats[S_RAM_AVG][i] = item[S_RAM_AVG] if item[S_RAM_AVG] > @stats[S_RAM_AVG][i]
          @stats[S_RAM_MAX][i] = item[S_RAM_MAX] if item[S_RAM_MAX] > @stats[S_RAM_MAX][i]
          S_NET_IN.upto(S_DISK_OUT){|s| @stats[s][i] += item[s]}
        end
      end
    end
    #@stats[S_RAM_AVG].each_index{|i| @stats[S_RAM_AVG][i] /= vms.size}
  end

  def cpu_data
    @stats[S_CPU_AVG].map{|v| v.round(2)}
  end

  def cpu_peak_usage
    peak_usage(S_CPU_AVG, 1)
  end

  def ram_peak_usage
    peak_usage(S_RAM_AVG, 1)
  end

  def disk_read_peak_usage
    peak_usage(S_DISK_IN, 1)
  end

  def disk_write_peak_usage
    peak_usage(S_DISK_OUT, 1)
  end

 def net_read_peak_usage
    peak_usage(S_NET_IN, 1)
  end

  def net_write_peak_usage
    peak_usage(S_NET_OUT, 1)
  end

  def peak_usage(type, round = 1)
    #puts @stats.inspect  if  @stats[S_CPU_AVG].max.nil?
    (@stats[type].max || 0).round(round).to_s
  end

end

def release
  FileUtils.chdir(__dir__)
  target = '//dapptov001/s$/apps/d3-charts'

  FileUtils.cp('dashboard.json', target)
  FileUtils.cp('dashboard.html', target)
  FileUtils.cp('dashboard.js', target)
  FileUtils.cp('chart.css', target)
  FileUtils.cp('styling.html', target)
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
#vms = vms.select{|vm| vm[VM_NAME] =~ /LELAVM/i}

json[:total] = {
    count: vms.size,
    cpu: vms.reduce(0){|count, vm| count + vm[VM_CPU]},
    ram: vms.reduce(0){|count, vm| count + vm[VM_RAM]}
}
json[:start] = start
json[:interval] = INTERVAL

# cluster vms by naming convention
# a group is detected if there are at least two servers where one is an live server
groups = vms.group_by{|vm| (vm[VM_NAME][/\w(\w*)\w\d\d\d$/, 1] || 'other').upcase}.to_a  # [key, [vm1, vm2, ...]]
            .select{|group| group[0] != 'OTHER' && group[1].any?{|vm| vm[VM_NAME] =~ /^L/i } && group[1].size > 1}

#groups = groups[0..15]


json[:groups] = groups.map do |group, gvms|
  env = {}
  ENVIRONMENTS.keys.each{|key| env[key] = select_env_vms(key, gvms)}
  live = env[:live]

  stats = GroupStats.new('.', live, start)

  owner = live.group_by{|vm| vm[VM_OWNER]}.to_a.sort_by{|item| -item[1].size}.first[0]
  owner = 'unknown' if owner == ''
  {
      group: group + ' ' + live.size.to_s,
      owner: owner,
      name: 'nyi',
      cpu: get_cpu(live, stats),
      ram: get_ram(live, stats),
      disk: {read: stats.disk_read_peak_usage, write: stats.disk_write_peak_usage},
      net: {read: stats.net_read_peak_usage, write: stats.net_write_peak_usage},
      env: get_env(env)
  }
end
json[:stop] = start + json[:groups].first[:cpu][:data].size * INTERVAL

json[:groups].sort_by!{|group| -group[:cpu][:total]}
File.write(File.join(__dir__, 'dashboard.json'), json.to_json)

release()