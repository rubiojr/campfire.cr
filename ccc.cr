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
  puts "list-rooms                      List available rooms."
  puts "transcript   <room> [date]      Get today's transcript."
  puts "                                (date is optional, format YYYY/MM/DD)."
  puts "backup       <dir>  [room]      Backup transcripts to JSON files."
  puts "                                Backs every room visible by default."
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

def check_backup_dir
  dir = ARGV[0]?

  if dir.nil? || !File.directory?(dir as String)
    puts "Invalid backup directory."
    puts
    usage
    exit 1
  end

  return ARGV.shift
end

def save_room_transcripts(base_dir, room)
  rdir = File.join(base_dir, room.id.to_s)
  Dir.mkdir(rdir) if !File.directory?(rdir)

  counter = 0
  loop do
    counter += 1
    day = (Time.now - counter.day).to_s "%Y/%m/%d"
    tdir = File.join(rdir, day)
    Dir.mkdir_p(tdir)
    tfile = File.join(tdir, "transcript.json")

    if File.exists?(tfile)
      puts "Transcript from '#{room.name}' (#{day}) already exists. Skipping."
      next
    end

    last_found = false
    File.open(tfile, "w") do |f|
      t = room.transcript_from(day)
      if t.nil? || ((JSON.parse(t as String) as Hash)["messages"] as Array).empty?
        puts "Last transcript from '#{room.name}' found at #{day}."
        last_found = true
      else
        puts "Saving transcript from '#{room.name}' (#{day}) to #{tfile}."
        f.puts(t)
      end
    end

    break if last_found
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
when "backup"
  dir = check_backup_dir
  if ARGV[0]?
    room = pop_room_arg
    save_room_transcripts(dir, room)
  else
    Campfire::Rooms.each do |room|
      save_room_transcripts(dir, room)
    end
  end
when "list-rooms"
  Campfire::Rooms.each do |room|
    puts "#{room.id} #{room.name}"
  end
end
