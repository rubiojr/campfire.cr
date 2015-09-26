#
# Campfire Crystal Client
# 
require "./src/*"

def usage
  puts "Usage: ccc <command> <args>"
  puts
  puts "AVAILABLE COMMANDS:"
  puts
  puts "say          <room> <text>      Send a message to a room."
  puts "stalk        <room>             Join a room and listen."
  puts "transcript   <room> [date]      Get today's transcript."
  puts "                                (date is optional, format YYYY/MM/DD)."
end

def pop_room_arg
  room_arg = ARGV[0]? && ARGV.shift
  if room_arg.nil?
    puts "Invalid room."
    exit 1
  end
  room = Campfire::Room.from_name(room_arg as String)
  if room.nil?
    puts "Room #{room} not found."
    exit 1
  end
  return room as Campfire::Room
end

def stalk(room: Campfire::Room)
  ch = Channel(Campfire::Message).new
  spawn do
    Campfire.stream(room.id, ch)
  end

  loop do
    msg = ch.receive
    puts msg.body
  end
end

cmd = ARGV[0]? && ARGV.shift
if cmd.nil?
  usage
  exit 2
end

if !Campfire.creds_ok?
  puts "Authentication failed!"
  puts
  puts "Make sure you added (correctly) your subdomain and token to ~/.campfire/auth.yml"
  puts "See http://github.com/rubiojr/crystal.cr"
  exit 1
end

case cmd
when "say"
  room_arg = ARGV[0]? && ARGV.shift
  if room_arg.nil?
    puts "Invalid room."
    exit 1
  end

  if 
    room = Campfire::Room.from_name(room_arg as String)
    if room.nil?
      puts "Room #{room} not found."
      exit 1
    end

    msg = ARGV[0]? && ARGV.shift
    if msg.nil?
      puts "Invalid message."
      exit 1
    end

    room.join
    room.speak msg
  end
when "stalk"
  room = pop_room_arg
  stalk(room as Campfire::Room)
when "transcript"
  room = pop_room_arg
    if ARGV[0]?
      date = ARGV.shift as String
      t = room.transcript_from(date)
      if !t
        puts "Transcript from #{date} not found."
        exit
      end
      puts t
    else
      puts room.transcript
    end
end

