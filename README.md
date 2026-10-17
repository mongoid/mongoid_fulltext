Mongoid Fulltext Search
=======================

[![Gem Version](https://badge.fury.io/rb/mongoid_fulltext.svg)](http://badge.fury.io/rb/mongoid_fulltext)
[![Test](https://github.com/mongoid/mongoid_fulltext/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/mongoid/mongoid_fulltext/actions/workflows/test.yml?query=branch%3Amaster)
[![Coverage Status](https://coveralls.io/repos/github/mongoid/mongoid_fulltext/badge.svg?branch=master)](https://coveralls.io/github/mongoid/mongoid_fulltext?branch=master)

Full-text search using n-gram matching for the Mongoid ODM.

CI reports real SimpleCov coverage from the Ruby 4.0 job to Coveralls. Run `COVERAGE=true bundle install` and `COVERAGE=true bundle exec rake spec` to collect coverage locally. Danger runs with the isolated `Gemfile.danger`; PR checks have read-only permissions and a separate workflow publishes the report as a comment.

MongoDB introduced full-text search capabilities in v2.4, so this gem is a good fit for cases where you want something a little less than a full-blown indexing service. The mongoid_fulltext gem
lets you do a fuzzy string search across relatively short strings, which makes it good for populating autocomplete boxes based on the display names of your Rails models but not appropriate for, say, indexing hundreds of thousands of HTML documents.

Install
-------

The current CI matrix exercises representative Ruby/Mongoid/MongoDB combinations from Ruby 2.1 and Mongoid 3 through Ruby 4.0, Mongoid 9, and MongoDB 8.0.
Use version 0.5.x for Mongoid 2.4.x and Ruby 1.8.7, 1.9.2 or 1.9.3.
For Ruby 1.8.7 and/or Mongoid 2.x use [mongoid_fulltext 0.5.x](https://github.com/mongoid/mongoid_fulltext/tree/0.5-stable).

``` ruby
gem 'mongoid_fulltext'
```

Examples
--------

Suppose you have an `Artist` model and want to index each artist's name:

``` ruby
class Artist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :first_name
  field :last_name

  def name
    [first_name, last_name].join(' ')
  end

  fulltext_search_in :name
end
```

The `fulltext_search_in` directive will index the full name of the artist, so now
you can call:

``` ruby
Artist.fulltext_search("vince vangogh")
```

which will return an array of the Artist instances that best match the search string. Most likely,
Vincent van Gogh will be included in the results. You can index multiple fields with the same
index, so we can get the same effect of our Artist index above using:

``` ruby
class Artist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :first_name
  field :last_name

  fulltext_search_in :first_name, :last_name
end
```

To restrict the number of results returned, pass the `:max_results` parameter to `fulltext_search`:

``` ruby
Artist.fulltext_search("vince vangogh", { :max_results => 5 })
```

To return a pair of `[ result, score ]` instead of an array of results, pass the `:return_scores` parameter to `fulltext_search`:

``` ruby
Artist.fulltext_search("vince vangogh", { :return_scores => true })
```

The larger a score is, the better mongoid_fulltext thinks the match is. The scores have the following rough
interpretation that you can use to make decisions about whether the match is good enough:

* If a prefix of your query matches something indexed, or if your query matches a prefix of something
  indexed (for example, searching for "foo" finds "myfoo" or searching for "myfoo" finds "foo"), you
  can expect a score of at least 1 for the match.
* If an entire word in your query matches an entire word that's indexed and you have the `index_full_words`
  option turned on (it's turned on by default), you can expect a score of at least 2 for the match.
* If neither of the above criteria are met, you can expect a score less than one.

If you don't specify a field to index, the default is the result of `to_s` called on the object.
The following definition will index the first and last name of an artist:

``` ruby
class Artist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :first_name
  field :last_name

  def to_s
    '%s %s' % [first_name, last_name]
  end

  fulltext_search_in
end
```

The full-text index is stored in a separate MongoDB collection in the same database as the
models you're indexing. By default, the name of this collection is generated for you. Above,
a collection named something like `mongoid_fulltext.index_artist_0` will be created to
hold the index data. You can override this naming and provide your own collection name with
the :index_name parameter:

``` ruby
class Artwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title, :index_name => 'mongoid_fulltext.foobar'
end
```

You can also create multiple indexes on a single model, in which case you'll want to
provide index names:

``` ruby
class Artwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  field :artist_name
  field :gallery_name
  filed :gallery_address

  fulltext_search_in :title, :index_name => 'title_index'
  fulltext_search_in :artist_name, :index_name => 'artist_name_index'
  fulltext_search_in :gallery_name, :gallery_address, :index_name => 'gallery_index'
end
```

The index names are helpful now because you'll have to specify which one you want to use when you
call `fulltext_search`:

``` ruby
Artwork.fulltext_search('warhol', :index => 'artist_name_index')
```

If you have multiple indexes specified and you don't supply a name to `fulltext_search`, the
method call will raise an exception.

If you're indexing multiple models, you may find that you need to combine results to create
a single result set. For example, if both the `Artist` model and the `Artwork` model are
indexed for full-text search, then to get results from both, you'd have to call
`Artist.fulltext_search` and `Artwork.fulltext_search` and combine the results yourself. If
your intention is instead to get the top k results from both Artists and Artworks, you can
merge both into a single index by using the same `:external_index` parameter:

``` ruby
class Artwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title, :index_name => 'artwork_and_artists'
end

class Artist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :name
  fulltext_search_in :name, :index_name => 'artwork_and_artists'
end
```

Now that these two models share the same external index collection, we can search them both through
either model's `fulltext_search` method:

``` ruby
Artwork.fulltext_search('picasso')  # returns same results as Artist.fulltext_search('picasso')
```

If you want to filter the results from full-text search, you set up filters when the indexes are
defined. For example, suppose that in addition to wanting to use the `artwork_and_artists` index
defined above to search for `Artwork`s or `Artist`s, we want to be able to run full-text searches
for artists only and for artworks priced above $10,000. Instead of creating two new indexes or
attempting to filter the results after the query is run, we can specify the filter predicates
at the time of index definition:

``` ruby
class Artwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  field :price
  fulltext_search_in :title, :index_name => 'artwork_and_artists',
                     :filters => { :is_expensive => lambda { |x| x.price > 10000 },
                                   :has_long_name => lambda { |x| x.title.length > 20 }}
end

class Artist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :name
  field :birth_year
  fulltext_search_in :name, :index_name => 'artwork_and_artists',
                     :filters => { :born_before_1900 => lambda { |x| x.birth_year < 1900 },
                                   :has_long_name => lambda { |x| x.name.length > 20}}
end
```

After defining filters, you can query for results that match particular values of filters:

``` ruby
# Only return artists born before 1900 that match 'foobar'
Artist.fulltext_search('foobar', :born_before_1900 => true)

# Return artists or artworks that match 'foobar' and have short names
Artist.fulltext_search('foobar', :has_long_name => false)

# Only return artworks with prices over 10000 that match 'mona lisa'
Artwork.fulltext_search('mona lisa', :is_expensive => true)

# Only return artworks with prices less than 10000 that match 'mona lisa'
Artwork.fulltext_search('mona lisa', :is_expensive => false)
```

Note that in all of the example queries above, supplying a filter that is defined on exactly
one of the models will restrict the search to results from that model only. For example,
since `:is_expensive` is defined only on `Artwork`s, a call to `fulltext_search` with either
`:is_expensive => true` or `:is_expensive => false` will return only `Artwork` results.

You can specify multiple filters per index and per model. Each filter is a predicate that will
be called on objects as they're inserted into the full-text index (any time the model is saved.)
Filters are only called on instances of models they're defined on, so in the example above, the
`is_expensive` filter is only applied to instances of `Artwork` and the `born_before_1900` filter
is only applied to instances of `Artist`, although both filters can be used when querying from
either model. The `has_long_name` filter, on the other hand, will return instances of both
`Artwork` and `Artist` since it's defined on each model.

Filters shouldn't ever throw, but if they do, the filter is just ignored. If you apply filters to
indexes that are on multiple fields, the filter is applied to each field and the filter result is
the AND of all of the individual results for each of the fields. Finally, if a filter is defined
but criteria for that filter aren't passed to `fulltext_search`, the result is as if the filter
had never been defined - you see both models that both pass and fail the filter in the results.

Indexing Options
----------------

`Artwork.update_ngram_index(timeout: false)` rebuilds the index for all records without a cursor timeout; the `timeout` option belongs to the class method, not the per-document `artwork.update_ngram_index` method.

`Artwork.create_indexes` can create the full-text collections and their indexes before any artworks have been saved.

Localized Mongoid fields (`field :title, type: String, localize: true`) are indexed for every locale in `I18n.available_locales`. Declare the field normally with `fulltext_search_in :title`; searches use `I18n.locale`, so use `I18n.with_locale(:cs) { Artwork.fulltext_search('obraz') }` to search a particular translation. Field readers, computed methods, `update_if`, and filters run within each locale, honoring Mongoid's configured fallback behavior. This does not search all languages at once.

All translations use the original full-text index collection. Each ngram record for an index that explicitly includes a localized field has a string `locale` value, for example `{ document_id: id, locale: 'cs', ngram: 'obr', score: score, class: 'Artwork' }`. Searches filter by locale, backed by a compound index beginning with `locale`, `ngram`, and `score`. Nonlocalized index records remain unchanged. Models sharing a localized index must all include a localized field in that index and use the same locale configuration. Define available locales before indexing and rebuild after adding a locale. The alphabet must still contain the characters being indexed. Existing localized-field users must follow [UPGRADING](UPGRADING.md) to rebuild locale-tagged records.

Searches can be prefixed with Mongoid criteria, for example `Artwork.where(published: true).fulltext_search('flowers', max_results: 5)`. The result remains an array in relevance order, not a chainable criteria; ordering and pagination on the preceding criteria are not a substitute for sorting or paginating that array. Excluded or deleted documents are skipped before applying `max_results`, within the existing candidate-set bound.

Single-collection inheritance is respected: a root-class search includes its descendants, while a subclass search excludes its parent and siblings. An unscoped search of an index shared by unrelated models still returns all those models. Adding criteria restricts the results to the calling model and its descendants. Existing index records already contain the class name, so no reindex is required.

The default `alphabet` only includes ASCII letters, digits, and spaces. Use a Unicode-aware regular expression to support whole scripts without enumerating their characters. For example, `/\p{Han}/` accepts Han characters, including those used in Chinese:

```ruby
class ChineseArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String
  fulltext_search_in :title, alphabet: /\p{Han}/, ngram_width: 2
end

artwork = ChineseArtwork.create!(title: "\u5367\u864e\u85cf\u9f99")
ChineseArtwork.fulltext_search("\u85cf\u9f99") # => [artwork]
```

For multilingual text, use `alphabet: /[\p{L}\p{M}\p{N}]/` to accept Unicode letters, combining marks, and numbers, or `/[\p{Latin}\p{Cyrillic}]/` to restrict letters to those scripts. Existing string allowlists remain supported and the ASCII default is unchanged.

The expression is tested against each character after accent normalization and lowercasing, not against whole words. Configured word separators are retained independently of the alphabet; other unmatched characters are discarded. `remove_accents: false` preserves combining marks and accents when needed. This is character-ngram matching, not language-aware word segmentation. A shorter `ngram_width` helps with short search terms. Changing the alphabet or ngram width requires rebuilding existing indexes with `ChineseArtwork.update_ngram_index`. Configuring the alphabet is separate from indexing Mongoid localized fields.

Additional indexing/query options can be used as parameters to `fulltext_search_in`.

* `alphabet`: a string allowlist or a regular expression matched against each character, default is `abcdefghijklmnopqrstuvwxyz0123456789 `.
* `word_separators`: word separators, default is the space character.
* `ngram_width`: ngram width, default is `3`.
* `index_full_words`: index full words, which improves exact matches, default is `true`.
* `index_short_prefixes`: index a prefix of each full word of length `(ngram_width-1)`. Useful if
  you use a larger ngram_width than the default of 3. Default for this option is `false`.
* `stop_words`: a hash of words to avoid indexing as full words. Used only if `index_full_words`
  is set to `true`. Defaults to a hash containing a list of common English stop words.
* `apply_prefix_scoring_to_all_words`: score n-grams at beginning of words higher, default is `true`.
* `max_ngrams_to_search`: maximum number of ngrams to query at any given time, default is `6`.
* `max_candidate_set_size`: maximum number of candidate ngrams to examine for a given query.
  Defaults to 1000. If you're seeing poor results, you can try increasing this value to consider
  more ngrams per query (changing this parameter does not require a re-index.) The amount of time
  a search takes is directly proportional to this parameter's value.
* `remove_accents`: remove accents on accented characters, default is `true`.
  We strip the accents using [NFKD normalization](http://unicode-utils.rubyforge.org/UnicodeUtils.html#method-c-compatibility_decomposition)
  using an external library, `unicode_utils`.
* `update_if`: controls whether or not the index will be updated. This can be set to a symbol,
  string, or proc. If the result of evaluating the value is true, the index will be updated.
    * When set to a symbol, the symbol is sent to the document.
    * When set to a string, the string is evaluated within the document's instance.
    * When set to a proc, the proc is called, and the document is given to the proc as the first arg.
    * When set to any other type of object, the document's index will not be updated.
* `reindex_immediately`: whether models will be reindexed automatically upon saves or updates. Defaults to true. When set to false, the class-level `update_ngram_index` method can be called to perform reindexing.

For Cyrillic and Latin text with numbers, use `alphabet: /[\p{Latin}\p{Cyrillic}\p{N}]/`.

Array filters
-------------

A filter may also return an Array. Consider the following example.

``` ruby
class Artist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :name
  field :exhibitions, as: Array, default: []

  fulltext_search_in :name, :index_name => 'exhibited_artist',
    :filters => {
      :exhibitions => lambda { |artist| artist.exhibitions }
    }
end
```

You can now find all artists that are at the Art Basel exhibition or all artists that have exhibited
at both the Art Basel and the New York Armory exhibition.

``` ruby
# All artists
Artist.fulltext_search('foobar')

# Artists at the Art Basel exhibition only
Artist.fulltext_search('foobar', :exhibitions => [ "Art Basel" ])

# Artists at both the Art Basel and the New York Armory exhibition
Artist.fulltext_search('foobar', :exhibitions => [ "Art Basel", "New York Armory" ])

# Note that the following explicit syntax may be used to achieve the
# same result as above
Artist.fulltext_search('foobar', :exhibitions => {:all => [ "Art Basel", "New York Armory" ]})
```

If you want to find all artists that are at either the Art Basel or the
New York Armory exhibition, then you may specify the `:any` operator in
the filter.

``` ruby
# Artists at either the Art Basel or the New York Armory exhibition
Artist.fulltext_search('foobar', :exhibitions => {:any => [ "Art Basel", "New York Armory" ]})
```

Note that `:all` and `:any` are currently the only supported operators
for the array filters.

Building the index
------------------

The fulltext index is built and maintained incrementally by hooking into `before_save` and
`before_destroy` callbacks on each model that's being indexed. If you want to build an index
on existing models, you can call the `update_ngram_index` method on the class or each instance:

``` ruby
Artwork.update_ngram_index
Artwork.find(id).update_ngram_index
```

If you need to update the index for a large number of documents, using the option below will
disable your query from timing out:

```ruby
Artwork.update_ngram_index(timeout: false)
```

You can remove all or individual instances from the index with the `remove_from_ngram_index`
method:

``` ruby
Artwork.remove_from_ngram_index
Artwork.find(id).remove_from_ngram_index
```

The methods on the model level perform bulk removal operations and are therefore faster that
updating or removing records individually.

If you need to control when the index is updated, provide the `update_if` option to
`fulltext_search_in`, and set it to a symbol, string, or proc. Eg:

``` ruby
# Only update the "age" index if the "age" field has changed.
fulltext_search_in :age,    :update_if => :age_changed?

# Only update the "names" index if the "firstname" or "lastname" field has changed.
fulltext_search_in :names,  :update_if => "firstname_changed? || lastname_changed?"

# Only update the "email" index if the "email" field ends with "gmail.com".
fulltext_search_in :email,  :update_if => Proc.new { |doc| doc.email.match /gmail.com\Z/ }
```

Mongo Database Indexes
----------------------

Mongoid provides an indexing mechanism on its models triggered by the `create_indexes` method.
Mongoid_fulltext will hook into that behavior and create appropriate database indexes on its
collections. These indexes are required for an efficient full text search.

Creating database indexes is typically done with the `db:mongoid:create_indexes` task.

``` bash
rake db:mongoid:create_indexes
```

Running the specs
-----------------

To run the specs, execute `rake spec`. You need a local MongoDB instance to run the specs.

Contributing
------------

Fork the project. Make your feature addition or bug fix with tests. Send a pull request. Bonus points for topic branches.

Copyright and License
---------------------

MIT License, see [LICENSE](LICENSE) for details.

(c) 2011-2017 [Artsy Inc.](http://artsy.github.io)
