# ARCHITECTURE PRIMER FOR AI AGENTS: Project Ben-Yehuda (bybe)

> **Quick Reference**: 2-page guide to help AI agents navigate the codebase efficiently

---

## PAGE 1: CORE DATA MODEL & ENTITIES

### PROJECT OVERVIEW
Project Ben-Yehuda (benyehuda.org) is a Hebrew digital library platform built with Rails 8.0, featuring full-text search via Elasticsearch, document format conversion (PDF/EPUB/DOCX), markdown-based content management, and user-curated collections.

**Tech Stack**: Ruby 3.3, Rails 8.0, MySQL, Chewy (Elasticsearch), Pandoc, MultiMarkdown, HAML views, RSpec tests

---

### MAIN DATA ENTITIES (app/models/)

#### **Authority Ecosystem**
- **Authority** (`authority.rb`): Core entity representing an author/creator. Associates with Person or CorporateBody.
  - Relationships: `has_many :involved_authorities, :publications, :featured_contents, :taggings`
  - Enums: `status` (published/unpublished/deprecated/awaiting_first), `intellectual_property` (public_domain/copyrighted/orphan)
  - Key methods: `manifestations(role)`, `volumes`, `collections`, `uncollected_works_collection` (auto-managed system collection)
  - Indexed: AuthoritiesIndex, AuthoritiesAutocompleteIndex (Elasticsearch)

#### **Work-Expression-Manifestation (FRBR-inspired)**
```
Work (abstract work, e.g., "Torah")
  └── Expression (specific version/translation)
      └── Manifestation (physical/digital realization)
```

- **Work** (`work.rb`): Abstract work concept
  - Enums: `genre` (poetry/prose/drama/fables/article/memoir/letters/reference/lexicon)

- **Expression** (`expression.rb`): Specific version/translation of Work
  - Enums: `language`, `period` (ancient/medieval/enlightenment/revival/modern)
  - Boolean: `translation`

- **Manifestation** (`manifestation.rb`): Actual content realization
  - Content: `markdown` (raw), `html` (converted), `sort_title`
  - Enums: `status` (published/nonpd/unpublished/deprecated)
  - Relationships: `recommendations`, `bookmarks`, `downloadables`, `collection_items`, `external_links`

#### **InvolvedAuthority** (`involved_authority.rb`)
- Polymorphic join: Authority → (Work | Expression) with role
- Enums: `role` (author/editor/illustrator/translator/photographer/designer/contributor)
- Validation: WORK_ROLES exclude translator; EXPRESSION_ROLES exclude author
- Triggers: Updates manifestation responsibility statements on changes

#### **Collection Ecosystem**
- **Collection** (`collection.rb`): Heterogeneous container for organizing content
  - Types: volume, periodical, periodical_issue, series, volume_series, other, uncollected (system-managed)
  - Relationships: `has_many :collection_items` (ordered by seqno), `parent_collection_items` (for nesting), `involved_authorities`
  - Methods: `collection_items_by_type()`, `manifestation_items`, `pby_volumes` scope for volumes edited and collected by Project Ben-Yehuda itself (as opposed to previously printed works)

  **Organization Pattern**: Collections provide flexible hierarchical organization:
  - Texts (Manifestations) can be organized into Collections
  - Collections can contain sub-Collections (via CollectionItem polymorphism)
  - **Periodicals structure**:
    - Collection (type: `periodical`) → contains multiple Collections (type: `periodical_issue`)
    - Each periodical_issue → contains Manifestations (articles/texts) and/or Collections (type: `series`)
    - Series can further contain Manifestations
  - Example: "Ha'aretz Newspaper" (periodical) → "Issue Jan 1950" (periodical_issue) → Articles (manifestations) + "Poetry Series" (series) → Poems (manifestations)

- **CollectionItem** (`collection_item.rb`): Polymorphic join (ordered)
  - Item types: Manifestation, Collection, Person, or alt_title (placeholder)
  - Validates: no cycles, unique seqno per collection
  - Orders items via `seqno` (sequence number) for display

#### **Data Flow Diagram**
```
Authority (person/corporate_body)
  ├── has_many involved_authorities
  │   ├── belongs_to (Work | Expression)
  │   └── role: author, translator, editor, etc.
  └── has_many publications

Work
  └── has_many expressions
      └── has_many manifestations
          ├── markdown (raw content)
          ├── html (converted via MarkdownToHtml)
          ├── downloadables (pdf/epub/docx/mobi/txt/odt/kwic)
          └── collection_items (organization)
```

#### **Other Key Models**
- **Ingestible** (`ingestible.rb`): Draft content being prepared for ingestion
  - Status: draft/ingested/failed/awaiting_authorities
  - DOCX attachment via ActiveStorage → converted to markdown via Pandoc

- **Downloadable** (`downloadable.rb`): Generated formats stored in ActiveStorage
  - Polymorphic: `belongs_to manifestation | anthology | collection`
  - Formats: pdf/html/docx/epub/mobi/txt/odt/kwic

- **Anthology** (`anthology.rb`): User-curated collection of texts
  - Access levels: priv/unlisted/pub
  - Has many AnthologyText joins, downloadables, taggings

- **Tag/Tagging** (`tag.rb`, `tagging.rb`): Crowdsourced tags
  - Tagging status: pending/approved/rejected/semiapproved/escalated
  - Polymorphic taggable: Authority, Manifestation, Work, Expression, Anthology, Collection

- **ExternalLink** (`external_link.rb`): Links to external resources
  - Status: submitted/approved/rejected
  - Polymorphic linkable: Authority, Manifestation, Collection

---

## PAGE 2: CONTROLLERS, SERVICES & KEY WORKFLOWS

### MAIN CONTROLLERS (app/controllers/)

#### **ManifestationController** (`manifestation_controller.rb`)
- `read()`: Renders manifestation with HTML, chapters, recommendations, bookmarks
- `browse()`: Elasticsearch-filtered list view (genre, period, tag, language filters)
- `download()` / `print()`: Triggers format generation via MakeFreshDownloadable
- `kwic()`: Keyword-in-context concordance for searching within text
- Auth: requires_editor for edit/update actions

#### **AuthorsController** (`authors_controller.rb`)
- `toc()`: Renders author's works organized by collection tree (via GenerateTocTree service)
- `manage_toc()`: Editor interface for manual TOC modification
- `publish()`: Transitions unpublished authority to published state
- `volumes()`: Returns JSON of author's multi-volume works

#### **CollectionsController** (`collections_controller.rb`)
- `show()`: Fetches collection + all nested manifestations (FetchCollection service)
- `download()` / `print()`: Generates downloadable for entire collection
- `pby_volumes()`: Special endpoint for multi-volume set browser
- `kwic()`: Collection-wide text search

#### **IngestiblesController** (`ingestibles_controller.rb`)
- `edit()`: Markdown editor for ingesting DOCX-converted content
- `review()`: Validates markdown TOC, checks for missing authorities before ingestion
- `ingest()`: Core ingestion—parses markdown TOC, creates Manifestations, collections, assigns to volumes
- `undo()`: Rolls back ingestion (deletes created manifestations, clears collection items)
- Locking: uses LockIngestibleConcern to prevent concurrent edits

---

### CRITICAL SERVICES (app/services/)

#### **Markdown Processing**
- **MarkdownToHtml** (`markdown_to_html.rb`): MultiMarkdown → HTML via rmultimarkdown gem
  - Adds `target="_blank"` to external links
  - Fixes footnote formatting
  - Wraps tables in scroll containers

- **MakeHeadingIdsUnique** (`make_heading_ids_unique.rb`): Ensures heading IDs don't collide when merging multiple texts

#### **Content Rendering**
- **ManifestationHtmlWithChapters** (`manifestation_html_with_chapters.rb`):
  - Extracts chapter headings from markdown
  - Generates chapter navigation sidebar
  - Adds anchors + permalink icons to h2/h3 headings

- **GenerateTocTree** (`generate_toc_tree.rb`): Builds collection-based TOC tree for authority
  - Two-pass: (1) fetch direct collections + children, (2) fetch manifestations by authority + parent collections

- **FetchCollection** (`fetch_collection.rb`): Preloads all manifestations + nested collections within a given collection
  - Avoids N+1 queries
  - Traverses both children (via collection_items) and parents (via inclusions)

#### **Downloadable Generation**
- **MakeFreshDownloadable** (`make_fresh_downloadable.rb`): HTML → format conversion
  - PDF: wkhtmltopdf
  - DOCX/ODT: PandocRuby
  - EPUB: gepub
  - MOBI: kindlegen
  - Caches result as Downloadable with ActiveStorage file_attach

- **GetFreshManifestationDownloadable** (`get_fresh_manifestation_downloadable.rb`): Wrapper that regenerates if stale or missing

#### **Search & Indexing**
- **SearchManifestations** (`search_manifestations.rb`): Elasticsearch query builder
  - Filters: languages, genres, periods, tags, authors, translations vs originals

- **ElasticsearchAutocomplete** (`elasticsearch_autocomplete.rb`): Prefix-search for autocomplete dropdowns

- **Indexes** (app/chewy/):
  - `manifestations_index.rb` - full-text index
  - `manifestations_autocomplete_index.rb` - prefix-search optimized
  - `authorities_index.rb`, `authorities_autocomplete_index.rb`
  - `collections_index.rb`

#### **Data Processing**
- **AlternateHebrewForms** (`alternate_hebrew_forms.rb`): Generates alternate spellings for search
- **GenerateKwicConcordance** (`generate_kwic_concordance.rb`): Builds KWIC table from manifestation text

---

### KEY WORKFLOWS

#### **Content Ingestion** (Ingestible → Manifestation)
1. User uploads DOCX file → Pandoc converts to Markdown
2. Editor reviews markdown in IngestiblesController#review
3. Editor identifies missing authorities (via IngestibleAuthoritiesController)
4. IngestiblesController#ingest parses TOC (markdown `&&&` markers), creates Manifestations, collections, assigns to volumes
5. Ingestion rollback (undo) deletes created records

#### **Reading/Browsing** (Manifestation display)
1. ManifestationController#read loads manifestation, calls ManifestationHtmlWithChapters
2. HTML rendered with chapter navigation sidebar
3. Recommendations, tags, external links populated
4. User can bookmark via JS endpoint (set_bookmark/remove_bookmark)

#### **Collection Browsing**
1. CollectionsController#show calls FetchCollection to preload all items
2. Renders nested manifestations + sub-collections
3. Download/print generates Downloadable via MakeFreshDownloadable

#### **Authority TOC**
1. AuthorsController#toc calls GenerateTocTree
2. Builds tree from: (a) authority's direct collections, (b) authority's manifestations grouped by collection
3. Renders as nested list with manifestation counts

---

### IMPORTANT PATTERNS

#### **Polymorphism**
- **CollectionItem**: item can be Manifestation, Collection, Person, or placeholder (alt_title)
- **InvolvedAuthority**: polymorphic join to Work or Expression
- **Downloadable**: polymorphic to Manifestation, Anthology, or Collection
- **Tagging**: taggable can be Authority, Manifestation, Work, Expression, Anthology, Collection
- **ExternalLink**: linkable can be Authority, Manifestation, Collection

#### **Caching & Performance**
- FetchCollection uses ActiveRecord::Associations::Preloader to avoid N+1
- Rails.cache used extensively (manifestation counts, author latest works, etc.)
- Many scopes with `preload()` for query optimization

#### **I18n**
- All user-visible strings use `I18n.t()` for Hebrew/English locales
- Config: `config/locales/he.yml`, `config/locales/en.yml`

#### **Indexing**
- `update_index()` callbacks in models trigger Chewy reindexing on save
- Used by ManifestationController#browse for filtered search

#### **File Storage**
- ActiveStorage (S3 for production, local in dev): Downloadable#stored_file, Ingestible#docx, Authority#profile_image

---

### COMMON MODIFICATION POINTS

| Task | Files to Modify |
|------|----------------|
| Add new manifestation filter | `SearchManifestations`, elasticsearch indexes, ManifestationController filters |
| Add new downloadable format | `MakeFreshDownloadable`, Downloadable doctype enum |
| Change markdown→HTML rendering | `MarkdownToHtml`, `ManifestationHtmlWithChapters` |
| Modify ingestion logic | `IngestiblesController#ingest`, Pandoc conversion settings |
| Change collection tree display | `GenerateTocTree`, `FetchCollection`, views/collections/* |
| Add authority field | Authority model + migrations, admin views, i18n |
| Modify search behavior | `SearchManifestations`, elasticsearch indexes |
| Update UI labels/messages | `config/locales/he.yml`, `config/locales/en.yml` |

---

### QUICK FILE LOCATION GUIDE

```
app/
├── models/          # Authority, Manifestation, Work, Expression, Collection, CollectionItem, etc.
├── controllers/     # ManifestationController, AuthorsController, CollectionsController, IngestiblesController
├── services/        # MarkdownToHtml, MakeFreshDownloadable, GenerateTocTree, FetchCollection, SearchManifestations
├── chewy/          # Elasticsearch indexes (manifestations_index.rb, authorities_index.rb)
├── views/          # HAML templates (not ERB)
└── api/v1/         # REST API endpoints

config/
├── routes.rb       # Key routes: /read/:id (manifestation), /author/:id (authority), /collections
├── locales/        # he.yml, en.yml (i18n)
└── s3.yml          # S3 credentials for ActiveStorage

db/
├── schema.rb       # Database schema
└── migrate/        # Migrations

spec/
├── models/         # Model specs
├── controllers/    # Controller specs
├── requests/       # API request specs
├── system/         # Capybara system specs (require js: true for JavaScript)
└── services/       # Service specs
```

---

**For questions about specific features, grep for class names or route patterns. Most controller actions are RESTful; most processing happens in services.**
