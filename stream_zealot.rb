#!/usr/bin/env ruby

# usage:

# stream_zealot
#   lists all streams and their status

# stream_zealot --live
#   lists only live streams



require 'open-uri'
require 'json'
require 'yaml'

class Streamer
  attr_accessor :site
  attr_accessor :name
  attr_accessor :url
  attr_accessor :category

  def fetch_live_data
    @live_data = site.live_data_for(self)
  end

  def live?
    site.streamer_live?(@live_data)
  end
end

class Site
  attr_reader :name
  attr_reader :regex

  def fetch_live_data_for(streamer)
    raise "overwrite me"
  end
end

class Twitch < Site
  def initialize
    @name = 'Twitch.tv'
    @regex = /(twitch\.tv\/)(.*)/
  end

  def live_data_api_url_for(streamer)
    "http://api.justin.tv/api/stream/list.json?channel=#{streamer.name}"
  end

  def live_data_for(streamer)
    data = open(live_data_api_url_for(streamer)).readlines.join("\n")

    JSON.parse(data)
  end

  def streamer_live?(live_data)
    live_data.length > 0
  end
end

class StreamZealot
  attr_reader :streamers
  attr_reader :sites

  def initialize
    @sites = [ Twitch.new ]
  end

  def read_streamers(yaml_file)
    data = open(yaml_file).readlines.join("\n")
    categories = YAML.load(data)

    @streamers = []

    categories.each { |cat, streams|
      streamers = streams.map{ |s| streamer_for_url(s) }
      streamers.each { |s| s.category = cat }
      @streamers += streamers
    }
  end

  def streamers_categorized
    categories = {}

    @streamers.each { |s|
      categories[s.category] ||= []
      categories[s.category] << s
    }

    categories
  end

  def live_streamers_categorized
    categories = streamers_categorized
    live_cats = {}

    categories.each {|cat, streamers|
      live = false

      streamers.each {|s|
        if s.live?
          if !live
            live_cats[cat] = []
            live = true
          end
          live_cats[cat] << s
        end
      }
    }

    live_cats
  end

  def put_streamers
    put_streamers_categorized(streamers_categorized)
  end

  def put_live_streamers
    put_streamers_categorized(live_streamers_categorized)
  end

  private

  def put_streamers_categorized(categories)
    categories.each { |cat, streams|
      puts "- #{cat}"
      streams.each { |stream|
        live = stream.live? ? " (LIVE)" : ""

        puts "    - #{stream.name}#{live}"
        puts "      #{stream.url}"
        puts ""
      }
    }
  end

  def streamer_for_url(url)
    streamer = nil

    @sites.each { |s|
      match = s.regex.match(url)
      if match
        streamer = Streamer.new
        streamer.site = s
        streamer.name = match[2]
        streamer.url = url
        streamer.fetch_live_data
        break
      end
    }

    streamer
  end
end

zealot = StreamZealot.new
zealot.read_streamers('streamers.yml')

if ARGV.length > 0 && ARGV[0] == '--live'
  zealot.put_live_streamers
else
  zealot.put_streamers
end