json.extract! lex_link, :id, :url, :description, :status, :item_id, :item_type, :created_at, :updated_at
json.url lex_link_url(lex_link, format: :json)
