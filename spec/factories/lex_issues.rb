FactoryBot.define do
  factory :lex_issue do
    subtitle { "MyString" }
    volume { "MyString" }
    issue { "MyString" }
    seq_num { 1 }
    toc { "MyText" }
    lex_publication { nil }
  end
end
