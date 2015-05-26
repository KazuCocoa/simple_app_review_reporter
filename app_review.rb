require 'rubygems'
require 'open-uri'
require 'net/http'
require 'json'

require 'oga'
require 'simple-rss'

MAX_POST_G = 20 # google play can get 20 reviews without pagination
MAX_POST_A = 50 # app store can get 50 reviews without pagination

class AppReview
  class GooglePlay
    def initialize(application_id, locale)
      @host = 'https://play.google.com'.freeze
      @review_rui = '/store/getreviews'.freeze
      @review_request = "id=#{application_id}&reviewSortOrder=0&reviewType=1&pageNum=0&hl=#{locale}".freeze
    end

    # @param [Integer] post_count how many you would like to get review comment
    # @return [Array] result Array of reviews
    def latest_reviews_upto(post_count)
      return puts 'You can require review post up to 20 for GooglePlay.' if post_count > MAX_POST_G

      uri = URI.parse("#{@host}#{@review_rui}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      response_body = http.post(uri.path, @review_request).body.split("\n")[2].force_encoding('UTF-8')

      # convert or delete unicode escaped strings regarding "<", ">" and "\"
      response_body.gsub!(/\\u([0-9a-f]{4})/) { [$1.hex].pack('U') }
      response_body.delete!('\\')

      review_html = Oga.parse_html("<http><body>#{response_body}</body></http>")

      (0..post_count-1).each.map do |node_num|
        <<-EOS
rating: #{rating(review_html.css('div.current-rating')[node_num].get('style'))}
#{review_html.css('span.review-date')[node_num].text}:#{review_html.css('div.review-body')[node_num].children[1].text}
#{review_html.css('div.review-body')[node_num].children[2].text}
        EOS
      end
    end

    def rating(style)
      '*' * (style.scan(/[0-9]+/).first.to_i / 20)
    end

  end


  class AppStore
    def initialize(app_store_id, locale)
      @host = 'http://itunes.apple.com'.freeze
      @rss = "/#{locale}/rss/customerreviews/id=#{app_store_id}/sortby=mostrecent/xml".freeze
    end

    # @param [Integer] post_count how many you would like to get review comment
    # @return [Array] result Array of reviews
    def latest_reviews_upto(post_count)
      return puts 'You can require review post up to 50 for AppStore.' if post_count > MAX_POST_A

      uri = URI.parse("#{@host}#{@rss}")
      http = Net::HTTP.new(uri.host, uri.port)

      response = http.get(uri.path)

      # rating
      SimpleRSS.item_tags << 'im:rating'
      SimpleRSS.item_tags << 'im:version'

      feed = SimpleRSS.parse response.body

      return ["no items in feed at #{Time.now}"] if feed.items.length == 0
      # entries[0] is top article regarding Application.
      feed.items[1..post_count].each.map do |entry|
        <<-EOS
#{entry.updated.strftime('%Y-%m-%d').force_encoding('UTF-8')}: rating #{'*' * entry.im_rating.to_i}
#{entry.title.force_encoding('UTF-8')}#{entry.content.force_encoding('UTF-8')}
        EOS
      end
    end
  end
end

class HipChat
  def initialize(token)
    @token = token
  end

  def report(messages, room_id)
    # Use API v1 because used HipChat access_token is only for API v1.
    # https://api.hipchat.com/v1/rooms/message?format=json&auth_token=
    uri = URI.parse("https://api.hipchat.com/v1/rooms/message?format=json&auth_token=#{@token}")
    request = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    http.start do |h|
      messages.each do |message|
        request.set_form_data({
          room_id: room_id,
          from: 'review_reporter',
          message_format: 'text',
          message: message,
        })
        h.request(request)
      end
    end
  end
end
