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
$options[:sig] = "none"

begin
  OptionParser.new do |opts|
    opts.banner = "Usage: pack [options]"
    opts.separator "Options:"
    opts.on("-d", "--debug", "Redirect console to SD card slot") { |t| $options[:debug] = "card0" }
    opts.on("-s", "--sig", "Protect image with signature") { |t| $options[:sig] = "sig" }
    opts.on("-p", "--pcb PCB", "Set used sys config pcb") { |t| $options[:pcb] = t }
    opts.on("--variant VAR", "TARGET_BUILD_VARIANT") { |t| $options[:variant] = t }
    opts.on("--platform NAME", "TARGET_BOARD_PLATFORM") { |t| $options[:platform] = t }
    opts.on("--target NAME", "TARGET_DEVICE") { |t| $options[:target] = t }
    opts.on("--top DIR", "build root") { |t| $options[:top] = t }
    opts.on("--action ACTION", ACTIONS, "One of: " << ACTIONS.join(", ")) do |t|
       $options[:action] = t
     end
  end.parse!

    raise "Missing parameters" unless $options[:top] && $options[:target] &&
     $options[:platform] && $options[:variant] && $options[:action]
    raise "One or more parameters are empty" if $options[:top].empty? ||
     $options[:target].empty? || $options[:platform].empty? || $options[:variant].empty?
    raise "Only usable on Allwinners #{$options[:platform]}" unless
	 PLATFORMS.has_key? $options[:platform]

    cpu = PLATFORMS[$options[:platform]]

    PACKAGE_ROOT = "#{$options[:top]}/vendor/softwinner/common/package/"
    TOOLS_ROOT = "#{PACKAGE_ROOT}/pctools/linux/mod_update/"
    DEVICE_ROOT  = "#{$options[:top]}/device/softwinner/#{$options[:target]}/"

    if (!(File.exist?("#{DEVICE_ROOT}configs/sys_config.fex") ||
		   File.exist?("#{DEVICE_ROOT}configs/sys_config@#{$options[:pcb]}.fex")) ||
	    !File.exist?("#{DEVICE_ROOT}configs/sys_partition.fex"))
	  raise "Please put sys_config.fex and sys_partition.fex into configs/ directory of your device tree"
	end
  FileUtils.mkdir("#{PACKAGE_ROOT}out") unless File.exist? ("#{PACKAGE_ROOT}out")

  case $options[:action]
  when :update_uboot
    RELATIVE_OUT = "#{PACKAGE_ROOT[/#{$options[:top]}\/(.*)/,1]}out/"
    sys_config_path = "#{DEVICE_ROOT}configs/sys_config.fex"
    sys_config_path = "#{DEVICE_ROOT}configs/sys_config@#{$options[:pcb]}.fex" if $options.has_key? :pcb
    puts "Building uboot using #{sys_config_path}"

     FileUtils.cp(sys_config_path, "#{PACKAGE_ROOT}out/sys_config.fex")
     # Copy clean u-boot
     # TODO: make fallback to default one
     FileUtils.cp("#{DEVICE_ROOT}configs/u-boot.fex", "#{PACKAGE_ROOT}out/u-boot.fex")

    system "busybox unix2dos #{PACKAGE_ROOT}out/sys_config.fex"
    if system("#{TOOLS_ROOT}script #{RELATIVE_OUT}sys_config.fex")
      puts "Compiled sys_config"
    else
      puts "Failed to compile sys_config"
      exit -1
    end
    if system("#{TOOLS_ROOT}update_uboot #{RELATIVE_OUT}u-boot.fex #{RELATIVE_OUT}sys_config.bin")
      puts "Uboot updated. Grab it here: #{PACKAGE_ROOT}out/u-boot.fex"
    else
      puts "Update uboot failed"
      exit -1
    end
    exit 0
  when :pack
  	# Clean build dir
  	FileUtils.rm_f(Dir.glob("#{PACKAGE_ROOT}out/*"))

  	# Copy basic files
  	FileUtils.cp(Dir.glob("#{PACKAGE_ROOT}chips/#{cpu}/configs/android/default/*.fex"),
  	 "#{PACKAGE_ROOT}out")
  	FileUtils.cp(Dir.glob("#{PACKAGE_ROOT}chips/#{cpu}/configs/android/default/*.cfg"),
  	 "#{PACKAGE_ROOT}out")

    # Override default files
    FileUtils.cp(Dir.glob("#{DEVICE_ROOT}configs/*.fex"), "#{PACKAGE_ROOT}out")
    FileUtils.cp(Dir.glob("#{DEVICE_ROOT}configs/*.cfg"), "#{PACKAGE_ROOT}out")

  	# Override if pcb is set
  	if $options[:pcb]
  	  puts "Using config for pcb #{$options[:pcb]}"
  	  FileUtils.cp("#{DEVICE_ROOT}configs/sys_config@#{$options[:pcb]}.fex",
  	   "#{PACKAGE_ROOT}out/sys_config.fex")
  	  FileUtils.cp("#{DEVICE_ROOT}configs/sys_partition@#{$options[:pcb]}.fex",
  	   "#{PACKAGE_ROOT}out/sys_partition.fex") if File.exist?("#{DEVICE_ROOT}configs/sys_partition@#{$options[:pcb]}.fex")
  	end

  	puts "Packing image..."
  	name = "#{cpu}_android_#{$options[:target]}"
  	name << "_card0" if $options[:debug] == "card0"
  	name << "_sig" if $options[:sig] == "sig"
  	name << "_#{$options[:variant]}"
  	name << "_pcb_#{$options[:pcb]}" if $options[:pcb]
  	name << "-" << Time.now.strftime("%F")
  	name << ".img"

  	cmd = "CRANE_IMAGE_OUT=#{$options[:top]}/out/target/product/#{$options[:target]}" <<
  	 " LICHEE_OUT=#{$options[:top]} ./pack -c #{cpu} -p android -b #{$options[:target]}" <<
  	 " -d #{$options[:debug]} -s #{$options[:sig]} -i #{name}"
  	exec("cd #{PACKAGE_ROOT} && " << cmd)
  end
end
