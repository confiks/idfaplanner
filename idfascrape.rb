require "rubygems"
require "sequel"
require "nokogiri"
require "faraday"
require "json"
require "byebug"

require "./utils"

DB = Sequel.sqlite("idfa.sqlite")
client = Faraday.new("https://www.idfa.nl")

if DB.table_exists?(:films)
  puts "The films table already exists. Refusing to scrape."
  abort
end

DB.create_table :films do
  primary_key :id
  
  String :uuid
  String :title
  String :summary
  Integer :duration
  String :details_path
end

DB.create_table :ratings do
  primary_key :id

  Integer :film_id
  Integer :score
end

(15..26).each do |day|
  puts "\nScraping #{day} november"

  state = Utils.state_from_html(
    client.get("/nl/blokkenschema?filters[formattedDate]=#{day} november").body
  )

  schedule = state["schedule"]["schedule"]
  total_pages = schedule["pagination"]["totalPages"]
  raise ArgumentError, "Too much items for a single page (#{total_pages.inspect})" if total_pages != 1

  schedule["items"].each do |item|
    if DB[:films].where(title: item["title"]).count > 0
      print "x"
      next
    end

    print "."

    DB[:films].insert({
      uuid: item["fionaId"],
      title: Nokogiri::HTML.parse(item["title"]).text,
      summary: Nokogiri::HTML.parse(item["summary"]).text,
      duration: item["duration"],
      details_path: item["uri"],
    })
  end
end
