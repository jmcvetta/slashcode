#
# $Id: mysql_dump.sql,v 1.2 2005/06/27 23:31:40 pudge Exp $
#

INSERT INTO reskey_resources VALUES (1, 'comments');

# all is for all checks for a given resource, which can be overridden with create/touch/use
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'use', 'Slash::ResKey::Checks::ProxyScan',          1001);

# dummy example of how to disable the Slash::ResKey::Checks::User check for "touch"
# (maybe, for example, because the check isn't needed)
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'touch', '',                                         101);



INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'touch',  'Slash::ResKey::Checks::User',    101);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'touch',  'Slash::ResKey::Checks::ACL',     201);

INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'use',    'Slash::ResKey::Checks::User',    101);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'use',    'Slash::ResKey::Checks::ACL',     201);


INSERT INTO vars VALUES ('reskey_checks_user_seclev_comments', 0, 'Minimum seclev to post a comment');
INSERT INTO vars VALUES ('reskey_checks_user_karma_comments', '', 'No minimum karma to post a comment');

INSERT INTO vars VALUES ('reskey_checks_acl_no_comments', 'reskey_no_comments', 'No comment posting for you!');

INSERT INTO vars VALUES ('reskey_srcid_masksize', 24, 'which srcid mask size to use for reskeys');

INSERT INTO vars VALUES ('reskey_checks_duration_timeframe_comments', 86400, 'timeframe base to use for max-uses, in seconds');
INSERT INTO vars VALUES ('reskey_checks_duration_max-uses_comments', 30, 'how many uses per timeframe');
INSERT INTO vars VALUES ('reskey_checks_duration_uses_comments', 120, 'min duration between uses');
INSERT INTO vars VALUES ('reskey_checks_duration_creation-use_comments', 5, 'min duration between creation and use');
