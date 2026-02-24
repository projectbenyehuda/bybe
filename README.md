This codebase runs https://benyehuda.org -- the Project Ben-Yehuda digital library of works in Hebrew.

We make little effort to make the code general, but if you're looking to do something similar (e.g. a digital library in Yiddish), maybe you can adapt some of our code.

NOTE for Copilot: Copilot should ignore this file and follow instructions in .github/copilot-instructions.md

You can browse a visualization of the data model [https://liambx.com/erd/p/github.com/projectbenyehuda/bybe/blob/master/db/schema.rb](here).

Development environment setup
-----------------------------

To set up a development environment, ensure you have a modern docker compose setup (e.g. run ```sudo apt-get install docker-compose-v2``` on Debian-like systems) and inside docker/bybe_dev run ```docker compose up -d``` to get started. See the README file in that folder for more.

For GitHub Copilot Workspace environments, see [.github/COPILOT_WORKSPACE_SETUP.md](.github/COPILOT_WORKSPACE_SETUP.md).

External (i.e. hosting system) dependencies
-------------------------------------------

* Pandoc 3.x for converting to markdown and generating ebooks and other formats. (previous versions skip SmartTag tags in DOCX files, causing random letters to disappear in certain DOCXes with extraneous mark-up.
* wkhtmltopdf for PDF generation
* ElasticSearch for search
** https://github.com/synhershko/elasticsearch-analysis-hebrew for the Hebrew analyzer for ElasticSearch
* YAZ and libyaz-dev for the 'zoom' gem for the bibliographic workshop
* watir and selenium for scraping other catalogue systems
* libpcap-dev for net-dns2
* libmagickwand-dev for RMagick
* libmysqlclient-dev for mysql2
* sidekiq for scheduled jobs [using systemd](https://github.com/sidekiq/sidekiq/wiki/Deployment)
* redis as [backend for sidekiq](https://github.com/sidekiq/sidekiq/wiki/Using-Redis)
* memcached for caching

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
Rails does not provides out-of-the box solution for Enum internationalization, so we use 
[human_enum_name](https://github.com/jkostolansky/human_enum_name) gem for that.

E.g. if we have
```ruby
enum :status, { draft: 0, ingested: 1, failed: 2, awaiting_authorities: 3 }
```
We can provide translations for enum values like this:
```yaml
he:
  activerecord:
    attributes:
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

Linters
-------
Since 2024 we've included some linters in project, namely:
- [rubocop](https://github.com/rubocop/rubocop)
- [haml_lint](https://github.com/sds/haml-lint)

### Some quick rubocop tips
Most simple command:
```shell
rubocop
```
Will check whole project. In most cases it is not required. Also it will produce tons of warnings, as many parts of
codebase does not follow style guidelines.

In most cases you may want to check single file:
```shell
rubocop <Path to file>
```

Another useful feature is rubocop's autocorrection. In some cases rubocop can try to fix style violations on its own.

There is "safe" autocorrection which should be OK in most cases:
```shell
rubocop -a <Path to file>
```

And more risky version of it, which can fix more issues, but known to produce errors more often:
```shell
rubocop -A <Path to file>
```

In any case you should be careful with autocorrection and always check result of autocorrection before commiting it 
to git.

### Pronto

To run linters only on those parts of projects, affected by your PR you can use 
[pronto](https://github.com/prontolabs/pronto) tool. For example following command:
```shell
pronto run -c origin/master
```
will run linters only on lines of code which were changed compared to `origin/master` branch. Our CI pipeline uses
this approach for all PRs.

NOTE: to run pronto tool you need to run `bundle install` first.

License
-------

The code is available for re-use under the GNU Affero General Public License http://www.gnu.org/licenses/agpl-3.0.html
