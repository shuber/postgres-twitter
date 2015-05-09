-- ############################################################################
-- # mentions
-- ############################################################################

ALTER TABLE mentions
  ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES users (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE mentions
  ADD CONSTRAINT tweet_fk FOREIGN KEY (tweet_id) REFERENCES tweets (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


-- ############################################################################
-- # tags
-- ############################################################################

ALTER TABLE tags
  ADD CONSTRAINT tweets_count CHECK (tweets >= 0);


-- ############################################################################
-- # taggings
-- ############################################################################

ALTER TABLE taggings
  ADD CONSTRAINT tag_fk FOREIGN KEY (tag_id) REFERENCES tags (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE taggings
  ADD CONSTRAINT tweet_fk FOREIGN KEY (tweet_id) REFERENCES tweets (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


-- ############################################################################
-- # tweets
-- ############################################################################

ALTER TABLE tweets
  ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES users (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE tweets ADD
  CONSTRAINT post_length CHECK (char_length(post) <= 140);


-- ############################################################################
-- # users
-- ############################################################################

ALTER TABLE users
  ADD CONSTRAINT mentions_count CHECK (mentions >= 0);

ALTER TABLE users
  ADD CONSTRAINT tweets_count CHECK (tweets >= 0);
