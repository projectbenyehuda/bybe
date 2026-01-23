# frozen_string_literal: true

require 'rails_helper'

describe Admin::TagsController do
  include_context 'when editor logged in', 'moderate_tags'

  describe '#index' do
    subject { get :index, params: params }

    let(:params) { {} }

    before do
      create_list(:tag, 3, status: :approved)
      create_list(:tag, 2, status: :pending)
    end

    it { is_expected.to be_successful }

    it 'assigns tags' do
      subject
      expect(assigns(:tags).count).to eq(3) # default filter is approved
    end

    context 'when filtering by status' do
      let(:params) { { status: 'pending' } }

      it 'filters tags by status' do
        subject
        expect(assigns(:tags).count).to eq(2)
      end
    end

    context 'when status filter is empty string' do
      let(:params) { { status: '' } }

      it 'shows all tags regardless of status' do
        subject
        expect(assigns(:tags).count).to eq(5) # 3 approved + 2 pending
      end
    end

    context 'when searching by name' do
      let!(:searchable_tag) do
        tag = create(:tag, name: "פואטיקה-#{SecureRandom.hex(4)}")
        create(:tag_name, tag: tag, name: "פואטיקה-#{SecureRandom.hex(4)}")
        tag
      end

      let(:params) { { q: 'פואטיק', status: '' } }

      it 'finds tags by name substring' do
        subject
        expect(assigns(:tags)).to include(searchable_tag)
      end
    end
  end

  describe '#show' do
    subject { get :show, params: { id: tag.id } }

    let(:tag) { create(:tag) }

    before do
      create_list(:tag_name, 2, tag: tag)
    end

    it { is_expected.to be_successful }

    it 'assigns tag and tag_names' do
      subject
      expect(assigns(:tag)).to eq(tag)
      # Tag automatically creates 1 tag_name via callback, plus 2 we created = 3
      expect(assigns(:tag_names).count).to eq(3)
    end
  end

  describe '#new' do
    subject { get :new }

    it { is_expected.to be_successful }

    it 'assigns new tag' do
      subject
      expect(assigns(:tag)).to be_a_new(Tag)
    end
  end

  describe '#create' do
    subject(:call) { post :create, params: { tag: tag_params } }

    let(:tag_params) do
      {
        name: "תרבות עממית #{SecureRandom.hex(4)}",
        status: 'approved'
      }
    end

    let(:created_tag) { Tag.order(id: :desc).first }

    context 'when params are valid' do
      it 'creates tag and primary tag_name' do
        expect { call }.to change(Tag, :count).by(1)
                                              .and change(TagName, :count).by(1)
        expect(call).to redirect_to admin_tag_path(created_tag)
        expect(created_tag.name).to eq(tag_params[:name])
        expect(created_tag.creator).to eq(current_user)
        expect(created_tag.tag_names.first.name).to eq(tag_params[:name])
      end
    end

    context 'when params are invalid' do
      let(:tag_params) { { name: nil } }

      it 're-renders the new form' do
        expect { call }.not_to change(Tag, :count)
        expect(call).to have_http_status(:unprocessable_content)
        expect(call).to render_template(:new)
      end
    end
  end

  describe '#edit' do
    subject { get :edit, params: { id: tag.id } }

    let(:tag) { create(:tag) }

    it { is_expected.to be_successful }

    it 'assigns tag' do
      subject
      expect(assigns(:tag)).to eq(tag)
    end
  end

  describe '#update' do
    subject(:call) { patch :update, params: { id: tag.id, tag: tag_params }.merge(extra_params) }

    let(:tag) do
      name = "Old Name #{SecureRandom.hex(4)}"
      # Tag automatically creates a primary tag_name via callback
      create(:tag, name: name)
    end

    let(:tag_params) do
      {
        name: 'New Name',
        status: 'rejected'
      }
    end

    let(:extra_params) { {} }

    context 'when params are valid' do
      it 'updates tag' do
        expect { call }.to change { tag.reload.name }.to('New Name')
        expect(call).to redirect_to admin_tag_path(tag)
        expect(tag.reload.status).to eq('rejected')
      end
    end

    context 'when params are invalid' do
      let(:tag_params) { { name: nil } }

      it 're-renders the edit form' do
        expect { call }.not_to(change { tag.reload.name })
        expect(call).to have_http_status(:unprocessable_content)
        expect(call).to render_template(:edit)
      end
    end

    context 'when alias_name is provided' do
      let(:extra_params) { { alias_name: 'פויאטיקה' } }

      it 'adds the new alias even when primary_tag_name exists' do
        # Verify primary tag_name exists before the update
        expect(tag.tag_names.find_by(name: tag.name)).to be_present

        # Should add a new alias
        expect { call }.to change { tag.tag_names.count }.by(1)

        # Verify the new alias was created
        expect(tag.tag_names.reload.pluck(:name)).to include('פויאטיקה')

        # Should still update the tag
        expect(tag.reload.name).to eq('New Name')
      end

      context 'when alias_name is blank' do
        let(:extra_params) { { alias_name: '   ' } }

        it 'does not add an alias' do
          expect { call }.not_to(change { tag.tag_names.count })
        end
      end

      context 'when alias_name already exists' do
        let!(:existing_tag_name) { create(:tag_name, name: 'פויאטיקה') }
        let(:extra_params) { { alias_name: 'פויאטיקה' } }

        it 'does not create a duplicate TagName' do
          expect { call }.not_to(change { tag.tag_names.count })
          expect(call).to redirect_to admin_tag_path(tag)
        end
      end
    end
  end

  describe '#destroy' do
    subject(:call) { delete :destroy, params: { id: tag.id } }

    let!(:tag) { create(:tag) }

    before do
      create_list(:tagging, 2, tag: tag)
    end

    it 'destroys tag and associated taggings' do
      expect { call }.to change(Tag, :count).by(-1)
                                            .and change(Tagging, :count).by(-2)
      expect(call).to redirect_to admin_tags_path
    end
  end

  describe '#add_alias' do
    subject(:call) { post :add_alias, params: { id: tag.id, alias_name: alias_name } }

    let(:tag) { create(:tag) }

    context 'with valid alias name' do
      let(:alias_name) { 'פויאטיקה' }

      it 'creates new tag_name' do
        # Tag already has 1 tag_name from callback, we're adding 1 more
        expect { call }.to change { tag.tag_names.count }.by(1)
        expect(call).to redirect_to edit_admin_tag_path(tag)
        expect(tag.tag_names.reload.pluck(:name)).to include(alias_name)
      end
    end

    context 'with blank alias name' do
      let(:alias_name) { '   ' } # blank with spaces

      it 'does not create tag_name' do
        initial_count = tag.tag_names.count
        call
        expect(tag.tag_names.count).to eq(initial_count)
        expect(call).to redirect_to edit_admin_tag_path(tag)
      end
    end

    context 'with duplicate alias name' do
      let!(:existing_tag_name) { create(:tag_name, name: 'דופליקט') }
      let(:alias_name) { 'דופליקט' }

      it 'does not create duplicate tag_name' do
        # Force tag creation before checking initial count
        tag.id

        initial_count = TagName.count
        call

        expect(TagName.count).to eq(initial_count)
        expect(response).to redirect_to edit_admin_tag_path(tag)
        expect(flash[:alert]).to eq(I18n.t('admin.tags.alias_already_exists'))
      end
    end
  end

  describe '#make_primary_alias' do
    subject(:call) do
      post :make_primary_alias, params: { id: tag.id, tag_name_id: new_primary.id }
    end

    let(:tag) { create(:tag, name: "Old Primary #{SecureRandom.hex(4)}") }
    let!(:new_primary) { create(:tag_name, tag: tag, name: "New Primary #{SecureRandom.hex(4)}") }

    it 'changes the primary name' do
      expect { call }.to change { tag.reload.name }.to(new_primary.name)
      expect(call).to redirect_to edit_admin_tag_path(tag)
    end

    it 'persists the name change to the database' do
      old_name = tag.name
      call
      # Verify in database by loading a fresh instance
      fresh_tag = Tag.find(tag.id)
      expect(fresh_tag.name).to eq(new_primary.name)
      expect(fresh_tag.name).not_to eq(old_name)
    end

    it 'maintains all existing tag_names' do
      initial_count = tag.tag_names.count
      call
      expect(tag.tag_names.count).to eq(initial_count)
    end
  end

  describe '#remove_alias' do
    subject(:call) do
      delete :remove_alias, params: { id: tag.id, tag_name_id: alias_to_remove.id }
    end

    let(:tag) { create(:tag, name: "Primary Name #{SecureRandom.hex(4)}") }
    # Tag automatically creates primary_name via callback, so we don't create it again
    let(:primary_name) { tag.tag_names.find_by(name: tag.name) }
    let!(:alias_to_remove) { create(:tag_name, tag: tag, name: "Alias Name #{SecureRandom.hex(4)}") }

    context 'when removing non-primary alias' do
      it 'removes the alias' do
        expect { call }.to change(TagName, :count).by(-1)
        expect(call).to redirect_to edit_admin_tag_path(tag)
        expect(tag.tag_names.reload.pluck(:name)).not_to include(alias_to_remove.name)
      end
    end

    context 'when trying to remove primary alias' do
      subject(:call) do
        delete :remove_alias, params: { id: tag.id, tag_name_id: primary_name.id }
      end

      it 'does not remove the alias' do
        expect { call }.not_to change(TagName, :count)
        expect(call).to redirect_to edit_admin_tag_path(tag)
      end
    end

    context 'when trying to remove the last alias' do
      subject(:call) do
        delete :remove_alias, params: { id: tag.id, tag_name_id: only_name.id }
      end

      let(:tag) { create(:tag, name: "Only Name #{SecureRandom.hex(4)}") }
      # Tag callback creates the only tag_name
      let(:only_name) { tag.tag_names.first }

      it 'does not remove the alias' do
        expect { call }.not_to change(TagName, :count)
        expect(call).to redirect_to edit_admin_tag_path(tag)
      end
    end
  end

  describe 'permission check' do
    context 'when user does not have moderate_tags permission' do
      let(:editor_without_permission) { create(:user, editor: true) }

      before do
        session[:user_id] = editor_without_permission.id
      end

      it 'redirects to home page' do
        get :index
        expect(response).to redirect_to('/')
      end
    end
  end
end
