Internationalization
--------------------
Despite the fact that the site is in Hebrew, we use English as the language for code, comments and commit messages.
This is to make it easier for non-Hebrew speakers to contribute to the project. We use standard
[rails i18n capabilities](https://guides.rubyonrails.org/i18n.html) and
[rails-18n gem](https://github.com/svenfuchs/rails-i18n) (providing translations for ActiveRecord validation messages
and other built-in rails messages) to support internationalization.

Main language of the site is Hebrew, but we also have English locale for non-hebrew speaking developers (latter is
only available in development and test environments). Significant part of English locale was generated using AI
translation, so it is not perfect and may contain some errors (feel free to fix them and submit a PR).

Historically we used single locale file with flat resources structure (i.e. no controller or view-specific prefixes),
but it was hard to maintain and navigate. Now we're switching to more structured approach, with separate files
for ActiveRecord models and messages, and use controller and view-specific scopes for other resources.
This is still a work in progress, but we strongly recommend to use structured approach for any new resources, and to
refactor existing resources to follow this approach when possible.

### Some recommendations for i18n in views and controllers
#### 1. Use scoped translations for messages used in controllers and views.
E.g. for 'books#show' view you can use:
```yaml
he:
  books:
    show:
      title: פרטי הספר
    create:
      success: ספר חדש נוסף
```

instead of
```yaml
he:
  books_title: פרטי הספר
  book_created: ספר חדש נוסף
```

#### 2. Use [lazy lookup](https://guides.rubyonrails.org/i18n.html#lazy-lookup) when possible.
E.g. in 'books#show' view you can use:
```haml
%h1= t('.title')
```

instead of
```haml
%h1= t('books.show.title')
```

Similarly in controller code you can use:
```ruby
redirect_to books_path, notice: I18n.t('.success')
```

instead of
```ruby
redirect_to books_path, notice: I18n.t('books.create.success')
```

#### 3. Provide translations for all ActiveRecord model names instead of adding separate translations for each model.
E.g. use:
```yaml
he:
  activerecord:
    models:
      book: ספר
```
And use in code:
```ruby
  Book.model_name.human # => "ספר"
```

instead of:
```yaml
he:
  book: ספר
```
and
```ruby
  I18n.t('book') # => "ספר"
```

#### 4. Provide translations for ActiveRecord attributes.
E.g. use:
```yaml
he:
  activerecord:
    attributes:
      book:
        title: כותרת
        author:  מחבר
```
and in view use human_attribute_name method:
```haml
%table
  %thead
    %tr
      %th= Book.human_attribute_name(:title) # => "כותרת"
      %th= Book.human_attribute_name(:author) # => "מחבר"
```

#### 5. Similarly use standard approach for ActiveRecord validation messages and other built-in rails messages.

#### 6. Properly internationalize enum values.
Rails does not provide out-of-the box solution for Enum internationalization, so we use
[human_enum_name](https://github.com/jkostolansky/human_enum_name) gem for that.

E.g. if we have an `Ingestible` class with enum declared like this:
```ruby
enum :status, { draft: 0, ingested: 1, failed: 2, awaiting_authorities: 3 }
```
We can provide translations for enum values like this:
```yaml
he:
  activerecord:
    attributes:
      ingestible:
        statuses:
          awaiting_authorities: ממתינה ליצירת אישים
          draft: טיוטה בעבודה
          ingested: נקלטה בקטלוג
          failed: ההעלאה נכשלה
```
And then use in code:
```ruby
  Ingestible.human_enum_name(:status, ingestible.status)
```
