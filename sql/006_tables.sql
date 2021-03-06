CREATE TABLE favorites (
  user_id   uuid NOT NULL,
  tweet_id  uuid NOT NULL,
  PRIMARY KEY(user_id, tweet_id)
);

CREATE TABLE followers (
  user_id      uuid NOT NULL,
  follower_id  uuid NOT NULL,
  created      timestamptz NOT NULL DEFAULT current_timestamp,
  PRIMARY KEY(user_id, follower_id)
);

CREATE TABLE mentions (
  user_id   uuid NOT NULL,
  tweet_id  uuid NOT NULL,
  PRIMARY KEY(user_id, tweet_id)
);

CREATE TABLE replies (
  tweet_id  uuid NOT NULL,
  reply_id  uuid NOT NULL,
  PRIMARY KEY(tweet_id, reply_id)
);

CREATE TABLE retweets (
  tweet_id    uuid NOT NULL,
  retweet_id  uuid NOT NULL,
  PRIMARY KEY(tweet_id, retweet_id)
);

CREATE TABLE tags (
  id       uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  name     text NOT NULL UNIQUE,
  tweets   integer NOT NULL DEFAULT 0,
  created  timestamptz NOT NULL DEFAULT current_timestamp,
  updated  timestamptz NOT NULL DEFAULT current_timestamp
);

CREATE TABLE taggings (
  tag_id    uuid NOT NULL,
  tweet_id  uuid NOT NULL,
  PRIMARY KEY(tag_id, tweet_id)
);

CREATE TABLE tweets (
  id         uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  user_id    uuid NOT NULL,
  post       text NOT NULL,
  favorites  integer NOT NULL DEFAULT 0,
  replies    integer NOT NULL DEFAULT 0,
  retweets   integer NOT NULL DEFAULT 0,
  mentions   text[] NOT NULL DEFAULT '{}',
  tags       text[] NOT NULL DEFAULT '{}',
  created    timestamptz NOT NULL DEFAULT current_timestamp,
  updated    timestamptz NOT NULL DEFAULT current_timestamp
);

CREATE TABLE users (
  id         uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  username   text NOT NULL UNIQUE,
  favorites  integer NOT NULL DEFAULT 0,
  followers  integer NOT NULL DEFAULT 0,
  following  integer NOT NULL DEFAULT 0,
  mentions   integer NOT NULL DEFAULT 0,
  tweets     integer NOT NULL DEFAULT 0,
  created    timestamptz NOT NULL DEFAULT current_timestamp,
  updated    timestamptz NOT NULL DEFAULT current_timestamp
);
