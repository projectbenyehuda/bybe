json.extract! lex_file, :id, :fname, :status, :title, :entrytype, :comments, :created_at, :updated_at
json.url lex_file_url(lex_file, format: :json)
