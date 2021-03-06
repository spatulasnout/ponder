require 'thread'
require 'fiber'
require 'ponder/recipient'

module Ponder
  class Channel < Recipient
    def initialize(name, thaum)
      super
      @name = name
      @users = {}
    end

    def name
      @mutex.synchronize do
        @name
      end
    end

    def topic
      if @topic
        @topic
      else
        fiber = Fiber.current
        callbacks = {}
        [331, 332, 403, 442].each do |numeric|
          callbacks[numeric] = @thaum.on(numeric) do |event_data|
            topic = event_data[:params].match(':(.*)').captures.first
            fiber.resume topic
          end
        end

        raw "TOPIC #{@name}"
        @topic = Fiber.yield
        callbacks.each do |type, callback|
          @thaum.callbacks[type].delete(callback)
        end

        @topic
      end
    end

    def add_user(user, prefixes = [])
      @mutex.synchronize do
        @users[user.nick.downcase] = [user, prefixes]
      end
    end

    def remove_user(nick)
      @mutex.synchronize do
        @users.delete nick.downcase
      end
    end

    def has_user?(user_or_nick)
      @mutex.synchronize do
        nick = case user_or_nick
        when String
          user_or_nick.downcase
        when User
          user_or_nick.nick.downcase
        end
        @users.key? nick
      end
    end

    def users
      @mutex.synchronize do
        @users
      end
    end

    def find_user(nick)
      @mutex.synchronize do
        @users[nick.downcase]
      end
    end

    def message(message)
      raw "PRIVMSG #{@name} :#{message}"
    end

    def inspect
      "#<Channel name=#{@name.inspect}>"
    end
  end
end
