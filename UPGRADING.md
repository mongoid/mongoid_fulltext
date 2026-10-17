# Upgrading

## 0.9.0

### Query ngram sampling

Query sampling now respects `max_ngrams_to_search` and spans both ends of the query when selecting at least two sliding-window ngrams. For example, selecting three 3-character ngrams from `abcdefghijk` previously produced `abc`, `def`, and `ghi`; it now produces `abc`, `efg`, and `ijk`. A limit of one selects the first window. Full-word and short-prefix terms are added separately and can increase the total number of queried terms.

The same query can return different matches or a different result order because scores are calculated from a different selection of query fragments. Review any application expectations that depend on exact matches, rankings, or score thresholds. No index rebuild is needed for this sampling change: document indexes already store every ngram, and only query-time selection changes.

### Localized fields

Indexes that explicitly include a Mongoid localized field now store ngrams for all configured locales in the original index collection, distinguished by a string `locale` field. Previously only the active translation was indexed, without locale metadata. Searches now filter by locale, and the compound search index begins with `locale`, `ngram`, and `score`. Nonlocalized indexes are unchanged.

Only models whose full-text index explicitly includes a localized field need this migration. Existing nonlocalized indexes require no changes.

Configure `I18n.available_locales` before using the model. For every affected model, run:

```ruby
Artwork.remove_from_ngram_index
Artwork.create_indexes
Artwork.update_ngram_index(timeout: false)
```

`remove_from_ngram_index` clears that model's old untagged records. `create_indexes` replaces the old compound search index with the locale-prefixed definition; there is no need to drop the collection or manually drop its indexes. `update_ngram_index` rebuilds the ngrams for all configured locales. Running only `create_indexes` does not migrate existing records: searches now require locale metadata, which old records lack. For a shared index, migrate every participating model.

Pause affected searches and writes while clearing and rebuilding, and resume after verifying searches in every locale. Searches will be incomplete during rebuilding. Searches use the current `I18n.locale`, and field access honors Mongoid's configured translation fallbacks.

Rebuild after adding a locale. Removing a locale from `I18n.available_locales` does not automatically purge its existing records on save; clear and rebuild the model's index to remove them. Document removal, destruction, and class-level removal delete records across all locales, including locales no longer configured. All models sharing a localized index must declare a localized field in that index and use the same locale configuration. No locale-suffixed collections are created.
