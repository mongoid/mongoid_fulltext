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

    Artist.fulltext_search("vince vangogh")

which will return the best matches for the search string as a Mongoid::Criteria. Most likely,
Vincent van Gogh will be included in the results. To restrict the number of results returned,
pass the `:max_results` parameter:

    Artist.fulltext_search("vince vangogh", :max_results => 5)

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

    Artwork.fulltext_search("untitled").each { |slug| puts 'slug: ' + slug }

By default, index terms are stored with each model instance in an embedded hash. But you
can also use an 'external' collection to store the index data by providing collection name
as the `external_collection` parameter:

    class Artwork
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :title
      fulltext_search_in :title, :external_collection => 'artwork_fulltext_index'
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
merge both into a single index by using the same `:external_collection` parameter:

    class Artwork
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :title
      fulltext_search_in :title, :external_collection => 'artwork_and_artists'
    end

    class Artist
      include Mongoid::Document
      include Mongoid::FullTextSearch

      field :name
      fulltext_search_in :name, :external_collection => 'artwork_and_artists'
    end

Now that these two models share the same external index collection, we can search them both through
either model's `fulltext_search` method:

    Artwork.fulltext_search('picasso')  # returns same results as Artist.fulltext_search('picasso')

Models with external indexes contain a complete internal index as well; you can access this to
retrieve only results of that model's type by passing the `:use_internal_index` flag:

    Artist.fulltext_search('picasso', :use_internal_index => true)
    
