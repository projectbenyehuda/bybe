# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manifestation search highlighting', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  # Scroll position thresholds for validation
  # MAX_NO_SCROLL: Maximum scroll position if page stayed at top (header height + margin)
  # MIN_SCROLLED: Minimum scroll position if page scrolled to first match in text
  # Note: The scroll function subtracts 255px from the match position, so scrolling
  # to matches near the top of content results in small scroll values
  MAX_NO_SCROLL_THRESHOLD = 300
  MIN_SCROLLED_THRESHOLD = 20

  let(:markdown_content) do
    <<~MARKDOWN
      ## Chapter 1

      This is the introduction paragraph with lots of filler content to push
      the actual search term further down the page. We need enough content here
      so that when we scroll to the first match, it will be significantly below
      the top of the page. Adding more text here to create distance.
      More filler text. More filler text. More filler text.
      Even more filler text to create enough vertical space.

      Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
      quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
      consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
      cillum dolore eu fugiat nulla pariatur.

      Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia
      deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste
      natus error sit voluptatem accusantium doloremque laudantium, totam rem
      aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto
      beatae vitae dicta sunt explicabo.

      Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit,
      sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.
      Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur,
      adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore
      et dolore magnam aliquam quaerat voluptatem.

      Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit
      laboriosam, nisi ut aliquid ex ea commodi consequatur. Quis autem vel eum
      iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae
      consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur.

      This is some sample text with the word sample appearing multiple times.
      Here is another paragraph with more content.

      ## Chapter 2

      Another section with different content and more text.
      The word sample appears here as well.
    MARKDOWN
  end

  let!(:manifestation_with_title_match) do
    Chewy.strategy(:atomic) do
      create(:manifestation,
             title: 'Sample Work Title',
             markdown: markdown_content,
             status: :published)
    end
  end

  let!(:manifestation_without_title_match) do
    Chewy.strategy(:atomic) do
      create(:manifestation,
             title: 'Different Work Title',
             markdown: markdown_content,
             status: :published)
    end
  end

  before do
    # Ensure heading lines are calculated
    manifestation_with_title_match.recalc_heading_lines
    manifestation_with_title_match.save!

    manifestation_without_title_match.recalc_heading_lines
    manifestation_without_title_match.save!
  end

  after do
    Chewy.massacre
  end

  def current_scroll_position
    page.evaluate_script('window.pageYOffset || document.documentElement.scrollTop')
  end

  describe 'search highlighting behavior' do
    context 'when search term matches the title' do
      it 'does not auto-scroll to first occurrence in text' do
        visit manifestation_path(manifestation_with_title_match, q: 'sample')

        # Wait for page to load and search highlighting to be applied
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Wait a moment for any potential scroll to settle
        # Then verify position remains at top
        sleep 0.5

        # Check that we are still at the top of the page (not scrolled to first match in text)
        expect(current_scroll_position).to be < MAX_NO_SCROLL_THRESHOLD
      end

      it 'still highlights all occurrences of the search term' do
        visit manifestation_path(manifestation_with_title_match, q: 'sample')

        # Search controls should be visible
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Multiple matches should be found (at least 2 in the text content)
        total_matches = page.find('#total-matches').text.to_i
        expect(total_matches).to be >= 2
      end
    end

    context 'when search term does not match the title' do
      it 'auto-scrolls to first occurrence in text as usual' do
        visit manifestation_path(manifestation_without_title_match, q: 'sample')

        # Wait for page to load and search highlighting to be applied
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Wait for scroll animation to complete (JavaScript uses 300ms animation)
        # Give extra time for animation to fully complete and settle
        sleep 0.5

        # Check that we have scrolled down (away from top of page)
        expect(current_scroll_position).to be > MIN_SCROLLED_THRESHOLD
      end

      it 'highlights all occurrences of the search term' do
        visit manifestation_path(manifestation_without_title_match, q: 'sample')

        # Search controls should be visible
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Multiple matches should be found
        total_matches = page.find('#total-matches').text.to_i
        expect(total_matches).to be >= 2
      end
    end

    context 'when search term partially matches the title' do
      it 'does not auto-scroll when title contains the search term (case-insensitive)' do
        visit manifestation_path(manifestation_with_title_match, q: 'Sample')

        # Wait for page to load
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Wait for any potential scroll to settle
        sleep 0.5

        # Should not scroll since "Sample" (different case) is in the title "Sample Work Title"
        expect(current_scroll_position).to be < MAX_NO_SCROLL_THRESHOLD
      end
    end

    context 'with Hebrew text' do
      let(:hebrew_markdown) do
        <<~MARKDOWN
          ## פרק ראשון

          זוהי פסקת הקדמה עם הרבה תוכן מילוי כדי לדחוף את מילת החיפוש האמיתית
          יותר למטה בעמוד. אנחנו צריכים מספיק תוכן כאן כדי שכאשר נגלול להתאמה הראשונה,
          היא תהיה באופן משמעותי מתחת לחלק העליון של העמוד. מוסיפים עוד טקסט כאן
          כדי ליצור מרחק. עוד טקסט מילוי. עוד טקסט מילוי. עוד טקסט מילוי.
          אפילו עוד טקסט מילוי כדי ליצור מספיק מרווח אנכי.

          טקסט נוסף בעברית כדי למלא את העמוד ולדחוף את התוכן למטה. אנחנו צריכים
          הרבה יותר תוכן כדי להבטיח שהעמוד יהיה ארוך מספיק לגלילה. בואו נוסיף
          עוד כמה פסקאות של טקסט מילוי בעברית.

          זהו טקסט ארוך נוסף שמטרתו למלא מקום ולהבטיח שיהיה מספיק תוכן בעמוד
          כדי שנצטרך לגלול כלפי מטה כדי לראות את כל המידע. אנחנו ממשיכים להוסיף
          עוד ועוד טקסט כדי להגיע לאורך מתאים.

          פסקה נוספת של טקסט מילוי בעברית. אנחנו ממשיכים להוסיף תוכן כדי להבטיח
          שהמסמך יהיה ארוך מספיק. זה חשוב כדי שהבדיקה תוכל לוודא שהגלילה עובדת
          כמו שצריך. עוד טקסט ועוד טקסט ועוד טקסט.

          ממשיכים עם עוד תוכן בעברית. אנחנו רוצים להבטיח שיש מספיק חומר כאן
          כדי שהדף יצטרך גלילה. זה נראה טוב עכשיו עם כל הטקסט הזה שאנחנו מוסיפים
          לכאן. בואו נוסיף עוד קצת יותר כדי להיות בטוחים.

          זה טקסט לדוגמה עם המילה דוגמה שמופיעה מספר פעמים.
          זה פסקה נוספת עם תוכן נוסף.

          ## פרק שני

          עוד קטע עם תוכן שונה ועוד טקסט.
          המילה דוגמה מופיעה גם כאן.
        MARKDOWN
      end

      let!(:hebrew_manifestation_with_title_match) do
        Chewy.strategy(:atomic) do
          create(:manifestation,
                 title: 'יצירה לדוגמה',
                 markdown: hebrew_markdown,
                 status: :published)
        end
      end

      let!(:hebrew_manifestation_without_title_match) do
        Chewy.strategy(:atomic) do
          create(:manifestation,
                 title: 'יצירה אחרת',
                 markdown: hebrew_markdown,
                 status: :published)
        end
      end

      before do
        hebrew_manifestation_with_title_match.recalc_heading_lines
        hebrew_manifestation_with_title_match.save!

        hebrew_manifestation_without_title_match.recalc_heading_lines
        hebrew_manifestation_without_title_match.save!
      end

      it 'does not auto-scroll when Hebrew search term matches Hebrew title' do
        visit manifestation_path(hebrew_manifestation_with_title_match, q: 'דוגמה')

        # Wait for page to load
        expect(page).to have_css('#search-highlight-controls', visible: :visible)
        sleep 0.5

        # Should not scroll since "דוגמה" is in the title "יצירה לדוגמה"
        expect(current_scroll_position).to be < MAX_NO_SCROLL_THRESHOLD
      end

      it 'auto-scrolls when Hebrew search term does not match Hebrew title' do
        visit manifestation_path(hebrew_manifestation_without_title_match, q: 'דוגמה')

        # Wait for page to load
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Wait for scroll animation to complete (JavaScript uses 300ms animation)
        # Give extra time for animation to fully complete and settle
        sleep 0.5

        # Should have scrolled to first match in text
        expect(current_scroll_position).to be > MIN_SCROLLED_THRESHOLD
      end
    end

    context 'when there is no search query' do
      it 'does not show search controls or highlight anything' do
        visit manifestation_path(manifestation_with_title_match)

        # Search controls should not be visible
        expect(page).to have_no_css('#search-highlight-controls', visible: :visible)
      end
    end
  end
end
