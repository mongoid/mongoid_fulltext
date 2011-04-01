Mongoid Fulltext Search
=======================

Full-text search using n-gram matching for the Mongoid ODM. 

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

    Artist.fulltext_search("vince vangogh", 5)

which will return the 5 best matches for the search string as a Mongoid::Criteria. Most likely,
Vincent van Gogh will be included in the results.

If you want something less than a Mongoid::Criteria returned, you can specify this with
the `:returns` key:

    class Artwork
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :title
      field :slug
      fulltext_search_in :title, :returns => :slug
    end

And a full-text search on the Artwork model will now search all titles and return an array 
of their corresponding slugs:

    Artwork.fulltext_search("untitled", 20).each { |slug| puts 'slug: ' + slug }

By default, index terms are stored with each model instance in an embedded hash. But you
can also use a separate collection to store the index data by providing a name for the
index collection:

    class Artwork
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :title
      fulltext_search_in :title, :index_collection => 'artwork_fulltext_index'
    end

Using a separate collection for the index can speed up your queries dramatically, but there's 
a little more overhead when models are modified or deleted. The string specifying the index 
collection must be a valid MongoDB collection name; it will correspond directly to a collection 
in the same database as these models that's used to store the index data.

If you're indexing multiple models, you may find that you need to combine results to create
a single result set. For example, if both the `Artist` model and the `Artwork` model are
indexed for full-text search, then to get results from both, you'd have to call 
`Artist.fulltext_search` and `Artwork.fulltext_search` and combine the results yourself. If
your intention is instead to get the top k results from both Artists and Artworks, you can
merge both into a single index by using the same `:index_collection` value:

    class Artwork
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :title
      fulltext_search_in :title, :index_collection => 'artwork_and_artists'
    end

    class Artist
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :name
      fulltext_search_in :name, :index_collection => 'artwork_and_artists'
    end

Now that these two models share the same index collection, we can search them both through
that single index that's accessible from `Mongoid::FullTextSearch`:

    index = Mongoid::FullTextSearch.get_index('artworks_and_artists')
    index.fulltext_search('picasso walking down the stairs')
    
