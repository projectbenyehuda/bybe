json.extract! lex_issue, :id, :subtitle, :volume, :issue, :seq_num, :toc, :lex_publication_id, :created_at, :updated_at
json.url lex_issue_url(lex_issue, format: :json)
