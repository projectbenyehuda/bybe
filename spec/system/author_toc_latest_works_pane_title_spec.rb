# frozen_string_literal: true

require 'rails_helper'

# Companion to spec/system/lexicon/latest_works_pane_title_spec.rb: the same
# "latest works by this author" pane appears in the Authority TOC sidebar, and its title is
# likewise longer than the sidebar is wide. `.headline-2-v02` truncates with an ellipsis by
# default; the title must wrap onto another line instead.
RSpec.describe 'Latest-works pane title in the Authority TOC', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  after do
    Chewy.massacre
  end

  it 'wraps the pane title rather than clipping it' do
    author = create(:authority, name: 'Test Author')
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Test Work', status: :published, author: author)
    end

    visit authority_path(author)

    # located through Capybara, so a markup change fails with a clear "expected to find css" error
    # rather than a null dereference inside the script below
    title = find('#author-whats-new-bg p.headline-2-v02')

    metrics = page.evaluate_script(<<~JS, title)
      (function(el) {
        var style = window.getComputedStyle(el);
        return {
          scrollWidth: el.scrollWidth,
          clientWidth: el.clientWidth,
          whiteSpace: style.whiteSpace,
          textOverflow: style.textOverflow
        };
      })(arguments[0])
    JS

    expect(metrics['whiteSpace']).not_to eq 'nowrap'
    expect(metrics['textOverflow']).not_to eq 'ellipsis'
    # the whole title fits horizontally: nothing is cut off
    expect(metrics['scrollWidth']).to be <= metrics['clientWidth'] + 1
  end
end
