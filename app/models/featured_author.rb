class FeaturedAuthor < ApplicationRecord
  belongs_to :user
  belongs_to :person
  validates :title, :body, presence: true

#  attr_accessible :title, :body
  has_many :featurings, class_name: 'FeaturedAuthorFeature', dependent: :destroy

  def featured_list
    s = ''
    featurings.each{ |fcf|
      s += '<br/>'+fcf.fromdate.strftime("%d-%m-%Y")+' '+I18n.t(:until)+' '+fcf.todate.strftime('%d-%m-%Y')
    }
    return s[5..-1] || ''
  end

end
