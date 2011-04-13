Mongoid Fulltext Search
=======================

Full-text search using n-gram matching for the Mongoid ODM. Works for MongoDB 1.6, support for 1.8 coming soon.

Some examples:
--------------
    
Suppose you have an `Artist` model and want to index each artist's name:

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

The `fulltext_search_in` directive will index the full name of the artist, so now
you can call:

    Artist.fulltext_search("vince vangogh")

which will return an array of the Artist instances that best match the search string. Most likely,
Vincent van Gogh will be included in the results. You can index multiple fields with the same
index, so we can get the same effect of our Artist index above using:

    class Artist
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :first_name
      field :last_name

      fulltext_search_in :first_name, :last_name
    end

To restrict the number of results returned, pass the `:max_results` parameter to `fulltext_search`:

    Artist.fulltext_search("vince vangogh", :max_results => 5)

If you don't specify a field to index, the default is the result of `to_s` called on the object.
The following definition will index the first and last name of an artist:

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

The full-text index is stored in a separate MongoDB collection in the same database as the
models you're indexing. By default, the name of this collection is generated for you. Above,
a collection named something like `mongoid_fulltext.index_artist_0` will be created to
hold the index data. You can override this naming and provide your own collection name with 
the :index_name parameter:

    class Artwork
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :title
      fulltext_search_in :title, :index_name => 'mongoid_fulltext.foobar'
    end

You can also create multiple indexes on a single model, in which case you'll want to
provide index names:

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

The index names are helpful now because you'll have to specify which one you want to use when you
call `fulltext_search`:

    Artwork.fulltext_search('warhol', :index => 'artist_name_index')

If you have multiple indexes specified and you don't supply a name to `fulltext_search`, the
method call will raise an exception.

If you're indexing multiple models, you may find that you need to combine results to create
a single result set. For example, if both the `Artist` model and the `Artwork` model are
indexed for full-text search, then to get results from both, you'd have to call 
`Artist.fulltext_search` and `Artwork.fulltext_search` and combine the results yourself. If
your intention is instead to get the top k results from both Artists and Artworks, you can
merge both into a single index by using the same `:external_index` parameter:

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

Now that these two models share the same external index collection, we can search them both through
either model's `fulltext_search` method:

    Artwork.fulltext_search('picasso')  # returns same results as Artist.fulltext_search('picasso')

Running the specs
-----------------

To run the specs, execute `rake spec`. You need a local MongoDB instance to run the specs.