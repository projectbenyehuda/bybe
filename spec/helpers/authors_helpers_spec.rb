# frozen_string_literal: true

require 'rails_helper'

describe AuthorsHelper do
  describe '.manifestation_label' do
    subject(:result) { helper.manifestation_label(manifestation, role, authority.id) }

    let(:authority) { create(:authority) }

    context 'when the role is author' do
      let(:role) { 'author' }
      let(:manifestation) { create(:manifestation, author: authority, orig_lang: 'he') }

      context 'when the authority is the only author' do
        it 'returns only the title' do
          expect(result).to eq(manifestation.title)
        end
      end

      context 'when the manifestation has translators' do
        let(:translator) { create(:authority) }
        let(:manifestation) { create(:manifestation, author: authority, translator: translator, orig_lang: 'ru') }

        it 'returns the title with translators string' do
          expect(result).to eq("#{manifestation.title} #{I18n.t(:translated_by)} #{translator.name}")
        end
      end

      context 'when the authority is not the only author' do
        let(:other_authority) { create(:authority) }

        let(:authors_string) { [authority.name, other_authority.name].sort.join(', ') }

        before do
          manifestation.expression.work.involved_authorities.create!(role: :author, authority: other_authority)
        end

        it 'returns the title with authors string' do
          expect(result).to eq("#{manifestation.title} / #{authors_string}")
        end
      end
    end

    context 'when the role is translator' do
      let(:role) { 'translator' }
      let(:manifestation) { create(:manifestation, author: authority, orig_lang: 'de', translator: authority) }
      let(:author) { manifestation.authors.first }

      context 'when the authority is the only translator' do
        it 'returns the title with authors string' do
          expect(result).to eq("#{manifestation.title} / #{author.name}")
        end
      end

      context 'when the manifestation has multiple translators' do
        let(:other_translator) { create(:authority) }
        let(:translators_string) { [authority.name, other_translator.name].sort.join(', ') }

        before do
          manifestation.expression.involved_authorities.create!(role: :translator, authority: other_translator)
        end

        it 'returns the title with authors and translators string' do
          expect(result).to eq("#{manifestation.title} / #{author.name} / #{translators_string}")
        end
      end
    end

    context 'when role is editor' do
      # Same logic should be used for all other roles like illustrator, etc.
      let(:role) { 'editor' }
      let(:manifestation) { create(:manifestation, editor: authority, orig_lang: 'he') }
      let(:author) { manifestation.authors.first }

      context 'when the authority is the only editor' do
        it 'returns the title with author string' do
          expect(result).to eq("#{manifestation.title} / #{author.name}")
        end
      end

      context 'when the authority is not the only editor' do
        let(:other_editor) { create(:authority) }

        let(:editors_string) { [authority.name, other_editor.name].sort.join(', ') }

        before do
          manifestation.expression.involved_authorities.create!(role: :editor, authority: other_editor)
        end

        it 'returns the title with author and editors string' do
          expect(result).to eq(
            "#{manifestation.title} / #{author.name} #{I18n.t('toc_by_role.made_by.editor')} #{editors_string}"
          )
        end
      end
    end
  end

  describe '.count_toc_nodes_manifestations' do
    include_context 'when authority has several collections'

    subject(:result) do
      tree = GenerateTocTree.call(authority)
      nodes = tree.top_level_nodes.select { |node| node.visible?(role, authority.id, involved_on_collection_level) }
      helper.count_toc_nodes_manifestations(nodes, role, authority.id, involved_on_collection_level)
    end

    context 'when counting author works at collection level' do
      let(:role) { :author }
      let(:involved_on_collection_level) { true }

      it 'returns correct count' do
        # Authority is not involved at collection level in the test data,
        # so this should return 0
        expect(result).to eq(0)
      end
    end

    context 'when counting editor works at collection level' do
      let(:role) { :editor }
      let(:involved_on_collection_level) { true }

      it 'returns correct count' do
        # Should count edited_manifestations (3 items)
        expect(result).to eq(edited_manifestations.count)
      end
    end

    context 'when counting translator works at collection level' do
      let(:role) { :translator }
      let(:involved_on_collection_level) { true }

      it 'returns correct count' do
        # Should count translated_manifestations (2 items)
        expect(result).to eq(translated_manifestations.count)
      end
    end

    context 'when counting author works at work level' do
      let(:role) { :author }
      let(:involved_on_collection_level) { false }

      it 'returns correct count' do
        # Should count uncollected (2) + top_level (3) = 5 manifestations
        # where authority is author at work level
        expect(result).to eq(uncollected_manifestations.count + top_level_manifestations.count)
      end
    end

    context 'when nodes array is empty' do
      let(:role) { :author }
      let(:involved_on_collection_level) { true }

      it 'returns 0' do
        count = helper.count_toc_nodes_manifestations([], role, authority.id, involved_on_collection_level)
        expect(count).to eq(0)
      end
    end
  end
end
