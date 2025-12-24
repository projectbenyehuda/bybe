def clean_tables
  Tagging.destroy_all
  Tag.destroy_all
  ExternalLink.destroy_all
  Recommendation.destroy_all

  InvolvedAuthority.destroy_all

  CorporateBody.destroy_all
  Person.destroy_all
  Authority.destroy_all

  Aboutness.destroy_all

  ListItem.destroy_all
  ActiveRecord::SessionStore::Session.delete_all
  BaseUser.destroy_all
  User.destroy_all

  Proof.destroy_all
  Manifestation.destroy_all
  Expression.destroy_all
  Work.destroy_all

  CollectionItem.delete_all
  Collection.delete_all

  Publication.destroy_all
  Holding.destroy_all
  BibSource.destroy_all

  Ahoy::Event.delete_all
  Ahoy::Visit.delete_all

  # Cleaning-up ElasticSearch indices
  Chewy.massacre
end
