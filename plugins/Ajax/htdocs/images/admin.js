// $Id: admin.js,v 1.12 2006/03/08 20:15:01 tvroom Exp $

function admin_signoff(el) {
	var params = [];
	params['op'] = 'admin_signoff';
	params['stoid'] = el.value;
	ajax_update(params, 'signoff_' + el.value);
	
}

function adminTagsCommands(stoid) {
	var toggletags_message_id = 'toggletags-message-' + stoid;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Executing commands...';

	var params = [];
	params['op'] = 'tags_admin_commands';
	params['stoid'] = stoid;
	var tags_admin_commands_el = $('tags_admin_commands-' + stoid);
	params['commands'] = tags_admin_commands_el.value;
	var reskeyel = $('admin_commands-reskey-' + stoid);
	params['reskey'] = reskeyel.value;
	ajax_update(params, 'tags-admin-' + stoid);

	toggletags_message_el.innerHTML = 'Commands executed.';
}

function tagsStoryHistory(sidenc) {
	var params = [];
	params['op'] = 'tags_story_history';
	params['sidenc'] = sidenc;
	var tagshistid = "taghist-" + sidenc;
	var popupid    = "taghistory-" + sidenc;
	var title      = "History ";
	var buttons    = createPopupButtons("<a href=\"#\">[?]</a></span><span><a href=\"javascript:closePopup('" + popupid + "-popup')\">[X]</a>");
	title = title + buttons;
	createPopup(getXYForId(tagshistid), title, popupid);
	ajax_update(params, "taghistory-" + sidenc + "-contents");
}

function remarks_create() {
	var reskey = $('remarks_reskey');
	var remark = $('remarks_new');
	if (!remark || !remark.value || !reskey || !reskey.value) {
		return false;
	}

	var params = [];
	params['op']     = 'remarks_create';
	params['remark'] = remark.value;
	params['reskey'] = reskey.value;
	remarks_max = $('remarks_max');
	if (remarks_max && remarks_max.value) {
		params['limit'] = remarks_max.value;
	}
	ajax_update(params, 'remarks_whole');
}

function remarks_fetch(secs, limit) {
	var params = [];
	params['op'] = 'remarks_fetch';
	// this not being used? -- pudge
	remarks_max = $('remarks_max');
	params['limit'] = limit;
	// run it every 30 seconds; don't need to call again
	ajax_periodic_update(secs, params, 'remarks_table');
}

function remarks_popup() {
	var params = [];
	params['op'] = 'remarks_config';
	var title = "Remarks Config ";
	var buttons = createPopupButtons('<a href="javascript:closePopup(\'remarksconfig-popup\', 1)">[X]</a>');
	title = title + buttons;
	createPopup(getXYForId('remarks_table'), title + buttons, 'remarksconfig');
	ajax_update(params, 'remarksconfig-contents');
	
}

function remarks_config_save() {
	var params = [];
	var min_priority = $('remarks_min_priority');
	var limit = $('remarks_limit');
	var filter = $('remarks_filter');
	params['op'] = 'remarks_config_save';
	if (min_priority) {
		params['min_priority'] = min_priority.value;
	}
	if (limit) {
		params['limit'] = limit.value;
	}
	if (filter) {
		params['filter'] = filter.value;
	}
	var message = $('remarksconfig-message');
	if (message) {
		message.innerHTML = "Saving...";
	}
	ajax_update(params, 'remarksconfig-message');
}

function admin_slashdbox_fetch(secs) {
	var params = [];
	params['op'] = 'admin_slashdbox';
	ajax_periodic_update(secs, params, "slashdbox-content");
}

function admin_perfbox_fetch(secs) {
	var params = [];
	params['op'] = 'admin_perfbox';
	ajax_periodic_update(secs, params, "performancebox-content");
}

function admin_authorbox_fetch(secs) {
	var params = [];
	params['op'] = 'admin_authorbox';
	ajax_periodic_update(secs, params, "authoractivity-content");
}

function admin_storyadminbox_fetch(secs) {
	var params = [];
	params['op'] = 'admin_storyadminbox';
	ajax_periodic_update(secs, params, "storyadmin-content");
}
