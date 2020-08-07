* [ ] Remove implicit dependency on ActiveSupport
* [ ] Remove explicit dependency on ActiveRecord for transactions
  * could be another module you optionally include
  * could auto-detect presence of ActiveRecord
* [ ] Remove / re-think explicit dependency on I18n
* [ ] Add tests for `on_error` behaviour
* [ ] Add GH workflow for tests
  * Multiple versions of Ruby
* [ ] Determine lowest supported version of Ruby
  * Update `gemspec` accordingly
* [ ] Find a new name which isn't so generic