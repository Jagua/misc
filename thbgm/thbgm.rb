#!/usr/bin/env ruby
# vim:fileencoding=utf-8
# -*- Mode: Ruby; Encoding: utf8n -*-
$stdout.sync = true
$stdout.set_encoding("CP932")
require 'optparse'
require 'yaml'

Version = '0.2'
puts "thbgm.rb version #{Version} (2011-09-25)" # version

if RUBY_VERSION<'1.9'
  puts "This script run on ruby1.9. your ruby version is #{RUBY_VERSION}."
  exit(-1)
end

yaml_file = 'thbgm.yaml'
thbgm_yml = YAML.load_file(yaml_file)

op = OptionParser.new
opt={}
opt[:loop]= 1
op.on('--th=VALUE', 'th no. (VALUE: 06,07,..,13)') {|v| opt[:th] = 'th'+v}
op.on('--loop=VALUE', 'loop count. (VALUE: 0-)') {|v| opt[:loop] = v}
op.on('--track=VALUE', 'track no.') {|v| opt[:track] = v}
op.on('--omit-subtitle', 'omit subtitle from title') {|v| opt[:omitsubttl] = v}
op.on('--filename=VALUE', 'filename template. (default: "%th%_%track% %title%.wav")') {|v| opt[:filename] = v}
op.parse!(ARGV)

unless opt[:th]
  puts op.help
  exit
end

titles_file = "titles/titles_#{opt[:th]}.txt"
thbgm = thbgm_yml["thbgm"][opt[:th]]
default_filename = "%th%_%track% %title%.wav"

if File.exist?(titles_file) and File.exist?(thbgm)
  list = open(titles_file, "r").lines.select{|s| s !~ /^(?:\#|@)/}
  dat = open(thbgm, "rb").read

  i="00"
  list.each do |ln0|
    ln = ln0.encode(Encoding::UTF_8)
    ln =~ /^([0-9a-fA-F]+),([0-9a-fA-F]+),([0-9a-fA-F]+),([^　]+.*?)(　?.*?)$/
    offset = $1.to_s.to_i(16)
    intro = $2.to_s.to_i(16)
    loop = $3.to_s.to_i(16)
    title = $4.strip
    subtitle = $5.strip
    title += subtitle unless opt[:omitsubttl]
    size = intro + loop*opt[:loop].to_i
    filename = opt[:filename]?opt[:filename]:(default_filename)
    filename = filename.gsub(/%.*?%/, {'%th%'=>opt[:th], '%track%'=>i, '%title%'=>title})
    riffheader = ["RIFF", size+44-8, "WAVEfmt ",  16, 1, 2, 44100, 44100*2*2, 2*2, 16, "data", size].pack("A4VA8VvvVVvvA4V")
    open(filename, "wb"){|f|
      f.write riffheader
      f.write dat[offset, intro]
      f.write dat[offset + intro, loop]*opt[:loop].to_i
    }
    i.succ!
    print filename + "... done.\n"
  end
end

__END__
