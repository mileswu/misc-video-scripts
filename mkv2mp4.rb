#!/usr/bin/env ruby
require (File.dirname(__FILE__) + "/ass2srt")
require 'optparse'

def puts(*args)
	if $log
		$log.puts(args)
		return
	end

	if $platform == :unix
		printf "\033[31m" 
		print(args)
		printf "\033[0m\n"
	else
		super(args)
	end
end

def pv(*args)
	if $options[:verbose]
		if $log
			$log.puts(args)
			return
		end
	
		if $platform == :unix
			printf "\033[32m" 
			print args
			printf "\033[0m\n"
		else
			puts args
		end
	end
end

def run(v)
	pv "Runnning: #{v}"
	unless $gui
		`#{v}`
	else
		io = IO.popen(v)
		#stdin, io, stderr = Open3::popen3(v)
		$pid = io.pid
		buffer = ""
		begin
			while(i = io.read(100))
				buffer << i
				pos = buffer.scan(/\d*.\d* %/)
				if pos and pos[-1]
				  prog = pos[-1][0..-2].to_i
				  $progress.set_value(prog) if $progress and $running
				end
				
				if $log and $running
					$log.print i
				elsif $options[:verbose]
					print i
				end
			end
		rescue EOFError
		end
		$pid = nil
	end
end

class Array
	def count
		length
	end
end

## Option parsing

$options = {:output => "", :preset=>:iphone}
if __FILE__ == $0
	OptionParser.new do |opts|
	  opts.banner = "Usage: mkv2mp4.rb [options] files"
	  opts.on("-v", "Verbose output") { |v| $options[:verbose] = v }
	  opts.on("-d", "Debug mode") { |d| $options[:debug] = d; $options[:verbose] = d }
	  opts.on("-o output", "Output directory, defaults to .") do |o|
		o += "/" if o[-1] != "/" if $platform == :unix
		o += "\\" if o[-1] != "\\" if $platform == :win
		$options[:output] = o  
	  end
	  opts.on("-q quality", "Quality 0.0->1.0") { |q| $options[:quality] = q }
	  opts.on("-p preset", "Preset, defaults to iphone. Choice of iphone, ipod, appletv, universal", [:iphone, :ipod, :appletv, :universal]) do |p|
		$options[:preset] = p
	  end
	  opts.on_tail("-h", "Show this message") { puts opts; exit }
	end.parse!

	$files = ARGV
	if $files.count == 0
	  puts "You must specify some files."
	  exit
	end
	
	pv "Called with the following options: #{$options.inspect}"
	pv "Processing the following files: #{$files}"
end
hb_conversion_preset = {
  :iphone => "iPhone & iPod Touch",
  :ipod => "iPod",
  :appletv => "AppleTV",
 :universal => "Universal" }
$options[:preset] = hb_conversion_preset[$options[:preset]]

## Executable setup / Environment
def find_exec(str)
	res = nil
	if(`which #{str} 2> /dev/null` != "")
		res = str
	elsif
		["./MacOS/", "./"].each do |i|
			j = i+str
			if (`ls #{j} 2> /dev/null` != "")
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
if RUBY_PLATFORM =~ /win32/
  $platform = :win
  
  base = File.dirname(__FILE__) + "\\"
  base += "src\\" if(__FILE__ =~ /exe/)
  
  $mkvinfo = base + "mkvinfo"
  $mkvextract = base + "mkvextract"
  $mp4box = base + "MP4Box"
  $handbrake = base + "HandBrakeCLI"
  $rm = "del"
  $mkdir = "mkdir"
  $sed = base + "sed -b"
  $null = "NUL"
else
  $platform = :unix
  
  $mkvinfo = find_exec "mkvinfo"
  $mkvextract = find_exec "mkvextract"
  $mp4box = find_exec "MP4Box"
  $handbrake = find_exec "HandBrakeCLI"
  $rm = "rm"
  $mkdir = "mkdir"
  $sed = "sed"
  $null = "/dev/null"
end

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
		return res
	end
		
	inter = sub_tracks&eng
	if inter.count != 0 #If not choose ENG ones
		res = inter.first
		return res
	else
		retun sub_tracks.first
	end
end

def convert_file(f)
	base_f = f[0..-5]	

	a = `#{$mkvinfo} "#{base_f}.mkv"`
	
	mp4box_extra = ""
	handbrake_extra =""
	
	#audio = find_tracks(a, /Language: jpn/).first
	#handbrake_extra += " -a #{audio}" if audio
	handbrake_extra += " -N jpn --native-dub"
	
	srt_sub = find_sub_track(a, /S_TEXT\/UTF8/)
	ass_sub = find_sub_track(a, /S_TEXT\/ASS/) if srt_sub.nil?
	
	##{"> #{$null}" unless $options[:verbose]}
	mkvextract_extra = ""
	mkvextract_extra += " 1>&2" if $gui.nil? and $options[:verbose]
	if(srt_sub)
		pv "SRT subs found at track #{srt_sub}. Extracting."
	  run("#{$mkvextract} tracks \"#{base_f}.mkv\" #{srt_sub}:tmp_orig.srt #{mkvextract_extra}")
	  run("#{$sed} -e \"s/{.*}//g\" tmp_orig.srt > tmp.srt")
	  run("#{$rm} tmp_orig.srt") if $options[:debug].nil?
	elsif(ass_sub)
		pv "ASS subs found at track #{ass_sub}. Extracting."
	  run("#{$mkvextract} tracks \"#{base_f}.mkv\" #{ass_sub}:tmp.ass #{mkvextract_extra}")
	  
	  pv "Converting ASS Subs"
	  s = File.open("tmp.ass", "rb").read
	  sout = ass2srt(s)
	  f = File.open("tmp.srt", "wb")
	  f.print(sout)
	  f.close
	  run("#{$rm} tmp.ass") if $options[:debug].nil?
	end

	if(srt_sub or ass_sub)
	  run("#{$mp4box} -ttxt tmp.srt")
	  run("#{$rm} tmp.srt") if $options[:debug].nil?
	  #`sed -i "" 's/translation_y="0"/translation_y="250"/' tmp.ttxt` 
	  mp4box_extra += " -add tmp.ttxt:lang=en"
	end
	
	
	
	pv "Running encode."
	unless $gui
		handbrake_extra += $options[:verbose] ? " 3>&1 1>&2 2>&3" : " 2>&1"
	end
	run("#{$handbrake} -i \"#{base_f}.mkv\" -o tmp.mp4#{(" -q " + $options[:quality]) if $options[:quality]} --preset=\"#{$options[:preset]}\"#{handbrake_extra}")
	
	
	pv "Running mux."
	run("#{$rm} tmp.m4v 2>#{$null}")
	run("#{$mp4box} -add tmp.mp4#{mp4box_extra} tmp.m4v #{mkvextract_extra}")

	run("#{$rm} tmp.mp4") if $options[:debug].nil?
	run("#{$rm} tmp.ttxt") if (srt_sub or ass_sub) and $options[:debug].nil?

	if(srt_sub or ass_sub)
	  run("#{$sed} -e \"s/text/sbtl/g\" tmp.m4v > \"#{$options[:output] + base_f}.m4v\"") 
	  run("#{$rm} tmp.m4v") if $options[:debug].nil?
	end
end

if __FILE__ == $0
	`#{$mkdir} #{$options[:output]} 2>&1`
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
end