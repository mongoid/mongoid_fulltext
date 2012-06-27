0.6.0 (Next Release)
--------------------

* [#2](https://github.com/artsy/mongoid_fulltext/pull/2): Upgrade to Mongoid 3.0 - [@volmer](https://github.com/volmer).
* [#1](https://github.com/artsy/mongoid_fulltext/pull/1): Fix: downcase destroys non-latin strings - [@netoneko](https://github.com/netoneko).

0.5.8 (3/8/2012)
----------------

* Fix: do not CGI.unescape inside fulltext search - [@dblock](https://github.com/dblock).
* Refactored array filter API, allowing for overriding filter query method - [@ethul](https://github.com/ethul).
* Fix: check for the existence of the Mongoid.logger before calling it in case it was configured to false - [@AaronH](https://github.com/AaronH).
* Added install instructions to Readme - [@Nerian](https://github.com/Nerian).

0.5.7 (1/11/2012)
-----------------

* Added `reindex_immediately` option to suppress automatic reindexing - [@joeyAghion](https://github.com/joeyAghion).
* Fix: treatment of word separators, adding newlines, tabs and dashes into the set of default word separators - [@aaw](https://github.com/aaw).

0.5.4 (11/8/2011)
-----------------

* Made full word and prefix bumps inversely proportional to the length of the string - [@aaw](https://github.com/aaw).

0.5.3 (11/8/2011)
-----------------

* Added an option to index short prefixes of words - [@aaw](https://github.com/aaw).

0.5.2 (11/5/2011)
-----------------

* Added the ability to index full words that are less than the ngram length and not stop words - [@aaw](https://github.com/aaw).

0.5.1 (11/2/2011)
-----------------

* Reducing the score for a full-word match (these used to be counted multiple times for multiple occurrences) and adding a list of stopwords to the config. Stopwords aren't given a score boost when matched as full words - [@aaw](https://github.com/aaw).
* Added UTF8 downcasing - [@zepplock](https://github.com/zepplock).

0.5.0 (10/11/2011)
-----------------

* Fix: inconsistet scoring words with the same length as the ngram length - [@aaw](https://github.com/aaw).

0.4.5 (10/5/2011)
-----------------

* Added `update_if` config option to control when index updates occur - [@nickhoffman](https://github.com/nickhoffman).

0.4.4 (8/31/2011)
-----------------

* Added `remove_accents` - [@tdp2110](https://github.com/tdp2110).

0.4.3 (8/3/2011)
----------------

* Fix: including `Mongoid::FulltextSearch` and not using it causes created_indexes to fail - [@dblock](https://github.com/dblock).

0.4.2 (6/28/2011)
-----------------

* Delay-creating indexes in sync with how Mongoid creates indexes on normal collections - [@dblock](https://github.com/dblock).

0.4.1 (6/27/2011)
-----------------

* Using `Mongoid.logger` for logging - [@dblock](https://github.com/dblock).
*	Changed `ensure_index` to index in the background, avoid blocking booting app - [@dblock](https://github.com/dblock).

0.4.0 (6/19/2011)
-----------------

* Removing all use of map-reduce - [@aaw](https://github.com/aaw).
* Support class name with module for example (Module::ClassConstantName) - [@steverandy](https://github.com/steverandy).

0.3.7 (6/7/2011)
----------------

*	Added support for updating model indexes in bulk - [@dblock](https://github.com/dblock).

0.3.6 (5/27/2011)
-----------------

* Skipping words that are shorter than the n-gram - [@dblock](https://github.com/dblock).
* Added `index_full_words` - [@dblock](https://github.com/dblock).
*	Keeping max score of ngram in the ngram hash - [@dblock](https://github.com/dblock).

0.3.5 (5/25/2011)
-----------------

* Added index on document_id for faster remove - [@dblock](https://github.com/dblock).
* Addeda way to return scored results - [@dblock](https://github.com/dblock).

0.3.4 (5/16/2011)
-----------------

* Added support for array filters - [@dblock](https://github.com/dblock).
* Added support for Ruby 1.8.7 - [@dbussink](https://github.com/dbussink).

0.3.2 (4/19/2011)
-----------------

Exposing `update_ngram_index` and `remove_from_ngram_index` for fast bulk-updating the index - [@aaw](https://github.com/aaw).

0.3.1 (4/14/2011)
-----------------

* Support for mongo versions >= 1.7.4 - [@aaw](https://github.com/aaw).

0.3.0 (4/13/2011)
-----------------

* Adding the ability to define filters on an index - [@aaw](https://github.com/aaw).

0.2.0 (4/13/2011)
-----------------

* Multiple indexes per model, removing internal indexes entirely - [@aaw](https://github.com/aaw).

0.1.1 (4/11/2011)
-----------------

* Keep garbage in the index from blowing up `fulltext_search` - [@aaw](https://github.com/aaw).
* Indexing the results of `to_s` if no fields are provided - [@aaw](https://github.com/aaw).
* Adding a `before_destroy` callback for external indexes - [@aaw](https://github.com/aaw).

0.1.0 (4/7/2011)
----------------

* Initial public release - [@aaw](https://github.com/aaw).
