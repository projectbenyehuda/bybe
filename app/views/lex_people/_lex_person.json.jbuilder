json.extract! lex_person, :id, :aliases, :copyrighted, :birthdate, :deathdate, :bio, :works, :about, :created_at, :updated_at
json.url lex_person_url(lex_person, format: :json)
