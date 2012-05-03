#!/usr/bin/env ruby

# https://github.com/jvoorhis/ruby-portaudio.git
require 'ruby-portaudio/lib/portaudio.rb'

PortAudio.init

$block_size = 4000
$sr   = 44100
$step = 1.0/$sr
$time = 0.0

$stream = PortAudio::Stream.open(
   :sample_rate => $sr,
   :frames => $block_size,
   :output => {
     :device => PortAudio::Device.default_output,
     :channels => 1,
     :sample_format => :float32
    })

$buffer = PortAudio::SampleBuffer.new(
   :format   => :float32,
   :channels => 1,
   :frames   => $block_size)

def genize x
  if x.is_a?(Proc)
    return x
  end
  lambda { x }
end

def noise
  lambda { rand()*2 - 1 }
end

def sine(freq)
  freq = genize freq
  angle = 0
  lambda {
    sample = Math.sin(angle)
    angle += 2 * 3.1415 * $step * freq.call
    sample
  }
end

def play(gen)
  loop do
    $stream << $buffer.fill {
      |frame, channel|
      #  rand()*2 - 1
      gen.call
    }
  end
end

$stream.start
#  play(noise())
#  play(sine(440))

lfo = sine(10)
freq = lambda { lfo.call * 100 + 440 }
play(sine(freq))

