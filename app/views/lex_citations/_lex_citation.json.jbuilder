json.extract! lex_citation, :id, :title, :from_publication, :authors, :pages, :link, :item_id, :item_type, :manifestation_id, :created_at, :updated_at
json.url lex_citation_url(lex_citation, format: :json)
