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
    opts.on("--platform NAME", "TARGET_BOARD_PLATFORM") { |t| $options[:platform] = t }
    opts.on("--target NAME", "TARGET_DEVICE") { |t| $options[:target] = t }
    opts.on("--top DIR", "build root") { |t| $options[:top] = t }
  end.parse!
  
    raise "Missing parameters" unless $options[:top] && $options[:target] &&
     $options[:platform]
    raise "Only usable on Allwinners #{$options[:platform]} <> fiber" unless 
	 $options[:platform] == "fiber" 
    
    PACKAGE_ROOT = "#{$options[:top]}/vendor/softwinner/common/package/"
    DEVICE_ROOT  = "#{$options[:top]}/device/softwinner/#{$options[:target]}/"
    
    if (!(File.exist?("#{DEVICE_ROOT}configs/sys_config.fex") || 
		   File.exist?("#{DEVICE_ROOT}configs/sys_config@#{$options[:pcb]}.fex")) ||
	    !File.exist?("#{DEVICE_ROOT}configs/sys_partition.fex"))
	  raise "Please put sys_config.fex and sys_partition.fex into configs/ directory of your device tree"
	end
	
	# Clean build dir
	FileUtils.rm_f(Dir.glob("#{PACKAGE_ROOT}out/*"))
	
	# Copy basic files
	FileUtils.cp(Dir.glob("#{PACKAGE_ROOT}chips/sun6i/configs/android/default/*.fex"),
	 "#{PACKAGE_ROOT}out")
	FileUtils.cp(Dir.glob("#{PACKAGE_ROOT}chips/sun6i/configs/android/default/*.cfg"),
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
	
	cmd = "CRANE_IMAGE_OUT=#{$options[:top]}/out/target/product/#{$options[:target]}" <<
	 " LICHEE_OUT=#{$options[:top]} ./pack -c sun6i -p android -b #{$options[:target]}" <<
	 " -d #{$options[:debug]} -s #{$options[:sig]}"
	exec("cd #{$options[:top]}/vendor/softwinner/common/package && " << cmd)
end
