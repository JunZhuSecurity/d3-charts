
require 'csv'
require 'FileUtils'
require 'Time'

S_TIME = 0
S_CPU_AVG = 1
S_CPU_MAX = 2
S_RAM_AVG = 3
S_RAM_MAX = 4
S_NET_IN = 5
S_NET_OUT = 6
S_DISK_IN = 7
S_DISK_OUT = 8

METRIC = []
METRIC[S_TIME] = nil
METRIC[S_CPU_AVG] = 'cpu.usage.average'
METRIC[S_CPU_MAX] = 'cpu.usage.maximum'
METRIC[S_RAM_AVG] = 'mem.active.average'
METRIC[S_RAM_MAX] = 'mem.active.maximum'
METRIC[S_NET_IN] = 'net.received.average'
METRIC[S_NET_OUT] = 'net.transmitted.average'
METRIC[S_DISK_IN] = 'disk.read.average'
METRIC[S_DISK_OUT] = 'disk.write.average'

INTERVAL = 30 * 60

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
    start = stats.values.first[0][0]
  end

  stats.each do |key, data|
    if key =~ /maximum/
      stats[key] = aggregate_max(data, start, INTERVAL)
    else
      stats[key] = aggregate_avg(data, start, INTERVAL)
    end
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

def aggregate_folder(folder)
  Dir.glob(File.join(folder, 'L*.csv')) do |file|
    aggregate_machine(file)
  end
end

def aggregate_all(root)
  folders = Dir.glob(File.join(root, '*')).select{|e|File.directory?(e) && e =~ /\d{4}-\d{2}-\d{2}$/}
  folders.sort.each do |folder|
    aggregate_folder(folder)
  end
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

         line[S_CPU_AVG] = line[S_CPU_AVG].to_f
         line[S_CPU_MAX] = line[S_CPU_MAX].to_f
         line[S_RAM_AVG] = line[S_RAM_AVG].to_f / (1024 * 1024)
         line[S_RAM_MAX] = line[S_RAM_MAX].to_f / (1024 * 1024)
         line[S_NET_IN] = line[S_NET_IN].to_f / 1024
         line[S_NET_OUT] = line[S_NET_OUT].to_f / 1024
         line[S_DISK_IN] = line[S_DISK_IN].to_f / 1024
         line[S_DISK_OUT] = line[S_DISK_OUT].to_f / 1024

         result << line
       end
    end
  end
  result
end


if $0 == __FILE__

  root = File.join(__dir__, 'data')
  aggregate_folder(File.join(root, '2014-04-03'))
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
