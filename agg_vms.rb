
require 'csv'
require 'time'

# indices in vms.csv
VM_NAME = 0
VM_CPU = 1
VM_RAM = 2      #GiB
VM_STORAGE = 3  #GiB
VM_HOST = 4
VM_OS = 5
VM_OWNER = 6


if $0 == __FILE__

  vms = %w(vms_mappvcv003.csv vms_mappvck003.csv).reduce([]) do |vms, csv|
      vms.concat CSV.read(File.join(folder, csv), 'r:bom|utf-8').drop(1)
    end
    vms.map do |vm|
      vm[VM_NAME].upcase!
      vm[VM_CPU] = vm[VM_CPU].to_i
      vm[VM_RAM] = vm[VM_RAM].to_f / 1024
      vm[VM_STORAGE] = vm[VM_STORAGE].to_f
    end
    vms




end