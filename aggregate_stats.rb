
require 'csv'
require 'fileutils'
require 'time'
require 'set'

ONE_HOUR = 60 * 60
ONE_DAY =  24 * ONE_HOUR
INTERVAL = 0.5 * ONE_HOUR

S_TIME = 0
S_CPU = 1
S_RAM = 2
S_DISK_IN = 3
S_DISK_OUT = 4
S_NET_IN = 5
S_NET_OUT = 6

METRIC = []
METRIC[S_TIME] = nil
METRIC[S_CPU] = 'cpu.usage.average'
METRIC[S_RAM] = 'mem.active.average'
METRIC[S_DISK_IN] = 'disk.read.average'
METRIC[S_DISK_OUT] = 'disk.write.average'
METRIC[S_NET_IN] = 'net.received.average'
METRIC[S_NET_OUT] = 'net.transmitted.average'

# indices in vms_yyy-mm-dd.csv
VM_NAME = 0
VM_CPU = 1
VM_RAM = 2      #GiB
VM_USED_STORAGE = 3  #GiB
VM_HOST = 4
VM_OS = 5
VM_OWNER = 6
VM_PROVISIONED_STORAGE = 7

# VMS History
VMS_DATE = 0
VMS_VM = 1
VMS_CPU = 2
VMS_RAM = 3
VMS_USED_STORAGE = 4
VMS_PROVISIONED_STORAGE = 5
VMS_VM_ADDED = 6
VMS_VM_REMOVED = 7


def aggregate(data, start, interval, agg)
  data = data.select{|item| item[0] >= start}.sort_by{|item| item[0]} # seek and sort
  result = []
  acc = []
  stop = start + interval
  data.each do |item|
    if item[0] < stop
      acc << item[1].to_f
    else
      if acc.size > 0
        result << agg.call(acc) # aggregate average
        acc = []
      else
        result << result.last || 0
      end
      start = stop
      stop = start + interval
      acc << item[1].to_f if item[0] < stop
    end
  end
  if acc.size > 0
    result << agg.call(acc) # aggregate average
  end
  result
end

def aggregate_avg(data, start, interval)
  aggregate(data, start, interval, lambda{|acc| acc.reduce(:+) / acc.size})
end

def aggregate_max(data, start, interval)
  aggregate(data, start, interval, lambda{|acc| acc.max})
end

def aggregate_machine(input)
  puts "Aggregating #{input}"

  stats = Hash.new{|hash, key| hash[key] = []}
  CSV.read(input, 'r:bom|utf-8').drop(1).each do |row|
    stats[row[0]] << [Time.parse(row[1]), row[2].to_f]
  end

  return if stats.size == 0

  output = File.join(File.dirname(input), '../stats', File.basename(input))
  if File.size?(output)
     start = Time.parse(File.readlines(output).last.split(',')[0]) + INTERVAL
  else
    File.write(output, '')
    start = stats.values.first.last[0] + 4 * INTERVAL
  end

  stats.each do |key, data|
    stats[key] = aggregate_avg(data, start, INTERVAL)
  end

  if stats.keys.size > 0
    File.open(output, 'a+') do |file|
      stats.values.first.size.times do |i|
        row = [start]
        METRIC[1..-1].each {|metric| row << (stats[metric][i] || 0)}
        file.puts row.join(',')
        start += INTERVAL
      end
    end
  end

end

def aggregate_all(root)
  FileUtils.mkpath(File.join(root, 'stats')) unless Dir.exists?(File.join(root, 'stats'))
  raw_data_folders(root).each do |folder|
    aggregate_folder(folder)
  end
  aggregate_vms(root)
end

def aggregate_newest(root)
  raw_data_folders(root)[-3..-1].each do |folder|
    aggregate_folder(folder)
  end
  aggregate_vms(root)
end

def aggregate_folder(folder)
  Dir.glob(File.join(folder, 'L*.csv')) do |file|
    aggregate_machine(file)
  end
end

def aggregate_vms(root)
  stats = File.join(root, 'stats/vms')
  vms_csv = File.join(stats, 'vms.csv')
  FileUtils.mkpath(stats) unless Dir.exists?(stats)
  filename = ->(folder) {File.join(stats, "vms_#{File.basename(folder)}.csv")}

  last_folder = File.size?(vms_csv) ? File.join(root, File.readlines(vms_csv).last.split(',')[0]) : nil

  raw_data_folders(root).drop_while{|f| last_folder && f <= last_folder}.each do |folder|
    vms = %w(vms_mappvcv003.csv vms_mappvck003.csv).reduce([]) do |vms, csv|
      vms.concat(CSV.read(File.join(folder, csv), 'r:bom|utf-8').drop(1))
    end
    vms.map do |vm|
      [VM_NAME, VM_OS, VM_OWNER, VM_HOST].each{|c| (vm[c] || '').gsub!(',', ' ')} # escape ','
      vm[VM_NAME].upcase!
      vm[VM_RAM] = '%g' % (vm[VM_RAM].to_f / 1024).round(1)
      vm[VM_USED_STORAGE] = vm[VM_USED_STORAGE].to_f.round(8)
      vm[VM_PROVISIONED_STORAGE] = vm[VM_PROVISIONED_STORAGE].to_f.round(8) if vm[VM_PROVISIONED_STORAGE]
    end
    vms = vms.sort_by {|vm| vm[VM_NAME]}

    File.open(filename.call(folder), 'w') do |file|
      vms.each{|vm| file.puts(vm.join(','))}
    end

    File.open(vms_csv, 'a+') do |file|
      current = vms.map{|vm| vm[VM_NAME]}.to_set
      last = last_folder ? read_vms(filename.call(last_folder)).map{|vm| vm[VM_NAME]}.to_set : current
      puts "#{last_folder}: #{last.size}"
      row = []
      row[VMS_DATE] = File.basename(folder)
      row[VMS_VM] = vms.size
      row[VMS_CPU] = vms.reduce(0){|result, vm| result + vm[VM_CPU].to_i}
      row[VMS_RAM] = vms.reduce(0){|result, vm| result + vm[VM_RAM].to_f}.ceil
      row[VMS_USED_STORAGE] = vms.reduce(0){|result, vm| result + vm[VM_USED_STORAGE].to_f}.ceil
      row[VMS_PROVISIONED_STORAGE] = vms.reduce(0){|result, vm| result + vm[VM_PROVISIONED_STORAGE].to_f}.ceil
      row[VMS_VM_ADDED] = (current - last).to_a.join('|')
      row[VMS_VM_REMOVED] = (last - current).to_a.join('|')
      file.puts(row.join(','))
    end
    last_folder = folder
  end
end

def get_vms(file)
  read_vms(file).each do |vm|
    vm[VM_CPU] = vm[VM_CPU].to_i
    vm[VM_RAM] = vm[VM_RAM].to_f
    vm[VM_USED_STORAGE] = vm[VM_USED_STORAGE].to_f
    vm[VM_PROVISIONED_STORAGE] = vm[VM_PROVISIONED_STORAGE].to_f
  end
end

def read_vms(file)
  return nil unless File.exists?(file)
  File.readlines(file).each.map{|line| line.split(',')}
end

def raw_data_folders(root)
  Dir.glob(File.join(root, '*')).select{|e|File.directory?(e) && e =~ /\/\d{4}-\d{2}-\d{2}$/}.sort
end

def get_stats(file, start)

  #TODO: Perhaps we need normalization if there are missing entries
  # - at the beginning  => can if happen if new machines are created
  # - in the middle  => should not happen because
  # - at the end     => should not happen because of powershell export, but maybe if machines are deleted

  result = []
  if File.exists?(file)
    File.readlines(file).each do |line|
      time = Time.parse(line)
       if time > start
         line = line.split(',')
         line[S_TIME] = time
         #(1..line.size-1).each{|i| line[i] = line[i].to_f}

         line[S_CPU] = line[S_CPU].to_f                   # Percent 0.0 .. 100.0
         line[S_RAM] = line[S_RAM].to_f / (1024 * 1024)   # KiB => GiB
         line[S_DISK_IN] = line[S_DISK_IN].to_f / 1024    # KiBps -> MiB/s
         line[S_DISK_OUT] = line[S_DISK_OUT].to_f / 1024  # KiBPS -> MiB/s
         line[S_NET_IN] = line[S_NET_IN].to_f / 1024      # KiBPS -> MiB/s    # * 1024 * 8 / (1000 * 1000)   #KiB/s -> #MBit/s
         line[S_NET_OUT] = line[S_NET_OUT].to_f / 1024    # KiBPS -> MiB/s    # * 1024 * 8 / (1000 * 1000) #KiB/s -> #MBit/s

         result << line
       end
    end
  end
  result
end

if $0 == __FILE__
  root = File.join(__dir__, 'data')

  aggregate_vms(root)

  #aggregate_vms(File.join(root, '2014-04-07'))

  #aggregate_folder(File.join(root, '2014-04-06'))
  #aggregate_all(root)

end
