require 'patchmaster/consts'

module PM

# A Connection connects an InputInstrument to an OutputInstrument. Whenever
# MIDI data arrives at the InputInstrument it is optionally modified or
# filtered, then the remaining modified data is sent to the
# OutputInstrument.
class Connection

  attr_accessor :input, :input_chan, :output, :output_chan,
    :pc_prog, :zone, :xpose, :filter

  # If input_chan is nil than all messages from input will be sent to
  # output.
  #
  # All channels (input_chan, output_chan, etc.) are 1-based here but are
  # turned into 0-based channels for later use.
  def initialize(input, input_chan, output, output_chan, filter=nil, opts={})
    @input, @input_chan, @output, @output_chan, @filter = input, input_chan, output, output_chan, filter
    @pc_prog, @zone, @xpose = opts[:pc_prog], opts[:zone], opts[:xpose]

    @input_chan -= 1 if @input_chan
    @output_chan -= 1 if @output_chan
  end

  def start(start_bytes=nil)
    midi_out(start_bytes) if start_bytes
    midi_out([PROGRAM_CHANGE + @output_chan, @pc_prog]) if pc?
    @input.add_connection(self)
    @thread = Thread.new(@input) do |instrument|
      loop { instrument.process_messages }
    end
  end

  def stop(stop_bytes=nil)
    midi_out(stop_bytes) if stop_bytes
    Thread.kill(@thread)
    @input.remove_connection(self)
  end

  def accept_from_input?(bytes)
    return true if @input_chan == nil
    return true unless bytes.channel?
    bytes.note? && bytes.channel == @input_chan
  end

  # Returns true if the +@zone+ is nil (allowing all notes throught) or if
  # +@zone+ is a Range and +note+ is inside +@zone+.
  def inside_zone?(note)
    @zone == nil || @zone.include?(note)
  end

  def midi_in(bytes)
    return unless accept_from_input?(bytes)

    # TODO handle running bytes if needed
    high_nibble = bytes.high_nibble
    case high_nibble
    when NOTE_ON, NOTE_OFF, POLY_PRESSURE
      return unless inside_zone?(bytes[1])
      bytes[0] = high_nibble + @output_chan
      bytes[1] = ((bytes[1] + @xpose) & 0xff) if @xpose
    when CONTROLLER, PROGRAM_CHANGE, CHANNEL_PRESSURE, PITCH_BEND
      bytes[0] = high_nibble + @output_chan
    end

    bytes = @filter.call(self, bytes) if @filter
    if bytes && bytes.size > 0
      midi_out(bytes)
    end
  end

  def midi_out(bytes)
    @output.midi_out(bytes)
  end

  def pc?
    @pc_prog != nil
  end

  def note_num_to_name(n)
    oct = (n / 12) - 1
    note = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'][n % 12]
    "#{note}#{oct}"
  end

  def to_s
    str = "#{@input.name} ch #{@input_chan ? @input_chan+1 : 'all'} -> #{@output.name} ch #{@output_chan+1}"
    str << "; pc #@pc_prog" if pc?
    str << "; xpose #@xpose" if @xpose
    str << "; zone #{note_num_to_name(@zone.begin)}..#{note_num_to_name(@zone.end)}" if @zone
  end
end

end # PM
