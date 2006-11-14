#
# $Id: mysql_dump.sql,v 1.13 2006/11/14 18:02:54 tvroom Exp $
#
INSERT INTO ajax_ops VALUES (NULL, 'firehose_fetch_text', 'Slash::FireHose', 'fetchItemText', 'ajax_base', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_reject', 'Slash::FireHose', 'rejectItem', 'ajax_admin_static', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_firehose', 'Slash::FireHose', 'ajaxGetUserFirehose', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_firehose', 'Slash::FireHose', 'ajaxCreateForFirehose', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_up_down', 'Slash::FireHose', 'ajaxUpDownFirehose', 'ajax_user_static', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_firehose', 'Slash::FireHose', 'ajaxGetAdminFirehose', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_save_note', 'Slash::FireHose', 'ajaxSaveNoteFirehose', 'ajax_admin', 'createuse');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','firehose.css','','','firehose','no','',2,0, '');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_admin_extras', 'Slash::FireHose', 'ajaxGetAdminExtras', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_form', 'Slash::FireHose', 'ajaxGetFormContents', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_updates', 'Slash::FireHose', 'ajaxFireHoseGetUpdates', 'ajax_user', 'createuse');
INSERT INTO vars (name, value, description) VALUES ('firehose_story_ignore_skids', '', 'list of skids that you want to not want created or shown as firehose entries.  Delimit skids with |');
INSERT INTO vars (name, value, description) VALUES ('firehose_color_slices', '30|30|0.2|0.2|0.2|0.2|0.2', 'Number or percent of remaining stories at each color level separated by | 30|0.5|0.5 would mean 30 stories at the level of highest popularity and 50% at each of remainining stories at the next 2 levels');
INSERT INTO vars (name, value, description) VALUES ('firehose_slice_points', '20|15|12|7|5|3|1', 'Minimum popularity value to reach a particular color level');
INSERT INTO vars (name, value, description) VALUES ('firehose_color_labels', 'red|orange|yellow|green|blue|purple|violet', 'Firehose color labels');
