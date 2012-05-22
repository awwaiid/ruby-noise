#!/usr/bin/env ruby

# I got this PortAudio bindings right off of github
# https://github.com/jvoorhis/ruby-portaudio.git
require 'ruby-portaudio/lib/portaudio.rb'

# Initialize the PortAudio interface
PortAudio.init

# Block size defines how many samples we buffer to send off at once
$block_size     = 8096
# Sample rate indicates how many samples per second we actually output
$sample_rate    = 44100
# Step is just a shortcut for how long is an individual sample
$step           = 1.0/$sample_rate
# Just as a handy favor, keep track of the absolute time and sample count.
# These are really not necessary
$time           = 0.0
$current_sample = 0;

# Take a parameter and ensure it is a generator. If it is already a generator
# leave it alone, otherwise wrap it up so that it *is* a generator.
def genize x
  if x.is_a?(Proc)
    return x
  end
  lambda { x }
end

# Actually play the samples from a generator, sending them to our output
# device.
def play(gen)

  $stream = PortAudio::Stream.open(
    :sample_rate => $sample_rate,
    :frames      => $block_size,
    :output      => {
      :device        => PortAudio::Device.default_output,
      :channels      => 1,
      :sample_format => :float32
    }
  )

  $buffer = PortAudio::SampleBuffer.new(
    :format   => :float32,
    :channels => 1,
    :frames   => $block_size
  )

  $stream.start
  loop do
    $stream << $buffer.fill {
      |frame, channel|
      #  $time         += $step
      #  $sample_count += 1
      gen.call
    }
  end
end

# == Basic Wave Generators

# Generate some "white noise" aka static
def noise
  lambda { rand()*2 - 1 }
end

# We keep track of the angle instead of the absolute time so that when the
# frequency dynamically changes there won't be any jumps in the wave. Jumps
# could end up sounding funny, but more often they sounds... weird.
def sine(freq)
  freq = genize freq
  angle = 0
  lambda {
    sample = Math.sin(angle)
    angle += 2 * 3.1415 * $step * freq.call
    sample
  }
end

# One simple way to define a square wave is to just look to see if a sine is
# positive or negative.
def sinesquare(freq)
  gen = sine(freq)
  lambda {
    sample = gen.call
    sample >= 0 ? 1 : -1
  }
end

# But we could do this without having to work with 'sin' if we are so inclined
def square(freq)
  freq   = genize freq
  sample = 1
  step   = 0
  lambda {
    step += 1
    sample_count = (1/freq.call)*$sample_rate/2
    if step > sample_count
      sample *= -1
      step = 0
    end
    sample
  }
end

# == Envelopes
# Well. Just one.

def envelope(attack, sustain, release)

end

#  play(noise())
#  play(sine(440))


lfo = sine(5)
freq = lambda { lfo.call * 100 + 440 }
#play(sine(freq))
play(square(freq))

