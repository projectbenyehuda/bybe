class Notifications < ActionMailer::Base
  default from: "editor@benyehuda.org" # TODO: un-hardcode

  # Send or queue notification based on recipient's email preferences
  def self.send_or_queue(method_name, recipient_email, *args)
    NotificationService.call(
      mailer_class: self,
      mailer_method: method_name,
      recipient_email: recipient_email,
      args: args
    )
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.proof_fixed.subject
  #
  def proof_fixed(proof, url, m, explanation)
    @greeting = t(:hello_anon)
    @proof = proof
    @url = url
    unless m.nil?
      @url = 'https://benyehuda.org'+@url # TODO: un-hardcode
    end
    @m = m
    @explanation = explanation
    mail to: proof.from
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   he.notifications.tag_approved.subject
  def tag_approved(tag)
    @greeting = t(:hello_anon)
    @tag = tag
    mail to: tag.creator.email
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   he.notifications.tag_merged.subject
  def tag_merged(orig_name, suggester, destination_tag)
    @greeting = t(:hello_anon)
    @orig_tag_name = orig_name
    @suggester = suggester.name
    @tag = destination_tag
    mail to: suggester.email
  end

  def tagging_approved(tagging)
    @greeting = t(:hello_anon)
    @tagging = tagging
    mail to: tagging.suggester.email
  end

  def tagging_rejected(tagging, explanation)
    @greeting = t(:hello_anon)
    @tagging = tagging
    @explanation = explanation
    mail to: tagging.suggester.email
  end

  def tagging_merged(tagging, original_tagname, suggester) # is this used?
    @greeting = t(:hello_anon)
    @original_tagname = original_tagname
    @tagging_suggester = suggester.name
    @tagging = tagging
    @tag = tagging.tag
    mail to: suggester.email
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   he.notifications.tag_rejected.subject
  def tag_rejected(tag, explanation, orig_name = nil)
    @greeting = t(:hello_anon)
    @tag = tag
    @explanation = explanation
    @name = orig_name ? orig_name : @tag.name
    mail to: tag.creator.email
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   he.notifications.warn.subject
  def warn(user, msg)
    @greeting = t(:hello_anon)
    @user = user
    @msg = msg
    mail to: [user.email, Rails.configuration.constants[:editor_email]]
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   he.notifications.block.subject
  def block(user, msg)
    @greeting = t(:hello_anon)
    @user = user
    @msg = msg
    mail to: [user.email, Rails.configuration.constants[:editor_email]]
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.proof_wontfix.subject
  #
  def proof_wontfix(proof, url, m, explanation)
    @greeting = t(:hello_anon)
    @proof = proof
    @url = url
    @explanation = explanation
    unless m.nil?
      @url = 'https://benyehuda.org'+@url # TODO: un-hardcode
    end
    @m = m
    mail to: proof.from
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.recommendation_accepted.subject
  #
  def recommendation_accepted(rec, url)
    @greeting = t(:hello_anon)
    @rec = rec
    @url = url

    mail to: rec.from
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications.recommendation_published.subject
  #
  def recommendation_published(rec, html_url, blog_url)
    @greeting = t(:hello_anon)
    @published_url = blog_url
    @rec = rec
    @url = html_url
    mail to: rec.from
  end

  def contact_form_submitted(pp)
    @contact_form = {name: pp[:name], email: pp[:email], phone: pp[:phone], topic: pp[:topic] || pp[:rtopic], body: pp[:body]}
    mail to: 'editor@benyehuda.org', subject: t('notifications.contact_form_submitted.subject'), reply_to: pp[:email]
  end

  def volunteer_form_submitted(pp)
    @form = pp
    mail to: 'editor@benyehuda.org', subject: t('notifications.volunteer_form_submitted.subject'), reply_to: pp[:email]
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   he.notifications.notification_digest.subject
  def notification_digest(recipient_email, notifications)
    @greeting = t(:hello_anon)
    @notifications = notifications
    mail to: recipient_email
  end
end
