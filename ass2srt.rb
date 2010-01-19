#!/usr/bin/env ruby
#Copyright (C) 2010 Adam Watkins (adam@stupidpupil.co.uk)
#
#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class ASSEvent
  
  attr_reader :startStamp, :endStamp, :text
  
  def initialize(startStamp, endStamp, text)
    @startStamp = startStamp
    @endStamp = endStamp
    @text = text
  end
  
  def srtText
    assText = @text.dup
    assText.gsub!("\r", "")
    
   ["b","u","i","s"].each do |mark|
     assText.gsub!(/\{.*?\\#{mark}1.*?\}/) {|x| "<#{mark}>#{x}"}
     assText.gsub!(/\{.*?\\#{mark}0.*?\}/) {|x| "</#{mark}>#{x}"}
     
     misMatches = assText.scan("<#{mark}>").count-assText.scan("</#{mark}>").count
  
     if misMatches > 0
       assText.insert(-1, "</#{mark}>"*misMatches)
     elsif misMatches < 0
       assText.insert(0, "<#{mark}>"*-misMatches)
      end
   end

    assText.gsub!(/\{.+?\}/,"") #Remove all formatting braces
    assText.gsub!("\\h", " ")#ASS Hard space -> space
    assText.gsub!(/\\(N|n)/,"\n")#ASS newlines
     
    assText.gsub!(/^\s+\n/, "\n") #SRT treats any 'empty' 
    assText.gsub!(/\n{2,}/, "\n") #(including just spaces) line as a seperator
    
    return assText
  end 
  
end

assFile = File.new(ARGV[0])

assEventsContents = assFile.read.match(/\[Events\](.*?)(^\[.+?\]|\z)/m)[1]
assEventFormatArray = assEventsContents.match(/Format: (.*)$/)[1].split(", ").map!{|x| x.strip}

assEventFormatHash = {
  :start => assEventFormatArray.index("Start"),
  :end => assEventFormatArray.index("End"),
  :text => assEventFormatArray.index("Text") #It better also be the last one, because…
}
componentsAfterText = (assEventFormatArray.length-1 - assEventFormatHash[:text])

assEvents = []
assStartsAndEnds = []

assEventsContents.lines.find_all {|x| !(x.match(/Dialogue: (.*)$/).nil?)}.each do |assEventString|
  assStartStamp = assEventString.split(",")[assEventFormatHash[:start]]
  assEndStamp = assEventString.split(",")[assEventFormatHash[:end]]
  
  if  componentsAfterText == 0 #It's the last
    assText = assEventString.match(/(.*?,){#{assEventFormatHash[:text]-1}},(.+)/)[-1]
  elsif componentsAfterText > 0 #Actually, this shouldn't ever happen, but we cope
    assText = assEventString.match(/(.*?,){#{assEventFormatHash[:text]-1}},(.+)(,.+){#{componentsAfterText}}/)[-1]
  else
    raise "Error reading ASS Text"
  end

  assEvents << ASSEvent.new(assStartStamp, assEndStamp, assText)
  assStartsAndEnds << assStartStamp
  assStartsAndEnds << assEndStamp
end

assStartsAndEnds.uniq!.sort!

srtOut = ""
srtCount = 0

assStartsAndEnds.each_with_index do |timeStamp, i|
  
  #Find all subtitles that have started, but not ended. Sort them so those first in, are highest up.
  assOnScreenEvents = assEvents.find_all{|x| (x.startStamp <= timeStamp and x.endStamp > timeStamp)}.sort {|x,y| x.startStamp <=> y.startStamp}
  
  if assOnScreenEvents.count > 0
    assEndStamp = assStartsAndEnds[i+1].nil? ? assOnScreenEvents[-1].endStamp : assStartsAndEnds[i+1]

    srtOut += "#{srtCount += 1}\n" #Sarts at one
    srtOut += "#{timeStamp.gsub(".",",")} --> #{assEndStamp.gsub(".",",")}\n"
    
    assOnScreenEvents.each do |assEvent|
      srtOut += "#{assEvent.srtText}\n"
    end
    srtOut += "\n"
  end
  
end

puts srtOut
