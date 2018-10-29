require "rubygems"
require "sequel"
require "nokogiri"
require "faraday"
require "json"
require "byebug"

require "./utils"

DB = Sequel.sqlite("idfa.sqlite")
client = Faraday.new("https://www.idfa.nl")

if !DB.table_exists?(:films)
  puts "The films table doesn't exist. Cannot select."
  abort
end

films_table = DB[:films]
ratings_table = DB[:ratings]

puts "You have rated #{ratings_table.count} of #{films_table.count} films:"
(0..3).each do |score|
  puts "  - #{ratings_table.where(score: score).count} films with score #{score}"
end

unrated_films = films_table
  .select_all(:films)
  .left_join(:ratings, "films.id = ratings.film_id")
  .where("ratings.film_id IS NULL")

previous_rating_id = nil
unrated_films.each do |event|
  puts "\n---\n\n"

  puts event[:title]
  puts "#{event[:duration]} minutes"
  puts "\n"
  puts event[:summary]
  puts "\n"
  puts event[:description]

  quit = false
  while true
    print "\nWhat do you want to do? Rate 0-3, s(kip), u(ndo previous), q(uit): "

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
        
        previous_rating_id = ratings_table.insert(film_id: event[:id], score: score)

        if score > 0
          puts "Rated with score #{"★ " * answer.to_i}!"
        else
          puts "Rated away."
        end

        break

      when "s"
        break

      when ""
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
