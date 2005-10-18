#
# $Id: mysql_dump.sql,v 1.7 2005/10/18 06:59:40 pudge Exp $
#

### Possible reskey_vars (default is undef/false unless specified):
# adminbypass        - 1/0 - If admin, bypass checks for duration, proxy, ACL, and user
# 
# user_is_admin      - 1/0 - Requires user to be admin
# user_is_subscriber - 1/0 - Requires user to be subscriber
# user_seclev        - \d+ - Minimum seclev to use resource
# user_karma         - \d+ - Minimum karma to use resource
# 
# acl                - \s+ - If this ACL present, can use resource
# acl_no             - \s+ - If this ACL present, can't use resource
# 
# duration_max-failures - \d+ - how many failures per reskey
# duration_max-uses     - \d+ - how many uses per timeframe
# duration_uses         - \d+ - min duration (in seconds) between uses
# duration_creation-use - \d+ - min duration between (in seconds) creation and use


INSERT INTO vars VALUES ('reskey_srcid_masksize', 24, 'which srcid mask size to use for reskeys');
INSERT INTO vars VALUES ('reskey_timeframe', 14400, 'Default timeframe base to use for max-uses (in seconds)');

INSERT INTO reskey_resources VALUES (1, 'comments');
INSERT INTO reskey_resources VALUES (2, 'zoo');
INSERT INTO reskey_resources VALUES (3, 'journal');
INSERT INTO reskey_resources VALUES (4, 'journal-soap');
INSERT INTO reskey_resources VALUES (5, 'pollbooth');




##### comments
### checks
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
#REPLACE INTO reskey_resource_checks VALUES (NULL, 1, 'touch', '', 101);

### vars
INSERT INTO reskey_vars VALUES (1, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (1, 'acl_no', 'reskey_no_comments', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (1, 'user_seclev', 0, 'Minimum seclev to use resource');
INSERT INTO reskey_vars VALUES (1, 'duration_max-uses',      30, 'how many uses per timeframe');
INSERT INTO reskey_vars VALUES (1, 'duration_max-failures',  10, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (1, 'duration_uses',         120, 'min duration (in seconds) between uses');
INSERT INTO reskey_vars VALUES (1, 'duration_creation-use',   5, 'min duration between (in seconds) creation and use');




##### zoo
### checks
INSERT INTO reskey_resource_checks VALUES (NULL, 2, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 2, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 2, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 2, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 2, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 2, 'all', 'Slash::ResKey::Checks::Duration',            601);

### vars
INSERT INTO reskey_vars VALUES (2, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (2, 'acl_no', 'reskey_no_zoo', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (2, 'user_seclev', 1, 'Minimum seclev to use resource');
INSERT INTO reskey_vars VALUES (2, 'duration_max-uses',      30, 'how many uses per timeframe');
INSERT INTO reskey_vars VALUES (2, 'duration_max-failures',   4, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (2, 'duration_uses',           2, 'min duration (in seconds) between uses');
INSERT INTO reskey_vars VALUES (2, 'duration_creation-use',   2, 'min duration (in seconds) between creation and use');



##### journal
# note that journal and journal deletion share a reskey.  this means if you try
# to delete a few dozen journal entries one at a time, you are screwed.  but
# as you can select multiple ones from a list, that should not a problem.
### checks
INSERT INTO reskey_resource_checks VALUES (NULL, 3, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 3, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 3, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 3, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 3, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 3, 'all', 'Slash::ResKey::Checks::Duration',            601);

### vars
INSERT INTO reskey_vars VALUES (3, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (3, 'acl_no', 'reskey_no_journal', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (3, 'user_seclev', 1, 'Minimum seclev to use resource');
INSERT INTO reskey_vars VALUES (3, 'duration_max-uses',      30, 'how many uses per timeframe');
INSERT INTO reskey_vars VALUES (3, 'duration_max-failures',  10, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (3, 'duration_uses',          30, 'min duration (in seconds) between uses');
INSERT INTO reskey_vars VALUES (3, 'duration_creation-use',   2, 'min duration (in seconds) between creation and use');


##### journal-soap
### checks
INSERT INTO reskey_resource_checks VALUES (NULL, 4, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 4, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 4, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 4, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 4, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 4, 'all', 'Slash::ResKey::Checks::Duration',            601);

### vars
INSERT INTO reskey_vars VALUES (4, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
#INSERT INTO reskey_vars VALUES (4, 'acl',    'reskey_journal-soap', 'If this ACL present, can use resource');
INSERT INTO reskey_vars VALUES (4, 'acl_no', 'reskey_no_journal', 'If this ACL present, can\'t use resource');
#INSERT INTO reskey_vars VALUES (4, 'user_is_subscriber', 1, 'Require user to be subscriber');
INSERT INTO reskey_vars VALUES (4, 'user_seclev', 1, 'Minimum seclev to use resource');
INSERT INTO reskey_vars VALUES (4, 'duration_max-uses',      30, 'how many uses per timeframe');
INSERT INTO reskey_vars VALUES (4, 'duration_max-failures',  10, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (4, 'duration_uses',          30, 'min duration (in seconds) between uses');



##### pollbooth
### checks
INSERT INTO reskey_resource_checks VALUES (NULL, 5, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 5, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 5, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 5, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 5, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 5, 'all', 'Slash::ResKey::Checks::Duration',            601);

### vars
INSERT INTO reskey_vars VALUES (5, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (5, 'acl_no', 'reskey_no_pollbooth', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (5, 'duration_max-uses',      10, 'how many uses per timeframe');
INSERT INTO reskey_vars VALUES (5, 'duration_max-failures',   3, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (5, 'duration_uses',          10, 'min duration (in seconds) between uses');
INSERT INTO reskey_vars VALUES (5, 'duration_creation-use',   2, 'min duration (in seconds) between creation and use');

