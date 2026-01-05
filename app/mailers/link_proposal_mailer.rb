class LinkProposalMailer < ActionMailer::Base
  default from: "editor@benyehuda.org"

  # Send or queue notification based on recipient's email preferences
  def self.send_or_queue(method_name, recipient_email, *args)
    NotificationService.call(
      mailer_class: self,
      mailer_method: method_name,
      recipient_email: recipient_email,
      args: args
    )
  end

  # Subject can be set in your I18n file at config/locales/he.yml
  # with the following lookup:
  #
  #   he.link_proposal_mailer.approved.subject
  #
  def approved(link)
    @greeting = t(:hello_anon)
    @link = link
    @linkable = link.linkable
    mail to: link.proposer_email
  end

  # Subject can be set in your I18n file at config/locales/he.yml
  # with the following lookup:
  #
  #   he.link_proposal_mailer.rejected.subject
  #
  def rejected(link, moderator_note = nil)
    @greeting = t(:hello_anon)
    @link = link
    @linkable = link.linkable
    @moderator_note = moderator_note
    mail to: link.proposer_email
  end
end
