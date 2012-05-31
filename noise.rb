#!/usr/bin/env ruby

# I got this PortAudio bindings right off of github via:
#   git clone https://github.com/jvoorhis/ruby-portaudio.git
#
# But I include it here as a submodule. After clone do:
#   git submodule update --init
#
# You'll also need to install the portaudio library itself I imagine

$: << "." # Add the current directory to the search path
require 'ruby-portaudio/lib/portaudio.rb'

# Initialize the PortAudio interface
PortAudio.init

# Block size defines how many samples we buffer to send off at once
$block_size     = 512
#  $block_size     = 1024
#  $block_size     = 4096
#  $block_size     = 8096
#  $block_size     = 16384
# Sample rate indicates how many samples per second we actually output
#  $sample_rate    = 8000
$sample_rate    = 44100
#  $sample_rate    = 48000
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
  lambda { x.to_f }
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
    $buffer.fill {
      |frame, channel|
      #  $time         += $step
      #  $sample_count += 1
      sample = gen.call()
      #  puts "Sample: " + sample.to_s
      return if sample.nil?
      sample
      #  break if sample.nil?
    }
    $stream << $buffer
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

# Ahhh.... sweet silence!
def silence()
  lambda {
    0
  }
end

# == Envelopes
# Well. Just one.

def envelope(gen, attack = 0, sustain = 0, release = 0)
  gen     = genize gen
  attack  = genize attack
  sustain = genize sustain
  release = genize release

  attack_sample_count  = attack.call() * $sample_rate
  sustain_sample_count = sustain.call() * $sample_rate
  release_sample_count = release.call() * $sample_rate

  mode = :attack
  current_sample = 0

  lambda {
    current_sample += 1
    loop do
      case mode
      when :attack
        if current_sample > attack_sample_count
          current_sample = 1
          mode = :sustain
        else
          scale = current_sample.to_f / attack_sample_count
          return gen.call() * scale
        end
      when :sustain
        if current_sample > sustain_sample_count
          current_sample = 1
          mode = :release
        else
          return gen.call()
        end
      when :release
        if current_sample > release_sample_count
          current_sample = 1
          mode = :attack
          return nil
        else
          scale = 1 - (current_sample.to_f / release_sample_count)
          return gen.call() * scale
        end
      end
    end
  }
end

# == Combinators

# Play one gen after another
def seq(gens)
  gens = gens.map! { |g| genize g }
  cur_gen = gens.shift
  lambda {
    if cur_gen.nil?
      nil
    else
      sample = cur_gen.call
      if sample.nil?
        cur_gen = gens.shift
        return nil if cur_gen.nil?
        cur_gen.call
      else
        sample
      end
    end
  }
end

# Play all the gens at once
def sum(gens)
  gens = gens.map! { |g| genize g }
  lambda {
    samples = gens.map { |g| g.call }
    samples = samples.compact
    return nil if samples.length == 0
    sample = samples.inject(0.0, :+)
    sample /= samples.length if samples.length > 0 # scale. Needed?
    sample
  }
end

def mousefreq()
  count = 0
  x = 0.0
  lambda {
    count += 1
    if count  % 1000 == 0
      x = `xmousepos`.split[0].to_f
    end
    x
  }
end

def mousevol()
  count = 0
  y = 0.0
  lambda {
    count += 1
    if count  % 1000 == 0
      y = `xmousepos`.split[1].to_f / 600
    end
    y
  }
end

def amp(gen, amount)
  gen = genize gen
  amount = genize amount
  lambda {
    sample = gen.call
    mult = amount.call
    return nil if sample.nil? or mult.nil?
    sample * mult
  }
end

#  play(noise())
#  play(sine(440))

# Low-Frequency-Oscillator (LFO)
lfo = sine(5)

# Wobble frequency from 340 to 540
wobble_freq = lambda { lfo.call * 100 + 440 }

#  play(sine(wobble_freq))
#  play(square(wobble_freq))


# Envelope examples
#  play(envelope(square(440), 2, 0, 2))
#  play(envelope(square(wobble_freq), 2, 0, 2))
#  play(envelope(sine(wobble_freq), 2, 0, 2))

# Wobbly enveloped frequency
#  play(
    #  envelope(square(440), 2, 0, 2),
    #  square(envelope(wobble_freq, 2, 0, 2)),
  #  ])
#  )


# Play a sequence
#  play(
  #  seq([
    #  envelope(square(440), 2, 0, 2),
    #  envelope(square(wobble_freq), 2, 0, 2),
  #  ])
#  )



#  play(
  #  sum([
    #  envelope(square(440), 2, 0, 2),
    #  envelope(square(wobble_freq), 2, 0, 2),
  #  ])
#  )


#  play(
  #  sum([
    #  envelope(square(440), 2, 0, 2),
    #  envelope(square(220), 2, 0, 2),
    #  envelope(square(880), 2, 0, 2),
    #  envelope(square(660), 2, 0, 2),
    #  envelope(square(1200), 2, 0, 2),
  #  ])
#  )

# Synth!
#  play(
  #  amp(
    #  sine( mousefreq() ),
    #  mousevol()
  #  )
#  );
