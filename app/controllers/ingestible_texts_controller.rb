# frozen_string_literal: true

# Controller to work with individual texts within an Ingestible object
class IngestibleTextsController < ApplicationController
  include LockIngestibleConcern
  include BybeUtils

  before_action { |c| c.require_editor('edit_catalog') }
  before_action :set_ingestible
  before_action :try_to_lock_record

  def edit
    @text = @ingestible.texts[@text_index]
    # Generate HTML with unique footnote anchors for this specific text
    texthtml = highlight_suspicious_markdown(MarkdownToHtml.call(@text.content))
    @text_html = footnotes_noncer(texthtml, "txt_#{@text_index}")
  end

  def update
    text_params = params.expect(ingestible_text: %i(content title))
    @ingestible.save_text_to_cache(text_params[:title], text_params[:content])
    @ingestible.texts[@text_index] = IngestibleText.new(text_params)
    @ingestible.save!
    redirect_to edit_ingestible_path(@ingestible, text_index: @text_index), notice: t(:updated_successfully)
  end

  def save_to_cache
    cache_params = params.permit(:title, :content)
    @ingestible.save_text_to_cache(cache_params[:title], cache_params[:content])
    head :ok
  end

  def fetch_cached_version
    return head :not_found unless params[:cache_index].to_s.match?(/\A\d+\z/)

    cache = @ingestible.parsed_textarea_cache
    cache_index = params[:cache_index].to_i
    return head :not_found if cache_index >= cache.length

    render json: { content: cache[cache_index]['content'] }
  end

  private

  def set_ingestible
    @ingestible = Ingestible.find(params[:ingestible_id])
    # Id is a zero-based index of text inside of ingestible texts collection
    @text_index = params[:id].to_i
  end
end
