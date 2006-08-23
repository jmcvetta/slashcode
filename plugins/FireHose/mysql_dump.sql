#
# $Id: mysql_dump.sql,v 1.7 2006/08/23 16:24:50 tvroom Exp $
#
INSERT INTO ajax_ops VALUES (NULL, 'firehose_fetch_text', 'Slash::FireHose', 'fetchItemText', 'ajax_base', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_reject', 'Slash::FireHose', 'rejectItem', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_firehose', 'Slash::FireHose', 'ajaxGetUserFirehose', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_firehose', 'Slash::FireHose', 'ajaxCreateForFirehose', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_up_down', 'Slash::FireHose', 'ajaxUpDownFirehose', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_firehose', 'Slash::FireHose', 'ajaxGetAdminFirehose', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_save_note', 'Slash::FireHose', 'ajaxSaveNoteFirehose', 'ajax_admin', 'createuse');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','firehose.css','','','firehose','no','',2,0, '');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_admin_extras', 'Slash::FireHose', 'ajaxGetAdminExtras', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_form', 'Slash::FireHose', 'ajaxGetFormContents', 'ajax_admin', 'createuse');
