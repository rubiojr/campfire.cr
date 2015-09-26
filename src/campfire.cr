require "http"
require "yaml"
require "json"

module Campfire
  # {
  #   "user": {
  #       "admin": true,
  #       "api_auth_token": "token",
  #       "auto_invite_to_new_rooms": true,
  #       "avatar_url": "http://foobar.com",
  #       "created_at": "2013/07/22 18:54:38 +0000",
  #       "email_address": "foo@bar.com",
  #       "id": 1433380,
  #       "name": "rubiojr",
  #       "type": "Member"
  #   }
  # }
  class User
    json_mapping({
      name: String,
      admin: Bool,
      email_address: String,
      avatar_url: String,
      api_auth_token: { type: String, nilable: true },
      id: Int32,
      type: String,
      created_at: String,
      auto_invite_to_new_rooms: Bool
    })

    def self.me
      json = Campfire.json_response(Campfire.get("/users/me.json"), "user")
      from_json(json)
    end

    def self.from_id(id : Int32)
      json = Campfire.json_response(Campfire.get("/users/#{id}.json"), "user")
      from_json(json)
    end

    def self.find(name)
      rooms = [] of Room

      concurrency = 20
      counter = Channel::Buffered(Bool).new(concurrency)
      concurrency.times { counter.send true }

      queue = Rooms.all
      loop do
        break if queue.empty?

        counter.receive
        spawn do
          room = queue.pop
          room.user_list.each do |u|
            if u.name == name
              rooms << room
            end
          end
          counter.send true
        end
      end

      return rooms
    end
  end
  
  class Rooms
    json_mapping({
      rooms: Array(Room)
    })

    def self.present(str)
      from_json(Campfire.get("/presence.json").body).rooms
    end

    def self.all
      from_json(Campfire.get("/rooms.json").body).rooms
    end
  end

  class Room 
    json_mapping({
      name: String,
      topic: String,
      full: { type: Bool, nilable: true },
      open_to_guests: { type: Bool, nilable: true },
      active_token_value: { type: String, nilable: true },
      id: Int32,
      membership_limit: { type: Int32, nilable: true },
      created_at: String,
      updated_at: String,
      users: { type: Array(User), nilable: true }
    })

    def user_list
      json = Campfire.json_response(Campfire.get("/room/#{id}.json"), "room")
      Room.from_json(json).users as Array(User)
    end

    def self.from_id(id : Int32)
      json = Campfire.json_response(Campfire.get("/room/#{id}.json"), "room")
      from_json(json)
    end

    def self.from_name(str: String)
      room = nil

      Rooms.all.each do |r|
        if r.name.downcase == str.downcase
          room = r
          break
        end
      end
      
      return room
    end

    def leave
      Campfire.post("/room/#{id}/leave.json")
    end

    def join 
      Campfire.post("/room/#{id}/join.json")
    end

    def speak(body)
      msg = {
        "message": {
          "type": "TextMessage",
          "body": body
        }
      }
      Campfire.post_body("/room/#{id}/speak.json", msg.to_json)
    end

    def transcript
      Campfire.get("/room/#{id}/transcript.json").body
    end

    # String with the format year/month/day
    def transcript_from(date: String)
      response = Campfire.get("/room/#{id}/transcript/#{date}.json")
      if response.status_code == 200
        return response.body
      else
        return nil
      end
    end
  end

  class Message
    property content, user_id, room_id, type
    property body, msg_id, starred, created_at

    def initialize(content)
      @user_id = content["user_id"]
      @room_id = content["room_id"]
      @type = content["type"]
      @body = content["body"]
      @msg_id = content["id"]
      @starred = content["starred"]
      @created_at = content["created_at"]
      @content = content
    end

    def self.build(content)
      msg = nil
        # validate this against a whitelist
        case content["type"]
        when "TextMessage"
          msg = TextMessage.new(content)
        when "TimestampMessage"
          msg = TimestampMessage.new(content)
        when "EnterMessage"
          msg = EnterMessage.new(content)
        when "LeaveMessage"
          msg = LeaveMessage.new(content)
        when "PasteMessage"
          msg = PasteMessage.new(content)
        when "KickMessage"
          msg = KickMessage.new(content)
        when "UploadMessage"
          msg = UploadMessage.new(content)
        when "TweetMessage"
          msg = TweetMessage.new(content)
        else
          raise "Unknown message type"
        end

      return msg
    end
    
    def to_s
      @body
    end

    def room
      Rooms.list[@room_id]
    end

    def user
      room.user_name(@user_id)
    end

  end

  class TextMessage < Message
    def to_s
      "[#{room.name.bold}] #{user.magenta.bold}: #{body}"
    end

    def contains_image?
      true if body =~ /(https?:.*\.(png|jpeg|jpg|gif))/
    end

    def image
      body =~ /(https?:.*\.(png|jpeg|jpg|gif))/
      $1
    end
  end
  class PasteMessage < TextMessage; end
  class KickMessage < TextMessage; end
  class UploadMessage < TextMessage; end
  class TweetMessage < TextMessage
    def author_username
      (content["tweet"] as Hash)["author_username"]
    end

    def message
      (content["tweet"] as Hash)["message"]
    end
  end

  class TimestampMessage < Message
    def to_s
      nil
    end
  end

  class EnterMessage < Message; end
  class LeaveMessage < Message; end
  
  def self.stream(room: Int32, channel: Channel(Message))
    client = build_client("streaming.campfirenow.com")
    client.get "/room/#{room}/live.json" do |response|
      buffer = StringIO.new
      oc = cc = 0
      loop do
        io = response.body_io
        char = io.read_char
        buffer << char
        if char == '{'
          oc += 1
        end
        if char == '}'
          cc += 1
        end

        if (oc == cc) && oc != 0
          oc = cc = 0
          json = JSON.parse(buffer.to_s) as Hash
          channel.send(Campfire::Message.build(json) as Message)
          buffer.clear
        end
      end
    end 
  end


  def self.json_response(response, key) 
    json = ""

    response.body.match(/#{key}":(.*)}$/) do |md|
      json = md[1]
    end

    return json
  end

  def self.build_client(domain)
    client = HTTP::Client.new domain, 443, true
    client.before_request do |req|
      req.headers["Accept"] = "application/json" 
      req.headers["Content-Type"] = "application/json"
    end
    client.basic_auth(config["token"], "X")

    client
  end

  def self.get(path)
    client = build_client("#{config["subdomain"]}.campfirenow.com")
    client.get path
  end
  
  def self.post(path)
    return post_body(path, nil)
  end
  
  def self.post_body(path, body)
    client = build_client("#{config["subdomain"]}.campfirenow.com")
    if body.nil?
      response = client.post path
    else
      headers = HTTP::Headers{
        "Accept": "application/json",
        "Content-Type": "application/json"
      }
      response = client.post path, headers, body
    end
    response
  end

  def self.creds_ok?
    response = get "/"
    response.status_code == 200
  end

  def self.config
    @@config ||= load_config
  end

  def self.load_config
    data = YAML.load(File.read(File.expand_path("~/.campfire/auth.yml"))) as Hash
    return data as Hash
  end

  def self.config=(config_hash)
    @@config = config_hash
  end
end
