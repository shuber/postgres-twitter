# Postgres Twitter

This is an experimental build of a simple "twitter" application in Postgres.


## Development

* I'm using the [dbext] VIM plugin for [splitscreen] SQL and executed results.
* I use the binding `<leader>see` to execute all statements in the buffer. (Sql Execute Everything)

[dbext]: https://github.com/vim-scripts/dbext.vim
[splitscreen]: https://www.dropbox.com/s/220z2nd5qdizho0/Screenshot%202015-05-08%2023.55.47.png?dl=0


## Ideas for Organization

    bin/
      compile
    sql/
      000_development.sql
      001_schemas.sql
      002_extensions.sql
      003_functions.sql
      004_trigger_functions.sql
      005_tables.sql
      006_constraints.sql
      007_triggers.sql
      008_indexes.sql
      009_api.sql
    test/


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


## Sample Output

    Connection: T(PGSQL)  D(twitter)  U(shuber)   at 23:50


    SELECT id, username, mentions, tweets FROM users;

                      id                  | username | mentions | tweets 
    --------------------------------------+----------+----------+--------
     2a29bdc5-5b44-400a-95fb-99ea2eb0ea03 | jane     |        1 |      1
     6e41bc72-2650-4eee-a5c4-f7974538c3c7 | steve    |        1 |      0
     da26b582-a14c-4f68-aa4d-b05a47e7bdd9 | doug     |        0 |      1
     49541427-180f-4d28-8ec9-6326cbaa071e | bob      |        1 |      3
     2f5cc57b-1abc-48b7-8503-9d4d353eeeb3 | tom      |        1 |      1
    (5 rows)


    SELECT * FROM mentions;

                   user_id                |               tweet_id               
    --------------------------------------+--------------------------------------
     2a29bdc5-5b44-400a-95fb-99ea2eb0ea03 | 8b8746a1-a05a-41ea-9a26-a2a0bb31e401
     2f5cc57b-1abc-48b7-8503-9d4d353eeeb3 | 8b8746a1-a05a-41ea-9a26-a2a0bb31e401
     6e41bc72-2650-4eee-a5c4-f7974538c3c7 | 2d1fe013-0801-4721-825b-6d481f74753a
     49541427-180f-4d28-8ec9-6326cbaa071e | 7225d9a4-025f-49e2-9c9c-126e601d9be7
    (4 rows)


    SELECT username, post, tweets.mentions, tags FROM tweets JOIN users on tweets.user_id = users.id;

     username |                          post                          |  mentions  |              tags               
    ----------+--------------------------------------------------------+------------+---------------------------------
     jane     | My first tweet!                                        | {}         | {}
     bob      | Another tweet with a tag! #hello-world @missing        | {missing}  | {hello-world}
     bob      | My second tweet! #hello-world #hello-world-again       | {}         | {hello-world,hello-world-again}
     bob      | Is anyone else hungry? #imHUNGRY #gimmefood @TOM @jane | {jane,tom} | {gimmefood,imhungry}
     doug     | @steve hola!                                           | {steve}    | {}
     tom      | @bob I am! #imhungry #metoo #gimmefood #now            | {bob}      | {gimmefood,imhungry,metoo,now}
    (6 rows)


    SELECT * FROM taggings;

                    tag_id                |               tweet_id               
    --------------------------------------+--------------------------------------
     3198bf19-7baa-4ce4-9ea4-89a1da3ccded | 5c8b8520-8b2c-4cc0-97c7-b057ce45fa04
     3198bf19-7baa-4ce4-9ea4-89a1da3ccded | ac92cb2c-d567-49f8-aea6-fbfe97b3bf3c
     fbc26ab2-0b99-4e96-ab0f-87bcd50383e4 | ac92cb2c-d567-49f8-aea6-fbfe97b3bf3c
     e2fdafb9-52a9-45e6-aed2-e8a69a7b17d1 | 8b8746a1-a05a-41ea-9a26-a2a0bb31e401
     7d594e04-6153-4740-b7ec-1ce64505cc47 | 8b8746a1-a05a-41ea-9a26-a2a0bb31e401
     e2fdafb9-52a9-45e6-aed2-e8a69a7b17d1 | 7225d9a4-025f-49e2-9c9c-126e601d9be7
     7d594e04-6153-4740-b7ec-1ce64505cc47 | 7225d9a4-025f-49e2-9c9c-126e601d9be7
     d9f07dbf-05d6-4891-b672-7ec2c7d99e58 | 7225d9a4-025f-49e2-9c9c-126e601d9be7
     66a07dc0-e45e-43e1-a541-9e28e0a4dc58 | 7225d9a4-025f-49e2-9c9c-126e601d9be7
    (9 rows)


    SELECT id, name, tweets FROM tags;

                      id                  |       name        | tweets 
    --------------------------------------+-------------------+--------
     3198bf19-7baa-4ce4-9ea4-89a1da3ccded | hello-world       |      2
     fbc26ab2-0b99-4e96-ab0f-87bcd50383e4 | hello-world-again |      1
     e2fdafb9-52a9-45e6-aed2-e8a69a7b17d1 | gimmefood         |      2
     7d594e04-6153-4740-b7ec-1ce64505cc47 | imhungry          |      2
     d9f07dbf-05d6-4891-b672-7ec2c7d99e58 | metoo             |      1
     66a07dc0-e45e-43e1-a541-9e28e0a4dc58 | now               |      1
    (6 rows)
