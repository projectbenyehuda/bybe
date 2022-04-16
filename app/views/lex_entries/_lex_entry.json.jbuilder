json.extract! lex_entry, :id, :title, :status, :lex_person_id, :lex_publication_id, :created_at, :updated_at
json.url lex_entry_url(lex_entry, format: :json)
