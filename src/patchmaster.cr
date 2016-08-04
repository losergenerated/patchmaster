require "./patchmaster/*"
require "./patchmaster/curses/main"
require "./patchmaster/irb/irb"
require "./patchmaster/web/sinatra_app"

# usage: patchmaster [-l] [-v] [-n] [-i] [-w] [-p port] [-d] [pm_file]
#
# Starts PatchMaster and optionally loads pm_file.
#
# -l lists all available MIDI inputs and outputs and exits. This is exactply
# -the same as running the `unimidi list` command from your shell.
#
# -v outputs the version number and exits.
#
# The -n flag tells PatchMaster to not use MIDI. All MIDI errors such as not
# being able to connect to the MIDI instruments specified in pm_file are
# ignored, and no MIDI data is sent/received. That is useful if you want to
# run PatchMaster without actually talking to any MIDI instruments.
#
# To run PatchMaster from within an IRB session use -i. Reads
# ./.patchmasterrc if it exists, $HOME/.patchmasterrc if not. See the
# documentation for details on the commands that are available.
#
# To run PatchMaster using a Web browser GUI use -w and point your browser
# at http://localhost:4567. To change the port, use -p.
#
# The -d flag turns on debug mode. The app becomes slightly more verbose and
# logs everything to `/tmp/pm_debug.txt'.
module Patchmaster
  use_midi = true
  gui = :curses
  port = nil
  OptionParser.new do |opts|
    opts.banner = "usage: patchmaster [options] [pm_file]"
    opts.on("-d", "--debug", "Turn on debug mode") { $DEBUG = true }
    opts.on("-l", "--list", "List MIDI inputs and outputs and exit") do
      system("unimidi list")
      exit 0
    end
    opts.on("-n", "--no-midi", "Turn off MIDI processing") { use_midi = false }
    opts.on("-i", "--irb", "Use an IRB console") { gui = :irb }
    opts.on("-w", "--web", "Use a Web browser GUI") { gui = :web }
    opts.on("-p", "--port PORT", "Web browser GUI port number") { |opt| port = opt.to_i }
    opts.on("-v", "--version", "Show version number and exit") do
      version_line = IO.readlines(File.join(File.dirname(__FILE__), "../Rakefile")).grep(/GEM_VERSION\s*=/).first
      version_line =~ /(\d+\.\d+\.\d+)/
      puts "patchmaster #{$1}"
      exit 0
    end
    opts.on_tail("-h", "-?", "--help", "Show this message") do
      puts opts
      exit 0
    end
  end.parse!(ARGV)

  pm = PM::PatchMaster.instance
  pm.use_midi = use_midi
  pm.load(ARGV[0]) if ARGV[0]
  case gui
  when :curses
    pm.gui = PM::Main.instance
  when :irb
    pm.gui = PM::IRB.instance
  when :web
    app = PM::SinatraApp.instance
    app.port = port if port
    pm.gui = app
  end
  pm.run
end
