This codebase runs https://benyehuda.org -- the Project Ben-Yehuda digital library of works in Hebrew.

We make little effort to make the code general, but if you're looking to do something similar (e.g. a digital library in Yiddish), maybe you can adapt some of our code.

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
