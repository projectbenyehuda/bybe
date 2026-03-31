class VolunteerProfile < ApplicationRecord
  # attr_accessible :name, :bio, :about, :profile_image
  has_attached_file :profile_image, styles: { full: '720x1040', medium: '360x520', thumb: '180x260', tiny: '90x120' },
                                    default_url: '/assets/:style/placeholder_man.jpg'
  validates_attachment_content_type :profile_image, content_type: /\Aimage\/.*\z/
  has_many :volunteer_profile_features, class_name: 'VolunteerProfileFeature', dependent: :destroy

  def featured_list
    s = ''
    volunteer_profile_features.each{ |vpf|
      s += '<br/>'+vpf.fromdate.strftime("%d-%m-%Y")+' '+I18n.t(:until)+' '+vpf.todate.strftime('%d-%m-%Y')
    }
    return s[5..-1] || ''
  end

end
