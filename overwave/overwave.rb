#!/usr/bin/env ruby1.9.1
# vim:fileencoding=utf-8
# -*- Mode: Ruby; Encoding: utf8n -*-
#
#  overwave.rb
#        Coding By Jagua  /  原曲 By ZUN
#
#
# The MIT License : http://opensource.org/licenses/mit-license.php
#
# Copyright (c) 2011 Jagua
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
#


class WAV

  attr_accessor :wave, :riffheader, :wavedata

  def initialize(riff)
    if riff[0,4] == 'RIFF' and riff[8,8] == 'WAVEfmt ' and riff[36,4] == 'data'
      @totalsize = riff[4,4].unpack("V")[0]
      @channels = riff[22,2].unpack("v")[0]
      @frequency = riff[24,4].unpack("V")[0] #!
      @sampling_rate = riff[24,4].unpack("V")[0] #!
      @bytepersec = riff[28,4].unpack("V")[0]
      @blocksize = riff[32,2].unpack("v")[0]
      @quantization_bit_rate = riff[34,2].unpack("v")[0]
      @wavesize = riff[40,4].unpack("V")[0]
      @wave = riff[44,@wavesize]

      # riff[40,4] (=wavesize) がゼロだったとき riff[4,4] および riff[40,4] を実サイズに訂正 （※特別扱いいくない！）
      if @wavesize == 0
        @totalsize = (riff.bytesize-8)
        riff[4,4] = [riff.bytesize-8].pack("V")
        @wavesize = (riff.bytesize-44)
        riff[40,4] = [riff.bytesize-44].pack("V")
        @wave = riff[44,@wavesize]
      end
      @riffheader = riff[0,44]

      @amplitude = 2**(@quantization_bit_rate-1)-1
    else
      raise 'WAV.load : unknown format'
    end
  end


  def WAV.pack24 wave
    s = []
    wave.each do |data|
      s << (data.to_i & 0xFF)
      s << ((data.to_i >> 8) & 0xFF)
      s << ((data.to_i >> 16) & 0xFF)
    end
    s.pack("C*")
  end

  def unpack24
    s = []
    self.wave.unpack("C*").each_slice(3) do |data|
      _tmp = (data[2] << 16) + (data[1] << 8) + data[0]
      s << (_tmp>=2**23 ? _tmp-0x1000000 : _tmp)
    end
    s
  end

  def WAV.pack16 wave
    s = []
    wave.each do |data|
      s << (data.to_i & 0xFF)
      s << ((data.to_i >> 8) & 0xFF)
    end
    s.pack("C*")
  end

  def unpack16
    self.wave.unpack("s*")
  end

  def WAV.pack8 wave
    s = []
    wave.each do |data|
      s << ((data.to_i + 2**(8-1)) & 0xFF)
    end
    s.pack("C*")
  end

  def unpack8
    self.wave.unpack("C*").map{|data| data - 2**(8-1)}
  end

  def WAV.pack wav, qbr
    case qbr
    when 24
      WAV.pack24 wav
    when 16
      WAV.pack16 wav
    when 8
      WAV.pack8 wav
    else
      raise "Invalid quantization_bit_rate"
    end
  end

  def unpack
    qbr = riffheader[34,2].unpack("v")[0]
    case qbr
    when 24
      unpack24
    when 16
      unpack16
    when 8
      unpack8
    else
      raise "Invalid quantization_bit_rate"
    end
  end

  def gen_pulse(o={})
    @frequency = o[:frequency]
    @duration = o[:duration]
    @volume = o[:volume]

    wave_engine = nil
    if o[:wave_generator] == :sine_wave
      wave_engine = Proc.new {|i|
        # @sampling_rate/@frequency = １周期のサンプリング数
        d = 360.0/(@sampling_rate/@frequency) # １サンプルごとに進む角度
        d *= (i%(@sampling_rate/@frequency)) # その角度ずつ増やす
        Math.sin(d/180.0*Math::PI)
      }
    elsif o[:wave_generator] == :square_wave
      wave_engine = Proc.new {|i|
        d = (@sampling_rate/@frequency)/2
        if i%(@sampling_rate/@frequency) < d
          sam = 1.0
        else
          sam = -1.0
        end
        sam
      }
    elsif o[:wave_generator] == :triangle_wave
      wave_engine = Proc.new {|i|
        a = (@sampling_rate/@frequency)/4
        d = (@sampling_rate/@frequency)/4
        t = 1.0*i%(@sampling_rate/@frequency)
        if (0..a) === t
          sam = t/d
        elsif (a..2*a) === t
          sam = 1.0-(t-a)/d
        elsif (2*a..3*a) === t
          sam = -(t-2*a)/d
        elsif (3*a..4*a) === t
          sam = -1.0+(t-3*a)/d
        end
        sam
      }
    elsif o[:wave_generator] == :sawtooth_wave
      wave_engine = Proc.new {|i|
        a = (@sampling_rate/@frequency)/2
        t = 1.0*i%(@sampling_rate/@frequency)
        if (0..a) === t
          sam = t/a
        else
          sam = -1+(t-a)/a
        end
        sam
      }
    end

    wave = Array.new(@sampling_rate*@duration,0)
    pr = nil
    (0..@sampling_rate*@duration-1).each do |i|
      case @quantization_bit_rate
      when 24
        wave[i] = @amplitude*@volume*wave_engine.call(i)
      when 16
        wave[i] = @amplitude*@volume*wave_engine.call(i)
      when 8
        wave[i] = @amplitude*@volume*wave_engine.call(i)
      end
    end

    wave_ = wave.dup
    wave_ = plugin_fadeout({:duration=>0.02, :wave=>wave_}) # 発音し始めと
    wave = plugin_fadein({:duration=>0.01, :wave=>wave_}) # し終わりのプチノイズ対策

    wave2 = []
    if @channels == 2
      wave.each do |i|
        wave2 << i
        wave2 << i
      end
      wave = wave2.dup
    end

    @wavedata = WAV.pack(wave, @quantization_bit_rate)
  end


  class << self

    alias load new

    def make_riffheader(o={})
      channels = o[:channels]
      sampling_rate = o[:sampling_rate]
      quantization_bit_rate = o[:quantization_bit_rate]

      size = 0
      riffheader = ["RIFF", size+44-8, "WAVEfmt ",  16, 1, channels, sampling_rate, sampling_rate*channels*quantization_bit_rate/8, channels*quantization_bit_rate/8, quantization_bit_rate, "data", size].pack("A4VA8VvvVVvvA4V")
    end

    def mix(wav1, wav2)
      wave1 = wav1.unpack
      wave2 = wav2.unpack
      waves = [wave1,wave2].sort{|a,b| b.size <=> a.size} #要素数が多い順に
      newwave = []
      (0..waves[0].size-1).each do |i|
        #newwave[i] = (waves[0][i]+(waves[1][i] ? waves[1][i] : waves[0][i]))/2
        newwave[i] = waves[0][i].to_i+waves[1][i].to_i
      end
      wav = WAV.pack(newwave, wav1.riffheader[34,2].unpack("v")[0])
      riffheader = wav1.riffheader
      riffheader[4,4] = [wav.bytesize+44-8].pack("V")
      riffheader[40,4] = [wav.bytesize].pack("V")
      load(riffheader + wav)
    end

  end


  def plugin_fadein( o={} )
    plugin_fadeinout( o.merge({:fadein=>true}) )
  end

  def plugin_fadeout( o={} )
    plugin_fadeinout( o.merge({:fadeout=>true}) )
  end

  def plugin_fadeinout( o={} )
    duration = o[:duration]
    wavedata = o[:wave]
    sample_size = wavedata.size #総サンプリング数
    if o[:fadein]
      pos_start = 0
      pos_end = @sampling_rate * duration
    elsif o[:fadeout]
      pos_start = sample_size - @sampling_rate * duration
      pos_end = sample_size
    end
    @newwave = Array.new
    wavedata.each_with_index do |i,index|
      if (pos_start..pos_end) === index
        dt = (pos_end-index)/(pos_end-pos_start)
        if o[:fadein]
          dt = 1.0-dt
        end
        @newwave.push (1.0*dt*i).to_i
      else
        @newwave.push i
      end
    end
    @newwave
  end


end




def th13_15 o
  #p o
  melody_waveform = o[:melody_waveform]
  melody_volume = o[:melody_volume]
  rhythm_waveform = o[:rhythm_waveform]
  rhythm_volume = o[:rhythm_volume]

  riffheader = WAV.make_riffheader({
    :channels => o[:channels],
    :sampling_rate => o[:sampling_rate],
    :quantization_bit_rate => o[:quantization_bit_rate],
  })

  wav_melody = WAV.load(riffheader)
  wav_rhythm = WAV.load(riffheader)

  # 音階と音長の組を指定．
  # とりあえずピアノの鍵盤 (88鍵) の範囲をサポート．
  # つまりオクターブ４のラの音 (440kHz) を基準に下４オク (12*4) と上３オク＋３鍵
  scale2hertz = {}
  scale = ["c","c#","d","d#","e","f","f#","g","g#","a","a#","b"]
  octave = 0
  note_value_index = 9
  alist = []
  88.times do |i|
    alist << [[octave, scale[note_value_index]],440*2**(((octave-4)*12+note_value_index-9).to_f/12)]
    note_value_index += 1
    if note_value_index == 12
      alist << [[octave, "r"], 0.00000001]
      note_value_index -= 12
      octave += 1
    end
  end
  scale2hertz = Hash[alist]

  # 神霊廟Extra道中曲「妖怪裏参道」作曲 : ZUN
  mml_melody = "f#4<c#4>g#4a8b8 a4g#8f#8 e8c#8e4
d4a4e4f8g8 f4e8d8c4>a4"
  mml_rhythm = ">c8c8c8c8 c8c8c8c16c16 c32c32c32c32c32c32r16c8c8 c32c32c32c32c32c32r16c16c48c48c48c48c48c48c48c48c48c48"

  quantization = 192  # 全音符の分解能
  tempo = 100         # てきとー

  waves = []
  _duration = 0
  [[wav_melody, mml_melody, melody_waveform, melody_volume], [wav_rhythm, mml_rhythm, rhythm_waveform, rhythm_volume]].each do |wav_stuff|
    wav, mml, engine, volume = wav_stuff[0], wav_stuff[1], wav_stuff[2], wav_stuff[3]
    wave = ""

    octave = 4
    score = []
    mml.scan(/[><]?[a-z]\#?\d+/).each do |t|
      d = t.scan(/([><]?)([a-z]\#?)(\d+)/).flatten
      scale = d[1]
      note_value = d[2].to_i
      if t[0,1] == ">"
        octave -= 1
      elsif t[0,1] == "<"
        octave += 1
      end
      score << [octave, scale, note_value]
    end

    score.each do |a|
      octave = a[0]     #オクターブ
      scale = a[1]      #音高
      note_value = a[2] #音価

      duration = 1.0 * quantization / note_value * 60 / ((quantization/4) * tempo) #seconds
      hertz = scale2hertz[[octave, scale]]
      wav.gen_pulse({
        :wave_generator => engine,
        :frequency => hertz,
        :duration => duration,
        :volume => volume,
      })
      wave += wav.wavedata
    end
    waves.push WAV.load(WAV.load(wav.riffheader + wave).riffheader + wave)
  end

  wav_music = WAV.mix(waves[0], waves[1])

  open("ow_#{o[:quantization_bit_rate]}bit_#{o[:sampling_rate]}Hz_#{o[:channels]}ch.wav", "wb"){|f|
    f.write wav_music.riffheader
    f.write wav_music.wave
  }
end


if __FILE__ == $0
  $stdout.sync = true
  $stdout.set_encoding("CP932") if RUBY_PLATFORM =~ /[^dar]win/i
  require 'optparse'

  Version = "0.01"

  op = OptionParser.new
  opt = {}
  op.on('--ch=VALUE', 'channel (VALUE:1,2)') {|v| opt[:ch] = v.to_i}
  op.on('--sr=VALUE', 'sampling rate (VALUE:48000,96000,192000)') {|v| opt[:sr] = v.to_i}
  op.on('--bitrate=VALUE', 'quantization bit rate (VALUE:8,16,24)') {|v| opt[:quantization_bit_rate] = v.to_i}
  op.on('--test=TH,NO,MELODY_WAVE_FORM,MELODY_VOLUME,RHYTHM_WAVE_FORM,RHYTHM_VOLUME', 'test mode.') {|v| opt[:test] = v}
  op.on_tail("-h", "--help", "Show this message") do
    puts op
    puts "
あそびかた：
    > ruby1.9.1 overwave.rb --ch=CH --sr=SR --bitrate=BR --test=13,15,A,B,C,D

    CH はチャンネル数を指定する．
        1 : モノラル    2 : ステレオ

    SR はサンプリングレートを指定する．
        44100 とか 48000 とか 96000 とか 192000 が一般的でしょう．

    BR は 8 か 16 か 24 のどれかを指定する．

    A にはメロディの波形（0 ～ 3）を指定する．
        0 : 正弦波    1 : 矩形波    2 : 三角波    3 : 鋸波
    B にはメロディの音量（0.0 ～ 1.0）を小数で指定する．
    C にはリズムの波形（0 ～ 3）を指定する．
        0 : 正弦波    1 : 矩形波    2 : 三角波    3 : 鋸波
    D にはリズムの音量（0.0 ～ 1.0）を小数で指定する．

    例）
      メロディは正弦波で音量 40%，リズムは矩形波で音量 3% にしたくて
      ステレオ (2ch) で 192kHz で 24 ビットな WAV ファイルを生成したい場合．
    > ruby1.9.1 overwave.rb --ch=2 --sr=192000 --bitrate=24 --test=13,15,0,0.4,1,0.03
    を実行すると ow_16bit_48000Hz_2ch.wav っていう WAV ファイルを生成する．

ちゅうい：
    ヘッドフォンなどでは聴かないようにしましょう．
    あとスピーカーが壊れても耳が痛くなっても責任は取りませんので
    ご使用の際は自己責任で！
"
    exit
  end
  op.parse!(ARGV)

  if opt[:test]
    args = opt[:test].split(/,/)
    raise unless args.size == 6

    waveforms = [:sine_wave, :square_wave, :triangle_wave, :sawtooth_wave]

    melody_waveform = waveforms[args[2].to_i] || :sine_wave
    melody_volume =  args[3].to_f || 0.4
    rhythm_waveform =  waveforms[args[4].to_i] || :triangle_wave
    rhythm_volume = args[5].to_f || 0.1

    if melody_volume + rhythm_volume >= 1.0
      puts "メロディの音量（#{melody_volume}）とリズムの音量（#{rhythm_volume}）の和が 1.0 以上だとエラーになります！"
      exit
    end

    puts "Channels: #{opt[:ch]}, Sampling Rate: #{opt[:sr]}, Quantization Bit Rate: #{opt[:quantization_bit_rate]}"
    puts "Melody (#{melody_waveform.to_s}, volume: #{(melody_volume*100).to_i}%)"
    puts "Rhythm (#{rhythm_waveform.to_s}, volume: #{(rhythm_volume*100).to_i}%)"
    print "Processing ... "

    th13_15({
      :channels => opt[:ch] || 2,
      :sampling_rate => opt[:sr] || 48000,
      :quantization_bit_rate => opt[:quantization_bit_rate] || 16,
      :melody_waveform => melody_waveform,
      :melody_volume => melody_volume,
      :rhythm_waveform => rhythm_waveform,
      :rhythm_volume => rhythm_volume,
    })
    print "Done.\n"
  end
end

__END__
