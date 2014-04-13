
require 'csv'
require 'fileutils'
require 'time'
require 'set'

INTERVAL = 30 * 60

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
VM_STORAGE = 3  #GiB
VM_HOST = 4
VM_OS = 5
VM_OWNER = 6

# VMS History
VMS_DATE = 0
VMS_VM = 1
VMS_CPU = 2
VMS_RAM = 3
VMS_STORAGE = 4
VMS_VM_ADDED = 5
VMS_VM_REMOVED = 6

# Source Format
# key1, TimeStamp, value
# key2, Timestamp, value
# key1, Timestamp, value

# Target Format
# Timestamp,value1,value2,value3

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
  FileUtils.mkpath(File.join(root, 'stats/vms')) unless Dir.exists?(File.join(root, 'stats/vms'))
  folders = Dir.glob(File.join(root, '*')).select{|e|File.directory?(e) && e =~ /\/\d{4}-\d{2}-\d{2}$/}
  folders.sort.each do |folder|
    aggregate_folder(folder)
  end
end

def aggregate_newest(root)
  folders = Dir.glob(File.join(root, '*')).select{|e|File.directory?(e) && e =~ /\/\d{4}-\d{2}-\d{2}$/}
  folders.sort[-2..-1].each do |folder|
    aggregate_folder(folder)
  end
end

def aggregate_folder(folder)
  Dir.glob(File.join(folder, 'L*.csv')) do |file|
    aggregate_machine(file)
  end


end

def aggregate_vms(folder)
  vms = %w(vms_mappvcv003.csv vms_mappvck003.csv).reduce([]) do |vms, csv|
    vms.concat(CSV.read(File.join(folder, csv), 'r:bom|utf-8').drop(1))
  end
  vms.map do |vm|
    [VM_NAME, VM_OS, VM_OWNER ,VM_HOST].each{|c| (vm[c] || '').gsub!(',', ' ')} # escape ','
    vm[VM_NAME].upcase!
    vm[VM_RAM] = '%g' % (vm[VM_RAM].to_f / 1024).round(1)
    vm[VM_STORAGE] = vm[VM_STORAGE].to_f.round(8)
  end
  vms = vms.sort_by {|vm| vm[VM_NAME]}

  stats = File.join(File.dirname(folder), 'stats/vms')
  filename = ->(date) {File.join(stats, "vms_#{date}.csv")}

  File.open(filename.call(File.basename(folder)), 'w') do |file|
    vms.each{|vm| file.puts(vm.join(','))}
  end

  File.open(File.join(stats, 'vms.csv'), 'a+') do |file|
    row = []
    row[VMS_DATE] = File.basename(folder)
    row[VMS_VM] = vms.size
    row[VMS_CPU] = vms.reduce(0){|result, vm| result + vm[VM_CPU].to_i}
    row[VMS_RAM] = vms.reduce(0){|result, vm| result + vm[VM_RAM].to_f}
    row[VMS_STORAGE] = vms.reduce(0){|result, vm| result + vm[VM_STORAGE].to_f}

    current = vms.map{|vm| vm[VM_NAME]}.to_set
    last = (read_vms(filename.call((Time.parse(folder) - 24 * 60 * 60).strftime('%Y-%m-%d'))) || vms).map{|vm| vm[VM_NAME]}.to_set

    row[VMS_VM_ADDED] = (current - last - current).size
    row[VMS_VM_REMOVED] =  (last - current).size

    file.puts(row.join(','))
  end
end

def read_vms(file)
  return nil unless File.exists?(file)
  File.readlines(file).each.map{|line| line.split(',')}
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
         line[S_NET_IN] = line[S_NET_IN].to_f / 1024      # KiBPS -> MiB/s
         line[S_NET_OUT] = line[S_NET_OUT].to_f / 1024

         result << line
       end
    end
  end
  result
end


if $0 == __FILE__

  root = File.join(__dir__, 'data')

  aggregate_vms(File.join(root, '2014-04-07'))

  #aggregate_folder(File.join(root, '2014-04-06'))
  #aggregate_all(root)

  #start = Time.now - 1 * 24 * 60 * 60
  #start = start - start.to_i % (INTERVAL)
  #puts get_stats(File.join(root, 'stats/LELAVMV004.csv'), start).inspect


#start = Time.parse('2014-03-31 08:00:00') + 3600
#puts start
#
#stats = Hash.new{|hash, key| hash[key] = []}
#input = File.join(__dir__, 'data', '2014-04-01', 'LADMADK001' + '.csv')
#CSV.read(input, 'r:bom|utf-8').drop(1).each do |row|
#  stats[row[0]] << [Time.parse(row[1]), row[2].to_f]
#end
#
#data = stats[METRIC[1]].sort_by{|item| item[0]}.select{|item| item[0] >= start}
#puts data.take(8).inspect
#puts aggregate_avg(stats[METRIC[1]], start, INTERVAL).take(4).inspect
#

end
