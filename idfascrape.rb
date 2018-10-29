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
  String :description
  Integer :subfilm_amount
  Integer :duration
  String :details_path
end

DB.create_table :film_screenings do
  primary_key :id

  Integer :film_id
  String :location
  Integer :duration
  DateTime :start_time
end

DB.create_table :ratings do
  primary_key :id

  Integer :film_id
  Integer :score
end

def add_film_screening(film_id, event)
  DB[:film_screenings].insert({
    film_id: film_id,
    location: event["location"]["name"],
    duration: event["duration"],
    start_time: DateTime.new(
      2018, 11, event["date"].gsub(/[^0-9]/, "").to_i, 
      event["startTime"]["hours"].to_i, event["startTime"]["minutes"].to_i
    ),
  })
end

(14..25).each do |day|
  puts "\nScraping #{day} November"

  # Get day result page
  day_name = Date.new(2018, 11, day).strftime("%A")
  state = Utils.state_from_html(
    client.get("/en/schedule-list?filters[formattedDate]=#{day_name} #{day} November&filters[time]=0&filters[screeningType]=Public").body
  )

  # Grab the schedule, and see if there is any pagination
  schedule = state["schedule"]["schedule"]
  total_pages = schedule["pagination"]["totalPages"]
  raise ArgumentError, "Too much items for a single page (#{total_pages.inspect})" if total_pages != 1

  schedule["items"].each do |event|
    # Skip events that have no films (for example a party event)
    if event["films"].length == 0
      print "X"
      next
    end

    # Don't reinsert films that are already present (based on the title), but add a screening
    duplicate_films = DB[:films].where(title: event["title"])
    if duplicate_films.count > 0
      print ":"
      add_film_screening(duplicate_films.first[:id], event)
      next
    end

    print "."

    film_id = DB[:films].insert({
      uuid: event["fionaId"],
      title: Nokogiri::HTML.parse(event["title"]).text,
      summary: Nokogiri::HTML.parse(event["summary"]).text,
      description: event["films"].map do |subfilm| 
        Nokogiri::HTML.parse(subfilm["info"]["general"]["synopsis"]).text.gsub("\n", "") + "\n\n"
      end.join,
      subfilm_amount: event["films"].length,
      duration: event["duration"],
      details_path: event["uri"],
    })

    add_film_screening(film_id, event)
  end
end
