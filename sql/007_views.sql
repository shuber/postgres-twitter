CREATE VIEW views.retweets AS
  SELECT r.tweet_id, t.*
  FROM tweets AS t
  INNER JOIN retweets AS r
  ON t.id = r.retweet_id;
