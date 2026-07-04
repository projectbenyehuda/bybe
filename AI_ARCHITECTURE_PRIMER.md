# ARCHITECTURE PRIMER FOR AI AGENTS: Project Ben-Yehuda (bybe)

Hebrew digital library (benyehuda.org). Full-text search via Elasticsearch, doc
conversion (PDF/EPUB/DOCX), markdown content, user-curated collections.

**Stack**: Ruby 3.3, Rails 8.0, MySQL, Chewy (Elasticsearch), Pandoc,
MultiMarkdown, HAML views (not ERB), RSpec tests (not minitest).

---

## CORE DATA MODEL (app/models/)

### Authority ecosystem
- **Authority** (`authority.rb`): an author/creator; wraps a Person or CorporateBody.
  - `has_many :involved_authorities, :publications, :featured_contents, :taggings`
  - Enums: `status` (published/unpublished/deprecated/awaiting_first),
    `intellectual_property` (public_domain/copyrighted/orphan)
  - Key methods: `manifestations(role)`, `volumes`, `collections`,
    `uncollected_works_collection` (auto-managed system collection)
  - Indexed: AuthoritiesIndex, AuthoritiesAutocompleteIndex

### Work → Expression → Manifestation (FRBR-inspired)
`Work` (abstract, e.g. "Torah") → `Expression` (a version/translation) →
`Manifestation` (a concrete digital realization).

- **Work** (`work.rb`): abstract work.
  - Enum `genre` (poetry/prose/drama/fables/article/memoir/letters/reference/lexicon)
  - `orig_lang` (ISO-ish string `he`/`ru`/`en`/`unk`): the work's **original
    composition language** — lives on Work, NOT Expression.
  - `origlang_title`: title in the original language (shown in `.origlang_details`).

- **Expression** (`expression.rb`): a version/translation of a Work.
  - `language`: language of THIS expression (what it's translated into, or same
    as `work.orig_lang` if untranslated). Enum `period`
    (ancient/medieval/enlightenment/revival/modern).
  - `translation` (bool): auto-set in `set_translation` callback as
    `language != work.orig_lang`.
  - Original language of a translated text, from a Manifestation:
    `manifestation.expression.work.orig_lang`; format for display via
    `orig_lang_label()` / `textify_lang()` in `lib/bybe_utils.rb` (mixed into
    `ApplicationHelper`, so available in all views).

- **Manifestation** (`manifestation.rb`): the actual content.
  - Content: `markdown` (raw), `html` (converted), `sort_title`.
  - Enum `status` (published/nonpd/unpublished/deprecated).
  - `has_many :recommendations, :bookmarks, :downloadables, :collection_items,
    :external_links`.

### InvolvedAuthority (`involved_authority.rb`)
Polymorphic join: Authority → (Work | Expression) with a `role`
(author/editor/illustrator/translator/photographer/designer/contributor/other),
display order via `ROLES_PRESENTATION_ORDER`.
- **`WORK_ROLES` excludes translator; `EXPRESSION_ROLES` excludes author** —
  translator ALWAYS lives on Expression, author ALWAYS on Work, never reversed.
  Common source of bugs: don't assume `work.involved_authorities` has translators.
- `Manifestation#involved_authorities` =
  `(expression.involved_authorities + expression.work.involved_authorities).uniq`
  — merges both levels. Changes update manifestation responsibility statements.

### Collection ecosystem
- **Collection** (`collection.rb`): heterogeneous container.
  - Types: volume, periodical, periodical_issue, series, volume_series, other,
    uncollected (system-managed).
  - `has_many :collection_items` (ordered by `seqno`), `parent_collection_items`
    (nesting), `involved_authorities`.
  - Methods: `collection_items_by_type()`, `manifestation_items`, `pby_volumes`
    scope (volumes edited+collected by PBY itself, vs previously printed works).
  - **Periodical structure**: periodical → periodical_issues → Manifestations
    and/or series → Manifestations. A `volume_series` contains `volume` sub-collections.
- **CollectionItem** (`collection_item.rb`): polymorphic, ordered join. Item is a
  Manifestation, Collection, Person, or alt_title placeholder. Validates: no
  cycles, unique `seqno` per collection.

### Other key models
- **Ingestible** (`ingestible.rb`): draft content for ingestion
  (draft/ingested/failed/awaiting_authorities). DOCX via ActiveStorage → Pandoc → markdown.
- **Downloadable** (`downloadable.rb`): generated format in ActiveStorage;
  polymorphic to Manifestation|Anthology|Collection; doctypes
  pdf/html/docx/epub/mobi/txt/odt/kwic.
- **Anthology** (`anthology.rb`): user-curated text set (priv/unlisted/pub).
- **Tag/Tagging** (`tag.rb`,`tagging.rb`): crowdsourced tags
  (pending/approved/rejected/semiapproved/escalated); taggable is Authority,
  Manifestation, Work, Expression, Anthology, or Collection.
- **ExternalLink** (`external_link.rb`): submitted/approved/rejected; linkable is
  Authority, Manifestation, or Collection.

---

## CONTROLLERS (app/controllers/)
- **ManifestationController**: `read` (HTML + chapters + recs + bookmarks),
  `browse` (Elasticsearch-filtered list), `download`/`print` (via
  MakeFreshDownloadable), `kwic` (in-text concordance). `requires_editor` for edits.
- **AuthorsController**: `toc` (works by collection tree via GenerateTocTree),
  `manage_toc` (editor TOC editing), `publish`, `volumes` (JSON of multi-volume works).
- **CollectionsController**: `show` (via FetchCollection), `download`/`print`,
  `pby_volumes`, `kwic`.
- **IngestiblesController**: `edit`, `review` (validate TOC + authorities),
  `ingest` (parse markdown TOC → create Manifestations/collections/volume
  assignments), `undo` (rollback). Concurrency via LockIngestibleConcern.

## SERVICES (app/services/)
- **MarkdownToHtml**: MultiMarkdown → HTML (rmultimarkdown); adds
  `target="_blank"`, fixes footnotes, wraps tables in scroll containers.
- **MakeHeadingIdsUnique**: dedupes heading IDs when merging texts.
- **ManifestationHtmlWithChapters**: extracts chapter headings, builds nav
  sidebar, adds anchors + permalink icons to h2/h3.
- **GenerateTocTree**: builds an authority's collection-based TOC tree (two-pass:
  direct collections+children, then manifestations grouped by parent collection).
- **FetchCollection**: preloads all manifestations + nested collections for a
  collection (avoids N+1; traverses children and parents).
- **MakeFreshDownloadable**: HTML → format (PDF wkhtmltopdf; DOCX/ODT PandocRuby;
  EPUB gepub; MOBI kindlegen); caches as Downloadable. **GetFreshManifestationDownloadable**
  regenerates when stale/missing.
- **SearchManifestations**: Elasticsearch query builder (languages, genres,
  periods, tags, authors, translations vs originals). **ElasticsearchAutocomplete**:
  prefix search.
- **Chewy indexes** (app/chewy/): manifestations_index, manifestations_autocomplete_index,
  authorities_index, authorities_autocomplete_index, collections_index. Model
  `update_index()` callbacks reindex on save.
- **AlternateHebrewForms** (alt spellings for search), **GenerateKwicConcordance**.

## KEY WORKFLOWS
- **Ingestion**: DOCX → Pandoc → markdown → `review` (authorities check) →
  `ingest` parses TOC (`&&&` markers) → Manifestations/collections/volumes; `undo` rolls back.
- **Reading**: `read` → ManifestationHtmlWithChapters → HTML + chapter nav + recs +
  tags + links; bookmark via JS (set_bookmark/remove_bookmark).
- **Collection browse**: `show` → FetchCollection preload → nested render → download via MakeFreshDownloadable.
- **Authority TOC**: `toc` → GenerateTocTree (direct collections + manifestations by collection).

---

## VIEW INTERNALS: Collection#show & Manifestation#read
The two most-visited/most-modified views; re-deriving them is expensive.

### Collection#show (`app/views/collections/show.html.haml`, ~350 lines)
- Controller builds `@htmls`, tuples via `CollectionsController#prep_for_show` →
  `build_htmls_recursively`:
  `[title, ias, html, is_curated, genre, i, ci, nesting_level, parent_authorities, title_footnote]`
  - `ias` = that item's `InvolvedAuthority` records (already merged Expression+Work,
    see `CollectionItem#involved_authorities`).
  - `ci` = the `CollectionItem`; use `ci.item_type` (`'Manifestation'` vs
    `'Collection'`) to know which branch renders, `ci.item` for the actual object.
  - `html` is `nil` when `ci.item_type == 'Collection'` (sub-collection header);
    otherwise the item's rendered HTML body.
- View loops `@htmls` twice: sidebar TOC (`.binder-texts-list`), then cards
  (`.by-card-v02.proofable`).
- Per-item translator (manifestation branch): filter `ias` by `ia.role ==
  'translator'`, reject authorities already shown at collection level
  (`ctranslators`), render `%p= "#{t(:translated_by)} #{names}"`. Item's original
  language: `ci.item.expression.work.orig_lang` (only when `ci.item_type == 'Manifestation'`).
- Collection-level authors/editors/translators come from `@collection.translators`
  / `.authors` / `.editors` / `.involved_authorities_by_role(:x)`, shown once in
  the top `.work-info-card` header.
- `FetchCollection.call(@collection)` preloads before `prep_for_show` (avoids N+1).

### Manifestation#read (`read.html.haml` → `_metadata.html.haml` + `_work_top.haml`)
- Instance vars in metadata partial: `@m` (Manifestation), `@e` (Expression),
  `@w`/`@e.work` (Work), `@translators`.
- Canonical translator + original-language display (mirror this elsewhere):
  ```haml
  - if @e.translation && @e.translators.size > 0
    %br
    = "#{t(:translation)}: "
    != @translators.map { |t| link_to(t.name, authority_path(t)) }.join(', ')
    - linktext = orig_lang_label(@e.work.orig_lang)
    != " (#{linktext})"
  ```
  i.e. original language = parenthetical text right after translator name(s), via `orig_lang_label()`.
- `.origlang_details` block (only when `@w.origlang_title.present?`): work's title
  in original language + link to source text if an `ExternalLink` of
  `linktype: source_text` exists.
- `.metadata` row variant: bold label + link to `works_path` filtered by language:
  `t(:orig_lang)+': '` then `link_to textify_lang(@e.work.orig_lang), works_path + '?ckb_languages[]=' + @e.work.orig_lang`.

### Shared visual vocabulary (reuse, don't reinvent)
- `.by-card-v02` / `-header-v02` / `-content-v02` — card container on nearly every content page.
- `.headline-1-v02` / `-2-v02` / `-3-v02` — title/author/secondary-role text sizes.
- `.by-icon-v02` — glyph-font icon (genre via `glyph_for_genre`/`textify_genre`); not for language.
- `.origlang_details` (in `application.scss`) — small print under title for orig-lang title/source link.
- Language helpers in `lib/bybe_utils.rb` (in `ApplicationHelper`, any view):
  - `textify_lang(iso)` → localized language name, falls back to `I18n.t(:unknown)`.
  - `orig_lang_label(orig_lang)` → display fragment like `"מרוסית"`/`"from Russian"`,
    or `I18n.t(:translated_from_unknown_lang)` if blank/`'unk'`/unrecognized — the
    parenthetical next to translator names.
- Existing i18n keys (in both he.yml/en.yml, rarely need new): `orig_lang`,
  `origlang_title`, `from_lang`, `translation`, `translated_from`,
  `translated_from_unknown_lang`, `translated_by`, `in_orig_lang`,
  `involved_authority.role.translator`, `involved_authority.abstract_roles.translator`,
  plus per-language keys (`hebrew`, `russian`, `german`, ...).

---

## PATTERNS & CONVENTIONS
- **Polymorphic joins**: CollectionItem, InvolvedAuthority, Downloadable, Tagging,
  ExternalLink (see each model above for allowed target types).
- **Performance**: FetchCollection uses `Preloader` (no N+1); `Rails.cache` for
  counts/latest-works; many scopes use `preload()`.
- **I18n**: all user-visible strings via `I18n.t()`; `config/locales/{he,en}.yml`.
  When storing user text in the DB, store the I18n key, not the translation.
- **Storage**: ActiveStorage (S3 prod, local dev) — Downloadable#stored_file,
  Ingestible#docx, Authority#profile_image.

## COMMON MODIFICATION POINTS
| Task | Files |
|------|-------|
| New manifestation filter | `SearchManifestations`, chewy indexes, ManifestationController |
| New downloadable format | `MakeFreshDownloadable`, Downloadable doctype enum |
| Change markdown→HTML | `MarkdownToHtml`, `ManifestationHtmlWithChapters` |
| Ingestion logic | `IngestiblesController#ingest`, Pandoc settings |
| Collection tree display | `GenerateTocTree`, `FetchCollection`, views/collections/* |
| Add authority field | Authority model + migration, admin views, i18n |
| UI labels/messages | `config/locales/{he,en}.yml` |

Layout: `app/{models,controllers,services,chewy,views}` and `app/api/v1`;
`config/{routes.rb,locales,s3.yml}`; `db/{schema.rb,migrate}`;
`spec/{models,controllers,requests,system,services}` (system specs need `js: true`).

**For specific features: grep class names or route patterns. Most actions are
RESTful; most processing lives in services.**
