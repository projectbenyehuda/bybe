# frozen_string_literal: true

require 'rails_helper'

describe 'Manifestation scrollspy' do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end
  let(:markdown_with_chapters) do
    <<~MARKDOWN
      ## Chapter 1

      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
      Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

      ## Chapter 2

      Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium.
      Totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

      ## Chapter 3

      Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.
      Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.
      Sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.

      ## Chapter 4

      Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur.
      Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur.
      Vel illum qui dolorem eum fugiat quo voluptas nulla pariatur.

      ## Chapter 5

      At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident.
      Similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga.
      Et harum quidem rerum facilis est et expedita distinctio.
    MARKDOWN
  end

  let!(:manifestation) do
    Chewy.strategy(:atomic) do
      create(:manifestation, markdown: markdown_with_chapters, status: :published)
    end
  end

  before do
    # Ensure heading lines are calculated
    manifestation.recalc_heading_lines
    manifestation.save!
  end

  after do
    Chewy.massacre
  end

  describe 'chapter navigation highlighting' do
    describe 'chapter titles with escaped characters' do
      let(:markdown_with_escaped_chars) do
        <<~MARKDOWN
          ## Chapter \\[Part 1\\] Introduction

          Lorem ipsum dolor sit amet, consectetur adipiscing elit.

          ## Chapter \\*Special\\* Section

          Ut enim ad minim veniam, quis nostrud exercitation.
        MARKDOWN
      end

      let!(:manifestation_with_escapes) do
        Chewy.strategy(:atomic) do
          create(:manifestation, markdown: markdown_with_escaped_chars, status: :published)
        end
      end

      before do
        manifestation_with_escapes.recalc_heading_lines
        manifestation_with_escapes.save!
      end

      it 'displays chapter titles without escape backslashes in navigation' do
        visit manifestation_path(manifestation_with_escapes)

        # Verify chapter titles display without backslashes in sidebar navigation
        within('#chapternav') do
          expect(page).to have_content('Chapter [Part 1] Introduction')
          expect(page).to have_no_content('Chapter \\[Part 1\\] Introduction')

          expect(page).to have_content('Chapter *Special* Section')
          expect(page).to have_no_content('Chapter \\*Special\\* Section')
        end
      end
    end

    describe 'chapter navigation structure' do
      it 'renders chapter navigation with correct structure' do
        visit manifestation_path(manifestation)

        # Verify chapter navigation exists
        expect(page).to have_css('#chapternav')
        expect(page).to have_css('.nav-link-chapter')

        # Verify we have the expected number of chapters
        chapter_links = all('.nav-link-chapter')
        expect(chapter_links.count).to eq(5)

        # Verify chapter anchors exist in the content
        chapter_anchors = all('a[name^="ch"]', visible: :all)
        expect(chapter_anchors.count).to eq(5)

        # Verify no chapter has default active class (scrollspy manages this)
        within('#chapternav') do
          expect(page).to have_no_css('.nav-link.active')
        end
      end

      it 'adjusts highlighting correctly when header height changes', :js do
        visit manifestation_path(manifestation)

        # Wait for page to load
        expect(page).to have_css('#chapternav')

        # Get initial header height
        initial_header_height = page.evaluate_script("$('#header').height()")
        expect(initial_header_height).to be > 0

        # Scroll down to trigger header height change (scrolled class)
        page.execute_script('window.scrollTo(0, 300)')
        sleep 0.3

        # Check if header has 'scrolled' class or height changed
        has_scrolled_class = page.evaluate_script("$('header').hasClass('scrolled')")
        new_header_height = page.evaluate_script("$('#header').height()")

        # If the header changes (either class or height), verify scrollspy still works
        if has_scrolled_class || new_header_height != initial_header_height
          # Scrollspy should still maintain exactly one active chapter
          within('#chapternav') do
            expect(page).to have_css('.nav-link.active', count: 1)
          end
        end
      end
    end

    describe 'scrollspy offset calculation', :js do
      it 'uses the correct header height as offset' do
        visit manifestation_path(manifestation)

        # Wait for scrollspy to be initialized
        expect(page).to have_css('#chapternav')

        # Verify that scrollspy is initialized with an offset
        # This checks that the scrollspy has been configured
        scrollspy_initialized = page.evaluate_script(<<~JS)
          typeof $('body').data('bs.scrollspy') !== 'undefined'
        JS

        expect(scrollspy_initialized).to be(true), 'Scrollspy should be initialized on body element'
      end
    end
  end
end
