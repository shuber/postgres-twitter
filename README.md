# Postgres Twitter

This is an experimental build of a simple "twitter" application in Postgres.


## Development

* I'm using the [dbext] VIM plugin for [splitscreen] SQL and executed results.
* I use the binding `<leader>see` to execute all statements in the buffer. (Sql Execute Everything)

[dbext]: https://github.com/vim-scripts/dbext.vim
[splitscreen]: https://www.dropbox.com/s/220z2nd5qdizho0/Screenshot%202015-05-08%2023.55.47.png?dl=0


## Organization

The `compile` executable combines all files under sql/ into `compiled.sql` or `development.sql`.

    bin/
      compile
    sql/
      000_development.sql
      001_schemas.sql
      002_extensions.sql
      003_functions.sql
      004_trigger_functions.sql
      005_behaviors.sql
      006_tables.sql
      007_views.sql
      008_constraints.sql
      009_indexes.sql
      010_triggers.sql
      999_development.sql
    test/


## Todo

* [ ] seed database from twitter stream
* [x] favorites
* [x] followers
* [x] mentions
* [x] replies
* [x] retweets
* [x] tags
* [x] tweets
* [x] users


## Ideas for API

#### The `random` schema

This is mostly for development. This object contains methods to return a random record from various tables. Also add `_id` suffixed versions of the methods to return a random record's primary key.

* `random.tag()`
* `random.tweet()`
* `random.user()`

#### The `tweets` schema

Public API for interacting with tweets

* `tweets.create`
* `tweets.delete`
* `tweets.find`
* `tweets.for_user`
* `tweets.update`

Public API for interacting with tags

* `tags.find_or_create(name text)`
* `tags.listen(names text[])`
* `tags.tweets(names text[])`

Or maybe put everything under the `api` schema

* `api.create_reply(tweet_id uuid, post text, user_id uuid)`
* `api.create_retweet(tweet_id uuid, post text, user_id uuid)`
* `api.create_tweet(post text, user_id uuid)`
* `api.delete_tweet(tweet_id uuid)`
* `api.favorite_tweet(tweet_id uuid, user_id uuid)`
* `api.unfavorite_tweet(tweet_id uuid, user_id uuid)`
* `api.follow_user(user_id uuid, follower_id uuid)`
* `api.unfollow_user(user_id uuid, follower_id uuid)`


## Sample Input

    INSERT INTO users (username) VALUES
      ('bob'),
      ('doug'),
      ('jane'),
      ('steve'),
      ('tom');

    INSERT INTO tweets (post, user_id) VALUES
      ('My first tweet!', random_user_id()),
      ('Another tweet with a tag! #hello-world @missing', random_user_id()),
      ('My second tweet! #hello-world #hello-world-again', random_user_id()),
      ('Is anyone else hungry? #imHUNGRY #gimmefood @TOM @jane', random_user_id()),
      ('@steve hola!', random_user_id()),
      ('@bob I am! #imhungry #metoo #gimmefood #now', random_user_id());

    INSERT INTO favorites (user_id, tweet_id)
    SELECT id as user_id, random_tweet_id() as tweet_id
    FROM users;

    INSERT INTO followers (follower_id, user_id)
    SELECT id as follower_id, random_user_id(id) as user_id
    FROM users;

    INSERT INTO replies (tweet_id, reply_id)
    SELECT id as tweet_id, random_tweet_id(id) as reply_id
    FROM tweets
    LIMIT 2;

    INSERT INTO retweets (tweet_id, retweet_id)
    SELECT id as tweet_id, random_tweet_id(id) as retweet_id
    FROM tweets
    LIMIT 2;


## Sample Queries

    SELECT id, username, followers, following, favorites, mentions, tweets FROM users;
    SELECT * FROM mentions;

    -------------------------------------------------------------------------------

    SELECT username, tweets.favorites, replies, retweets, tweets.mentions, tags
    FROM tweets JOIN users on tweets.user_id = users.id;

    DELETE FROM tweets
    WHERE id IN (
      SELECT t.id
      FROM tweets t
      ORDER BY random()
      LIMIT 1
    );

    UPDATE tweets
    SET post = 'replaced!'
    WHERE id IN (
      SELECT t.id
      FROM tweets t
      ORDER BY random()
      LIMIT 1
    );

    SELECT username, tweets.favorites, replies, retweets, tweets.mentions, tags
    FROM tweets JOIN users on tweets.user_id = users.id;

    -------------------------------------------------------------------------------

    SELECT * FROM taggings;
    SELECT id, name, tweets FROM tags;


## Sample Output

    Connection: T(PGSQL)  D(twitter)  U(shuber)   at 12:52
                      id                  | username | followers | following | favorites | mentions | tweets 
    --------------------------------------+----------+-----------+-----------+-----------+----------+--------
     267ce9ac-c3df-4bf4-bbed-3aee28094a52 | doug     |         2 |         1 |         1 |        0 |      1
     46c226b4-f26f-412c-a72f-9fe1b35da997 | bob      |         0 |         1 |         1 |        1 |      1
     9d2860c9-a713-43e5-a384-c1b24b3d1c4d | tom      |         2 |         1 |         1 |        1 |      1
     da1b62ea-c0bc-4f29-9d27-212144bc29c0 | jane     |         0 |         1 |         1 |        1 |      3
     7bba5bea-d98b-4079-abea-fed05034dc6a | steve    |         1 |         1 |         1 |        1 |      0
    (5 rows)
                   user_id                |               tweet_id               
    --------------------------------------+--------------------------------------
     da1b62ea-c0bc-4f29-9d27-212144bc29c0 | 2d872de0-46cc-44aa-9aec-015fd5291c72
     9d2860c9-a713-43e5-a384-c1b24b3d1c4d | 2d872de0-46cc-44aa-9aec-015fd5291c72
     7bba5bea-d98b-4079-abea-fed05034dc6a | 1bab8cad-9cac-473d-a689-fbc710aaaea6
     46c226b4-f26f-412c-a72f-9fe1b35da997 | 3bc21b9d-c778-4c64-84b8-798fd65072d8
    (4 rows)
     username | favorites | replies | retweets |  mentions  |              tags               
    ----------+-----------+---------+----------+------------+---------------------------------
     tom      |         1 |       0 |        0 | {}         | {hello-world,hello-world-again}
     jane     |         2 |       0 |        0 | {bob}      | {gimmefood,imhungry,metoo,now}
     doug     |         0 |       1 |        0 | {}         | {}
     jane     |         0 |       1 |        0 | {steve}    | {}
     jane     |         1 |       0 |        1 | {jane,tom} | {gimmefood,imhungry}
     bob      |         1 |       0 |        1 | {missing}  | {hello-world}
    (6 rows)
     username | favorites | replies | retweets |  mentions  |              tags               
    ----------+-----------+---------+----------+------------+---------------------------------
     tom      |         1 |       0 |        0 | {}         | {hello-world,hello-world-again}
     doug     |         0 |       1 |        0 | {}         | {}
     jane     |         1 |       0 |        1 | {jane,tom} | {gimmefood,imhungry}
     bob      |         1 |       0 |        1 | {missing}  | {hello-world}
     jane     |         2 |       0 |        0 | {}         | {}
    (5 rows)
                    tag_id                |               tweet_id               
    --------------------------------------+--------------------------------------
     579e5a0f-5835-46ac-aced-528f8cd6e913 | 1d572544-8a84-4053-aef5-238260be3fa3
     579e5a0f-5835-46ac-aced-528f8cd6e913 | 37421d41-416e-463d-9ad5-b9570f9356e8
     0d86a554-0db2-4f60-8833-3d6bd6ed58af | 37421d41-416e-463d-9ad5-b9570f9356e8
     c2620f3c-5a5c-4fa5-88f4-f01e2e12173e | 2d872de0-46cc-44aa-9aec-015fd5291c72
     3efbea1c-3002-4b87-917b-d3ead6483983 | 2d872de0-46cc-44aa-9aec-015fd5291c72
    (5 rows)
                      id                  |       name        | tweets 
    --------------------------------------+-------------------+--------
     579e5a0f-5835-46ac-aced-528f8cd6e913 | hello-world       |      2
     0d86a554-0db2-4f60-8833-3d6bd6ed58af | hello-world-again |      1
     c2620f3c-5a5c-4fa5-88f4-f01e2e12173e | gimmefood         |      1
     3efbea1c-3002-4b87-917b-d3ead6483983 | imhungry          |      1
    (4 rows)
