# frozen_string_literal: true

module Lexicon
  # Controller for LexCitationAuthor
  class CitationAuthorsController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_citation, only: %i(index create)
    before_action :set_author, only: %i(match update edit_link update_link destroy)
    before_action :try_to_lock_record

    layout false

    def index
      # lex_file too: an author with no name of its own derives its display name from the
      # entry (see LexEntry#surname_first_title), which consults the file of a not-yet-ingested entry
      @authors = @citation.authors.preload(entry: :lex_file).sort_by(&:display_name)
    end

    def create
      @author = @citation.authors.build(author_params)

      # We use auto-completion to select an entry, so if an entry from db is selected we need to nullify the name
      if @author.lex_entry_id.present?
        @author.name = nil
      end

      @author.link = @author.link.to_s.strip.presence

      # invalid_link? short-circuits the save, which would otherwise reset the error it just added
      if invalid_link?(@author) || !@author.save
        # resetting value of possibly selected lex_entry_id if record is invalid (probaly non-unique value)
        @author.lex_entry_id = nil
        status = :unprocessable_content
      else
        status = :ok
      end

      render status: status
    end

    # Modal offering to link a plaintext author imported from a legacy PHP file to an existing
    # person entry, pre-filled with the name the match was found by (see LexCitationAuthor.normalize_name)
    # and the entry id it resolves to, so confirming immediately submits a valid match instead of
    # requiring the editor to reselect it from the autocomplete dropdown themselves.
    def match
      @matching_entry = @author.matching_entry
    end

    # Links the author to the chosen person entry. The imported name is deliberately left untouched,
    # so the citation keeps displaying it as "lastname, firstname" exactly as the legacy file had it.
    # An entry-linked author may not also carry a link, so any leftover link is dropped -- the same
    # thing ParseCitations#update_link does when it links an author during ingestion.
    def update
      # The record is looked up rather than the id assigned straight through, so a submission naming
      # an entry that does not exist is rejected here. Two ordinary cases reach this: the
      # autocomplete clears its hidden id field as soon as the editor edits the text, and the
      # autocomplete index can still offer an entry that has since been deleted (a stale document
      # outlives the row it described, since the index is only pruned when a destroy runs through
      # the model). Without the lookup the second case sails past validation -- `entry` is nil, so
      # `entry_must_be_person` never runs -- and fails on the lex_entries foreign key with a 500.
      @author.assign_attributes(entry: LexEntry.find_by(id: match_params[:lex_entry_id]), link: nil)

      if @author.entry.nil?
        @author.errors.add(:lex_entry_id, :entry_not_found)
      elsif @author.save
        return head :ok
      end

      render :match, status: :unprocessable_content
    end

    # Modal for pointing a plaintext author -- one with no lexicon entry of its own -- at an
    # arbitrary URL, the counterpart of #match for the authors no entry can be found for. An
    # entry-linked author already links to that entry and may not carry a link as well, so the
    # views only offer this for entry-less ones; the model validation is the backstop.
    def edit_link; end

    def update_link
      # Submitting an empty field clears the link, which is how an editor removes one.
      @author.link = link_params[:link].to_s.strip.presence

      return render_link_errors if invalid_link?(@author)
      return head :ok if @author.save

      render_link_errors
    end

    def destroy
      @author.destroy!
    end

    private

    # Whether the author's link has to be refused, recording why on the author when it does.
    #
    # The same allowlist TextLinksConcern applies to a text link's url: the value is rendered
    # straight into an href (see LexiconHelper#render_citation_author), so anything not
    # known-inert is refused rather than sanitized. It is checked here rather than as a model
    # validation because ingestion stores legacy relative hrefs such as '00563.php'
    # (see ParseCitations#update_link), which a validation would then refuse to save.
    def invalid_link?(author)
      return false if author.link.blank?
      return false if author.link.match?(Lexicon::TextLinkExtraction::ALLOWED_URL_PATTERN)

      author.errors.add(:link, :invalid_url)
      true
    end

    # The two callers want different things back: the modal (which sends no Accept preference)
    # re-renders itself from the returned HTML, while the inline editor of the authors list has
    # no modal to re-render and asks for text/plain so it can report the reason as it stands.
    # html is declared first so that the modal's */* lands on it.
    def render_link_errors
      respond_to do |format|
        format.html { render :edit_link, status: :unprocessable_content }
        format.text { render plain: @author.errors.full_messages.join("\n"), status: :unprocessable_content }
      end
    end

    def author_params
      params.expect(lex_citation_author: %i(name link lex_entry_id))
    end

    # Only the entry reference is accepted: the modal's autocomplete box also submits the title the
    # editor searched by, but the imported name must survive the match unchanged.
    def match_params
      params.expect(lex_citation_author: %i(lex_entry_id))
    end

    def link_params
      params.expect(lex_citation_author: %i(link))
    end

    def set_citation
      @citation = LexCitation.find(params[:citation_id])
    end

    def set_author
      @author = LexCitationAuthor.find(params[:id])
      @citation = @author.citation
    end

    def record_to_lock
      @citation.person.lex_entry
    end
  end
end
