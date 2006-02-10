#
# $Id: mysql_dump.sql,v 1.4 2006/02/10 14:51:17 jamiemccarthy Exp $
#

INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_tags', '3600', 'Seconds to cache tag data in memcached');
INSERT INTO vars (name, value, description) VALUES ('tags_cache_expire', '180', 'Local data cache expiration for tags');
INSERT INTO vars (name, value, description) VALUES ('tags_tagname_regex', '^[a-z][a-z0-9/]{0,63}$', 'Regex that tag names must conform to');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowread', '0', 'Who is allowed to see existing tags on stories (incl. search on them)? 0=nobody 1=admins 2=subscribers 3=non-neg. karma 4=all logged in');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowwrite', '0', 'Who is allowed to tag stories? 0=nobody 1=admins 2=subscribers 3=non-neg. karma 4=all logged in');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_lastscanned', '0', 'The last tagid scanned to update stories');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_examples', 'cool dupe', 'Example tags for stories');

INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_story', 'Slash::Tags', 'ajaxGetUserStory', 'ajax_tags_read', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_story', 'Slash::Tags', 'ajaxCreateForStory', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_admin_commands', 'Slash::Tags', 'ajaxProcessAdminTags', 'ajax_admin', 'use');

