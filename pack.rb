#!/usr/bin/env ruby
#
# Copyright (C) 2015 Bartosz Jankowski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'optparse'
require 'fileutils'

PLATFORMS = {"fiber" => "sun6i", "polaris" => "sun8iw3p1"}
ACTIONS =  [:pack, :update_uboot]

$options = {}
$options[:debug] = "uart0"
$options[:sig] = false
$options[:variant] = ENV["TARGET_BUILD_VARIANT"]
$options[:top] = ENV["ANDROID_BUILD_TOP"]
$options[:target] = ENV["TARGET_PRODUCT"]
$options[:uboot] = "u-boot.fex"
$options[:logo] = "bootlogo.bmp"

begin
  OptionParser.new do |opts|
    opts.banner = "Usage: pack [options]"
    opts.separator "Options:"
    opts.on("-d", "--debug", "Redirect console to SD card slot") { |t| $options[:debug] = "card0" }
    opts.on("-s", "--sig", "Protect image with signature") { |t| $options[:sig] = true }
    opts.on("-p", "--pcb PCB", "Set used sys config pcb") { |t| $options[:pcb] = t }
    opts.on("-u", "--uboot UBOOT", "Set custom filename for u-boot (from configs dir)") { |t| $options[:uboot] = t }
    opts.on("-l", "--logo LOGO", "Set custom filename for bootlogo (from configs dir)") { |t| $options[:logo] = t }
    opts.on("--platform NAME", "TARGET_BOARD_PLATFORM") { |t| $options[:platform] = t }
    opts.on("--action ACTION", ACTIONS, "One of: " << ACTIONS.join(", ")) do |t|
       $options[:action] = t
     end
  end.parse!

    raise "Android's enviroment is not set, please make a lunch first" unless ENV["OUT"] &&
     $options[:variant] && $options[:top] && $options[:target]
    raise "Missing parameters" unless $options[:platform] && $options[:action]
    raise "Only usable on Allwinners #{$options[:platform]}" unless
     PLATFORMS.has_key? $options[:platform]
    
    CPU = PLATFORMS[$options[:platform]]
    # define path constants
    PACKAGE_ROOT = "#{$options[:top]}/vendor/softwinner/common/package/"                  # /(...)/vendor/softwinner/common/package/
    PLATFORM_ROOT = "#{PACKAGE_ROOT}chips/#{CPU}/"                                        # /(...)/vendor/softwinner/common/package/chips/sun6i/
    TOOLS_ROOT = "#{PACKAGE_ROOT}pctools/linux/mod_update/"                               # /(...)/vendor/softwinner/common/package/pctools/linux/mod_update/
    DEVICE_ROOT  = "#{$options[:top]}/device/softwinner/#{$options[:target]}/"            # /(...)/device/softwinner/shady/
    PACKAGE_OUT = "#{PACKAGE_ROOT}out/"                                                   # /(...)/vendor/softwinner/common/package/out/
    RELATIVE_OUT = "#{PACKAGE_ROOT[/#{$options[:top]}\/(.*)/,1]}out/"                     #  vendor/softwinner/common/package/out/
    ANDROID_OUT =  "#{ENV["OUT"]}/"                                                       # /(...)/out/target/product/shady/"
    
    #puts "PACKAGE_ROOT: #{PACKAGE_ROOT}"
    #puts "PLATFORM_ROOT: #{PLATFORM_ROOT}"
    #puts "TOOLS_ROOT: #{TOOLS_ROOT}"
    #puts "DEVICE_ROOT: #{DEVICE_ROOT}"
    #puts "PACKAGE_OUT: #{PACKAGE_OUT}"
    #puts "RELATIVE_OUT: #{RELATIVE_OUT}"
    #puts "ANDROID_OUT: #{ANDROID_OUT}"
    
    raise "Package core files don't exist!" unless
     File.exist? PACKAGE_ROOT
    raise "Platform files don't exist for #{$options[:platform]}" unless
     File.exist? PLATFORM_ROOT
     
    if (!(File.exist?("#{DEVICE_ROOT}configs/sys_config.fex") ||
		   File.exist?("#{DEVICE_ROOT}configs/sys_config@#{$options[:pcb]}.fex")) ||
	    !File.exist?("#{DEVICE_ROOT}configs/sys_partition.fex"))
	  raise "Please put sys_config.fex and sys_partition.fex into configs/ directory of your device tree"
	end
    
  FileUtils.mkdir(PACKAGE_OUT) unless File.exist? (PACKAGE_OUT)

  case $options[:action]
  when :update_uboot
    sys_config_path = "#{DEVICE_ROOT}configs/sys_config.fex"
    sys_config_path = "#{DEVICE_ROOT}configs/sys_config@#{$options[:pcb]}.fex" if $options.has_key? :pcb
    puts "Building uboot using #{sys_config_path}"

     FileUtils.cp(sys_config_path, "#{PACKAGE_OUT}sys_config.fex")
    
    # Copy clean u-boot
    if File.exist?("#{DEVICE_ROOT}configs/u-boot.fex")
      FileUtils.cp("#{DEVICE_ROOT}configs/u-boot.fex", "#{PACKAGE_OUT}u-boot.fex")
      puts "Overlaying default u-boot"
    else
      FileUtils.cp("#{PLATFORM_ROOT}bin/u-boot-#{CPU}.bin", "#{PACKAGE_OUT}u-boot.fex")
    end
    
    system "busybox unix2dos #{PACKAGE_OUT}sys_config.fex"
    if system("#{TOOLS_ROOT}script #{RELATIVE_OUT}sys_config.fex")
      puts "Compiled sys_config"
    else
      puts "Failed to compile sys_config"
      exit -1
    end
    if system("#{TOOLS_ROOT}update_uboot #{RELATIVE_OUT}u-boot.fex #{RELATIVE_OUT}sys_config.bin")
      puts "Uboot updated. Grab it here: #{PACKAGE_OUT}u-boot.fex"
    else
      puts "Update uboot failed"
      exit -1
    end
    exit 0
  when :pack
  	# Clean build dir
  	FileUtils.rm_f(Dir.glob("#{PACKAGE_OUT}*"))

  	# Copy basic files
  	FileUtils.cp(Dir.glob("#{PLATFORM_ROOT}configs/android/default/*.fex"),
  	 PACKAGE_OUT)
  	FileUtils.cp(Dir.glob("#{PLATFORM_ROOT}configs/android/default/*.cfg"),
  	 PACKAGE_OUT)

    # Override default files
    FileUtils.cp(Dir.glob("#{DEVICE_ROOT}configs/*.fex"), PACKAGE_OUT)
    FileUtils.cp(Dir.glob("#{DEVICE_ROOT}configs/*.cfg"), PACKAGE_OUT)

  	# Override if pcb is set
  	if $options[:pcb]
  	  puts "Using config for pcb #{$options[:pcb]}"
  	  FileUtils.cp("#{DEVICE_ROOT}configs/sys_config@#{$options[:pcb]}.fex",
  	   "#{PACKAGE_OUT}sys_config.fex")
  	  FileUtils.cp("#{DEVICE_ROOT}configs/sys_partition@#{$options[:pcb]}.fex",
  	   "#{PACKAGE_OUT}sys_partition.fex") if File.exist?("#{DEVICE_ROOT}configs/sys_partition@#{$options[:pcb]}.fex")
  	end

    #TODO: sdcard redirect
    #if [ $PACK_DEBUG = card0 ]; then
    #cp $TOOLS_DIR/awk_debug_card0 out/awk_debug_card0
    #TX=`awk  '$0~"a31"{print $2}' pctools/linux/card_debug_pin`
    #RX=`awk  '$0~"a31"{print $3}' pctools/linux/card_debug_pin`
    #MS=`awk  '$0~"a31"{print $4}' pctools/linux/card_debug_pin`
    #CK=`awk  '$0~"a31"{print $5}' pctools/linux/card_debug_pin`
    #DO=`awk  '$0~"a31"{print $6}' pctools/linux/card_debug_pin`
    #DI=`awk  '$0~"a31"{print $7}' pctools/linux/card_debug_pin`

    #sed -i s'/jtag_ms = /jtag_ms = '$MS'/g' out/awk_debug_card0
    #sed -i s'/jtag_ck = /jtag_ck = '$CK'/g' out/awk_debug_card0
    #sed -i s'/jtag_do = /jtag_do = '$DO'/g' out/awk_debug_card0
    #sed -i s'/jtag_di = /jtag_di = '$DI'/g' out/awk_debug_card0
    #sed -i s'/uart_debug_tx =/uart_debug_tx = '$TX'/g' out/awk_debug_card0
    #sed -i s'/uart_debug_rx =/uart_debug_rx = '$RX'/g' out/awk_debug_card0
    #sed -i s'/uart_tx =/uart_tx = '$TX'/g' out/awk_debug_card0
    #sed -i s'/uart_rx =/uart_rx = '$RX'/g' out/awk_debug_card0
    #awk -f out/awk_debug_card0 out/sys_config.fex > out/a.fex
    #rm out/sys_config.fex
    #mv out/a.fex out/sys_config.fex
    #echo "uart -> card0 !!!"
    #fi

  	puts "Packing image..."
    
    FileUtils.cp_r(["#{PLATFORM_ROOT}tools/split_xxxx.fex", "#{PLATFORM_ROOT}boot-resource/boot-resource",
     "#{PLATFORM_ROOT}boot-resource/boot-resource.ini"], PACKAGE_OUT)

    FileUtils.cp("#{DEVICE_ROOT}configs/#{$options[:logo]}", "#{PACKAGE_OUT}boot-resource/bootlogo.bmp") &&
     puts("Overlaying default bootlogo") if File.exist?("#{DEVICE_ROOT}configs/#{$options[:logo]}")
    
    if File.exist?("#{DEVICE_ROOT}configs/#{$options[:uboot]}")
      FileUtils.cp("#{DEVICE_ROOT}configs/#{$options[:uboot]}", "#{PACKAGE_OUT}u-boot.fex")
      puts "Overlaying default u-boot"
    else
      FileUtils.cp("#{PLATFORM_ROOT}bin/u-boot-#{CPU}.bin", "#{PACKAGE_OUT}u-boot.fex")
    end
     
    FileUtils.cp(["#{PLATFORM_ROOT}tools/usbtool.fex", "#{PLATFORM_ROOT}tools/cardtool.fex",
     "#{PLATFORM_ROOT}tools/cardscript.fex", "#{PLATFORM_ROOT}tools/aultls32.fex", 
     "#{PLATFORM_ROOT}tools/aultools.fex"], PACKAGE_OUT)
     
     FileUtils.cp("#{PLATFORM_ROOT}bin/boot0_nand_#{CPU}.bin", "#{PACKAGE_OUT}boot0_nand.fex")
     FileUtils.cp("#{PLATFORM_ROOT}bin/boot0_sdcard_#{CPU}.bin", "#{PACKAGE_OUT}boot0_sdcard.fex")
     FileUtils.cp("#{PLATFORM_ROOT}bin/fes1_#{CPU}.bin", "#{PACKAGE_OUT}fes1.fex")
    
    # update out file name
    
    image_conf = File.read("#{PACKAGE_OUT}image.cfg").encode("UTF-8", 'binary', invalid: :replace, undef: :replace, replace: '')
    image_name = "#{CPU}_android_#{$options[:target]}"
  	image_name << "_card0" if $options[:debug] == "card0"
  	image_name << "_sig" if $options[:sig] == "sig"
  	image_name << "_#{$options[:variant]}"
  	image_name << "_pcb_#{$options[:pcb]}" if $options[:pcb]
  	image_name << "-" << Time.now.strftime("%F")
  	image_name << ".img"
    image_conf.gsub!(/(?<=^imagename = )(.+)$/, image_name)
    File.open("#{PACKAGE_OUT}image.cfg", "w") { |f| f << image_conf }
    
    system "busybox unix2dos #{PACKAGE_OUT}sys_config.fex"
    system "busybox unix2dos #{PACKAGE_OUT}sys_partition.fex"
    system "busybox unix2dos #{PACKAGE_OUT}boot-resource.ini"
        
    if system("#{TOOLS_ROOT}script #{RELATIVE_OUT}sys_config.fex")
      puts "Compiled sys_config"
    else
      raise "Failed to compile sys_config"
    end
    
    if system("#{TOOLS_ROOT}script #{RELATIVE_OUT}sys_partition.fex")
      puts "Compiled sys_partition"
    else
      raise "Failed to compile sys_partition"
    end
    
    FileUtils.cp("#{PACKAGE_OUT}sys_config.bin", "#{PACKAGE_OUT}config.fex")
    system("#{TOOLS_ROOT}update_boot0 #{RELATIVE_OUT}boot0_nand.fex #{RELATIVE_OUT}sys_config.bin NAND")
    system("#{TOOLS_ROOT}update_boot0 #{RELATIVE_OUT}boot0_sdcard.fex #{RELATIVE_OUT}sys_config.bin SDMMC_CARD")

    raise "Update uboot failed" unless system("#{TOOLS_ROOT}update_uboot #{RELATIVE_OUT}u-boot.fex #{RELATIVE_OUT}sys_config.bin")
    raise "Update fes1 failed" unless system("#{TOOLS_ROOT}update_fes1 #{RELATIVE_OUT}fes1.fex #{RELATIVE_OUT}sys_config.bin")
    raise "Update mbr failed" unless system("#{TOOLS_ROOT}update_mbr #{RELATIVE_OUT}sys_partition.bin 4")
    FileUtils.mv("sunxi_mbr.fex", PACKAGE_OUT)
    FileUtils.mv("dlinfo.fex", PACKAGE_OUT)
    
    # setup boot resource
    bootres_ini = File.read("#{PACKAGE_OUT}boot-resource.ini").encode("UTF-8", 'binary', invalid: :replace, undef: :replace, replace: '')
    bootres_ini.gsub!(/(?<=^fsname=)(.+)$/, "#{PACKAGE_OUT}boot-resource.fex")
    bootres_ini.gsub!(/(?<=^root0=)(.+)$/, "#{PACKAGE_OUT}boot-resource")
    File.open("#{PACKAGE_OUT}boot-resource.ini", "w") { |f| f << bootres_ini }
    
    
    # get bootloader.fex
    raise "Failed to build bootloader fs" unless system("#{TOOLS_ROOT}../fsbuild200/fsbuild #{RELATIVE_OUT}boot-resource.ini #{RELATIVE_OUT}split_xxxx.fex")
    FileUtils.mv("#{PACKAGE_OUT}boot-resource.fex", "#{PACKAGE_OUT}bootloader.fex")

    # get env.fex
    system("#{TOOLS_ROOT}u_boot_env_gen #{RELATIVE_OUT}env.cfg #{RELATIVE_OUT}env.fex")
    
    FileUtils.ln_s("#{ANDROID_OUT}boot.img", "#{PACKAGE_OUT}boot.fex")
    FileUtils.ln_s("#{ANDROID_OUT}system.img", "#{PACKAGE_OUT}system.fex")
    FileUtils.ln_s("#{ANDROID_OUT}recovery.img","#{PACKAGE_OUT}recovery.fex")
    
    if $options[:sig]
      puts "Adding signature..."
      system("#{TOOLS_ROOT}signature #{RELATIVE_OUT}sunxi_mbr.fex #{RELATIVE_OUT}dlinfo.fex")
    end
   puts "Building image..."
   raise "Failed to build image" unless system("cd #{PACKAGE_OUT} && #{TOOLS_ROOT}../eDragonEx/dragon image.cfg sys_partition.fex && cd -")
   FileUtils.mv("#{PACKAGE_OUT}#{image_name}", "#{$options[:top]}/")
   puts "Image is ready. Grab it here: #{$options[:top]}/#{image_name}"
  end
end
