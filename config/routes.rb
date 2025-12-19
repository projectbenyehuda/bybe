include BybeUtils

Bybeconv::Application.routes.draw do
  get 'periodicals', to: 'periodicals#index', as: 'periodicals_index'
  get 'periodicals/show'
  get 'collections_migration/index'
  get 'collections_migration/person'
  post 'collections_migration/migrate'
  post 'collections_migration/create_collection'
  namespace :admin do
    resources :featured_contents do
      resources :features, controller: 'featured_content_features', only: %i(create)
    end
    resources :featured_content_features, only: %i(destroy)

    resources :projects

    resources :authorities, only: [] do
      member do
        post :refresh_uncollected_works_collection
      end
    end
  end

  resources :ingestibles do
    resources :authorities, controller: :ingestible_authorities, only: %i(create destroy) do
      member do
        post :replace
      end
    end
    resources :collection_authorities, controller: :ingestible_collection_authorities, only: %i(create destroy) do
      member do
        post :replace
      end
    end
    resources :texts, controller: :ingestible_texts, only: %i(edit update)
    member do
      get :review
      patch :update_markdown
      patch :update_toc
      post :update_toc_list
      get :edit_toc
      post :ingest
      post :undo
      patch :unlock
    end
  end

  resources :collection_items, only: %i(create show edit update destroy) do
    member do
      post :drag_item
      post :transplant_item
    end
  end

  resources :collections, only: %i(show create update destroy) do
    get 'manage'
    post 'download'
    get 'print'
    get 'kwic'
    get 'kwic_download'
    get 'kwic_context/:manifestation_id/:paragraph', action: :kwic_context, as: :kwic_context
    get 'periodical_issues'
    post 'add_periodical_issue'
    post 'add_external_link'
    post 'remove_external_link'
  end

  # Not inside resources block because it doesn't require a collection_id (creates new periodical)
  post 'collections/create_periodical_with_issue' => 'collections#create_periodical_with_issue',
       as: 'create_periodical_with_issue'

  get 'autocomplete_publication_title' => 'admin#autocomplete_publication_title', as: 'autocomplete_publication_title'
  get 'autocomplete_collection_title' => 'admin#autocomplete_collection_title', as: 'autocomplete_collection_title'
  get 'autocomplete_authority_name_and_aliases' => 'admin#autocomplete_authority_name_and_aliases',
      as: 'autocomplete_authority_name_and_aliases'
  match 'author/:id/manage_toc' => 'authors#manage_toc', as: 'authors_manage_toc', via: %i(get post)

  resources :involved_authorities, only: %i(index create destroy)

  resources :user_blocks
  resource :user_preferences, only: %i(edit update)
  get 'crowd/index'
  get 'crowd/populate_edition' => 'crowd#populate_edition', as: 'crowd_populate_edition'
  get 'crowd/populate_edition/:id' => 'crowd#populate_edition', as: 'crowd_populate_edition_id'
  post 'crowd/do_populate_edition' => 'crowd#do_populate_edition', as: 'crowd_do_populate_edition'
  resources :lex_files
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  mount V1::Api => '/'

  resources :anthology_texts do
    post 'mass_create', on: :collection
    get 'confirm_destroy'
  end

  resources :anthologies
  match 'anthologies/print/:id' => 'anthologies#print', as: 'anthology_print', via: %i(get post)
  match 'anthologies/download/:id' => 'anthologies#download', as: 'anthology_download', via: %i(get post)
  match 'anthologies/seq/:id' => 'anthologies#seq', as: 'anthology_seq', via: %i(get post)
  get 'anthologies/clone/:id' => 'anthologies#clone', as: 'anthology_clone'
  resources :news_items
  resources :bib_sources
  resources :holdings
  resources :publications
  get 'bib/index'
  get 'bib/scans' => 'bib#scans', as: 'bib_scans'
  get 'bib/authority/:authority_id' => 'bib#authority', as: 'bib_authority'
  match 'bib/pubs_by_authority', via: %i(get post)
  get 'bib/pubs_maybe_done'
  get 'bib/publication_mark_false_positive/:id' => 'bib#publication_mark_false_positive',
      as: 'publication_mark_false_positive'
  get 'bib/make_scanning_task/:id' => 'bib#make_scanning_task', as: 'bib_make_scanning_task'
  get 'bib/todo_by_location'
  get 'bib/holding_status/:id' => 'bib#holding_status', as: 'holding_status'
  post 'bib/make_author_page'
  match 'bib/shopping/:source_id' => 'bib#shopping', as: 'bib_shopping', via: %i(get post)

  get 'aboutnesses/remove'

  get 'static_pages/render'

  get 'admin/index'
  get 'admin/missing_languages'
  get 'admin/missing_genres'
  get 'admin/missing_copyright'
  get 'admin/missing_images'
  get 'admin/messy_tocs'
  get 'admin/tocs_missing_links'
  match 'admin/authors_without_works', via: %i(get post)
  get 'admin/incongruous_copyright'
  get 'admin/suspicious_headings'
  get 'admin/texts_between_dates'
  get 'admin/authority_records_between_dates'
  get 'admin/first_manifestations_between_dates'
  get 'admin/suspicious_titles'
  get 'admin/slash_in_titles'
  get 'admin/similar_titles'
  get 'admin/periodless'
  get 'admin/suspicious_translations'
  get 'admin/mark_similar_as_valid/:id' => 'admin#mark_similar_as_valid', as: 'mark_similar_as_valid'
  get 'admin/mark_slash_title_as_okay/:item_type/:id' => 'admin#mark_slash_title_as_okay',
      as: 'mark_slash_title_as_okay'
  get 'admin/translated_from_multiple_languages'
  get 'admin/raw_tocs'
  get 'admin/my_convs/:id' => 'admin#my_convs', as: 'my_convs'
  get 'admin/tag_moderation' => 'admin#tag_moderation', as: 'tag_moderation'
  get 'admin/tag_review/:id' => 'admin#tag_review', as: 'tag_review'
  get 'admin/tagging_review/:id' => 'admin#tagging_review', as: 'tagging_review'
  post 'admin/approve_tag/:id' => 'admin#approve_tag', as: 'approve_tag'
  post 'admin/approve_tag_and_next/:id' => 'admin#approve_tag_and_next', as: 'approve_tag_and_next'
  post 'admin/reject_tag/:id' => 'admin#reject_tag', as: 'reject_tag'
  post 'admin/reject_tag_and_next/:id' => 'admin#reject_tag_and_next', as: 'reject_tag_and_next'
  post 'admin/undo_reject_tag/:id' => 'admin#undo_reject_tag', as: 'undo_reject_tag'
  post 'admin/approve_tagging/:id' => 'admin#approve_tagging', as: 'approve_tagging'
  post 'admin/reject_tagging/:id' => 'admin#reject_tagging', as: 'reject_tagging'
  post 'admin/undo_approve_tagging/:id' => 'admin#undo_approve_tagging', as: 'undo_approve_tagging'
  post 'admin/undo_reject_tagging/:id' => 'admin#undo_reject_tagging', as: 'undo_reject_tagging'
  post 'admin/escalate_tag/:id' => 'admin#escalate_tag', as: 'escalate_tag'
  post 'admin/escalate_tagging/:id' => 'admin#escalate_tagging', as: 'escalate_tagging'
  get 'admin/merge_tag/:id' => 'admin#merge_tag', as: 'merge_tag'
  post 'admin/merge_tag' => 'admin#do_merge_tag', as: 'do_merge_tag'
  get 'admin/merge_tagging/:id' => 'admin#merge_tagging', as: 'merge_tagging'
  post 'admin/merge_tagging' => 'admin#do_merge_tagging', as: 'do_merge_tagging'
  post 'admin/warn_user/:id' => 'admin#warn_user', as: 'warn_user'
  post 'admin/block_user/:id' => 'admin#block_user', as: 'block_user'
  post 'admin/unblock_user/:id' => 'admin#unblock_user', as: 'unblock_user'
  get 'admin/conversion_verification'
  get 'admin/assign_conversion_verification' => 'admin#assign_conversion_verification',
      as: 'assign_conversion_verification'
  get 'admin/assign_proofs' => 'admin#assign_proofs', as: 'assign_proofs'
  get 'admin/static_pages_list'
  get 'admin/static_page/new' => 'admin#static_page_new', as: 'static_page_new'
  post 'admin/static_page/create' => 'admin#static_page_create', as: 'static_page_create'
  get 'admin/static_page/edit/:id' => 'admin#static_page_edit', as: 'static_page_edit'
  patch 'admin/static_page/update' => 'admin#static_page_update', as: 'static_page_update'
  get 'admin/static_page/:id' => 'admin#static_page_show', as: 'static_page_show'
  get 'admin/volunteer_profiles_list'
  get 'admin/confirm_with_comment' => 'admin#confirm_with_comment', as: 'confirm_with_comment'
  get 'admin/volunteer_profile/new' => 'admin#volunteer_profile_new', as: 'volunteer_profile_new'
  post 'admin/volunteer_profile/create' => 'admin#volunteer_profile_create', as: 'volunteer_profile_create'
  get 'admin/volunteer_profile/edit/:id' => 'admin#volunteer_profile_edit', as: 'volunteer_profile_edit'
  patch 'admin/volunteer_profile/update' => 'admin#volunteer_profile_update', as: 'volunteer_profile_update'
  post 'admin/volunteer_profile/add_feature' => 'admin#volunteer_profile_add_feature',
       as: 'volunteer_profile_add_feature'
  get 'admin/volunteer_profile/delete_feature/:id' => 'admin#volunteer_profile_delete_feature',
      as: 'volunteer_profile_delete_feature'
  get 'admin/volunteer_profile/:id' => 'admin#volunteer_profile_show', as: 'volunteer_profile_show'
  get 'admin/volunteer_profile/destroy/:id' => 'admin#volunteer_profile_destroy', as: 'volunteer_profile_destroy'
  get 'autocomplete_manifestation_title' => 'admin#autocomplete_manifestation_title',
      as: 'autocomplete_manifestation_title'
  get 'autocomplete_person_name' => 'admin#autocomplete_person_name', as: 'autocomplete_person_name'

  get 'autocomplete_tag_name' => 'application#autocomplete_tag_name_name', as: 'autocomplete_tag_name'
  get 'autocomplete_dict_entry' => 'manifestation#autocomplete_dict_entry', as: 'autocomplete_dict_entry'
  get 'admin/featured_author_list'
  get 'admin/featured_author/new' => 'admin#featured_author_new', as: 'featured_author_new'
  post 'admin/featured_author/create' => 'admin#featured_author_create', as: 'featured_author_create'
  get 'admin/featured_author/edit/:id' => 'admin#featured_author_edit', as: 'featured_author_edit'
  patch 'admin/featured_author/update' => 'admin#featured_author_update', as: 'featured_author_update'
  get 'admin/featured_author/destroy/:id' => 'admin#featured_author_destroy', as: 'featured_author_destroy'
  post 'admin/featured_author/add_feature' => 'admin#featured_author_add_feature', as: 'featured_author_add_feature'
  get 'admin/featured_author/delete_feature/:id' => 'admin#featured_author_delete_feature',
      as: 'featured_author_delete_feature'
  get 'admin/featured_author/:id' => 'admin#featured_author_show', as: 'featured_author_show'
  get 'admin/sitenotice_list'
  get 'admin/sitenotice/new' => 'admin#sitenotice_new', as: 'sitenotice_new'
  post 'admin/sitenotice/create' => 'admin#sitenotice_create', as: 'sitenotice_create'
  get 'admin/sitenotice/edit/:id' => 'admin#sitenotice_edit', as: 'sitenotice_edit'
  patch 'admin/sitenotice/update' => 'admin#sitenotice_update', as: 'sitenotice_update'
  get 'admin/sitenotice/destroy/:id' => 'admin#sitenotice_destroy', as: 'sitenotice_destroy'
  get 'admin/sitenotice/:id' => 'admin#sitenotice_show', as: 'sitenotice_show'
  get 'volunteer/:id' => 'user#show', as: 'volunteer_show'

  get '/mobile_search' => 'application#mobile_search'
  match 'search/results', via: %i(get post), as: 'search_results_internal'
  get 'authors/all', as: 'all_authors'
  get 'authors/genre'
  get 'authors/show'
  get 'authors/new', as: 'authors_new'
  get 'authors/edit'
  match 'authors/list', via: %i(get post)
  get 'authors/print'
  post 'authors/update'
  get 'authors/destroy', as: 'authors_destroy'
  post 'authors/create'
  patch 'authors/update'
  get 'authors/get_random_author'
  get 'authors/volumes', as: 'authority_volumes'
  post 'authors/add_link/:id' => 'authors#add_link', as: 'author_add_link'
  post 'authors/delete_link/:id' => 'authors#delete_link', as: 'author_delete_link'
  match 'author/:id/edit_toc' => 'authors#edit_toc', as: 'authors_edit_toc', via: %i(get post)
  match 'author/:id/to_manual_toc' => 'authors#to_manual_toc', as: 'authors_to_manual_toc', via: %i(get post)
  match 'author/:id' => 'authors#toc', as: 'authority', via: %i(get post)

  match 'author/publish/:id' => 'authors#publish', as: 'author_publish', via: %i(get post)
  get 'author/:id/delete_photo' => 'authors#delete_photo', as: 'delete_author_photo'
  get 'author/:id/whatsnew' => 'authors#whatsnew_popup', as: 'author_whatsnew_popup'
  get 'author/:id/links' => 'authors#all_links', as: 'author_links_popup'
  get 'welcome/:id/featured_popup' => 'welcome#featured_popup', as: 'featured_content_popup'
  get 'welcome/:id/featured_author' => 'welcome#featured_author_popup', as: 'featured_author_popup'
  get 'author/:id/latest' => 'authors#latest_popup', as: 'author_latest_popup'
  get 'author/:id/kwic' => 'authors#kwic', as: 'author_kwic'
  get 'author/:id/kwic/download' => 'authors#kwic_download', as: 'author_kwic_download'
  get 'author/:id/kwic/context/:manifestation_id/:paragraph' => 'authors#kwic_context', as: 'author_kwic_context'
  get 'add_tagging/:taggable_type/:taggable_id' => 'taggings#add_tagging_popup', as: 'add_tagging_popup'
  get 'pending_taggings/:tag_id' => 'taggings#pending_taggings_popup', as: 'pending_taggings_popup'
  get '/page/:tag' => 'static_pages#view', as: 'static_pages_by_tag', via: [:get]
  get 'read/:id' => 'manifestation#read', as: 'manifestation'
  match 'dict/:id' => 'manifestation#dict', as: 'dict_browse', via: %i(get post)
  get 'dict/:id/print' => 'manifestation#dict_print', as: 'dict_print'
  get 'dict/:id/:entry' => 'manifestation#dict_entry', as: 'dict_entry'
  get 'dict/:id/:entry/print' => 'manifestation#dict_entry_print', as: 'dict_entry_print'
  get 'read/:id/read' => 'manifestation#readmode', as: 'manifestation_readmode'
  get 'periods' => 'manifestation#periods', as: 'periods'
  match 'authors', to: 'authors#browse', as: 'authors', via: %i(get post)
  get 'works', to: 'manifestation#browse', as: 'works'
  get 'works/all', to: 'manifestation#all', as: 'all_works'
  match 'manifestation/genre' => 'manifestation#genre', as: 'genre', via: %i(get post)
  match 'period/:period' => 'manifestation#period', as: 'period', via: %i(get post)
  match 'translations' => 'manifestation#translations', as: 'translations', via: %i(get post)
  get 'whatsnew' => 'manifestation#whatsnew', as: 'whatsnew'
  match 'tag/:id/works' => 'manifestation#by_tag', as: 'search_by_tag', via: %i(get post)
  match 'tag/:id/authors' => 'authors#by_tag', as: 'authors_by_tag', via: %i(get post)
  get 'tag/:id' => 'taggings#tag_portal', as: 'tag'
  post 'tag_by_name' => 'taggings#tag_by_name', as: 'tag_by_name'
  match 'download/:id' => 'manifestation#download', as: 'manifestation_download', via: %i(get post)
  match 'print/:id' => 'manifestation#print', as: 'manifestation_print', via: %i(get post)
  get 'kwic/:id' => 'manifestation#kwic', as: 'manifestation_kwic'
  get 'kwic/:id/download' => 'manifestation#kwic_download', as: 'manifestation_kwic_download'
  get 'kwic/:id/context/:paragraph' => 'manifestation#kwic_context', as: 'manifestation_kwic_context'
  get 'manifestation/show/:id' => 'manifestation#show', as: 'manifestation_show'
  get 'manifestation/render_html'
  get 'manifestation/chomp_period/:id' => 'manifestation#chomp_period', as: 'manifestation_chomp_period'
  post 'manifestation/set_bookmark'
  post 'manifestation/remove_bookmark'
  get 'manifestation/edit/:id' => 'manifestation#edit', as: 'manifestation_edit'
  get 'manifestation/remove_image/:id' => 'manifestation#remove_image'
  get 'manifestation/edit_metadata/:id' => 'manifestation#edit_metadata', as: 'manifestation_edit_metadata'
  match 'manifestation/list', via: %i(get post)
  get 'manifestation/genre' => 'manifestation#genre', as: 'manifestation_genre'
  get 'manifestation/index', as: 'manifestation_index'
  get 'manifestation/remove_link'
  post 'manifestation/update'
  patch 'manifestation/update'
  post 'manifestation/add_images'
  get 'manifestation/get_random'
  post 'manifestation/like'
  post 'manifestation/unlike'
  get 'manifestation/surprise_work'
  get 'manifestation/autocomplete_works_by_author'
  get 'manifestation/autocomplete_authority_name' => 'manifestation#autocomplete_authority_name',
      as: 'manifestation_autocomplete_authority_name'
  get 'work/show/:id' => 'manifestation#workshow', as: 'work_show' # temporary, until we have a works controller
  get 'manifestation/add_aboutnesses/:id' => 'manifestation#add_aboutnesses'
  resources :api_keys, except: :show
  get 'taggings/render_tags', as: 'render_tags'
  get 'tag_suggest' => 'taggings#suggest', as: 'tag_suggest'
  match 'tags' => 'taggings#list_tags', via: %i(get post)
  get 'tags/listall' => 'taggings#listall_tags', as: 'tags_listall'
  resources :taggings
  resources :aboutnesses
  resources :preferences, only: [:update]

  match 'user/list', via: %i(get post)
  post 'user/set_editor_bit'
  get 'user/:id/make_editor' => 'user#make_editor', as: 'user_make_editor'
  get 'user/:id/make_crowdsourcer' => 'user#make_crowdsourcer', as: 'user_make_crowdsourcer'
  get 'user/:id/make_admin' => 'user#make_admin', as: 'user_make_admin'
  get 'user/:id/unmake_editor' => 'user#unmake_editor', as: 'user_unmake_editor'
  get 'user/:id/unmake_crowdsourcer' => 'user#unmake_crowdsourcer', as: 'user_unmake_crowdsourcer'
  get 'user/:id' => 'user#show', as: 'user_show'
  get 'welcome/index'
  get 'welcome/contact'
  get 'welcome/volunteer'
  post 'welcome/submit_contact'
  post 'welcome/submit_volunteer'
  get 'admin/manifestation_batch_tools' => 'admin#manifestation_batch_tools',
      as: 'manifestation_batch_tools_admin_index'
  delete 'admin/destroy_manifestation' => 'admin#destroy_manifestation', as: 'destroy_manifestation_admin_index'
  post 'admin/unpublish_manifestation' => 'admin#unpublish_manifestation', as: 'unpublish_manifestation_admin_index'
  if Rails.env.test?
    namespace :test do
      resource :session, only: :create
    end
  end
  get 'session/create'
  get 'session/destroy'
  get 'session/login'
  get 'session/dismiss_sitenotice'
  post 'session/do_login'

  get '/auth/:provider/callback' => 'session#create'
  post '/auth/:provider/callback' => 'session#create'

  match 'auth/failure', to: redirect('/'), via: %i(get post)
  match 'signout', to: 'session#destroy', as: 'signout', via: %i(get post)

  resources :html_dirs
  match 'html_dirs/:id/guess_author' => 'html_dirs#guess_author', via: %i(get post)
  match 'html_dirs/:id/associate_viaf' => 'html_dirs#associate_viaf', as: 'html_dirs_associate_viaf', via: %i(get post)

  resources :proofs, only: %i(index show create new) do
    member do
      post :resolve
    end
    collection do
      post :purge
    end
  end

  get 'legacy_recommendation/list'
  get 'legacy_recommendation/purge' => 'legacy_recommendation#purge', as: 'legacy_recommendation_purge'
  match 'legacy_recommendation/:id/resolve' => 'legacy_recommendation#resolve', as: 'legacy_recommendation_resolve',
        via: %i(get post)
  resources :legacy_recommendations
  resources :recommendations

  get 'recommendation/display/:id' => 'recommendations#display', as: 'recommendation_display'

  get 'html_file/analyze'
  match 'html_file/:id/edit' => 'html_file#edit', as: 'html_file_edit', via: %i(get post)
  post 'html_file/:id/update' => 'html_file#update'
  match 'html_file/:id/confirm_html_dir_person' => 'html_file#confirm_html_dir_person',
        as: 'html_file_confirm_html_dir_person', via: %i(get post)
  get 'html_file/analyze_all'
  get 'html_file/:id/frbrize' => 'html_file#frbrize', as: 'html_file_frbrize'

  get 'html_file/list'
  get 'html_file/list_for_editor'
  get 'html_file/publish'
  post 'html_file/list'
  get 'html_file/publish'
  get 'html_file/parse'
  get 'html_file/render_html'
  post 'html_file/render_html'
  get 'html_file/unsplit'
  get 'html_file/chop1'
  get 'html_file/choplast1'
  get 'html_file/chop2'
  get 'html_file/choplast2'
  get 'html_file/chop3'
  get 'html_file/chop_title'
  get 'html_file/poetry'
  get 'html_file/mark_manual'
  get 'html_file/new'
  get 'html_file/mark_superseded'
  match 'html_file/edit_markdown', via: %i(get post)
  post 'html_file/create'
  get 'html_file/destroy'

  mount Blazer::Engine, at: 'blazer'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root to: 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
  #
  # match legacy BY urls, but *only* those
  get '*path' => 'html_file#render_by_legacy_url', constraints: lambda { |req|
    is_legacy_url(req.path)
  }
end
