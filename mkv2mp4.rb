#!/usr/bin/env ruby

def puts(*args)
	printf "\033[31m"
	print(args)
	printf "\033[0m\n"
end

def pv(*args)
	if $options[:verbose]
		printf "\033[32m"
		print args
		printf "\033[0m\n"
	end
end
=begin
module Kernel
dd
	def `(v)
		pv "Runnning: #{v}"
		super(v)
	end
end
=end
## Option parsing

require 'optparse'
$options = {:output => "", :preset=>:iphone}
OptionParser.new do |opts|
  opts.banner = "Usage: mkv2mp4.rb [options] files"
  opts.on("-v", "Verbose output") { |v| $options[:verbose] = v }
  opts.on("-d", "Debug mode") { |d| $options[:debug] = d }
  opts.on("-o output", "Output directory, defaults to .") do |o|
    o += "/" if o[-1] != "/"
    $options[:output] = o  
  end
  opts.on("-p preset", "Preset, defaults to iphone. Choice of iphone, ipod, appletv, universal", [:iphone, :ipod, :appletv, :universal]) do |p|
    $options[:preset] = p
  end
  opts.on_tail("-h", "Show this message") { puts opts; exit }
end.parse!

hb_conversion_preset = {
  :iphone => "iPhone & iPod Touch",
  :ipod => "iPod",
  :appletv => "AppleTV",
  :universal => "Universal" }
$options[:preset] = hb_conversion_preset[$options[:preset]]

$files = ARGV
if $files.count == 0
  puts "You must specify some files."
  exit
end

pv "Called with the following options: #{$options.inspect}"
pv "Processing the following files: #{$files}"

## Executable setup

def find_exec(str)
	res = nil
	if(`which #{str} 2>/dev/null` != "")
		res = str
	elsif
		["./MacOS/", "./"].each do |i|
			j = i+str
			if (`ls #{j} 2>/dev/null` != "")
				res = j
				break
			end
		end
	end

	if res.nil?
		puts "Missing the following executable: #{str}"
		exit
	else
		pv "Found #{str} at #{res}"
		return res
	end
end

$mkvinfo = find_exec "mkvinfo"
$mkvextract = find_exec "mkvextract"
$mp4box = find_exec "MP4Box"
$handbrake = find_exec "HandBrakeCLI"
find_exec "ruby"
find_exec "ass2srt.rb" #Hack to check it's there

## Conversion

def find_tracks(str, regex)
	lines = str.split("\n")
	match = []
	res = []
	lines.count.times do |i|
		match << i if (lines[i] =~ regex)
	end
	for i in match
	  pot2 = lines[0..i].reverse.select {|a| a =~ /Track number:/ }
	  if pot2[0]
		pot3 = pot2[0].match(/Track number: (\d+)/)
		if pot3 and pot3[1]
		  res << pot3[1]
		end
	  end
	end
	return res
end

def find_sub_track(a, regexp_type)
	sub_tracks = find_tracks(a, regexp_type)
	jpn = find_tracks(a, /Language: jpn/)
	eng = find_tracks(a, /Language: eng/)

	inter = sub_tracks&jpn #Choose JPN subs first
	if inter.count != 0
		res = inter.first
	else #If not choose ENG ones
		inter = sub_tracks&eng
		res = inter.first
	end
	return res
end

def convert_file(f)
	base_f = f[0..-5]	

	a = `#{$mkvinfo} #{base_f}.mkv`
	
	mp4box_extra = ""
	handbrake_extra =""
	
	#audio = find_tracks(a, /Language: jpn/).first
	#handbrake_extra += " -a #{audio}" if audio
	handbrake_extra += " -N jpn --native-dub"
	
	srt_sub = find_sub_track(a, /S_TEXT\/UTF8/)
	ass_sub = find_sub_track(a, /S_TEXT\/ASS/) if srt_sub.nil?

	if(srt_sub)
		pv "SRT subs found at track #{srt_sub}. Extracting."
	  `#{$mkvextract} tracks #{base_f}.mkv #{srt_sub}:tmp.srt #{"1>&2" if $options[:verbose]}`
	elsif(ass_sub)
		pv "ASS subs found at track #{ass_sub}. Extracting."
	  `#{$mkvextract} tracks #{base_f}.mkv #{ass_sub}:tmp.ass #{"1>&2" if $options[:verbose]}`
	  
	  `ruby ass2srt.rb tmp.ass > tmp.srt`
	  `rm tmp.ass` if $options[:debug].nil?
	end

	if(srt_sub or ass_sub)
	  `#{$mp4box} -ttxt tmp.srt`
	  `rm tmp.srt` if $options[:debug].nil?
	  #`sed -i "" 's/translation_y="0"/translation_y="250"/' tmp.ttxt` 
	  mp4box_extra += " -add tmp.ttxt:lang=en"
	end

	pv "Running encode."
	#`#{$handbrake} -i #{base_f}.mkv -o tmp.mp4 --preset="#{$options[:preset]}"#{handbrake_extra} #{$options[:verbose] ? "3>&1 1>&2 2>&3" : "2>&1"}`

	pv "Running mux."
	`#{$mp4box} -add tmp.mp4#{mp4box_extra} #{$options[:output] + base_f}.m4v #{"2>&1" if $options[:verbose]}`

	`rm tmp.mp4` if $options[:debug].nil?
	`rm tmp.ttxt` if (srt_sub or ass_sub) and $options[:debug].nil?

	if(srt_sub or ass_sub)
	  `sed -i "" "s/text/sbtl/g" #{$options[:output] + base_f}.m4v` 
	end
end

`mkdir #{$options[:output]} 2>&1`
$files.each do |f|
	#check it exists
	begin
		fp = File.open(f)
	rescue => err
		puts "Cannot open file #{f}: #{err}"
		exit
	end
	
	puts "Converting #{f}"
	convert_file(f)
	puts "Done #{f}"
end
