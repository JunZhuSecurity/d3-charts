
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
      elsif result.size > 0
        result << result.last
      else
        raise 'Not data found'
      end
      start = stop
      stop = start + interval
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

def aggregate_machine(date, machine)
  root = File.join(__dir__, 'data')
  stats = Hash.new{|hash, key| hash[key] = []}

  output = File.join(root, 'stats', machine + '.csv')
  if File.size?(output)
     #File.readlines(output).last.split(',')[0]
  else
    File.write(output, '')
  end

  input = File.join(root, date, machine + '.csv')
  CSV.read(input, 'r:bom|utf-8').drop(1).each do |row|
    stats[row[0]] << [Time.parse(row[1]), row[2].to_f]
  end

  stats.each do |item|
    item[1] = aggregate_avg(item[1], start, INTERVAL)
    puts item.size
  end

  #if stats.keys.size > 0
  #  File.open(output, 'a+') do |file|
  #    file.puts
  #  end
  #end

end

aggregate_machine('2014-04-01', 'LADMADK001')

#start = Time.parse('2014-03-31 08:00:00') + 3600
#puts start
#data = stats[METRIC[S_DISK_IN]].sort_by{|item| item[0]}.select{|item| item[0] >= start}
#puts data.take(8).inspect
#puts aggregate_avg(stats[METRIC[S_DISK_IN]], start, INTERVAL).take(4).inspect

