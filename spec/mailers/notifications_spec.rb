# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications, type: :mailer do
  describe 'handling deleted users' do
    let(:user) { create(:user) }

    describe '#tag_approved' do
      context 'when creator exists' do
        let(:tag) { create(:tag, creator: user) }
        let(:mail) { described_class.tag_approved(tag) }

        it 'sends email to creator' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes creator name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when creator is nil (deleted user)' do
        let(:tag) { create(:tag, creator: user) }

        before do
          # Simulate user deletion by setting creator_id to nil
          tag.update_column(:created_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tag_approved(tag)
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tag_approved(tag) }.not_to raise_error
        end
      end
    end

    describe '#tag_rejected' do
      context 'when creator exists' do
        let(:tag) { create(:tag, creator: user) }
        let(:mail) { described_class.tag_rejected(tag, 'Not relevant') }

        it 'sends email to creator' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes creator name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when creator is nil (deleted user)' do
        let(:tag) { create(:tag, creator: user) }

        before do
          tag.update_column(:created_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tag_rejected(tag, 'Not relevant')
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tag_rejected(tag, 'Not relevant') }.not_to raise_error
        end
      end
    end

    describe '#tagging_approved' do
      context 'when suggester exists' do
        let(:tagging) { create(:tagging, suggester: user) }
        let(:mail) { described_class.tagging_approved(tagging) }

        it 'sends email to suggester' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes suggester name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when suggester is nil (deleted user)' do
        let(:tagging) { create(:tagging, suggester: user) }

        before do
          tagging.update_column(:suggested_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tagging_approved(tagging)
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tagging_approved(tagging) }.not_to raise_error
        end
      end
    end

    describe '#tagging_rejected' do
      context 'when suggester exists' do
        let(:tagging) { create(:tagging, suggester: user) }
        let(:mail) { described_class.tagging_rejected(tagging, 'Not relevant') }

        it 'sends email to suggester' do
          expect(mail.to).to eq([user.email])
        end

        it 'includes suggester name in body' do
          expect(mail.body.encoded).to include(user.name)
        end
      end

      context 'when suggester is nil (deleted user)' do
        let(:tagging) { create(:tagging, suggester: user) }

        before do
          tagging.update_column(:suggested_by, nil)
        end

        it 'does not send email' do
          mail = described_class.tagging_rejected(tagging, 'Not relevant')
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end

        it 'does not crash' do
          expect { described_class.tagging_rejected(tagging, 'Not relevant') }.not_to raise_error
        end
      end
    end
  end
end
