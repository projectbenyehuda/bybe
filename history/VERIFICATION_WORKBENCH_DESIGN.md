# Migration Verification Workbench - Design Document

**Date**: 2025-12-26
**Status**: IMPLEMENTED
**Target**: Lexicon Migration from PHP to Rails

## Implementation Summary

The verification workbench has been fully implemented with the following components:

1. ✅ Database migration for `verification_progress` JSON column
2. ✅ LexEntry model with verification methods (start_verification!, verification_percentage, mark_verified!)
3. ✅ VerificationController with all CRUD and verification actions
4. ✅ Routes for verification queue and workbench
5. ✅ Hebrew and English I18n strings (using "מראי מקום" for citations)
6. ✅ Verification queue view (index.html.haml)
7. ✅ Main verification screen with three-column layout (show.html.haml)
8. ✅ All partials: checklist, source PHP (iframe), migrated entry, person sections, publication sections
9. ✅ CSS styles (verification.scss) with responsive design
10. ✅ JavaScript interactions (verification.js) using jQuery

### Key Improvements from Original Design

1. **Rendered PHP in iframe**: The source PHP is rendered in an iframe instead of showing raw source code, making it easier for users to verify the migrated content against the original appearance.

2. **Hebrew terminology**: Citations are labeled as "מראי מקום" (marei mekorot) instead of "ציטוטים" throughout the Hebrew UI, which is more appropriate for this context.

---

## Executive Summary

This document describes a comprehensive verification workbench for reviewing and correcting migrated lexicon entries. The workbench provides side-by-side comparison of source PHP files and migrated content, with inline editing capabilities and progress tracking.

## Design Goals

1. **Side-by-side comparison**: Original PHP source vs. migrated LexEntry
2. **Contextualized editing**: Edit buttons adjacent to each verifiable element
3. **Partial progress tracking**: Save verification state without publishing
4. **Verification checklist**: Guide verifiers through all elements
5. **Status transitions**: Mark entries as verified when complete
6. **Bilingual UI**: Hebrew primary, English for debugging

---

## 1. Data Model Extensions

### 1.1 New Field: `verification_progress` (JSONB)

**Table**: `lex_entries`
**Column**: `verification_progress` (jsonb, nullable)

**Structure**:
```json
{
  "verified_by": "user@example.com",
  "started_at": "2025-12-26T10:00:00Z",
  "last_updated_at": "2025-12-26T11:30:00Z",
  "checklist": {
    "title": {"verified": true, "notes": ""},
    "life_years": {"verified": true, "notes": ""},
    "bio": {"verified": false, "notes": "Check formatting"},
    "works": {"verified": true, "notes": ""},
    "citations": {
      "verified": false,
      "items": {
        "123": {"verified": true, "notes": ""},
        "124": {"verified": false, "notes": "Missing author link"}
      }
    },
    "links": {
      "verified": true,
      "items": {
        "45": {"verified": true, "notes": ""},
        "46": {"verified": true, "notes": ""}
      }
    },
    "attachments": {"verified": true, "notes": ""}
  },
  "overall_notes": "Bio formatting needs review",
  "ready_for_publish": false
}
```

**Benefits**:
- Tracks which elements have been verified
- Stores per-element notes for follow-up
- Records verifier identity and timestamps
- No additional tables needed (JSONB is flexible)

### 1.2 New Status Values

**Extend** `LexEntry.status` enum:
- `raw` (101) - existing: migration not done
- `migrating` (102) - existing: async migration in progress
- `error` (103) - existing: error during migration
- `**verifying**` (104) - **NEW**: under verification review
- `**verified**` (105) - **NEW**: verification complete, ready for publishing

**Status Flow**:
```
raw → migrating → error (if failed)
              ↓
           draft → verifying → verified → published
```

**Rationale**: Separates "migrated" (draft) from "verified" (verified) from "live" (published)

---

## 2. User Interface Design

### 2.1 Entry Point: Verification Queue

**URL**: `/lexicon/verification/queue`

**Features**:
- List entries with status `draft`, `verifying`, or `error`
- Filter by status, entry type (person/publication), date
- Show verification progress percentage
- "Start Verification" button per entry

**Columns**:
| Title | Type | Status | Progress | Last Updated | Actions |
|-------|------|--------|----------|--------------|---------|
| משה בן מימון | Person | Verifying | 75% (6/8 verified) | 2 hours ago | Continue |
| ספר המצוות | Publication | Draft | 0% | 1 day ago | Start |

**Hebrew Labels** (with English in locale):
- כותרת (Title)
- סוג (Type)
- סטטוס (Status)
- התקדמות (Progress)
- עדכון אחרון (Last Updated)
- פעולות (Actions)

### 2.2 Main Verification Screen

**URL**: `/lexicon/verification/:id`

**Layout**: Three-column responsive design

```
┌─────────────────────────────────────────────────────────────────┐
│ Verification: משה בן מימון                    [Mark as Verified] │
├──────────────────┬──────────────────────────┬────────────────────┤
│                  │                          │                    │
│  CHECKLIST       │   SOURCE (PHP)           │  MIGRATED ENTRY    │
│  (Sticky)        │   (Read-only)            │  (Editable)        │
│                  │                          │                    │
│  ☑ Title         │   <div align="center">   │  Title: משה בן מימון│
│  ☑ Life Years    │   <h1>משה בן מימון</h1>  │  [Edit] ✏️         │
│  ☐ Bio           │   </div>                 │                    │
│  ☑ Works         │   <font>1138-1204</font> │  Life: 1138-1204   │
│  ☐ Citations (3) │   ...                    │  [Edit] ✏️         │
│    ☑ Citation 1  │   <h3>ביבליוגרפיה</h3>  │                    │
│    ☐ Citation 2  │   <ul>                   │  Bio: [content...]  │
│    ☐ Citation 3  │     <li>Blau, J...       │  [Edit] ✏️         │
│  ☑ Links (2)     │     </li>                │                    │
│  ☑ Attachments   │   </ul>                  │  Works: [content...] │
│                  │                          │  [Edit] ✏️         │
│  Notes:          │                          │                    │
│  ┌────────────┐  │                          │  Citations:         │
│  │Check bio   │  │   [Full PHP Source]      │  ┌──────────────┐  │
│  │formatting  │  │   [Scrollable]           │  │ Subject: כללי │  │
│  └────────────┘  │                          │  │ ☐ Not Verified│  │
│                  │                          │  │ Blau, J...    │  │
│  Progress: 62%   │                          │  │ [Edit] [✓]    │  │
│  [Save Progress] │                          │  └──────────────┘  │
│                  │                          │                    │
└──────────────────┴──────────────────────────┴────────────────────┘
```

**Responsive Behavior**:
- **Desktop (>1200px)**: Three columns as shown
- **Tablet (768px-1200px)**: Two columns (checklist stacks above, source/migrated side-by-side below)
- **Mobile (<768px)**: Single column with tabs (Checklist / Source / Migrated)

### 2.3 Left Column: Verification Checklist

**Features**:
- Sticky positioning (scrolls independently)
- Checkbox for each verifiable element
- Nested checkboxes for collection items (citations, links)
- Click checkbox to mark verified
- Click label to scroll to corresponding section in right column
- Overall progress percentage
- Notes textarea for overall comments
- "Save Progress" button (updates `verification_progress` JSON)

**Checklist Items** (Hebrew with English):

For **LexPerson**:
- [ ] כותרת (Title)
- [ ] שנות חיים (Life Years)
- [ ] ביוגרפיה (Biography)
- [ ] יצירות (Works)
- [ ] ציטוטים (Citations)
  - [ ] ציטוט 1: [title preview]
  - [ ] ציטוט 2: [title preview]
  - ...
- [ ] קישורים (Links)
  - [ ] קישור 1: [url preview]
  - [ ] קישור 2: [url preview]
  - ...
- [ ] קבצים מצורפים (Attachments)

For **LexPublication**:
- [ ] כותרת (Title)
- [ ] תיאור (Description)
- [ ] תוכן עניינים (Table of Contents)
- [ ] ניווט א-ב (A-Z Navigation)
- [ ] קישורים (Links)
- [ ] קבצים מצורפים (Attachments)

**Interaction**:
- Click checkbox → mark verified, update JSON via AJAX
- Click label → scroll right column to element
- Uncheck → clear verified flag, optionally add note

### 2.4 Middle Column: Source PHP

**Features**:
- Read-only view of original PHP file
- Syntax-highlighted HTML (use Prism.js or similar)
- Line numbers for reference
- Synchronized scrolling (optional): when scrolling right column, highlight corresponding source section

**Data Source**:
- `LexFile.full_path` → read file from disk
- If file missing, show warning: "⚠️ קובץ מקור לא נמצא (Source file not found)"
- Cache file content in session to avoid repeated disk reads

**Display**:
```html
<div class="source-php">
  <div class="source-header">
    <h4>קובץ מקור (Source File)</h4>
    <span class="filename">rambam.php</span>
  </div>
  <pre class="language-html line-numbers"><code>...</code></pre>
</div>
```

### 2.5 Right Column: Migrated Entry (Editable)

**Features**:
- Displays migrated data in structured sections
- Each section has inline "Edit" button
- Clicking "Edit" opens modal or inline form
- After save, updates display without page reload
- Visual indicator for unverified items (yellow highlight or icon)

**Sections for LexPerson**:

#### Section 1: Title & Life Years
```
┌────────────────────────────────────────────┐
│ כותרת וזמנים (Title & Life Years)          │
│                                            │
│ כותרת: משה בן מימון                        │
│ שם למיון: מימון, משה בן                    │
│ שנות חיים: 1138-1204                       │
│ מגדר: זכר                                  │
│                                            │
│ [ערוך / Edit] ✏️                           │
└────────────────────────────────────────────┘
```

**Verification indicator**:
- ✅ Green checkmark if `verification_progress.checklist.title.verified == true`
- ⚠️ Yellow warning if false

#### Section 2: Biography
```
┌────────────────────────────────────────────┐
│ ביוגרפיה (Biography)            ☐ לא אומת │
│                                            │
│ [Rendered HTML/Markdown]                   │
│ משה בן מימון, הרמב"ם, נולד בקורדובה...   │
│                                            │
│ [ערוך / Edit] ✏️                           │
└────────────────────────────────────────────┘
```

#### Section 3: Works
```
┌────────────────────────────────────────────┐
│ יצירות (Works)                   ☑ אומת   │
│                                            │
│ [Rendered HTML/Markdown]                   │
│ • משנה תורה                                │
│ • מורה נבוכים                              │
│                                            │
│ [ערוך / Edit] ✏️                           │
└────────────────────────────────────────────┘
```

#### Section 4: Citations
```
┌────────────────────────────────────────────────────────────────┐
│ ציטוטים (Citations)                          ☐ לא אומת (2/3)  │
│                                                                │
│ נושא: כללי (General)                                           │
│                                                                │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ ☑ Blau, J. (1980). "Maimonides' Philosophy"...          │  │
│ │    מ: Encyclopaedia Judaica                              │  │
│ │    עמ': 123-145                                          │  │
│ │    [ערוך / Edit] ✏️  [סמן כמאומת / Mark Verified] ✓     │  │
│ └──────────────────────────────────────────────────────────┘  │
│                                                                │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ ☐ Cohen, S. (1995). "Guide to the Perplexed"...         │  │
│ │    קישור: [link]                                         │  │
│ │    [ערוך / Edit] ✏️  [סמן כמאומת / Mark Verified] ✓     │  │
│ └──────────────────────────────────────────────────────────┘  │
│                                                                │
│ [הוסף ציטוט / Add Citation] ➕                                 │
└────────────────────────────────────────────────────────────────┘
```

**Citation Card Features**:
- Verification checkbox (updates `verification_progress.checklist.citations.items[citation_id]`)
- Inline "Mark Verified" button (quick action)
- "Edit" button opens existing citation edit modal
- Display parsed fields: authors, title, publication, pages, link
- Show AI parsing status badge if `status == 'ai_parsed'`
- Color coding:
  - Green border: verified
  - Yellow border: not verified
  - Red border: status == 'raw' (needs parsing)

#### Section 5: Links
```
┌────────────────────────────────────────────┐
│ קישורים (Links)                  ☑ אומת   │
│                                            │
│ ☑ Wikipedia: https://he.wikipedia.org/...  │
│    [ערוך / Edit] ✏️  [✓]                   │
│                                            │
│ ☑ Jewish Encyclopedia: http://...          │
│    [ערוך / Edit] ✏️  [✓]                   │
│                                            │
│ [הוסף קישור / Add Link] ➕                  │
└────────────────────────────────────────────┘
```

#### Section 6: Attachments
```
┌────────────────────────────────────────────┐
│ קבצים מצורפים (Attachments)      ☑ אומת   │
│                                            │
│ ☑ rambam.jpg (150 KB)                      │
│    [הצג / View] 👁️  [מחק / Delete] 🗑️    │
│                                            │
│ [העלה קובץ / Upload File] ⬆️               │
└────────────────────────────────────────────┘
```

**Sections for LexPublication**: Similar structure, but replace bio/works with description/toc/az_navbar

### 2.6 Edit Modals

**Reuse existing modal infrastructure** (similar to links CRUD):

#### Title & Life Years Modal
```
┌───────────────────────────────────────────────────┐
│ ערוך פרטים בסיסיים (Edit Basic Details)      [×] │
├───────────────────────────────────────────────────┤
│                                                   │
│ כותרת (Title): [___________________________]     │
│                                                   │
│ שנת לידה (Birth Year): [____]                     │
│ שנת פטירה (Death Year): [____]                    │
│                                                   │
│ מגדר (Gender): [זכר ▾]                            │
│                                                   │
│ ☑ סמן כמאומת (Mark as verified)                  │
│                                                   │
│ הערות (Notes): [_________________________]       │
│                                                   │
│           [ביטול / Cancel]  [שמור / Save]         │
└───────────────────────────────────────────────────┘
```

**Features**:
- Form loads from `/lexicon/verification/:id/edit_section?section=title`
- Checkbox at bottom: "Mark as verified" (updates verification JSON)
- Notes field for this specific section
- On save: update LexEntry + update `verification_progress.checklist.title`

#### Biography/Works Modal
```
┌───────────────────────────────────────────────────┐
│ ערוך ביוגרפיה (Edit Biography)               [×] │
├───────────────────────────────────────────────────┤
│                                                   │
│ [Rich text editor with Markdown preview]          │
│ ┌───────────────────────────────────────────────┐ │
│ │ משה בן מימון, הרמב"ם...                      │ │
│ │                                               │ │
│ │ [Toolbar: B I U Link Image]                  │ │
│ └───────────────────────────────────────────────┘ │
│                                                   │
│ ☑ סמן כמאומת (Mark as verified)                  │
│                                                   │
│ הערות (Notes): [_________________________]       │
│                                                   │
│           [ביטול / Cancel]  [שמור / Save]         │
└───────────────────────────────────────────────────┘
```

#### Citation Edit Modal

**Reuse existing** `/lexicon/citations/:id/edit` modal with addition:
- Checkbox: "סמן ציטוט זה כמאומת (Mark this citation as verified)"
- Updates `verification_progress.checklist.citations.items[citation_id]`

### 2.7 Top Action Bar

```
┌─────────────────────────────────────────────────────────────────┐
│ אימות: משה בן מימון (Verifying: Maimonides)                    │
│                                                                 │
│ [← חזור לרשימה / Back to Queue]                                │
│                                                                 │
│ התקדמות (Progress): 62% (5/8 verified)                          │
│ ■■■■■□□□                                                        │
│                                                                 │
│ [שמור התקדמות / Save Progress] [סמן כמאומת / Mark as Verified] │
└─────────────────────────────────────────────────────────────────┘
```

**"Save Progress" button**:
- Updates `verification_progress` JSON
- Does NOT change entry status
- Shows toast: "התקדמות נשמרה (Progress saved)"

**"Mark as Verified" button**:
- **Only enabled** when all checklist items are verified (100%)
- Updates `LexEntry.status` → `verified`
- Updates `verification_progress.ready_for_publish` → `true`
- Redirects to queue with success message: "הערך אומת בהצלחה (Entry verified successfully)"

---

## 3. Backend Implementation Plan

### 3.1 Database Migration

**File**: `db/migrate/YYYYMMDDHHMMSS_add_verification_to_lex_entries.rb`

```ruby
class AddVerificationToLexEntries < ActiveRecord::Migration[7.1]
  def change
    # Add JSONB column for verification progress
    add_column :lex_entries, :verification_progress, :jsonb, default: {}, null: false

    # Add new status values (extend existing enum)
    # Note: Rails enum uses integers, so add to status enum in model

    # Add index for querying entries in verification
    add_index :lex_entries, :verification_progress,
              using: :gin,
              where: "status IN (104, 105)", # verifying, verified
              name: :idx_verification_progress
  end
end
```

### 3.2 Model Updates

**File**: `app/models/lex_entry.rb`

```ruby
class LexEntry < ApplicationRecord
  # Extend existing status enum
  enum :status, {
    draft: 0,
    published: 1,
    deprecated: 2,
    raw: 101,
    migrating: 102,
    error: 103,
    verifying: 104,      # NEW
    verified: 105        # NEW
  }, prefix: true

  # Scopes for verification queue
  scope :needs_verification, -> { where(status: [:draft, :verifying, :error]) }
  scope :in_verification, -> { where(status: :verifying) }
  scope :verified_pending_publish, -> { where(status: :verified) }

  # Initialize verification progress
  def start_verification!(user_email)
    update!(
      status: :verifying,
      verification_progress: {
        verified_by: user_email,
        started_at: Time.current,
        last_updated_at: Time.current,
        checklist: build_checklist,
        overall_notes: "",
        ready_for_publish: false
      }
    )
  end

  # Calculate verification percentage
  def verification_percentage
    return 0 if verification_progress.blank?

    checklist = verification_progress['checklist'] || {}
    total = 0
    verified = 0

    # Count top-level items
    %w[title life_years bio works attachments].each do |key|
      if checklist[key]
        total += 1
        verified += 1 if checklist[key]['verified']
      end
    end

    # Count collection items (citations, links)
    %w[citations links].each do |collection|
      if checklist[collection]&.dig('items')
        items = checklist[collection]['items']
        total += items.size
        verified += items.count { |_k, v| v['verified'] }
      end
    end

    return 0 if total.zero?
    ((verified.to_f / total) * 100).round
  end

  # Check if ready to mark as verified
  def verification_complete?
    verification_percentage == 100
  end

  # Mark entry as verified
  def mark_verified!
    raise "Verification not complete" unless verification_complete?

    update!(
      status: :verified,
      verification_progress: verification_progress.merge(
        'ready_for_publish' => true,
        'completed_at' => Time.current
      )
    )
  end

  private

  def build_checklist
    checklist = {}

    case lex_item_type
    when 'LexPerson'
      checklist['title'] = { verified: false, notes: '' }
      checklist['life_years'] = { verified: false, notes: '' }
      checklist['bio'] = { verified: false, notes: '' }
      checklist['works'] = { verified: false, notes: '' }

      # Citations
      citation_items = lex_item.citations.each_with_object({}) do |cit, hash|
        hash[cit.id.to_s] = { verified: false, notes: '' }
      end
      checklist['citations'] = { verified: false, items: citation_items }

    when 'LexPublication'
      checklist['title'] = { verified: false, notes: '' }
      checklist['description'] = { verified: false, notes: '' }
      checklist['toc'] = { verified: false, notes: '' }
      checklist['az_navbar'] = { verified: false, notes: '' }
    end

    # Links (common to both)
    link_items = lex_item.links.each_with_object({}) do |link, hash|
      hash[link.id.to_s] = { verified: false, notes: '' }
    end
    checklist['links'] = { verified: false, items: link_items }

    # Attachments
    checklist['attachments'] = { verified: false, notes: '' }

    checklist
  end
end
```

### 3.3 Controller: VerificationController

**File**: `app/controllers/lexicon/verification_controller.rb`

```ruby
module Lexicon
  class VerificationController < ApplicationController
    before_action :set_entry, except: [:index]

    # GET /lexicon/verification/queue
    def index
      @entries = LexEntry.needs_verification
                         .includes(:lex_item, :lex_file)
                         .order(updated_at: :desc)
                         .page(params[:page])
    end

    # GET /lexicon/verification/:id
    def show
      # Initialize verification if not started
      unless @entry.status_verifying? || @entry.status_verified?
        @entry.start_verification!(current_user.email)
      end

      @source_content = load_source_php
      @checklist = @entry.verification_progress['checklist']
      @item = @entry.lex_item # LexPerson or LexPublication
    end

    # PATCH /lexicon/verification/:id/update_checklist
    def update_checklist
      path = params[:path] # e.g., "title" or "citations.items.123"
      verified = params[:verified] # true/false
      notes = params[:notes] # optional notes

      # Update nested hash
      progress = @entry.verification_progress.deep_dup
      checklist = progress['checklist']

      # Navigate to nested key and update
      keys = path.split('.')
      target = checklist.dig(*keys[0..-2]) || checklist
      target[keys.last] = { 'verified' => verified, 'notes' => notes }

      progress['last_updated_at'] = Time.current
      @entry.update!(verification_progress: progress)

      render json: {
        success: true,
        percentage: @entry.verification_percentage,
        complete: @entry.verification_complete?
      }
    end

    # PATCH /lexicon/verification/:id/save_progress
    def save_progress
      notes = params[:overall_notes]

      progress = @entry.verification_progress.deep_dup
      progress['overall_notes'] = notes
      progress['last_updated_at'] = Time.current

      @entry.update!(verification_progress: progress)

      flash.now[:success] = I18n.t('lexicon.verification.progress_saved')
      render json: { success: true }
    end

    # POST /lexicon/verification/:id/mark_verified
    def mark_verified
      begin
        @entry.mark_verified!
        redirect_to lexicon_verification_index_path,
                    notice: I18n.t('lexicon.verification.entry_verified')
      rescue => e
        flash.now[:error] = e.message
        redirect_to lexicon_verification_path(@entry), alert: e.message
      end
    end

    # GET /lexicon/verification/:id/edit_section?section=title
    def edit_section
      @section = params[:section]
      @item = @entry.lex_item

      render partial: "lexicon/verification/edit_#{@section}"
    end

    # PATCH /lexicon/verification/:id/update_section
    def update_section
      section = params[:section]
      mark_verified = params[:mark_verified] == '1'
      notes = params[:notes]

      # Update the item (LexPerson or LexPublication)
      if @entry.lex_item.update(item_params)
        # Update verification checklist
        if mark_verified
          progress = @entry.verification_progress.deep_dup
          progress['checklist'][section] = { 'verified' => true, 'notes' => notes }
          progress['last_updated_at'] = Time.current
          @entry.update!(verification_progress: progress)
        end

        flash.now[:success] = I18n.t('lexicon.verification.section_updated')
        render json: { success: true, percentage: @entry.verification_percentage }
      else
        render json: { success: false, errors: @entry.lex_item.errors.full_messages },
               status: :unprocessable_entity
      end
    end

    private

    def set_entry
      @entry = LexEntry.includes(:lex_item, :lex_file).find(params[:id])
    end

    def load_source_php
      return nil unless @entry.lex_file&.full_path

      file_path = @entry.lex_file.full_path
      return nil unless File.exist?(file_path)

      File.read(file_path)
    rescue => e
      Rails.logger.error("Failed to load source PHP: #{e.message}")
      nil
    end

    def item_params
      # Permit params based on item type
      case @entry.lex_item_type
      when 'LexPerson'
        params.require(:lex_person).permit(
          :birthdate, :deathdate, :bio, :works, :gender, :aliases, :copyrighted
        )
      when 'LexPublication'
        params.require(:lex_publication).permit(
          :description, :toc, :az_navbar
        )
      end
    end
  end
end
```

### 3.4 Routes

**File**: `config/routes.rb` (add to lexicon namespace)

```ruby
namespace :lexicon, path: :lex do
  # Existing routes...

  namespace :verification do
    get :queue, to: 'verification#index', as: :index
    resources :entries, only: [:show], path: '', as: '' do
      member do
        patch :update_checklist
        patch :save_progress
        post :mark_verified
        get :edit_section
        patch :update_section
      end
    end
  end

  # Shorthand route
  get 'verification', to: 'verification#index'
end
```

**Generated paths**:
- `/lexicon/verification/queue` → verification queue
- `/lexicon/verification/:id` → verification screen
- `/lexicon/verification/:id/update_checklist` → AJAX checkbox toggle
- `/lexicon/verification/:id/save_progress` → save notes
- `/lexicon/verification/:id/mark_verified` → complete verification

### 3.5 Views Structure

**Files**:
```
app/views/lexicon/verification/
├── index.html.haml              # Verification queue
├── show.html.haml               # Main verification screen
├── _checklist.html.haml         # Left column
├── _source_php.html.haml        # Middle column
├── _migrated_entry.html.haml    # Right column
├── _person_sections.html.haml   # Right column content for LexPerson
├── _publication_sections.html.haml # Right column content for LexPublication
├── _edit_title.html.haml        # Modal: edit title/life years
├── _edit_bio.html.haml          # Modal: edit biography
├── _edit_works.html.haml        # Modal: edit works
├── _edit_description.html.haml  # Modal: edit publication description
└── _edit_toc.html.haml          # Modal: edit TOC
```

---

## 4. JavaScript Interactions

### 4.1 Checklist Item Toggle

```javascript
// app/javascript/controllers/verification_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "progress", "markVerifiedBtn"]

  toggleItem(event) {
    const checkbox = event.target
    const path = checkbox.dataset.path
    const verified = checkbox.checked
    const notes = checkbox.dataset.notes || ""

    // AJAX request to update checklist
    fetch(this.updateUrl, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({ path, verified, notes })
    })
    .then(response => response.json())
    .then(data => {
      // Update progress bar
      this.progressTarget.textContent = `${data.percentage}%`
      this.progressTarget.style.width = `${data.percentage}%`

      // Enable/disable "Mark Verified" button
      if (data.complete) {
        this.markVerifiedBtnTarget.disabled = false
      } else {
        this.markVerifiedBtnTarget.disabled = true
      }

      // Visual feedback
      this.showToast('נשמר')
    })
  }

  scrollToSection(event) {
    event.preventDefault()
    const label = event.target
    const sectionId = label.dataset.sectionId
    const section = document.getElementById(sectionId)

    if (section) {
      section.scrollIntoView({ behavior: 'smooth', block: 'start' })
      section.classList.add('highlight-flash')
      setTimeout(() => section.classList.remove('highlight-flash'), 2000)
    }
  }

  saveProgress(event) {
    event.preventDefault()
    const notes = document.querySelector('#overall_notes').value

    fetch(this.saveProgressUrl, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({ overall_notes: notes })
    })
    .then(response => response.json())
    .then(data => {
      this.showToast('התקדמות נשמרה')
    })
  }

  showToast(message) {
    // Use Bootstrap toast or custom notification
    const toast = document.createElement('div')
    toast.className = 'toast-notification'
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 3000)
  }

  get updateUrl() {
    return this.element.dataset.updateUrl
  }

  get saveProgressUrl() {
    return this.element.dataset.saveProgressUrl
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }
}
```

### 4.2 Section Edit Modal

**Reuse existing modal infrastructure** from links CRUD:

```javascript
// Existing pattern in app
function openModal(url) {
  fetch(url, { headers: { 'Accept': 'text/html' } })
    .then(response => response.text())
    .then(html => {
      const modalContainer = document.getElementById('modal-container')
      modalContainer.innerHTML = html
      const modal = new bootstrap.Modal(modalContainer.querySelector('.modal'))
      modal.show()
    })
}

// Add to section edit buttons
document.querySelectorAll('[data-edit-section]').forEach(btn => {
  btn.addEventListener('click', (e) => {
    e.preventDefault()
    const section = btn.dataset.editSection
    const entryId = btn.dataset.entryId
    const url = `/lexicon/verification/${entryId}/edit_section?section=${section}`
    openModal(url)
  })
})
```

### 4.3 Citation Quick Verify

```javascript
// Quick "Mark Verified" button on citation cards
document.querySelectorAll('[data-verify-citation]').forEach(btn => {
  btn.addEventListener('click', (e) => {
    e.preventDefault()
    const citationId = btn.dataset.citationId
    const path = `citations.items.${citationId}`

    // Toggle verified state
    const isVerified = btn.classList.contains('verified')

    fetch(updateChecklistUrl, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({
        path,
        verified: !isVerified,
        notes: ''
      })
    })
    .then(response => response.json())
    .then(data => {
      // Toggle button state
      btn.classList.toggle('verified')
      btn.textContent = btn.classList.contains('verified')
        ? '✓ מאומת'
        : 'סמן כמאומת'

      // Update citation card styling
      const card = btn.closest('.citation-card')
      card.classList.toggle('verified')

      // Update progress
      updateProgress(data.percentage)
    })
  })
})
```

---

## 5. I18n Locales

### 5.1 Hebrew (config/locales/he.yml)

```yaml
he:
  lexicon:
    verification:
      queue:
        title: "תור אימות הגירה"
        columns:
          title: "כותרת"
          type: "סוג"
          status: "סטטוס"
          progress: "התקדמות"
          last_updated: "עדכון אחרון"
          actions: "פעולות"
        actions:
          start: "התחל אימות"
          continue: "המשך אימות"
        filters:
          all: "הכל"
          draft: "טיוטה"
          verifying: "באימות"
          error: "שגיאה"
      show:
        title: "אימות: %{entry_title}"
        back_to_queue: "חזור לרשימה"
        save_progress: "שמור התקדמות"
        mark_verified: "סמן כמאומת"
        progress: "התקדמות"
      checklist:
        title: "רשימת בדיקה"
        overall_notes: "הערות כלליות"
        person:
          title: "כותרת"
          life_years: "שנות חיים"
          bio: "ביוגרפיה"
          works: "יצירות"
          citations: "ציטוטים"
          links: "קישורים"
          attachments: "קבצים מצורפים"
        publication:
          title: "כותרת"
          description: "תיאור"
          toc: "תוכן עניינים"
          az_navbar: "ניווט א-ב"
          links: "קישורים"
          attachments: "קבצים מצורפים"
      source:
        header: "קובץ מקור"
        file_not_found: "⚠️ קובץ מקור לא נמצא"
      migrated:
        header: "ערך שהועבר"
        edit: "ערוך"
        add_citation: "הוסף ציטוט"
        add_link: "הוסף קישור"
        upload_file: "העלה קובץ"
        verified: "מאומת"
        not_verified: "לא אומת"
        mark_verified: "סמן כמאומת"
      messages:
        progress_saved: "ההתקדמות נשמרה בהצלחה"
        entry_verified: "הערך אומת בהצלחה"
        section_updated: "הקטע עודכן בהצלחה"
        verification_incomplete: "אימות לא הושלם - אנא אמת את כל הרכיבים"
```

### 5.2 English (config/locales/en.yml)

```yaml
en:
  lexicon:
    verification:
      queue:
        title: "Migration Verification Queue"
        columns:
          title: "Title"
          type: "Type"
          status: "Status"
          progress: "Progress"
          last_updated: "Last Updated"
          actions: "Actions"
        actions:
          start: "Start Verification"
          continue: "Continue Verification"
        filters:
          all: "All"
          draft: "Draft"
          verifying: "Verifying"
          error: "Error"
      show:
        title: "Verifying: %{entry_title}"
        back_to_queue: "Back to Queue"
        save_progress: "Save Progress"
        mark_verified: "Mark as Verified"
        progress: "Progress"
      checklist:
        title: "Verification Checklist"
        overall_notes: "Overall Notes"
        person:
          title: "Title"
          life_years: "Life Years"
          bio: "Biography"
          works: "Works"
          citations: "Citations"
          links: "Links"
          attachments: "Attachments"
        publication:
          title: "Title"
          description: "Description"
          toc: "Table of Contents"
          az_navbar: "A-Z Navigation"
          links: "Links"
          attachments: "Attachments"
      source:
        header: "Source File"
        file_not_found: "⚠️ Source file not found"
      migrated:
        header: "Migrated Entry"
        edit: "Edit"
        add_citation: "Add Citation"
        add_link: "Add Link"
        upload_file: "Upload File"
        verified: "Verified"
        not_verified: "Not Verified"
        mark_verified: "Mark as Verified"
      messages:
        progress_saved: "Progress saved successfully"
        entry_verified: "Entry verified successfully"
        section_updated: "Section updated successfully"
        verification_incomplete: "Verification incomplete - please verify all components"
```

---

## 6. CSS Styling Considerations

### 6.1 Layout Classes

```scss
// app/assets/stylesheets/lexicon/verification.scss

.verification-container {
  display: grid;
  grid-template-columns: 250px 1fr 1fr;
  gap: 1rem;
  height: calc(100vh - 120px);

  @media (max-width: 1200px) {
    grid-template-columns: 1fr 1fr;
    grid-template-rows: auto 1fr;
  }

  @media (max-width: 768px) {
    grid-template-columns: 1fr;
    grid-template-rows: auto auto auto;
  }
}

.verification-checklist {
  position: sticky;
  top: 20px;
  max-height: calc(100vh - 140px);
  overflow-y: auto;
  padding: 1rem;
  background: #f8f9fa;
  border-radius: 8px;

  ul {
    list-style: none;
    padding-left: 0;

    li {
      margin-bottom: 0.5rem;

      &.nested {
        padding-left: 1.5rem;
      }
    }
  }

  .progress-bar-container {
    margin-top: 1rem;
    height: 20px;
    background: #e9ecef;
    border-radius: 10px;
    overflow: hidden;

    .progress-bar {
      height: 100%;
      background: linear-gradient(90deg, #28a745, #20c997);
      transition: width 0.3s ease;
    }
  }
}

.verification-source {
  padding: 1rem;
  background: #fff;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  overflow-y: auto;
  max-height: calc(100vh - 140px);

  pre {
    margin: 0;
    font-size: 0.875rem;
    line-height: 1.5;
  }
}

.verification-migrated {
  padding: 1rem;
  background: #fff;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  overflow-y: auto;
  max-height: calc(100vh - 140px);

  .section {
    margin-bottom: 2rem;
    padding: 1rem;
    border: 2px solid #e9ecef;
    border-radius: 8px;
    position: relative;

    &.verified {
      border-color: #28a745;
      background: #f0fff4;
    }

    &.not-verified {
      border-color: #ffc107;
      background: #fffbf0;
    }

    &.highlight-flash {
      animation: highlight 2s ease;
    }
  }

  .section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;

    h4 {
      margin: 0;
    }

    .verification-badge {
      font-size: 0.875rem;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;

      &.verified {
        background: #28a745;
        color: white;
      }

      &.not-verified {
        background: #ffc107;
        color: #333;
      }
    }
  }

  .citation-card {
    padding: 1rem;
    margin-bottom: 1rem;
    border: 2px solid #e9ecef;
    border-radius: 8px;
    background: #fff;

    &.verified {
      border-color: #28a745;
      background: #f0fff4;
    }

    .citation-actions {
      margin-top: 0.5rem;
      display: flex;
      gap: 0.5rem;
    }
  }
}

@keyframes highlight {
  0%, 100% { background: inherit; }
  50% { background: #fff3cd; }
}

.toast-notification {
  position: fixed;
  bottom: 2rem;
  right: 2rem;
  background: #28a745;
  color: white;
  padding: 1rem 1.5rem;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  z-index: 9999;
  animation: slideIn 0.3s ease, slideOut 0.3s ease 2.7s;
}

@keyframes slideIn {
  from { transform: translateX(400px); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

@keyframes slideOut {
  from { transform: translateX(0); opacity: 1; }
  to { transform: translateX(400px); opacity: 0; }
}
```

### 6.2 RTL Support

Since the interface is primarily Hebrew, ensure RTL is properly configured:

```scss
// Ensure RTL for Hebrew content
[dir="rtl"] {
  .verification-checklist ul li.nested {
    padding-left: 0;
    padding-right: 1.5rem;
  }

  .verification-migrated .section-header {
    text-align: right;
  }

  .citation-card .citation-actions {
    flex-direction: row-reverse;
  }
}
```

---

## 7. Testing Strategy

### 7.1 Model Tests

**File**: `spec/models/lex_entry_spec.rb` (add to existing)

```ruby
RSpec.describe LexEntry, type: :model do
  describe 'verification' do
    let(:entry) { create(:lex_entry, :with_person, status: :draft) }

    describe '#start_verification!' do
      it 'sets status to verifying' do
        entry.start_verification!('user@example.com')
        expect(entry.status).to eq('verifying')
      end

      it 'initializes verification_progress' do
        entry.start_verification!('user@example.com')
        expect(entry.verification_progress).to include('verified_by', 'checklist')
      end

      it 'builds checklist based on item type' do
        entry.start_verification!('user@example.com')
        checklist = entry.verification_progress['checklist']
        expect(checklist.keys).to include('title', 'life_years', 'bio', 'works', 'citations', 'links')
      end
    end

    describe '#verification_percentage' do
      before do
        entry.start_verification!('user@example.com')
      end

      it 'returns 0 when nothing verified' do
        expect(entry.verification_percentage).to eq(0)
      end

      it 'calculates percentage correctly' do
        progress = entry.verification_progress.deep_dup
        progress['checklist']['title']['verified'] = true
        progress['checklist']['life_years']['verified'] = true
        entry.update!(verification_progress: progress)

        # Assuming 8 total items (6 sections + 2 citations)
        expect(entry.verification_percentage).to eq(25) # 2/8
      end
    end

    describe '#verification_complete?' do
      before do
        entry.start_verification!('user@example.com')
      end

      it 'returns true when all items verified' do
        progress = entry.verification_progress.deep_dup
        verify_all_items(progress['checklist'])
        entry.update!(verification_progress: progress)

        expect(entry.verification_complete?).to be true
      end
    end

    describe '#mark_verified!' do
      before do
        entry.start_verification!('user@example.com')
      end

      it 'raises error if verification not complete' do
        expect { entry.mark_verified! }.to raise_error('Verification not complete')
      end

      it 'updates status to verified when complete' do
        progress = entry.verification_progress.deep_dup
        verify_all_items(progress['checklist'])
        entry.update!(verification_progress: progress)

        entry.mark_verified!
        expect(entry.status).to eq('verified')
      end
    end
  end
end
```

### 7.2 Controller Tests

**File**: `spec/controllers/lexicon/verification_controller_spec.rb`

```ruby
RSpec.describe Lexicon::VerificationController, type: :controller do
  let(:entry) { create(:lex_entry, :with_person, status: :draft) }

  describe 'GET #index' do
    it 'returns entries needing verification' do
      get :index
      expect(response).to be_successful
      expect(assigns(:entries)).to include(entry)
    end
  end

  describe 'GET #show' do
    it 'initializes verification if not started' do
      get :show, params: { id: entry.id }
      expect(entry.reload.status).to eq('verifying')
    end

    it 'loads source PHP content' do
      create(:lex_file, lex_entry: entry, full_path: '/path/to/file.php')
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return('<html>...</html>')

      get :show, params: { id: entry.id }
      expect(assigns(:source_content)).to eq('<html>...</html>')
    end
  end

  describe 'PATCH #update_checklist' do
    before do
      entry.start_verification!('user@example.com')
    end

    it 'updates checklist item' do
      patch :update_checklist, params: {
        id: entry.id,
        path: 'title',
        verified: true,
        notes: 'Looks good'
      }, format: :json

      expect(response).to be_successful
      checklist = entry.reload.verification_progress['checklist']
      expect(checklist['title']['verified']).to be true
    end

    it 'returns updated percentage' do
      patch :update_checklist, params: {
        id: entry.id,
        path: 'title',
        verified: true
      }, format: :json

      json = JSON.parse(response.body)
      expect(json['percentage']).to be > 0
    end
  end

  describe 'POST #mark_verified' do
    before do
      entry.start_verification!('user@example.com')
    end

    it 'marks entry as verified when complete' do
      # Verify all items
      progress = entry.verification_progress.deep_dup
      verify_all_items(progress['checklist'])
      entry.update!(verification_progress: progress)

      post :mark_verified, params: { id: entry.id }
      expect(entry.reload.status).to eq('verified')
    end

    it 'redirects with error if verification incomplete' do
      post :mark_verified, params: { id: entry.id }
      expect(response).to redirect_to(lexicon_verification_path(entry))
      expect(flash[:alert]).to be_present
    end
  end
end
```

### 7.3 System Tests (Capybara)

**File**: `spec/system/lexicon/verification_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe 'Lexicon Verification', type: :system, js: true do
  let(:entry) { create(:lex_entry, :with_person, status: :draft) }
  let!(:lex_file) { create(:lex_file, lex_entry: entry, full_path: Rails.root.join('spec/fixtures/files/sample.php')) }

  before do
    # Assume authentication
    login_as(create(:user))
  end

  describe 'verification queue' do
    it 'displays entries needing verification' do
      visit lexicon_verification_queue_path

      expect(page).to have_content(entry.title)
      expect(page).to have_link('התחל אימות')
    end

    it 'shows progress for entries in verification' do
      entry.start_verification!('user@example.com')

      visit lexicon_verification_queue_path
      expect(page).to have_content('0%')
    end
  end

  describe 'verification screen' do
    before do
      visit lexicon_verification_path(entry)
    end

    it 'displays three columns' do
      expect(page).to have_css('.verification-checklist')
      expect(page).to have_css('.verification-source')
      expect(page).to have_css('.verification-migrated')
    end

    it 'shows source PHP content' do
      expect(page).to have_content('קובץ מקור')
      # Check for PHP content from fixture
    end

    it 'allows checking items in checklist' do
      checkbox = find('input[type="checkbox"][data-path="title"]')
      checkbox.check

      # Wait for AJAX
      expect(page).to have_content('נשמר')

      # Verify percentage updated
      expect(entry.reload.verification_progress['checklist']['title']['verified']).to be true
    end

    it 'enables mark verified button when complete' do
      # Initially disabled
      expect(page).to have_button('סמן כמאומת', disabled: true)

      # Check all items (simulate)
      entry.verification_progress['checklist'].each_key do |key|
        find("input[data-path='#{key}']").check if page.has_css?("input[data-path='#{key}']")
      end

      # Button should be enabled
      expect(page).to have_button('סמן כמאומת', disabled: false)
    end

    it 'opens edit modal when clicking edit button' do
      click_button 'ערוך', match: :first

      expect(page).to have_css('.modal')
      expect(page).to have_field('כותרת')
    end

    it 'saves section edits and updates display' do
      click_button 'ערוך', match: :first

      within('.modal') do
        fill_in 'כותרת', with: 'עריכה חדשה'
        check 'סמן כמאומת'
        click_button 'שמור'
      end

      expect(page).to have_content('עריכה חדשה')
      expect(page).to have_css('.section.verified')
    end
  end
end
```

---

## 8. Performance Considerations

### 8.1 Database Queries

**Problem**: Loading source PHP and related data can be slow

**Solutions**:
1. **Eager loading**: Use `includes(:lex_item, :lex_file, lex_item: [:citations, :links])` in controller
2. **Caching source PHP**: Store in session/cache after first load:
   ```ruby
   def load_source_php
     cache_key = "lex_file_content_#{@entry.lex_file.id}"
     Rails.cache.fetch(cache_key, expires_in: 1.hour) do
       File.read(@entry.lex_file.full_path)
     end
   end
   ```

3. **JSONB indexes**: Add GIN index on `verification_progress` for fast queries:
   ```ruby
   add_index :lex_entries, :verification_progress, using: :gin
   ```

### 8.2 Frontend Performance

**Problem**: Large PHP files and many citations can slow rendering

**Solutions**:
1. **Lazy load tabs**: Load source PHP only when middle column is visible
2. **Virtual scrolling**: For >50 citations, use virtual scroll library
3. **Debounce AJAX**: When checking multiple items rapidly, debounce updates
   ```javascript
   const debouncedUpdate = debounce(updateChecklist, 500)
   ```

4. **Optimize re-renders**: Use Stimulus targets to update only changed elements

### 8.3 Concurrency

**Problem**: Multiple verifiers editing same entry

**Solutions**:
1. **Optimistic locking**: Add `lock_version` column to `lex_entries`
2. **Last-write-wins**: Show warning if `updated_at` changed since page load
3. **User assignment**: Add `verification_progress.locked_by` to prevent conflicts

---

## 9. Migration Path

### Step-by-step Implementation Plan

1. **Phase 1: Data Model** (1-2 days)
   - Create migration for `verification_progress` column
   - Add new status enum values
   - Update LexEntry model with methods
   - Write model tests

2. **Phase 2: Backend** (2-3 days)
   - Create VerificationController
   - Implement all controller actions
   - Write controller tests
   - Add routes

3. **Phase 3: Views - Queue** (1 day)
   - Create verification queue view
   - Add filters and pagination
   - Write I18n strings

4. **Phase 4: Views - Main Screen** (3-4 days)
   - Create three-column layout
   - Build checklist component
   - Build source PHP viewer
   - Build migrated entry sections
   - Make responsive

5. **Phase 5: JavaScript** (2-3 days)
   - Implement Stimulus controller
   - Add AJAX interactions
   - Add modal handlers
   - Test all interactions

6. **Phase 6: Edit Modals** (2 days)
   - Create edit partials for each section
   - Wire up to existing edit actions
   - Add verification checkbox to forms

7. **Phase 7: System Tests** (1-2 days)
   - Write Capybara tests
   - Test happy path
   - Test edge cases

8. **Phase 8: Polish** (1 day)
   - Add CSS styling
   - Improve UX (animations, feedback)
   - Accessibility audit (keyboard navigation)

**Total estimated time**: 13-18 days

---

## 10. Future Enhancements

### 10.1 Batch Operations

- Select multiple entries from queue
- Bulk assign to verifier
- Export verification report (CSV/PDF)

### 10.2 Verification Comments/Discussion

- Add comment threads to entries
- Tag specific sections for discussion
- Notify verifiers of new comments

### 10.3 Analytics Dashboard

- Chart: verification progress over time
- Metrics: average time per entry, common issues
- Leaderboard: top verifiers

### 10.4 AI-Assisted Verification

- Highlight differences between source and migrated
- Suggest corrections based on common patterns
- Auto-verify simple sections (e.g., title extraction confidence >95%)

### 10.5 Keyboard Shortcuts

- `j/k` - Next/previous checklist item
- `e` - Edit current section
- `v` - Toggle verification for current item
- `s` - Save progress
- `m` - Mark as verified (if complete)

---

## 11. Open Questions

1. **User Authentication**: Who can access verification workbench?
   - Only admins?
   - Specific "verifier" role?
   - Any authenticated user?

2. **Reverting Published Entries**: If an error is found after publishing, should we allow reverting to `verifying` status?

3. **Source File Changes**: If PHP file is updated after migration, should we:
   - Block verification?
   - Re-run migration automatically?
   - Show warning and allow manual decision?

4. **Verification Audit Trail**: Should we track who verified each section? (currently only tracking entry-level verifier)

5. **Citation Parsing Status**: Should we enforce that all citations have `status != 'raw'` before allowing verification completion?

---

## Appendix A: Mockups (Text-based)

### A.1 Queue View (Desktop)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ תור אימות הגירה (Migration Verification Queue)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ סינון: [הכל ▾] [Person ▾]  חיפוש: [________] [🔍]                         │
│                                                                             │
├────────┬──────────┬──────────┬─────────────┬──────────────┬──────────────┤
│ כותרת  │ סוג      │ סטטוס    │ התקדמות     │ עדכון אחרון  │ פעולות       │
├────────┼──────────┼──────────┼─────────────┼──────────────┼──────────────┤
│ משה    │ Person   │ Verifying│ ████████░░  │ 2 hours ago  │ [המשך אימות] │
│ בן     │          │          │ 75% (6/8)   │              │              │
│ מימון  │          │          │             │              │              │
├────────┼──────────┼──────────┼─────────────┼──────────────┼──────────────┤
│ ספר    │ Pub      │ Draft    │ ░░░░░░░░░░  │ 1 day ago    │ [התחל אימות] │
│ המצוות │          │          │ 0%          │              │              │
├────────┼──────────┼──────────┼─────────────┼──────────────┼──────────────┤
│ יהודה  │ Person   │ Error    │ ████░░░░░░  │ 3 days ago   │ [התחל אימות] │
│ הלוי   │          │          │ 40% (3/8)   │              │              │
└────────┴──────────┴──────────┴─────────────┴──────────────┴──────────────┘

[1] 2 3 ... 10                                                        50 per page
```

### A.2 Main Verification Screen (Desktop)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ אימות: משה בן מימון                                   [סמן כמאומת - disabled]│
│ [← חזור לרשימה]                                                             │
│                                                                             │
│ התקדמות: 62% ████████████░░░░░░                                             │
├──────────────────┬──────────────────────────┬────────────────────────────────┤
│ רשימת בדיקה     │ קובץ מקור (Source)       │ ערך שהועבר (Migrated)         │
│ (Checklist)      │                          │                               │
├──────────────────┼──────────────────────────┼────────────────────────────────┤
│ ☑ כותרת          │ 1  <div align="center">  │ ┌────────────────────────────┐│
│ ☑ שנות חיים     │ 2  <h1>משה בן מימון</h1> │ │ כותרת וזמנים       ☑ אומת ││
│ ☐ ביוגרפיה      │ 3  </div>                │ │                            ││
│ ☑ יצירות         │ 4  <font>1138-1204</font>│ │ כותרת: משה בן מימון        ││
│ ☐ ציטוטים (3)   │ 5                        │ │ שם למיון: מימון, משה בן    ││
│   ☑ Blau...      │ 6  <h3>ביבליוגרפיה</h3> │ │ שנות חיים: 1138-1204       ││
│   ☐ Cohen...     │ 7  <ul>                  │ │ מגדר: זכר                  ││
│   ☐ Kraemer...   │ 8  <li>Blau, J. (1980)   │ │                            ││
│ ☑ קישורים (2)   │ 9  "Maimonides'          │ │ [ערוך ✏️]                  ││
│   ☑ Wikipedia    │ 10 Philosophy"...        │ └────────────────────────────┘│
│   ☑ JewEnc       │ 11 </li>                 │                               │
│ ☑ קבצים (1)     │ 12 <li>Cohen, S...       │ ┌────────────────────────────┐│
│                  │ 13 </li>                 │ │ ביוגרפיה         ☐ לא אומת││
│ הערות כלליות:   │ ...                      │ │                            ││
│ ┌──────────────┐ │                          │ │ משה בן מימון, הרמב"ם...   ││
│ │בדוק עיצוב    │ │ [Scrollable]             │ │                            ││
│ │הביוגרפיה     │ │                          │ │ [ערוך ✏️]                  ││
│ └──────────────┘ │                          │ └────────────────────────────┘│
│                  │                          │                               │
│ [שמור התקדמות]  │                          │ ┌────────────────────────────┐│
│                  │                          │ │ יצירות              ☑ אומת││
│                  │                          │ │                            ││
│                  │                          │ │ • משנה תורה                ││
│                  │                          │ │ • מורה נבוכים              ││
│                  │                          │ │                            ││
│                  │                          │ │ [ערוך ✏️]                  ││
│                  │                          │ └────────────────────────────┘│
│                  │                          │                               │
│                  │                          │ [Citations section below...]  │
└──────────────────┴──────────────────────────┴────────────────────────────────┘
```

### A.3 Edit Title Modal

```
                  ┌───────────────────────────────────────┐
                  │ ערוך פרטים בסיסיים                [×]│
                  ├───────────────────────────────────────┤
                  │                                       │
                  │ כותרת (Title):                        │
                  │ [משה בן מימון_________________]       │
                  │                                       │
                  │ שנת לידה (Birth Year):                │
                  │ [1138]                                │
                  │                                       │
                  │ שנת פטירה (Death Year):               │
                  │ [1204]                                │
                  │                                       │
                  │ מגדר (Gender):                        │
                  │ [זכר                           ▾]     │
                  │                                       │
                  │ ☑ סמן כמאומת (Mark as verified)      │
                  │                                       │
                  │ הערות (Notes):                        │
                  │ ┌───────────────────────────────────┐ │
                  │ │                                   │ │
                  │ └───────────────────────────────────┘ │
                  │                                       │
                  │      [ביטול]            [שמור]        │
                  │                                       │
                  └───────────────────────────────────────┘
```

---

## Conclusion

This design provides a comprehensive migration verification workbench that meets all stated requirements:

✅ Side-by-side comparison of source PHP and migrated content
✅ Contextualized edit buttons for easy corrections
✅ Partial progress tracking via JSONB field
✅ Comprehensive verification checklist
✅ Status transition workflow (draft → verifying → verified → published)
✅ Full Hebrew UI with English locale support

The design leverages existing patterns in the codebase (tabbed interfaces, modal editing, remote forms) while introducing new capabilities (three-column layout, granular verification tracking, progress visualization).

Next steps: Review this design, request modifications as needed, then proceed to implementation following the phased plan in Section 9.
