
require 'fileutils'

FileUtils.chdir(__dir__)
FileUtils.cp('aggregate_stats.rb', 'get-vm-stats')
FileUtils.cp('dashboard.rb', 'get-vm-stats')
FileUtils.cp('timeline.rb', 'get-vm-stats')
FileUtils.cp('app_info.rb', 'get-vm-stats')

target = '//dapptov001/s$/VMWare'
FileUtils.cp('get-vm-stats/collect-data-mappvck003.ps1', target)
FileUtils.cp('get-vm-stats/collect-data-mappvcv003.ps1', target)
FileUtils.cp('get-vm-stats/aggregate_stats.rb', target)
FileUtils.cp('get-vm-stats/timeline.rb', target)
FileUtils.cp('get-vm-stats/dashboard.rb', target)
FileUtils.cp('get-vm-stats/app_info.rb', target)
FileUtils.cp('get-vm-stats/get-vm-stats.rb', target)

target = '//dapptov001/s$/apps/d3-charts'
# FileUtils.cp('appgroups.json', target)
# FileUtils.cp('timeline.json', target)
FileUtils.cp('dashboard.html', target)
FileUtils.cp('dashboard.js', target)
FileUtils.cp('timeline.js', target)
FileUtils.cp('interaction.js', target)
FileUtils.cp('chart.css', target)

