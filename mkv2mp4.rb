def find_exec(str)
	return str if(`which #{str}` != "")
	["./MacOS/", "./"].each do |i|
		j = i+str
		return j if (`ls #{j}` != "")
	end
	raise "Missing #{str}"
end

$mkvinfo = find_exec "mkvinfo"
$mkvextract = find_exec "mkvextract"
$mp4box = find_exec "MP4Box"
$handbrake = find_exec "HandBrakeCLI"

a = `#{$mkvinfo} 1.mkv`
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

mp4box_extra = ""
handbrake_extra =""

#audio = find_tracks(a, /Language: jpn/).first
#handbrake_extra += " -a #{audio}" if audio
handbrake_extra += " -N jpn --native-dub"

srt_sub = find_tracks(a, /S_TEXT\/UTF8/)
ass_sub = find_tracks(a, /S_TEXT\/ASS/)
jpn = find_tracks(a, /Language: jpn/)
eng = find_tracks(a, /Language: eng/)

for i in [srt_sub, ass_sub]
	inter = i&jpn
	if inter.count != 0
		i.delete_if{ true }
		i << inter.first
	else
		inter = i&eng
		i.delete_if{true}
		i << inter.first
	end
end

if(srt_sub.first)
  `#{$mkvextract} tracks 1.mkv #{srt_sub.first}:tmp.srt`
elsif(ass_sub.first)
  `#{$mkvextract} tracks 1.mkv #{ass_sub.first}:tmp.ass`
  `ruby ass2srt.rb tmp.ass > tmp.srt`
  `rm tmp.ass`
end

if(srt_sub or ass_sub)
  `#{$mp4box} -ttxt tmp.srt`
  `rm tmp.srt`
  #`sed -i "" 's/translation_y="0"/translation_y="250"/' tmp.ttxt` 
  mp4box_extra += " -add tmp.ttxt"#:lang=en"
end
#`#{$handbrake} -i 1.mkv -o tmp.mp4 --preset="iPhone & iPod Touch"#{handbrake_extra} 1>&2`
`#{$mp4box} -add tmp.mp4#{mp4box_extra} 1.m4v`
#`rm tmp.mp4`
#`rm tmp.ttxt` if (srt_sub or ass_sub)

if(srt_sub or ass_sub)
  `sed -i "" "s/text/sbtl/" 1.m4v` 
end
