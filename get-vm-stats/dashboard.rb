
require 'json'
require 'csv'

require_relative 'aggregate_stats'
require_relative 'app_info'

ENVIRONMENTS = {
    :live => /^L.*[^K]\d\d\d$/i,
    :kfall => /^L.*K\d\d\d$/i,
    :ref => /^R/i,
    :stable => /^D/i,
    :ci => /^C/i,
    :other => /^[^LRDC]/i
}

def get_short_os(os)
  case os
    when /windows server 2012/i    then 'Win2012'
    when /windows server 2008 r2/i then 'Win2008R2'
    when /windows server 2008/i    then 'Win2008'
    when /windows server 2003/i    then 'Win2003'
    when /windows 8/i              then 'Windows 8'
    when /windows 7/i              then 'Windows 7'
    when /windows xp/i             then 'Windows XP'
    when /red hat .* linux 6/i     then 'RHE Linux 6'
    when /red hat .* linux 5/i     then 'RHE Linux 5'
    when /ubuntu/i                 then 'Ubuntu Linux'
    when /centos/i                 then 'CentOS'
    when /linux/i                  then 'Linux'

    else 'Other'
  end
end

def get_vms(date)
  read_vms("stats/vms/vms_#{date}.csv").each do |vm|
    vm[VM_CPU] = vm[VM_CPU].to_i
    vm[VM_RAM] = vm[VM_RAM].to_f
    vm[VM_STORAGE] = vm[VM_STORAGE].to_f
  end
end

def select_env_vms(env, vms)
  env_pattern = ENVIRONMENTS[env]
  vms.select{|vm| vm[VM_NAME] =~ env_pattern}
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
    {read: peak_usage(S_DISK_IN),
     wrote: peak_usage(S_DISK_OUT),
     data_read: data(S_DISK_IN),
     data_wrote: data(S_DISK_OUT)}
  end

  def net
    {received: peak_usage(S_NET_IN),
     sent: peak_usage(S_NET_OUT),
     data_received: data(S_NET_IN),
     data_sent: data(S_NET_OUT)}
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

  last = Dir.glob('*').select{|e|File.directory?(e) && e =~ /^\d{4}-\d{2}-\d{2}$/}.sort.last
  vms = get_vms(last)

  #oses = vms.map{|vm| vm[VM_OS] || "other"}.group_by{|os| os.downcase}.map{|k,v|[k, v.size]}.sort_by{|item| -item[1]}
  #puts oses.inspect

  # go back 7 days and round to INTERVAL
  start = Time.now - (7 * 24 * 60 * 60 + 6 * 60 * 60)
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

    stats = GroupStats.new('.', live + env[:kfall], start)

    owner = get_app_info(group)[:owner]
    owner = live.group_by{|vm| vm[VM_OWNER]}.to_a.sort_by{|item| item[1].size}.last[0] if owner == ''
    owner = 'unknown owner' if owner == ''

    os = live.group_by{|vm| vm[VM_OS]}.to_a.sort_by{|item| item[1].size}.last[0]

    {
        group: group,
        alias: get_app_info(group)[:alias],
        owner: owner,

        total: gvms.size,
        storage: gvms.reduce(0){|m, vm| m + vm[VM_STORAGE]}.round(0),
        os: [os, get_short_os(os)],

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