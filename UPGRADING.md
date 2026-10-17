# Upgrading

## 0.9.0

### Weighted fields

`:priorities` and `:score_aggregation` are opt-in. Indexes declaring neither option retain the existing last-field-wins behavior and exact scores, and require no rebuild. Opted-in indexes use maximum per-field array contributions followed by either maximum or summed weighted field contributions. Even `:priorities => {}` or `:score_aggregation => :max` intentionally switches from legacy merging to maximum scoring.

After enabling either option, changing weights, or changing aggregation, rebuild every affected model:

```ruby
Artwork.update_ngram_index(timeout: false)
```

This replaces each document's stored scores, including all configured locales. No collection format or database-index change is required. For shared collections, rebuild every model whose configuration changed. Coordinate writes and searches during rebuilding: until it finishes, results mix old and new scores. Rebuild from a stable dataset or pause affected writes to avoid races with normal save callbacks.

Remove neither option without rebuilding again: unweighted declarations will only restore legacy scores as documents are subsequently reindexed. Review result ordering, score thresholds, and candidate limits when adopting weights or sum aggregation; the unweighted prefix/full-word scoring thresholds do not apply to weighted/summed scores.

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
