-- ############################################################################
-- # Seed data
-- ############################################################################

INSERT INTO users (username) VALUES
  ('bob'),
  ('doug'),
  ('jane'),
  ('steve'),
  ('tom');

INSERT INTO tweets (post, user_id) VALUES
  ('My first tweet!', random.id('users')),
  ('Another tweet with a tag! #hello-world @missing', random.id('users')),
  ('My second tweet! #hello-world #hello-world-again', random.id('users')),
  ('Is anyone else hungry? #imHUNGRY #gimmefood @TOM @jane', random.id('users')),
  ('@steve hola!', random.id('users')),
  ('@bob I am! #imhungry #metoo #gimmefood #now', random.id('users'));

INSERT INTO favorites (user_id, tweet_id)
SELECT id as user_id, random.id('tweets') as tweet_id
FROM users;

INSERT INTO followers (follower_id, user_id)
SELECT id as follower_id, random.id('users', id) as user_id
FROM users;

INSERT INTO replies (tweet_id, reply_id)
SELECT id as tweet_id, random.id('tweets', id) as reply_id
FROM tweets
LIMIT 2;

INSERT INTO retweets (tweet_id, retweet_id)
SELECT id as tweet_id, random.id('tweets', id) as retweet_id
FROM tweets
LIMIT 2;


-- ############################################################################
-- # Debug output
-- ############################################################################

SELECT id, username, followers, following, favorites, mentions, tweets FROM users;
SELECT * FROM mentions;

-------------------------------------------------------------------------------

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

SELECT * from views.retweets;
