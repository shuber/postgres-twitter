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
  ('My first tweet!', random_user_id()),
  ('Another tweet with a tag! #hello-world @missing', random_user_id()),
  ('My second tweet! #hello-world #hello-world-again', random_user_id()),
  ('Is anyone else hungry? #imHUNGRY #gimmefood @TOM @jane', random_user_id()),
  ('@steve hola!', random_user_id()),
  ('@bob I am! #imhungry #metoo #gimmefood #now', random_user_id());


-- ############################################################################
-- # Debug output
-- ############################################################################

SELECT id, username, mentions, tweets FROM users;
SELECT * FROM mentions;

-------------------------------------------------------------------------------

SELECT username, post, tweets.mentions, tags
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

SELECT username, post, tweets.mentions, tags
FROM tweets JOIN users on tweets.user_id = users.id;

-------------------------------------------------------------------------------

SELECT * FROM taggings;
SELECT id, name, tweets FROM tags;
