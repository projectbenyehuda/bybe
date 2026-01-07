# frozen_string_literal: true

require 'rails_helper'

describe UserController do
  include_context 'Admin user logged in'

  let!(:test_user) { create(:user, name: 'Test User') }

  describe '#list' do
    context 'without filters' do
      it 'lists all users' do
        get :list
        expect(response).to be_successful
        expect(assigns(:user_list)).to include(test_user)
      end
    end

    context 'with filter' do
      let!(:other_user) { create(:user, name: 'Other User') }

      it 'filters users by query' do
        get :list, params: { q: 'Test' }
        expect(response).to be_successful
        expect(assigns(:user_list)).to include(test_user)
        expect(assigns(:user_list)).not_to include(other_user)
      end
    end

    context 'with role filters' do
      let!(:editor_user) { create(:user, name: 'Editor User', editor: true) }
      let!(:admin_user) { create(:user, name: 'Admin User', admin: true) }
      let!(:crowdsourcer_user) { create(:user, name: 'Crowdsourcer User', crowdsourcer: true) }
      let!(:regular_user) { create(:user, name: 'Regular User') }

      it 'filters users by editor status' do
        get :list, params: { filter_editor: '1' }
        expect(response).to be_successful
        expect(assigns(:user_list)).to include(editor_user)
        expect(assigns(:user_list)).not_to include(regular_user)
        expect(assigns(:user_list)).not_to include(admin_user)
        expect(assigns(:user_list)).not_to include(crowdsourcer_user)
      end

      it 'filters users by admin status' do
        get :list, params: { filter_admin: '1' }
        expect(response).to be_successful
        expect(assigns(:user_list)).to include(admin_user)
        expect(assigns(:user_list)).not_to include(regular_user)
        expect(assigns(:user_list)).not_to include(editor_user)
        expect(assigns(:user_list)).not_to include(crowdsourcer_user)
      end

      it 'filters users by crowdsourcer status' do
        get :list, params: { filter_crowdsourcer: '1' }
        expect(response).to be_successful
        expect(assigns(:user_list)).to include(crowdsourcer_user)
        expect(assigns(:user_list)).not_to include(regular_user)
        expect(assigns(:user_list)).not_to include(editor_user)
        expect(assigns(:user_list)).not_to include(admin_user)
      end

      it 'filters users by multiple role filters' do
        get :list, params: { filter_editor: '1', filter_admin: '1' }
        expect(response).to be_successful
        # Should show both editors and admins
        expect(assigns(:user_list)).to include(editor_user)
        expect(assigns(:user_list)).to include(admin_user)
        expect(assigns(:user_list)).not_to include(regular_user)
        expect(assigns(:user_list)).not_to include(crowdsourcer_user)
      end

      it 'combines text search with role filters' do
        get :list, params: { q: 'Editor', filter_editor: '1' }
        expect(response).to be_successful
        expect(assigns(:user_list)).to include(editor_user)
        expect(assigns(:user_list)).not_to include(regular_user)
        expect(assigns(:user_list)).not_to include(admin_user)
      end

      it 'sets instance variables for filter checkboxes' do
        get :list, params: { filter_editor: '1', filter_admin: '1' }
        expect(assigns(:filter_editor)).to be true
        expect(assigns(:filter_admin)).to be true
        expect(assigns(:filter_crowdsourcer)).to be_falsey
      end
    end

    context 'with pagination' do
      before do
        create_list(:user, 30)
      end

      it 'paginates users' do
        get :list, params: { page: 2 }
        expect(response).to be_successful
        expect(assigns(:user_list).current_page).to eq(2)
      end
    end
  end

  describe '#make_crowdsourcer' do
    it 'preserves query and page parameters' do
      get :make_crowdsourcer, params: { id: test_user.id, q: 'Test', page: 2 }
      expect(response).to redirect_to(action: :list, q: 'Test', page: 2)
      test_user.reload
      expect(test_user.crowdsourcer).to be true
    end

    it 'preserves filter parameters' do
      get :make_crowdsourcer, params: {
        id: test_user.id,
        q: 'Test',
        page: 2,
        filter_editor: '1',
        filter_admin: '1'
      }
      expect(response).to redirect_to(
        action: :list,
        q: 'Test',
        page: 2,
        filter_editor: '1',
        filter_admin: '1',
        filter_crowdsourcer: nil
      )
    end
  end

  describe '#make_editor' do
    it 'preserves query and page parameters' do
      get :make_editor, params: { id: test_user.id, q: 'Test', page: 2 }
      expect(response).to redirect_to(action: :list, q: 'Test', page: 2)
      test_user.reload
      expect(test_user.editor).to be true
    end

    it 'preserves filter parameters' do
      get :make_editor, params: {
        id: test_user.id,
        filter_editor: '1',
        filter_crowdsourcer: '1'
      }
      expect(response).to redirect_to(
        action: :list,
        q: nil,
        page: nil,
        filter_editor: '1',
        filter_admin: nil,
        filter_crowdsourcer: '1'
      )
    end
  end

  describe '#make_admin' do
    it 'preserves query and page parameters' do
      get :make_admin, params: { id: test_user.id, q: 'Test', page: 2 }
      expect(response).to redirect_to(action: :list, q: 'Test', page: 2)
      test_user.reload
      expect(test_user.admin).to be true
    end

    it 'preserves filter parameters' do
      get :make_admin, params: {
        id: test_user.id,
        filter_admin: '1'
      }
      expect(response).to redirect_to(
        action: :list,
        q: nil,
        page: nil,
        filter_editor: nil,
        filter_admin: '1',
        filter_crowdsourcer: nil
      )
    end
  end

  describe '#unmake_editor' do
    before { test_user.update!(editor: true) }

    it 'preserves query and page parameters' do
      get :unmake_editor, params: { id: test_user.id, q: 'Test', page: 2 }
      expect(response).to redirect_to(action: :list, q: 'Test', page: 2)
      test_user.reload
      expect(test_user.editor).to be false
    end
  end

  describe '#unmake_crowdsourcer' do
    before { test_user.update!(crowdsourcer: true) }

    it 'preserves query and page parameters' do
      get :unmake_crowdsourcer, params: { id: test_user.id, q: 'Test', page: 2 }
      expect(response).to redirect_to(action: :list, q: 'Test', page: 2)
      test_user.reload
      expect(test_user.crowdsourcer).to be false
    end
  end

  describe '#set_editor_bit' do
    before { test_user.update!(editor: true) }

    it 'preserves query and page parameters when adding a bit' do
      post :set_editor_bit, params: {
        id: test_user.id,
        bit: 'handle_proofs',
        set_to: '1',
        q: 'Test',
        page: 2
      }
      expect(response).to redirect_to(action: :list, q: 'Test', page: 2)
      expect(ListItem.where(listkey: 'handle_proofs', item: test_user)).to exist
    end

    it 'preserves query and page parameters when removing a bit' do
      ListItem.create!(listkey: 'handle_proofs', item: test_user)

      post :set_editor_bit, params: {
        id: test_user.id,
        bit: 'handle_proofs',
        set_to: '0',
        q: 'Test',
        page: 2
      }
      expect(response).to redirect_to(action: :list, q: 'Test', page: 2)
      expect(ListItem.where(listkey: 'handle_proofs', item: test_user)).not_to exist
    end

    it 'preserves filter parameters' do
      post :set_editor_bit, params: {
        id: test_user.id,
        bit: 'handle_proofs',
        set_to: '1',
        filter_editor: '1',
        filter_admin: '1'
      }
      expect(response).to redirect_to(
        action: :list,
        q: nil,
        page: nil,
        filter_editor: '1',
        filter_admin: '1',
        filter_crowdsourcer: nil
      )
    end
  end
end
