require "rubygems"
require "sequel"
require "nokogiri"
require "faraday"
require "byebug"

DB = Sequel.sqlite("db.sqlite")
client = Faraday.new("https://www.idfa.nl")

if !DB.table_exists?(:films)
  print "Scraping... "

  DB.create_table :films do
    primary_key :id
    String :name
    String :description
    
    String :image_url
    String :details_path
  end

  DB.create_table :ratings do
    primary_key :id
    Integer :film_id
    Integer :score
  end

  films_table = DB[:films]

  (["0"] + ("A".."Z").to_a).each do |startwith|
    print startwith

    doc = Nokogiri::HTML(
      client.get("/nl/festival/films-events-temp.aspx?startwith=#{startwith}").body
    )

    doc.css(".rgMasterTable tbody tr td div.film").each do |film_div|
      film = {}

      film[:image_url] = film_div.css("div.image img").attribute("src").value
      film[:details_path] = film_div.css("h5 a").attribute("href").value
      
      text_div = film_div.css("div.text")
      film[:name] = text_div.css("h5").text.strip

      text_div.css("h5, b, a").remove
      film[:description] = text_div.text.strip

      films_table.insert(film)
    end
  end

  print "\n"

else
  puts "The films table already exists. Skipping scrape phase.\n\n"
end

films_table = DB[:films]
ratings_table = DB[:ratings]

puts "You have rated #{ratings_table.count} of #{films_table.count} films:"
(0..3).each do |score|
  puts "  - #{ratings_table.where(score: score).count} films with score #{score}"
end

unrated_films = DB[:films]
  .select_all(:films)
  .left_join(:ratings, "films.id = ratings.film_id")
  .where("ratings.film_id IS NULL")

previous_rating_id = nil
unrated_films.each do |film|
  puts "\n---\n\n"

  puts film[:name]
  puts film[:description]

  quit = false
  while true
    print "\nWhat do you want to do? Rate 0-3, l(ong description), s(kip), u(ndo previous), q(uit): "

    begin
      answer = gets.strip
    rescue SystemExit, Interrupt
      print "\n"
      answer = "q"
    end

    case answer
      when "`", "§", "0", "1", "2", "3"
        if answer == "`" || answer == "§"
          score = 0
        else
          score = answer.to_i
        end
        
        previous_rating_id = ratings_table.insert(film_id: film[:id], score: score)

        if score > 0
          puts "Rated with score #{"★ " * answer.to_i}!"
        else
          puts "Rated away."
        end

        break

      when "l"
        synopsis_span = Nokogiri::HTML(
          client.get(film[:details_path]).body
        ).css(".synopsis-container .syn-synopsis")

        puts "\n#{synopsis_span.text.strip}"

      when "s"
        break

      when "u"
        if !previous_rating_id
          puts "No previous rating to undo."
        else
          ratings_table.where("id = ?", previous_rating_id).delete
          previous_rating_id = nil

          puts "Removed previous rating. Re-run script to rate again."
        end

      when "q"
        puts "Bye!"
        quit = true
        break

      else
        puts "Unrecognized answer '#{answer}'. Try again."
    end
  end

  break if quit
end
