// $Id: common.js,v 1.38 2006/09/12 22:45:00 pudge Exp $

function createPopup(xy, titlebar, name, contents, message) {
	var body = document.getElementsByTagName("body")[0]; 
	var div = document.createElement("div");
	div.id = name + "-popup";
	div.style.position = "absolute";
	
	var leftpos = xy[0] + "px";
	var toppos  = xy[1] + "px";
	
	div.style.left = leftpos;
	div.style.top = toppos;
	div.style.zIndex = "100";
	contents = contents || "";
	message  = message || "";

	div.innerHTML = '<div id="' + name + '-title" class="popup-title">' + titlebar + '</div>' +
                        '<div id="' + name + '-contents" class="popup-contents">' + contents + '</div>' +
			'<div id="' + name + '-message" class="popup-message">' + message + '</div>';

	body.appendChild(div);
	div.className = "popup";
	return div;
}

function createPopupButtons() {
	var buttons = "";
	if (arguments.length > 0) {
		buttons = '<span class="buttons">';
	}
	for (var i=0; i<arguments.length; i++) {
		buttons =  buttons + "<span>" + arguments[i] + "</span>";
	}

	buttons = buttons + "</span>";
	return buttons;
}

function closePopup(id, refresh) {
	var el = $(id);
	if (el) {
		el.parentNode.removeChild(el);
	}
	if (refresh) {
		window.location.reload();
	}
}

function handleEnter(ev, func, arg) {
        if (!ev) {
                ev = window.event;
        }
        var code = ev.which || ev.keyCode;
        if (code == 13) { // return/enter
		func(arg);
                ev.returnValue = true;
                return true;
        }
        ev.returnValue = false;
        return false;
}


function moveByObjSize(div, addOffsetWidth, addOffsetHeight) {
	if (addOffsetWidth) {
		div.style.left = parseFloat(div.style.left || 0) + (addOffsetWidth * div.offsetWidth) + "px";
	}
	if (addOffsetHeight) {
		div.style.top = parseFloat(div.style.top || 0) + (addOffsetHeight * div.offsetHeight) + "px";
	}
}

function moveByXY(div, x, y) {
	if (x) {
		div.style.left = parseFloat(div.style.left || 0) + x + "px";
	}
	if (y) {
		div.style.top = parseFloat(div.style.top || 0) + y + "px";
	}
}

function getXYForId(id, addWidth, addHeight) {
	var div = $(id);
	var xy = Position.cumulativeOffset(div);
	if (addWidth) {
		xy[0] = xy[0] + div.offsetWidth;
	}
	if (addHeight) {
		xy[1] = xy[1] + div.offsetHeight;
	}
	return xy;
}

function toggleIntro(id, toggleid) {
	var obj = $(id);
	var toggle = $(toggleid);
	if (obj.className == 'introhide') {
		obj.className = "intro"
		toggle.innerHTML = "[-]";
	} else {
		obj.className = "introhide"
		toggle.innerHTML = "[+]";
	}
}

function tagsToggleStoryDiv(id, is_admin, type) {
	var bodyid = 'toggletags-body-' + id;
        var tagsbody = $(bodyid);
	if (tagsbody.className == 'tagshide') {
		tagsShowBody(id, is_admin, '', type);
	} else {
		tagsHideBody(id);
	}
}

function tagsHideBody(id) {
	// Make the body of the tagbox vanish
	var tagsbodyid = 'toggletags-body-' + id;
        var tagsbody = $(tagsbodyid);
	tagsbody.className = "tagshide"

	// Make the title of the tagbox change back to regular
	var titleid = 'tagbox-title-' + id;
        var title = $(titleid);
	title.className = "tagtitleclosed";

	// Make the tagbox change back to regular.
	var tagboxid = 'tagbox-' + id;
        var tagbox = $(tagboxid);
	tagbox.className = "tags";

	// Toggle the button back.
	var tagsbuttonid = 'toggletags-button-' + id;
        var tagsbutton = $(tagsbuttonid);
	tagsbutton.innerHTML = "[+]";
}

function tagsShowBody(id, is_admin, newtagspreloadtext, type) {

	type = type || "stories";

	if (type == "firehose") {
		setFirehoseAction();
	}

	//alert("Tags show body / Type: " + type );
	
	// Toggle the button to show the click was received
	var tagsbuttonid = 'toggletags-button-' + id;
        var tagsbutton = $(tagsbuttonid);
	tagsbutton.innerHTML = "[-]";

	// Make the tagbox change to the slashbox class
	var tagboxid = 'tagbox-' + id;
        var tagbox = $(tagboxid);
	tagbox.className = "tags";

	// Make the title of the tagbox change to white-on-green
	var titleid = 'tagbox-title-' + id;
        var title = $(titleid);
	title.className = "tagtitleopen";

	// Make the body of the tagbox visible
	var tagsbodyid = 'toggletags-body-' + id;
        var tagsbody = $(tagsbodyid);
	
	tagsbody.className = "tagbody";
	
	// If the tags-user div hasn't been filled, fill it.
	var tagsuserid = 'tags-user-' + id;
	var tagsuser = $(tagsuserid);
	if (tagsuser.innerHTML == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story, and a reskey to allow
		// the user to enter more tags.
		tagsuser.innerHTML = "Retrieving...";
		var params = [];
		if (type == "stories") {
			params['op'] = 'tags_get_user_story';
			params['sidenc'] = id;
		} else if (type == "urls") {
			//alert('getting user urls ' + id);
			params['op'] = 'tags_get_user_urls';
			params['id'] = id;
		} else if (type == "firehose") {
			params['op'] = 'tags_get_user_firehose';
			params['id'] = id;
		}
		params['newtagspreloadtext'] = newtagspreloadtext;
		var handlers = {
			onComplete: function() { 
				var textid = 'newtags-' + id;
				var input = $(textid);
				input.focus();
			}
		}
		ajax_update(params, tagsuserid, handlers);
		//alert('after ajax_update ' + tagsuserid);

		// Also fill the admin div.  Note that if the user
		// is not an admin, this call will not actually
		// return the necessary form (which couldn't be
		// submitted anyway).  The is_admin parameter just
		// saves us an ajax call to find that out, if the
		// user is not actually an admin.
		if (is_admin) {
			var tagsadminid = 'tags-admin-' + id;
			params = [];
			if (type == "stories") {
				params['op'] = 'tags_get_admin_story';
				params['sidenc'] = id;
			} else if (type == "urls") {
				params['op'] = 'tags_get_admin_url';
				params['id'] = id;
			} else if (type == "firehose") {
				params['op'] = 'tags_get_admin_firehose';
				params['id'] = id;
			}
			ajax_update(params, tagsadminid);
		}

	} else {
		if (newtagspreloadtext) {
			// The box was already open but it was requested
			// that we append some text to the user text.
			// We can't do that by passing it in, so do it
			// manually now.
			var textinputid = 'newtags-' + id;
			var textinput = $(textinputid);
			textinput.value = textinput.value + ' ' + newtagspreloadtext;
			textinput.focus();
		}
	}
}

function tagsOpenAndEnter(id, tagname, is_admin, type) {
	// This does nothing if the body is already shown.
	tagsShowBody(id, is_admin, tagname, type);
}

function reportError(request) {
	// replace with something else
	alert("error");
}

function tagsCreateForStory(id) {
	var toggletags_message_id = 'toggletags-message-' + id;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tags_create_for_story';
	params['sidenc'] = id;
	var newtagsel = $('newtags-' + id);
	params['tags'] = newtagsel.value;
	var reskeyel = $('newtags-reskey-' + id);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}

function tagsCreateForUrl(id) {
	var toggletags_message_id = 'toggletags-message-' + id;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tags_create_for_url';
	params['id'] = id;
	var newtagsel = $('newtags-' + id);
	params['tags'] = newtagsel.value;
	var reskeyel = $('newtags-reskey-' + id);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}

//Firehose functions begin
function tagsCreateForFirehose(id) {
	var toggletags_message_id = 'toggletags-message-' + id;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';
	
	var params = [];
	params['op'] = 'tags_create_for_firehose';
	params['id'] = id;
	var newtagsel = $('newtags-' + id);
	params['tags'] = newtagsel.value; 
	var reskeyel = $('newtags-reskey-' + id);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);
	toggletags_message_el.innerHTML = 'Tags saved.';
}

function toggle_firehose_body(id, is_admin) {
	var params = [];
	setFirehoseAction();
	params['op'] = 'firehose_fetch_text';
	params['id'] = id;
	var fhbody = $('fhbody-'+id);
	var fh = $('firehose-'+id);
	if (fhbody.className == "empty") {
		var handlers = {
			onComplete: function() { firehose_get_admin_extras(id) }
		};
		if (is_admin) {
			ajax_update(params, 'fhbody-'+id, handlers);
		} else {
			ajax_update(params, 'fhbody-'+id);
		}
		fhbody.className = "body";
		fh.className = "article";
		tagsShowBody(id, is_admin, '', "firehose");
	} else if (fhbody.className == "body") {
		fhbody.className = "hide";
		fh.className = "briefarticle";
		tagsHideBody(id);
	} else if (fhbody.className == "hide") {
		fhbody.className = "body";
		fh.className = "article";
		tagsShowBody(id, is_admin, '', "firehose");
	}
}

function toggleFirehoseTagbox(id) {
	var fhtb = $('fhtagbox-'+id);
	if (fhtb.className == "hide") {
		fhtb.className = "tagbox";
	} else {
		fhtb.className = "hide";
	}
}

function firehose_up_down(id, dir) {
	setFirehoseAction();
	var params = [];
	var handlers = {
		onComplete: json_handler
	};
	params['op'] = 'firehose_up_down';
	params['id'] = id;
	params['dir'] = dir;
	var updown = $('updown-' + id);
	ajax_update(params, '', handlers);
}
// firehose functions end

// helper functions
function ajax_update(params, onsucc, options, url) {
	var h = $H(params);

	if (!url)
		url = '/ajax.pl';

	if (!options)
		options = {};

	options.method = 'post';
	options.parameters = h.toQueryString();

	var ajax = new Ajax.Updater(
		{ success: onsucc },
		url,
		options
	);
}

function ajax_periodic_update(secs, params, onsucc, options, url) {
	var h = $H(params);
	
	if (!url) 
		url = '/ajax.pl';
		
	if (!options)
		options = {};

	options.frequency = secs;
	options.method = 'post';
	options.parameters = h.toQueryString();

	var ajax = new Ajax.PeriodicalUpdater({ success: onsucc }, url, options);
}

function eval_response(transport) {
	var response;
	try {
		eval("response = " + transport.responseText)
	} catch (e) {
		alert(e + "\n" + transport.responseText)
	}
	return response;
}

function json_handler(transport) {
	var response = eval_response(transport);

 	if (response.html) {
		for (el in response.html) {
			if ($(el))
				$(el).innerHTML = response.html[el];
		}
		
	} 

	if (response.value) {
		for (el in response.value) {
			if ($(el))
				$(el).value = response.value[el];
		}
	}
}

function firehose_new_handler(transport) {
	var response = eval_response(transport);
	var processed = 0;
	if (response.added) {
		for (el in response.added) {
			var fh = 'firehose-' + el;
			processed = processed + 1;
			if ($(fh)) {
			} else {
				if (insert_new_at == "bottom") {
					new Insertion.Bottom('firehoselist', response.added[el]);
				} else {
					new Insertion.Top('firehoselist', response.added[el]);
				}
			}
		}
	}
	if (response.maxtime) {
		if (processed > 0 ) { maxtime = response.maxtime }
	}
	setTimeout("firehose_fetch_new()", "30000");
}

function firehose_check_removed_handler(transport) {
	var response = eval_response(transport);
 
	if (response.removed) {
		for (el in response.removed) {
			var fh_id = 'firehose-' + el;
			var fh = $(fh_id);
			fh.className="hide";
			fh.parentNode.removeChild(fh);
		}
	}
	setTimeout("firehose_check_removed()", "30000");
}

function firehose_get_updates_handler(transport) {
	var response = eval_response(transport);
	var processed = 0;
	if (response.update_new) {
		for (el in response.update_new) {
			var fh = 'firehose-' + el;
			processed = processed + 1;
			if ($(fh)) {
			} else {
				if (insert_new_at == "bottom") {
					new Insertion.Bottom('firehoselist', response.update_new[el]);
				} else {
					new Insertion.Top('firehoselist', response.update_new[el]);
				}
			}
		}
	}
	if (processed) {
		if (response.update_time) {
			update_time = response.update_time;
		}
	}
	setTimeout("firehose_get_updates()", "30000");
}

function firehose_get_item_idstring() {
	var fhl = $('firehoselist');
	var children = fhl.childNodes;
	var str = "";
	var id;
	for (var i = 0; i < children.length; i++) {
		if (children[i].id) {
			id = children[i].id;
			id = id.replace(/\D+/g, "");
			str = str + id + ",";
		}
	}
	return str;
}

function firehose_get_updates() {
	if (play == 0) {
		setTimeout("firehose_get_updates()", 2000);
		return;
	}
	var params = [];
	var handlers = {
		onComplete: firehose_get_updates_handler
	};
	params['op'] = 'firehose_get_updates';
	params['ids'] = firehose_get_item_idstring();
	ajax_update(params, '', handlers);
	
}

function firehose_check_removed() {
	if (play == 0) {
		setTimeout("firehose_check_removed()", 2000);
		return;
	}
	var params = [];
	var handlers = {
		onComplete: firehose_check_removed_handler
	};
	params['op'] = 'firehose_check_removed';
	params['ids'] = firehose_get_item_idstring();
	ajax_update(params, '', handlers);

}

function firehose_fetch_new() {
	if (play == 0) {
		setTimeout("firehose_fetch_new()", 2000);
		return;
	}
	var params = [];
	var handlers = {
		onComplete: firehose_new_handler
	};
	params['op'] = 'firehose_fetch_new';
	params['maxtime'] = maxtime;
	ajax_update(params, '', handlers);
}

function setFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	firehose_action_time = newtime;
}

function getSecsSinceLastFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	var diff = (newtime - firehose_action_time) / 1000;
	return diff;
}

function firehose_play() {
	play = 1;
	var pause = $('pause');
	var play_div = $('play');
	play_div.className = "hide";
	pause.className = "";
}

function firehose_pause() {
	play = 0;
	var pause = $('pause');
	var play_div = $('play');
	pause.className = "hide";
	play_div.className = "";
}
