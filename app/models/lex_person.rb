class LexPerson < ApplicationRecord
  @@html_entities_coder = HTMLEntities.new
  has_one :lex_entry
  has_many :lex_links, as: :item, dependent: :destroy
  belongs_to :person
  
  def self.parse_bio(buf)
    ActionView::Base.full_sanitizer.sanitize(buf)
  end
  def self.parse_books(buf)
    buf.scan(/<li>(.*?)<\/li>/m).map{|x| x.class == Array ? PandocRuby.convert(x[0], M: 'dir=rtl', from: :html, to: :markdown_mmd).gsub("\n",' ').force_encoding('UTF-8') : ''}.join("\n")
  end
  def self.parse_bib(buf)
    #buf.scan(/<li>(.*?)<\/li>/).map{|x| x.class == Array ? @@html_entities_coder.decode(x[0].gsub(/<font.*?>/,'').gsub(/<\/font>/,'')) : ''}
    buf.scan(/<li>(.*?)<\/li>/m).map{|x| x.class == Array ? PandocRuby.convert(x[0], M: 'dir=rtl', from: :html, to: :markdown_mmd).gsub("\n",' ').force_encoding('UTF-8') : ''}.join("\n")
  end
  def self.parse_links(person, buf)
    buf.scan(/<li>(.*?)<\/li>/m).map{|x| x.class == Array ? @@html_entities_coder.decode(x[0].gsub(/<font.*?>/,'').gsub(/<\/font>/,'')) : ''}.map{ |linkstring| 
      if linkstring =~ /(.*?)<a .*? href="(.*?)".*?>(.*?)<\/a>(.*)/m
        link = LexLink.new(url: $2, description: "#{$1} #{$3} #{$4}")
        person.lex_links << link
        link.save!
      else
        nil
      end
    }
  end
  def self.create_from_html(entry, lexfile)
    if entry.lex_item.present? 
      return entry.lex_item
    else
      buf = File.open(lexfile.full_path).read
      anchors = buf.scan(/<a name="(.*?)">/)
      # ret['links'] = parse_links(buf[/a name="links".*?<\/ul/m])
      @lex_person = LexPerson.new(bio: parse_bio(buf[/<\/table>.*?<a name="Books/m]), works: parse_books(buf[/a name="Books".*?<a name/m]), about: parse_bib(buf[/a name="Bib.".*?<a name/m]))
      @lex_person.save!
      parse_links(@lex_person, buf[/a name="links".*?<\/ul/m])
      return @lex_person
      #     t.string "aliases"
      #t.string "birthdate"
      #t.string "deathdate"
    end
  end

end

# ["Books"]=>4325, ["Bib."]=>3896, ["links"]=>3879, ["top"]=>179, ["no1"]=>67, ["no2"]=>65, ["no3"]=>52, ["no14-15"]=>3, ["no18"]=>8, ["no19"]=>7, ["no20"]=>6, ["Bib.1"]=>3, ["no410"]=>1, ["no411"]=>1, ["no412"]=>1, ["HLN3"]=>3, ["no0101"]=>2, ["no0102"]=>2, ["no010304"]=>2, ["no010506"]=>2, ["no21-22"]=>1, ["no307"]=>2, ["no308"]=>2, ["no309-310"]=>1, ["no311"]=>1, ["no312-313"]=>1, ["no314"]=>2, ["no315"]=>2, ["no316"]=>2, ["no360"]=>4, ["no359"]=>12, ["5552"]=>1, ["5261"]=>3, ["5472"]=>1, ["5502"]=>1, ["5502\" href=\"01227.php"]=>1, ["5433"]=>1, ["5162"]=>3, ["5350"]=>3, ["5350\" href=\"00386.php"]=>1, ["5352"]=>3, ["5352\" href=\"00386.php"]=>1, ["5345"]=>3, ["5
