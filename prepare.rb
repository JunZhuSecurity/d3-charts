require 'csv'
require 'json'

TIME = 0
CPU = 26 # data[0].find_index('CPU') #note that the TCP header was forgotten
RAM = 27

result = []

(1..6).each do |i|
  data = CSV.read("monitoring/lcdnscv00#{i}.csv").drop(1)
  data.each_index do |row|
    if data[row][CPU]
      if i == 1
        result[row] = [data[row][TIME], [], [] ]
      end
      result[row][1] << data[row][CPU].to_f
      result[row][2] << data[row][RAM].to_f
    end
  end
end
(1..3).each do |i|
  data = CSV.read("monitoring/lcdnsck00#{i}.csv").drop(1)
  data.each_index do |row|
    if data[row][CPU]
      result[row][1] << data[row][CPU].to_f
      result[row][2] << data[row][RAM].to_f
    end
  end
end

result = result.reduce([]){|memo, row| row.nil? ? memo : (memo << row)}

cpu_per_vm = 2
json = {}

json[:time] = result.map{|row| row[0].sub(/ \+0100$/, '')}
json[:cpu] = result.map{|row| row[1].reduce(0){|memo, cpu| memo + cpu_per_vm * (cpu ? cpu : 0) / 100}.round(2)}
json[:ram] = result.map{|row| (row[2].reduce(0){|memo, ram| memo + ram} / row[2].length).round(2)}

File.write('data/timeline.json', json.to_json)

puts json.to_json

