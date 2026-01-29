# frozen_string_literal: true

require 'rails_helper'

describe Admin::FeaturedAuthorsController do
  include_context 'when editor logged in'

  describe '#index' do
    subject { get :index }

    before do
      create_list(:featured_author, 5)
    end

    it { is_expected.to be_successful }
  end

  describe '#new' do
    subject { get :new }

    it { is_expected.to be_successful }
  end

  describe '#create' do
    subject(:call) { post :create, params: { person_id: person.id, featured_author: featured_author_params } }

    let(:person) { create(:authority).person }

    let(:featured_author_params) do
      {
        title: title,
        body: Faker::Lorem.paragraph
      }
    end

    let(:created_featured_author) { FeaturedAuthor.order(id: :desc).first }

    context 'when params are valid' do
      let(:title) { Faker::Book.title }

      it 'creates record' do
        expect { call }.to change(FeaturedAuthor, :count).by(1)
        expect(call).to redirect_to admin_featured_author_path(created_featured_author)
        expect(created_featured_author).to have_attributes(featured_author_params)
        expect(created_featured_author.user).to eq current_user
        expect(created_featured_author.person).to eq person
      end
    end

    context 'when params are invalid' do
      let(:title) { nil }

      it 're-renders the new form' do
        expect { call }.not_to change(FeaturedAuthor, :count)
        expect(call).to have_http_status(:unprocessable_content)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'member actions' do
    let(:featured_author) { create(:featured_author) }

    describe '#show' do
      subject { get :show, params: { id: featured_author.id } }

      it { is_expected.to be_successful }
    end

    describe '#edit' do
      subject { get :edit, params: { id: featured_author.id } }

      it { is_expected.to be_successful }
    end

    describe '#update' do
      subject(:call) { patch :update, params: { id: featured_author.id, featured_author: featured_author_params } }

      let(:new_person) { create(:authority).person }

      context 'when params are valid' do
        let(:featured_author_params) do
          {
            title: 'new_title',
            body: 'new_body'
          }
        end

        it 'updates record and redirects to show page' do
          expect(call).to redirect_to admin_featured_author_path(featured_author)
          featured_author.reload
          expect(featured_author).to have_attributes(featured_author_params)
        end
      end

      context 'when params are invalid' do
        let(:featured_author_params) { { title: '', body: '' } }

        it 're-renders the edit form' do
          expect(call).to have_http_status(:unprocessable_content)
          expect(call).to render_template(:edit)
        end
      end
    end

    describe '#destroy' do
      subject(:call) { delete :destroy, params: { id: featured_author.id } }

      before do
        featured_author
      end

      it 'removes record' do
        expect { call }.to change(FeaturedAuthor, :count).by(-1)
        expect(call).to redirect_to admin_featured_authors_path
      end
    end
  end
end
