#
# $Id: mysql_dump.sql,v 1.1 2006/10/25 21:48:30 jamiemccarthy Exp $
#

INSERT INTO ajax_ops VALUES (NULL, 'comments_moderate_cid', 'Slash::Moderation', 'ajaxModerateCid', 'ajax_user', 'createuse');

INSERT INTO vars (name, value, description) VALUES ('m1', '1', 'Allows use of the moderation system');
DELETE FROM vars WHERE name='show_mods_with_comments';
INSERT INTO vars (name, value, description) VALUES ('m1_admin_show_mods_with_comments', '1', 'Show moderations with comments for admins?');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_hitcount','3','Number of hits on comments.pl before user can be considered eligible for moderation');
INSERT INTO vars (name, value, description) VALUES ('m1_eligible_percentage','0.8','Percentage of users eligible to moderate');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_end', '0.8888', 'Ending percentage into the pool of eligible moderators (used by moderatord)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_upfairratio', '1.3', 'Factor of upmods fairness ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_downfairratio', '1.3', 'Factor of downmods fairness ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_fairtotal', '1.3', 'Factor of fairness total in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_stirratio', '1.3', 'Factor of stirred-points ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');

INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 0, 'Normal',        0, 0,  0,  0, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 1, 'Offtopic',      1, 1, -1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 2, 'Flamebait',     1, 1, -1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 3, 'Troll',         1, 1, -1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 4, 'Redundant',     1, 1, -1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 5, 'Insightful',    1, 1,  1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 6, 'Interesting',   1, 1,  1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 7, 'Informative',   1, 1,  1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 8, 'Funny',         1, 1,  1,  1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES ( 9, 'Overrated',     0, 0, -1, -1, 0.5);
INSERT INTO modreasons (id, name, m2able, listable, val, karma, fairfrac) VALUES (10, 'Underrated',    0, 0,  1,  1, 0.5);

