# Releasing `mongoid_fulltext`
## Guidelines
Generally, `mongoid_fulltext` should be released with enthusiasm but care. Release bug fixes as added, features as desired, and breaking API changes as absolutely necessary.

## This is how we do it.
1. Run the test suite in your local environment first, and ensure that everything's passing.

    ```bash
    bundle install
    rake
    ```

2. Run the test suite on [Travis](https://travis-ci.org) to be certain that your changes work in a variety of environments. Only merge and release when all tests are passing.

3. Bump the version in [`lib/mongoid/full_text_search/version.rb`](lib/mongoid/full_text_search/version.rb).

    * If the release fixes bugs or adds features with negligible impact, increment the third number (e.g., `0.3.2` → `0.3.3`).
    * If the release adds significant new features, increment the second number and zero out the third (e.g., `0.3.2` → `0.4.0`).
    * If the release adds breaking API changes, increment the first number and zero out the second and third (e.g., `0.3.2` → `1.0.0`).

    You've gotta know it---it's semantic!

4. Add a header for the new version to [`CHANGELOG.md`](CHANGELOG.md) and list all the changes your release will include underneath it, crediting contributors as appropriate.

6. Update the [`README`](README.md) to document any new features. Remove any warnings indicating that users are reading the documentation for an unreleased version.

7. Commit your changes...

    ```bash
    git add README.md CHANGELOG.md lib/mongoid/full_text_search/version.rb
    git commit -m "Preparing for release, 0.4.0."
    git push origin master
    ```

8. ...and do the thing!

    ```bash
    rake release
    #=> mongoid_fulltext 0.4.0 built to pkg/mongoid_fulltext-0.4.0.gem
    #=> Tagged 0.4.0.
    #=> Pushed git commits and tags.
    #=> Pushed mongoid_fulltext 0.4.0 to rubygems.org.
    ```
