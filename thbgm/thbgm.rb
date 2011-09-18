#!/usr/bin/env ruby
# vim:fileencoding=utf-8
# -*- Mode: Ruby; Encoding: utf8n -*-
$stdout.sync = true
$stdout.set_encoding("CP932")
require 'yaml'

puts "thbgm.rb version 0.1 (2011-09-19)" # version

if RUBY_VERSION<'1.9'
  puts "This script run on ruby1.9. your ruby version is #{RUBY_VERSION}."
  exit(-1)
end

yaml_file = 'thbgm.yaml'
thbgm_yml = YAML.load_file(yaml_file)

argv = ARGV[0]
if argv =~/-(th\d+)/
  th = $1.to_s
  puts "argv : #{th}"
else
  puts "help:"
  puts "  puts titles-file in the folder \"titles\", and execute this script."
  puts "  in case you get the wave file of th13, you execute the following command."
  puts "  > thbgm.rb -th13"
  exit
end

titles_file = "titles/titles_#{th}.txt"
thbgm = thbgm_yml["thbgm"][th]

#filename_template = "%th%_%2d %title%"

if File.exist?(titles_file) and File.exist?(thbgm)
  list = open(titles_file, "r").lines.select{|s| s !~ /^(?:\#|@)/}
  #puts list
  dat = open(thbgm, "rb").read

  i="00"
  list.each do |ln|
    offset, intro, loop, title = ln.strip.split(/,/).map{|i|
      i=~/^[0-9a-fA-F]+$/?i.to_i(16):i.encode("CP932")
    }
    size = intro + loop
    filename = "#{th}_#{i} #{title}.wav"
    riffheader = ["RIFF", size+44-8, "WAVEfmt ",  16, 1, 2, 44100, 44100*2*2, 2*2, 16, "data", size].pack("A4VA8VvvVVvvA4V")
    open(filename, "wb"){|f|
      f.write riffheader
      f.write dat[offset, size]
    }
    i.succ!
    print file + "... done.\n"
  end
end

__END__
