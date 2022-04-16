json.extract! lex_text, :id, :title, :authors, :pages, :lex_publication_id, :lex_issue_id, :manifestation_id, :created_at, :updated_at
json.url lex_text_url(lex_text, format: :json)
