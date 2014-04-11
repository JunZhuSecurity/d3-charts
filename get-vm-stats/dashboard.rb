
require 'json'
require 'csv'

require_relative 'aggregate_stats'
require_relative 'app_info'

# indices in vms.csv
VM_NAME = 0
VM_CPU = 1
VM_RAM = 2      #GiB
VM_STORAGE = 3  #GiB
VM_HOST = 4
VM_OS = 5
VM_OWNER = 6

ENVIRONMENTS = {
    :live => /^L.*[^K]\d\d\d$/i,
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
    vm[VM_STORAGE] = vm[VM_STORAGE].to_f
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
  %i(live kfall ref stable ci other).select{|key| environments[key]}.each do |key|
    count = cpu = ram = 0
    environments[key].each do |vm|
      count += 1
      cpu += vm[VM_CPU]
      ram += vm[VM_RAM]
    end
    if count > 0
      cpu = (cpu / count).round(1)
      ram = (ram / count).round(1)
      result << [key.to_s.upcase, count, cpu, ram]
    end
  end
  result
end

class GroupStats

  # total peak
  # vm peak
  # timeline

  def initialize(folder, vms, start)
    @vm_count = vms.size
    @stats = []
    @cpu_total    = @ram_total = 0
    @cpu_vm_total = @ram_vm_total = 0
    @cpu_vm_used  = @ram_vm_used = 0
    vms.each do |vm|
      @cpu_total += vm[VM_CPU]
      @ram_total += vm[VM_RAM]
      vm_stats = get_stats(File.join(folder, 'stats', vm[VM_NAME] + '.csv'), start)
      S_CPU.upto(METRIC.size - 1){|s| @stats[s] = Array.new(vm_stats.size, 0)} unless @stats.size > 0
      vm_stats.each_with_index do |item, i|
        if i < @stats[1].size  # Hack in case stats count differs

          used = item[S_CPU] * vm[VM_CPU] / 100
          @stats[S_CPU][i] += used
          if used > @cpu_vm_used
            @cpu_vm_used = used
            @cpu_vm_total = vm[VM_CPU]
          end

          used = item[S_RAM]
          @stats[S_RAM][i] += used
          if used > @ram_vm_used
            @ram_vm_used = used
            @ram_vm_total = vm[VM_RAM]
          end

          S_DISK_IN.upto(S_NET_OUT){|s| @stats[s][i] += item[s]}
        end
      end
    end
  end

  def cpu
    used_total(S_CPU, @cpu_total, @cpu_vm_used, @cpu_vm_total)
  end

  def ram
    used_total(S_RAM, @ram_total, @ram_vm_used, @ram_vm_total)
  end

  def used_total(type, total, vm_used, vm_total)
    {
        used: peak_usage(type),
        total: total,
        vm: {
            used:  vm_used.round(1),
            total: vm_total
        },
        data: data(type)
    }
  end

  def disk
    io(S_DISK_IN)
  end

  def net
    io(S_NET_IN)
  end

  def io(type)
    {
      in: peak_usage(type),
      out: peak_usage(type + 1),
      data_in: data(type),
      data_out: data(type + 1)
    }
  end

  def data(type)
    @stats[type].map{|v| v.round(2)}
  end

  def peak_usage(type, round = 1)
    #puts @stats.inspect  if  @stats[S_CPU_AVG].max.nil?
    (@stats[type].max || 0).round(round)
  end

end

def generate_dashboard_json(root)
  FileUtils.chdir(root)

  json = {}

  data = Dir.glob('*').select{|e|File.directory?(e) && e =~ /^\d{4}-\d{2}-\d{2}$/}
  data = data.sort.last
  vms = get_vms(data) # get latest vms

  oses = vms.map{|vm| vm[VM_OS] || "other"}.group_by{|os| os.downcase}.map{|k,v|[k, v.size]}.sort_by{|item| -item[1]}
  puts oses.inspect

  # go back 7 days and round to INTERVAL
  start = Time.now - 6 * 24 * 60 * 60  - 6 * 60 * 60
  start = start - start.to_i % (INTERVAL)

  json[:total] = {
      count: vms.size,
      cpu: vms.reduce(0){|count, vm| count + vm[VM_CPU]},
      ram: vms.reduce(0){|count, vm| count + vm[VM_RAM]}.round(0),
      storage: vms.reduce(0){|count, vm| count + vm[VM_STORAGE]}.round(0)
  }
  json[:start] = start
  json[:interval] = INTERVAL

  # cluster vms by naming convention
  # a group is detected if there are at least two servers where one is an live server
  groups = vms.group_by{|vm| (vm[VM_NAME][/\w(\w*)\w\d\d\d$/, 1] || 'other').upcase}.to_a  # [key, [vm1, vm2, ...]]
              .select{|group| group[0] != 'OTHER' && group[1].any?{|vm| vm[VM_NAME] =~ ENVIRONMENTS[:live] } && group[1].size > 2}

  json[:groups] = groups.map do |group, gvms|

    env = {}
    ENVIRONMENTS.keys.each{|key| env[key] = select_env_vms(key, gvms)}
    live = env[:live]

    stats = GroupStats.new('.', live, start)

    owner = get_app_info(group)[:owner]
    owner = live.group_by{|vm| vm[VM_OWNER]}.to_a.sort_by{|item| item[1].size}.last[0] if owner == ''
    owner = 'unknown' if owner == ''

    os = live.group_by{|vm| vm[VM_OS]}.to_a.sort_by{|item| item[1].size}.last[0]

    {
        group: group,
        alias: get_app_info(group)[:alias],
        owner: owner,

        total: gvms.size,
        storage: gvms.reduce(0){|m, vm| m + vm[VM_STORAGE]}.round(0),
        os: os,

        cpu: stats.cpu,
        ram: stats.ram,
        disk: stats.disk,
        net: stats.net,
        env: get_env(env)
    }
  end

  json[:groups].sort_by!{|group| -group[:cpu][:total]}
  json[:stop] = start + json[:groups].first[:cpu][:data].size * INTERVAL

  json.to_json
end

if $0 == __FILE__
  json = generate_dashboard_json(File.join(__dir__, 'data'))
  File.write(File.join(__dir__, 'dashboard.json'), json)

  require_relative 'release'
end