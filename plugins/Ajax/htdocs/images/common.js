// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id: common.js,v 1.178 2008/03/14 15:48:06 scc Exp $

// by now, both jQuery and prototype have loaded.  Tell jQuery to play nice (for now)
if ( jQuery !== undefined )
  jQuery.noConflict();

// temporary glue massages what prototype wants in $(expr) to what jQuery wants
function make_selector( expr ) {
  return (typeof expr !== 'string' || expr[0]=='#') ? expr : '#'+expr;
}

// global settings, but a firehose might use a local settings object instead
var firehose_settings = {};
  firehose_settings.startdate = '';
  firehose_settings.duration = '';
  firehose_settings.mode = '';
  firehose_settings.color = '';
  firehose_settings.orderby = '';
  firehose_settings.orderdir = '';

  firehose_settings.issue = '';
  firehose_settings.is_embedded = 0;
  firehose_settings.not_id = 0;
  firehose_settings.section = 0;

// Settings to port out of settings object
  firehose_updates = Array(0);
  firehose_updates_size = 0;
  firehose_ordered = Array(0);
  firehose_before = Array(0);
  firehose_after = Array(0);
  firehose_removed_first = '0';
  firehose_removals = null;
  firehose_future = null;

// globals we haven't yet decided to move into |firehose_settings|
var fh_play = 0;
var fh_is_timed_out = 0;
var fh_is_updating = 0;
var fh_update_timerids = Array(0);
var fh_is_admin = 0;
var console_updating = 0;
var fh_colorslider; 
var fh_ticksize;
var fh_colors = Array(0);
var fh_use_jquery = 0;
var vendor_popup_timerids = Array(0);
var vendor_popup_id = 0;
var fh_slider_init_set = 0;
var ua=navigator.userAgent;
var is_ie = ua.match("/MSIE/");


// eventually add site specific constants like this to a separate .js
var sitename = "Slashdot";

function createPopup(xy, titlebar, name, contents, message, onmouseout) {
	var body = document.getElementsByTagName("body")[0]; 
	var div = document.createElement("div");
	div.id = name + "-popup";
	div.style.position = "absolute";

	if (onmouseout) {
		div.onmouseout = onmouseout;
	}

	var leftpos = xy[0] + "px";
	var toppos  = xy[1] + "px";
	
	div.style.left = leftpos;
	div.style.top = toppos;
	div.style.zIndex = "100";
	contents = contents || "";
	message  = message || "";

	div.innerHTML = '<iframe></iframe><div id="' + name + '-title" class="popup-title">' + titlebar + '</div>' +
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
	var el = jQuery(make_selector(id))[0];
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
	var div = jQuery(make_selector(id))[0];
	var offset = jQuery(div).offset();
	var xy = [ offset.left, offset.top ];
	if (addWidth) {
		xy[0] = xy[0] + div.offsetWidth;
	}
	if (addHeight) {
		xy[1] = xy[1] + div.offsetHeight;
	}
	return xy;
}

function firehose_toggle_advpref() {
	var obj = jQuery('#fh_advprefs')[0];
	if (obj.className == 'hide') {
		obj.className = "";
	} else {
		obj.className = "hide";
	}
}

function firehose_open_prefs() {
	var obj = jQuery('#fh_advprefs')[0];
	obj.className = "";
}

function toggleId(id, first, second) {
	var obj =jQuery(make_selector(id))[0];
	if (obj.className == first) {
		obj.className = second;
	} else if (obj.className == second) {
		obj.className = first;
	} else {
		obj.className = first;
	}
}

function toggleIntro(id, toggleid) {
	var obj = jQuery(make_selector(id))[0];
	var toggle = jQuery(make_selector(toggleid))[0];
	if (obj.className == 'introhide') {
		obj.className = "intro"
		toggle.innerHTML = "[-]";
		toggle.className = "expanded";
	} else {
		obj.className = "introhide"
		toggle.innerHTML = "[+]";
		toggle.className = "condensed";
	}
}

function tagsToggleStoryDiv(id, is_admin, type) {
	var bodyid = '#toggletags-body-' + id;
	var tagsbody = jQuery(bodyid)[0];
	if (tagsbody.className == 'tagshide') {
		tagsShowBody(id, is_admin, '', type);
	} else {
		tagsHideBody(id);
	}
}

function tagsHideBody(id) {
	// Make the body of the tagbox vanish
	var tagsbodyid = '#toggletags-body-' + id;
	var tagsbody = jQuery(tagsbodyid)[0];
	tagsbody.className = "tagshide"

	// Make the title of the tagbox change back to regular
	var titleid = '#tagbox-title-' + id;
	var title = jQuery(titleid)[0];
	title.className = "tagtitleclosed";

	// Make the tagbox change back to regular.
	var tagboxid = '#tagbox-' + id;
	var tagbox = jQuery(tagboxid)[0];
	tagbox.className = "tags";

	// Toggle the button back.
	var tagsbuttonid = '#toggletags-button-' + id;
	var tagsbutton = jQuery(tagsbuttonid)[0];
	tagsbutton.innerHTML = "[+]";
}

function tagsShowBody(id, is_admin, newtagspreloadtext, type) {

	type = type || "stories";

	if (type == "firehose") {
		setFirehoseAction();
		if (fh_is_admin) {
			firehose_get_admin_extras(id);
		}
	}

	//alert("Tags show body / Type: " + type );
	
	// Toggle the button to show the click was received
	var tagsbuttonid = '#toggletags-button-' + id;
	var tagsbutton = jQuery(tagsbuttonid)[0];
	tagsbutton.innerHTML = "[-]";

	// Make the tagbox change to the slashbox class
	var tagboxid = '#tagbox-' + id;
	var tagbox = jQuery(tagboxid)[0];
	tagbox.className = "tags";

	// Make the title of the tagbox change to white-on-green
	var titleid = '#tagbox-title-' + id;
	var title = jQuery(titleid)[0];
	title.className = "tagtitleopen";

	// Make the body of the tagbox visible
	var tagsbodyid = '#toggletags-body-' + id;
	var tagsbody = jQuery(tagsbodyid)[0];
	
	tagsbody.className = "tagbody";
	
	// If the tags-user div hasn't been filled, fill it.
	var tagsuserid = '#tags-user-' + id;
	var tagsuser = jQuery(tagsuserid)[0];
	if (tagsuser.innerHTML == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story, and a reskey to allow
		// the user to enter more tags.
		tagsuser.innerHTML = "Retrieving...";
		var params = {};
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
				var textid = '#newtags-' + id;
				var input = jQuery(textid)[0];
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
			params = {};
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
			var textinputid = '#newtags-' + id;
			var textinput = jQuery(textinputid)[0];
			textinput.value = textinput.value + ' ' + newtagspreloadtext;
			textinput.focus();
		}
	}
}

function tagsOpenAndEnter(id, tagname, is_admin, type) {
	// This does nothing if the body is already shown.
	tagsShowBody(id, is_admin, tagname, type);
}

function completer_renameMenu( s, params ) {
	if ( s )
		params._sourceEl.innerHTML = s;
}

function completer_setTag( s, params ) {
	createTag(s, params._id, params._type);
	var tagField = document.getElementById('newtags-'+params._id);
	if ( tagField ) {
		var s = tagField.value.slice(-1);
		if ( s.length && s != " " )
			tagField.value += " ";
		tagField.value += s;
	}
}

function completer_handleNeverDisplay( s, params ) {
	if ( s == "neverdisplay" )
		admin_neverdisplay("", "firehose", params._id);
}

function completer_save_tab(s, params) {
	firehose_save_tab(params._id);
}

function clickCompleter( obj, id, is_admin, type, tagDomain, customize ) {
	return attachCompleter(obj, id, is_admin, type, tagDomain, customize);
}

function focusCompleter( obj, id, is_admin, type, tagDomain, customize ) {
	if ( navigator.vendor !== undefined ) {
		var vendor = navigator.vendor.toLowerCase();
		if ( vendor.indexOf("apple") != -1
				|| vendor.indexOf("kde") != -1 )
			return false;
	}

	return attachCompleter(obj, id, is_admin, type, tagDomain, customize);
}

function attachCompleter( obj, id, is_admin, type, tagDomain, customize ) {
	if ( customize === undefined )
		customize = new Object();
	customize._id = id;
	customize._is_admin = is_admin;
	customize._type = type;
	if ( tagDomain != 0 && customize.queryOnAttach === undefined )
		customize.queryOnAttach = true;
	
	if ( !YAHOO.slashdot.gCompleterWidget )
		YAHOO.slashdot.gCompleterWidget = new YAHOO.slashdot.AutoCompleteWidget();

	YAHOO.slashdot.gCompleterWidget.attach(obj, customize, tagDomain);
	return false;
}

function reportError(request) {
	// replace with something else
	alert("error");
}

function createTag(tag, id, type) {
	var params = {};
	params['id'] = id;
	params['type'] = type;
	if ( fh_is_admin && ("_#)^*".indexOf(tag[0]) != -1) ) {
	  params['op'] = 'tags_admin_commands';
	  params['reskey'] = jQuery('#admin_commands-reskey-' + id)[0].value;
	  params['command'] = tag;
	} else {
	  params['op'] = 'tags_create_tag';
	  params['reskey'] = reskey_static;
	  params['name'] = tag;
	  if ( fh_is_admin && (tag == "hold") ) {
	    firehose_collapse_entry(id);
	  }
	}
	ajax_update(params, '');
}

function tagsCreateForStory(id) {
	var toggletags_message_id = '#toggletags-message-' + id;
	var toggletags_message_el = jQuery(toggletags_message_id)[0];
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = {};
	params['op'] = 'tags_create_for_story';
	params['sidenc'] = id;
	var newtagsel = jQuery('#newtags-' + id)[0];
	params['tags'] = newtagsel.value;
	var reskeyel = jQuery('#newtags-reskey-' + id)[0];
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}

function tagsCreateForUrl(id) {
	var toggletags_message_id = '#toggletags-message-' + id;
	var toggletags_message_el = jQuery(toggletags_message_id)[0];
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = {};
	params['op'] = 'tags_create_for_url';
	params['id'] = id;
	var newtagsel = jQuery('#newtags-' + id)[0];
	params['tags'] = newtagsel.value;
	var reskeyel = jQuery('#newtags-reskey-' + id)[0];
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}

//Firehose functions begin
function setOneTopTagForFirehose(id, newtag) {
	var params = {};
	params['op'] = 'firehose_update_one_tag';
	params['id'] = id;
	params['tags'] = newtag;
	// params['reskey'] = reskeyel.value;
	ajax_update(params, '');
}

function tagsCreateForFirehose(id) {
	var toggletags_message_id = '#toggletags-message-' + id;
	var toggletags_message_el = jQuery(toggletags_message_id)[0];
	toggletags_message_el.innerHTML = 'Saving tags...';
	
	var params = {};
	params['op'] = 'tags_create_for_firehose';
	params['id'] = id;
	var newtagsel = jQuery('#newtags-' + id)[0];
	params['tags'] = newtagsel.value; 
	var reskeyel = jQuery('#newtags-reskey-' + id)[0];
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);
	toggletags_message_el.innerHTML = 'Tags saved.';
}

function toggle_firehose_body(id, is_admin) {
	var params = {};
	setFirehoseAction();
	params['op'] = 'firehose_fetch_text';
	params['id'] = id;
	var fhbody = jQuery('#fhbody-'+id)[0];
	var fh = jQuery('#firehose-'+id)[0];
	var usertype = fh_is_admin ? " adminmode" : " usermode";
	if (fhbody.className == "empty") {
		var handlers = {
			onComplete: function() { 
				firehose_get_admin_extras(id); 
			}
		};
		params['reskey'] = reskey_static;
		if (is_admin) {
			ajax_update(params, 'fhbody-'+id, handlers);
		} else {
			ajax_update(params, 'fhbody-'+id);
		}
		fhbody.className = "body";
		fh.className = "article" + usertype;
		if (is_admin)
			tagsShowBody(id, is_admin, '', "firehose");
	} else if (fhbody.className == "body") {
		fhbody.className = "hide";
		fh.className = "briefarticle" + usertype;
		/*if (is_admin)
			tagsHideBody(id);*/
	} else if (fhbody.className == "hide") {
		fhbody.className = "body";
		fh.className = "article" + usertype;
		/*if (is_admin)
			tagsShowBody(id, is_admin, '', "firehose"); */
	}
}

function toggleFirehoseTagbox(id) {
	var fhtb = jQuery('#fhtagbox-'+id)[0];
	if (fhtb.className == "hide") {
		fhtb.className = "tagbox";
	} else {
		fhtb.className = "hide";
	}
}

function firehose_set_options(name, value) {
	var pairs = [
		// name		value		curid		newid		newvalue 	title 
		["orderby", 	"createtime", 	"popularity",	"time",		"popularity"	],
		["orderby", 	"popularity", 	"time",		"popularity",	"createtime"	],
		["orderdir", 	"ASC", 		"asc",		"desc",		"DESC"],
		["orderdir", 	"DESC", 	"desc",		"asc",		"ASC"],
		["mode", 	"full", 	"abbrev",	"full",		"fulltitle"],
		["mode", 	"fulltitle", 	"full",		"abbrev",	"full"]
	];
	var params = {};
	params['op'] = 'firehose_set_options';
	params['reskey'] = reskey_static;
	var theForm = document.forms["firehoseform"];
	if (name == "firehose_usermode") {
		if (value ==  true) {
			value = 1;
		}
		if (value == false) {
			value = 0;
		}
		params['setusermode'] = 1;
		params[name] = value;
	}

	if (name == "nodates" || name == "nobylines" || name == "nothumbs" || name == "nocolors" || name == "mixedmode" || name == "nocommentcnt" || name == "nomarquee" || name == "noslashboxes") {
		value = value == true ? 1 : 0;
		params[name] = value;
		params['setfield'] = 1;
		var classname;
		if (name == "nodates") {
			classname = "date";
		} else if (name == "nobylines") {
			classname = "nickname";
		}

		if (classname) {
			var els = document.getElementsByClassName(classname, jQuery('#firehoselist')[0]);
			var classval = classname;
			if (value) {
				classval = classval + " hide";
			}
			for (i = 0; i< els.length; i++) {
				els[i].className = classval;
			}
		}
	}

	if (name == "fhfilter" && theForm) {
		for (i=0; i< theForm.elements.length; i++) {
			if (theForm.elements[i].name == "fhfilter") {
				firehose_settings.fhfilter = theForm.elements[i].value;
			}
		}
		firehose_settings.page = 0;
	}
	if (name != "color") {
	for (i=0; i< pairs.length; i++) {
		var el = pairs[i];
		if (name == el[0] && value == el[1]) {
			firehose_settings[name] = value;
			if (jQuery(make_selector(el[2]))[0]) {
				jQuery(make_selector(el[2]))[0].id = el[3];
				if(jQuery(make_selector(el[3]))[0]) {
					var namenew = el[0];
					var valuenew = el[4];
					jQuery(make_selector(el[3]))[0].firstChild.onclick = function() { firehose_set_options(namenew, valuenew); return false;}
				}
			}
		}
	}
	if (name == "mode" || name == "firehose_usermode" || name == "tab" || name == "mixedmode" || name == "nocolors" || name == "nothumbs") {
		// blur out then remove items
		if (name == "mode") {
			fh_view_mode = value;
		}
		if (jQuery('#firehoselist')[0]) {
			// set page
			page = 0;
			
			if (!is_ie) {
				var attributes = { 
					opacity: { from: 1, to: 0 }
				};
				var myAnim = new YAHOO.util.Anim("firehoselist", attributes); 
				myAnim.duration = 1;
				myAnim.onComplete.subscribe(function() {
					jQuery('#firehoselist')[0].style.opacity = "1";
				});
				myAnim.animate();
			}
			// remove elements
			setTimeout(firehose_remove_all_items, 600);
		}
	}
	}

	if (name == "color" || name == "tab" || name == "pause" || name == "startdate" || name == "duration" || name == "issue" || name == "pagesize") { 
		params[name] = value;
		if (name == "startdate") {
			firehose_settings.startdate = value;
		}
		if (name == "duration")  {
			firehose_settings.duration = value;
		}
		if (name == "issue") {
			firehose_settings.issue = value;
			firehose_settings.startdate = value;
			firehose_settings.duration = 1;
			firehose_settings.page = 0;
			var issuedate = firehose_settings.issue.substr(5,2) + "/" + firehose_settings.issue.substr(8,2) + "/" + firehose_settings.issue.substr(10,2);

			if (jQuery('#fhcalendar')[0]) {
				jQuery('#fhcalendar')[0]._widget.setDate(issuedate, "day");
			}
			if (jQuery('#fhcalendar_pag')[0]) {
				jQuery('#fhcalendar_pag')[0]._widget.setDate(issuedate, "day");
			}
		}
		if (name == "color") {
			firehose_settings.color = value;
		}
		if (name == "pagesize") {
			firehose_settings.page = 0;
		}
	}

	var handlers = {
		onComplete: function(transport) { 
			json_handler(transport);
			firehose_get_updates({ oneupdate: 1 });
		}
	};

	if (name == 'tabsection') {
		firehose_settings.section = value;
		params['tabtype'] = 'tabsection';
	}

	if (name == 'tabtype') {
		params['tabtype'] = value;
	}

	params['section'] = firehose_settings.section;
	for (i in firehose_settings) {
		params[i] = firehose_settings[i];
	}
	ajax_update(params, '', handlers);
}

function firehose_remove_all_items() {
	var fhl = jQuery('#firehoselist')[0];
	var children = fhl.childNodes;
	for (var i = children.length -1 ; i >= 0; i--) {
		var el = children[i];
		if (el.id) {
			el.parentNode.removeChild(el);
		}
	}
}


function firehose_up_down(id, dir) {
	if (!check_logged_in()) return;

	setFirehoseAction();
	var params = {};
	var handlers = {
		onComplete: json_handler
	};
	params['op'] = 'firehose_up_down';
	params['id'] = id;
	params['reskey'] = reskey_static;
	params['dir'] = dir;
	var updown = jQuery('#updown-' + id)[0];
	ajax_update(params, '', handlers);
	if (updown) {
		if (dir == "+") {
			updown.className = "votedup";	
		} else if (dir == "-") {
			updown.className = "voteddown";	
		}
	}

	if (dir == "-" && fh_is_admin) {
		firehose_collapse_entry(id);
	}
}

function firehose_remove_tab(tabid) {
	setFirehoseAction();
	var params = {};
	var handlers = {
		onComplete:  json_handler
	};
	params['op'] = 'firehose_remove_tab';
	params['tabid'] = tabid;
	params['reskey'] = reskey_static;
	params['section'] = firehose_settings.section;
	ajax_update(params, '', handlers);

}


// firehose functions end

// helper functions
function ajax_update(request_params, id, handlers, request_url) {
	// make an ajax request to request_url with request_params, on success,
	//  update the innerHTML of the element with id

	var opts = {
		url: request_url || '/ajax.pl',
		data: request_params,
		type: 'POST',
		contentType: 'application/x-www-form-urlencoded',
	};

	if ( id ) {
		opts['success'] = function(html){
			jQuery(make_selector(id)).html(html);
		}
	}

	if ( handlers && handlers.onComplete ) {
		opts['complete'] = handlers.onComplete;
	}

	jQuery.ajax(opts);
}

function ajax_periodic_update(interval_in_seconds, request_params, id, handlers, request_url) {
	setInterval(function(){
		ajax_update(request_params, id, handlers, request_url);
	}, interval_in_seconds*1000);
}

function eval_response(transport) {
	var response;
	try {
		eval("response = " + transport.responseText)
	} catch (e) {
		//alert(e + "\n" + transport.responseText)
	}
	return response;
}

function json_handler(transport) {
	var response = eval_response(transport);
	json_update(response);
	return response;
}

function json_update(response) {
	if (response.eval_first) {
		try {
			eval(response.eval_first)
		} catch (e) {

		}
	}

	if (response.html) {
		for (el in response.html) {
			if (jQuery(make_selector(el))[0])
				jQuery(make_selector(el))[0].innerHTML = response.html[el];
		}
		
	} 

	if (response.value) {
		for (el in response.value) {
			if (jQuery(make_selector(el))[0])
				jQuery(make_selector(el))[0].value = response.value[el];
		}
	}

	if (response.html_append) {
		for (el in response.html_append) {
			if (jQuery(make_selector(el))[0])
				jQuery(make_selector(el))[0].innerHTML = jQuery(make_selector(el))[0].innerHTML + response.html_append[el];
		}
	}

	if (response.html_append_substr) {
		for (el in response.html_append_substr) {
			if (jQuery(make_selector(el))[0]) {
				var this_html = jQuery(make_selector(el))[0].innerHTML;
				var i = jQuery(make_selector(el))[0].innerHTML.search(/<span class="?substr"?> ?<\/span>[\s\S]*$/i);
				if (i == -1) {
					jQuery(make_selector(el))[0].innerHTML += response.html_append_substr[el];
				} else {
					jQuery(make_selector(el))[0].innerHTML = jQuery(make_selector(el))[0].innerHTML.substr(0, i) +
						response.html_append_substr[el];
				}
			}
		}
	}		
	
	if (response.eval_last) {
		try {
			eval(response.eval_last)
		} catch (e) {

		}
	}
}


function firehose_handle_update() {
	if (firehose_updates.length > 0) {
		var el = firehose_updates.pop();
		var fh = 'firehose-' + el[1];
		var wait_interval = 800;
		if(el[0] == "add") {
			if (firehose_before[el[1]] && jQuery('#firehose-' + firehose_before[el[1]]).size()) {
				jQuery('#firehose-' + firehose_before[el[1]]).after(el[2]);
			} else if (firehose_after[el[1]] && jQuery('#firehose-' + firehose_after[el[1]]).size()) {
				jQuery('#firehose-' + firehose_after[el[1]]).before(el[2]);
			} else if (insert_new_at == "bottom") {
				jQuery('#firehoselist').append(el[2]);
			} else {
				jQuery('#firehoselist').prepend(el[2]);
			}
		
			var toheight = 50;
			if (fh_view_mode == "full") {
				toheight = 200;
			}

			var attributes = { 
				height: { from: 0, to: toheight }
			};
			if (!is_ie) {
				attributes.opacity = { from: 0, to: 1 };
			}
			var myAnim = new YAHOO.util.Anim(fh, attributes); 
			myAnim.duration = 0.7;

			if (firehose_updates_size > 10) {
				myAnim.duration = myAnim.duration / 2;
				wait_interval = wait_interval / 2;
			}
			if (firehose_updates_size > 20) {
				myAnim.duration = myAnim.duration / 2;
				wait_interval = wait_interval / 2;

			}
			if (firehose_updates_size > 30) {
				myAnim.duration = myAnim.duration / 1.5;
				wait_interval = wait_interval / 2;
			}

			myAnim.onComplete.subscribe(function() {
				if (jQuery(make_selector(fh))[0]) {
					jQuery(make_selector(fh))[0].style.height = "";
					if (fh_use_jquery) {
						jQuery("#" + fh + " h3 a[class!='skin']").click(
				                	function(){
                	        				jQuery(this).parent('h3').next('div.hide').toggle("fast");
				                        	jQuery(this).parent('h3').find('a img').toggle("fast");
                        			        	return false;
                        				}
                				);
					}
				}
			});
			myAnim.animate();
		} else if (el[0] == "remove") {
			var fh_node = jQuery(make_selector(fh))[0];
			if (fh_is_admin && fh_view_mode == "fulltitle" && fh_node && fh_node.className == "article" ) {
				// Don't delete admin looking at this in expanded view
			} else {
				var attributes = { 
					height: { to: 0 }
				};
				
				if (!is_ie) {
					attributes.opacity = { to: 0};
				}
				var myAnim = new YAHOO.util.Anim(fh, attributes); 
				myAnim.duration = 0.4;
				wait_interval = 500;
				
				if (firehose_updates_size > 10) {
					myAnim.duration = myAnim.duration * 2;
					if (!firehose_removed_first) {
						wait_interval = wait_interval * 2;
					} else {
						wait_interval = 50;
					}
				}
				firehose_removed_first = 1;
				if (firehose_removals < 10 ) {
					myAnim.onComplete.subscribe(function() {
						var elem = this.getEl();
						if (elem && elem.parentNode) {
							elem.parentNode.removeChild(elem);
						}
					});
					myAnim.animate(); 
				} else {
					var elem = jQuery(make_selector(fh))[0];
					wait_interval = 25;
					if (elem && elem.parentNode) {
						elem.parentNode.removeChild(elem);
					}
				}
			}
		}
		setTimeout(firehose_handle_update, wait_interval);
	} else {
		firehose_reorder();
		firehose_get_next_updates();
	}
}

function firehose_reorder() {
	if (firehose_ordered) {
		var fhlist = jQuery('#firehoselist')[0];
		if (fhlist) {
			var item_count = 0;
			for (i = 0; i < firehose_ordered.length; i++) {
				if (/^\d+$/.test(firehose_ordered[i])) {
					item_count++;
				}
				var fhel = jQuery('#firehose-' + firehose_ordered[i])[0];
				if (fhlist && fhel) {
					fhlist.appendChild(fhel);
				}
				if ( firehose_future[firehose_ordered[i]] ) {
					if (jQuery("#ttype-" + firehose_ordered[i])[0]) {
						jQuery("#ttype-" + firehose_ordered[i])[0].className = "future";
					}
				} else {
					if (jQuery("#ttype-" + firehose_ordered[i])[0] && jQuery("#ttype-" + firehose_ordered[i])[0].className == "future") {
						jQuery("#ttype-" + firehose_ordered[i])[0].className = "story";
					}
				}
			}
			if (console_updating) {
				document.title = sitename + " - Console (" + item_count + ")";
			} else {
				document.title = sitename + " - Firehose (" + item_count + ")";
			}
		}
	}

}

function firehose_get_next_updates() {
	var interval = getFirehoseUpdateInterval();
	//alert("fh_get_next_updates");
	fh_is_updating = 0;
	firehose_add_update_timerid(setTimeout(firehose_get_updates, interval));
}


function firehose_get_updates_handler(transport) {
	if (jQuery('#busy')[0]) {
		jQuery('#busy')[0].className = "hide";
	}
	var response = eval_response(transport);
	var processed = 0;
	firehose_removals = response.update_data.removals;
	firehose_ordered = response.ordered;
	firehose_future = response.future;
	firehose_before = Array(0);
	firehose_after = Array(0);
	for (i = 0; i < firehose_ordered.length; i++) {
		if (i > 0) {
			firehose_before[firehose_ordered[i]] = firehose_ordered[i - 1];
		}
		if (i < (firehose_ordered.length - 1)) {
			firehose_after[firehose_ordered[i]] = firehose_ordered[i + 1];
		}
	}
	if (response.html) {
		json_update(response);
		processed = processed + 1;
	}
	if (response.updates) {
		firehose_updates = response.updates;
		firehose_updates_size = firehose_updates.length;
		firehose_removed_first = 0;
		processed = processed + 1;
		firehose_handle_update();
	}
}

function firehose_get_item_idstring() {
	var fhl = jQuery('#firehoselist')[0];
	var str = "";
	var children;
	if (fhl) {
		var id;
		children = fhl.childNodes;
		if (children) {
			for (var i = 0; i < children.length; i++) {
				if (children[i].id) {
					id = children[i].id;
					id = id.replace(/^firehose-/g, "");
					id = id.replace(/^\s+|\s+$/g, "");
					str = str + id + ",";
				}
			}
		}
	}
	return str;
}


function firehose_get_updates(options) {
	options = options || {};
	run_before_update();
	if ((fh_play == 0 && !options.oneupdate) || fh_is_updating == 1) {
		firehose_add_update_timerid(setTimeout(firehose_get_updates, 2000));
	//	alert("wait loop: " + fh_is_updating);
		return;
	}
	if (fh_update_timerids.length > 0) {
		var id = 0;
		while(id = fh_update_timerids.pop()) { clearTimeout(id) };
	}
	fh_is_updating = 1
	var params = {};
	var handlers = {
		onComplete: firehose_get_updates_handler
	};
	params['op'] = 'firehose_get_updates';
	params['ids'] = firehose_get_item_idstring();
	params['updatetime'] = update_time;

	for (i in firehose_settings) {
		params[i] = firehose_settings[i];
	}

	if ( firehose_settings.is_embedded ) {
		params['embed'] = 1;
	}
	params['fh_pageval'] = firehose_settings.pageval;
	if (jQuery('#busy')[0]) {
		jQuery('#busy')[0].className = "";
	}
	ajax_update(params, '', handlers);
}


function setFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	firehose_action_time = newtime;
	if (fh_is_timed_out) {
		fh_is_timed_out = 0;
		firehose_play();
		firehose_get_updates();
		if (console_updating) {
			console_update(1, 0)
		}
	}
}

function getSecsSinceLastFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	var diff = (newtime - firehose_action_time) / 1000;
	return diff;
}

function getFirehoseUpdateInterval() {
	var interval = 45000;
	if (updateIntervalType == 1) {
		interval = 30000;
	}
	interval = interval + (5 * interval * getSecsSinceLastFirehoseAction() / inactivity_timeout);
	if (getSecsSinceLastFirehoseAction() > inactivity_timeout) {
		interval = 3600000;
	}

	return interval;
}

function run_before_update() {
	var secs = getSecsSinceLastFirehoseAction();
	if (secs > inactivity_timeout) {
		fh_is_timed_out = 1;
		if (jQuery('#message_area')[0])
			jQuery('#message_area')[0].innerHTML = "Automatic updates have been slowed due to inactivity";
		//firehose_pause();
	}
}

function firehose_play() {
	fh_play = 1;
	setFirehoseAction();
	firehose_set_options('pause', '0');
	var pausepanel = jQuery('#pauseorplay')[0];
	if (jQuery('#message_area')[0])
		jQuery('#message_area')[0].innerHTML = "";
	if (pausepanel) {
		pausepanel.innerHTML = "Updated";
	}
	var pause = jQuery('#pause')[0];
	
	var play_div = jQuery('#play')[0];
	if (play_div) {
		play_div.className = "hide";
	}
	if (pause) {
		pause.className = "show";
	}
}

function is_firehose_playing() {
  return YAHOO.util.Dom.hasClass('play', 'hide');
}

function firehose_pause() {
	fh_play = 0;
	var pause = jQuery('#pause')[0];
	var play_div = jQuery('#play')[0];
	pause.className = "hide";
	play_div.className = "show";
	if (jQuery('#pauseorplay')[0]) {
		jQuery('#pauseorplay')[0].innerHTML = "Paused";
	}
	firehose_set_options('pause', '1');
}

function firehose_add_update_timerid(timerid) {
	fh_update_timerids.push(timerid);		
}

function firehose_collapse_entry(id) {
	var fhbody = jQuery('#fhbody-'+id)[0];
	var fh = jQuery('#firehose-'+id)[0];
	if (fhbody && fhbody.className == "body") {
		fhbody.className = "hide";
	}
	if (fh) {	
		fh.className = "briefarticle";
	}
	tagsHideBody(id)

}

function firehose_remove_entry(id) {
	var fh = jQuery('#firehose-' + id)[0];
	if (fh) {
		var attributes = { 
			height: { to: 0 }
		};
		if (!is_ie) {
			attributes.opacity = { to: 0 };
		}
		var myAnim = new YAHOO.util.Anim(fh, attributes); 
		myAnim.duration = 0.5;
		myAnim.onComplete.subscribe(function() {
			var el = this.getEl();
			el.parentNode.removeChild(el);
		});
		myAnim.animate();
	}
}

var firehose_cal_select_handler = function(type,args,obj) { 
	var selected = args[0];
	firehose_settings.issue = '';
	firehose_set_options('startdate', selected.startdate);
	firehose_set_options('duration', selected.duration);
}; 


function firehose_calendar_init( widget ) {
	widget.changeEvent.subscribe(firehose_cal_select_handler, widget, true);
}

function firehose_slider_init() {
	if (!fh_slider_init_set) {
		fh_colorslider = YAHOO.widget.Slider.getHorizSlider("colorsliderbg", "colorsliderthumb", 0, 105, fh_ticksize);
		var fh_set_val_return = fh_colorslider.setValue(fh_ticksize * fh_colors_hash[fh_color] , 1);
		var fh_get_val_return = fh_colorslider.getValue();
		fh_colorslider.subscribe("slideEnd", firehose_slider_end);
	}
}	

function firehose_slider_end(offsetFromStart) {
	var newVal = fh_colorslider.getValue();
	if (newVal) {
		fh_slider_init_set = 1;
	}
	var color = fh_colors[ newVal / fh_ticksize ];
	jQuery('#fh_slider_img')[0].title = "Firehose filtered to " + color;
	if (fh_slider_init_set) {
		firehose_set_options("color", color)
	}
}

function firehose_slider_set_color(color) {
	fh_colorslider.setValue(fh_ticksize * fh_colors_hash[color] , 1);
}

function firehose_change_section_anon(section) {
	window.location.href= window.location.protocol + "//" + window.location.host + "/firehose.pl?section=" + encodeURIComponent(section) + "&tabtype=tabsection";
}

function pausePopVendorStory(id) {
	vendor_popup_id=id;
	closePopup('vendorStory-26-popup');
	vendor_popup_timerids[id] = setTimeout(vendorStoryPopup, 500);
}

function clearVendorPopupTimers() {
	clearTimeout(vendor_popup_timerids[26]);
}

function vendorStoryPopup() {
	id = vendor_popup_id;
	var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:pageTracker._trackPageview('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
	var buttons = createPopupButtons("<a href=\"#\" onclick=\"closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
	title = title + buttons;
	var closepopup = function (e) {
	if (!e) var e = window.event;
	var relTarg = e.relatedTarget || e.toElement;
	if (relTarg && relTarg.id == "vendorStory-26-popup") {
		closePopup("vendorStory-26-popup");
	}
	};
	createPopup(getXYForId('sponsorlinks', 0, 0), title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = {};
	params['op'] = 'getTopVendorStory';
	params['skid'] = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function pausePopVendorStory2(id) {
	vendor_popup_id=id;
	closePopup('vendorStory-26-popup');
	vendor_popup_timerids[id] = setTimeout(vendorStoryPopup2, 500);
}

function vendorStoryPopup2() {
	id = vendor_popup_id;
	var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:pageTracker._trackPageview('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
	var buttons = createPopupButtons("<a href=\"#\" onclick=\"closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
	title = title + buttons;
	var closepopup = function (e) {
		if (!e) var e = window.event;
		var relTarg = e.relatedTarget || e.toElement;
		if (relTarg && relTarg.id == "vendorStory-26-popup") {
			closePopup("vendorStory-26-popup");
		}
	};
	createPopup(getXYForId('sponsorlinks2', 0, 0), title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = {};
	params['op'] = 'getTopVendorStory';
	params['skid'] = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function logToDiv(id, message) {
	var div = jQuery(make_selector(id))[0];
	if (div) {
	div.innerHTML = div.innerHTML + message + "<br>";
	}
}


function firehose_open_tab(id) {
	var tf = jQuery('#tab-form-'+id)[0];
	var tt = jQuery('#tab-text-'+id)[0];
	var ti = jQuery('#tab-input-'+id)[0];
	tf.className="";
	ti.focus();
	tt.className="hide";
}

function firehose_save_tab(id) {
	var tf = jQuery('#tab-form-'+id)[0];
	var tt = jQuery('#tab-text-'+id)[0];
	var ti = jQuery('#tab-input-'+id)[0];
	var params = {};
	var handlers = {
		onComplete: json_handler 
	};
	params['op'] = 'firehose_save_tab';
	params['tabname'] = ti.value;
	params['section'] = firehose_settings.section;

	params['tabid'] = id;
	ajax_update(params, '',  handlers);
	tf.className = "hide";
	tt.className = "";
}


var logged_in   = 1;
var login_cover = 0;
var login_box   = 0;
var login_inst  = 0;

function init_login_divs() {
	login_cover = document.getElementById('login_cover');
	login_box   = document.getElementById('login_box');
}

function install_login() {
	if (login_inst)
		return;

	if (!login_cover || !login_box)
		init_login_divs();

	if (!login_cover || !login_box)
		return;

	login_cover.parentNode.removeChild(login_cover);
	login_box.parentNode.removeChild(login_box);

	var top_parent = document.getElementById('top_parent');
	top_parent.parentNode.insertBefore(login_cover, top_parent);
	top_parent.parentNode.insertBefore(login_box, top_parent);
	login_inst = 1;
}

function show_login_box() {
	if (!login_inst)
		install_login();

	if (login_cover && login_box) {
		login_cover.style.display = '';
		login_box.style.display = '';
	}

	return;
}

function hide_login_box() {
	if (!login_inst)
		install_login();

	if (login_cover && login_box) {
		login_box.style.display = 'none';
		login_cover.style.display = 'none';
	}

	return;
}

function check_logged_in() {
	if (!logged_in) {
		show_login_box();
		return 0;
	}
	return 1;
}

var modal_cover = 0;
var modal_box   = 0;
var modal_inst  = 0;

function init_modal_divs() {
	modal_cover = jQuery('#modal_cover')[0];
	modal_box   = jQuery('#modal_box')[0];
}

function install_modal() {
	if (modal_inst)
		return;

	if (!modal_cover || !modal_box)
		init_modal_divs();

	if (!modal_cover || !modal_box)
		return;

	modal_cover.parentNode.removeChild(modal_cover);
	modal_box.parentNode.removeChild(modal_box);

	var modal_parent = jQuery('#top_parent')[0];
	modal_parent.parentNode.insertBefore(modal_cover, modal_parent);
	modal_parent.parentNode.insertBefore(modal_box, modal_parent);
	modal_inst = 1;
}

function show_modal_box() {
	if (!modal_inst)
		install_modal();

	if (modal_cover && modal_box) {
		modal_cover.style.display = '';
		modal_box.style.display = '';
	}

	return;
}

function hide_modal_box() {
	if (!modal_inst)
		install_modal();

	if (modal_cover && modal_box) {
		modal_box.style.display = 'none';
		modal_cover.style.display = 'none';
	}

	return;
}

function getModalPrefs(section, title, tabbed) {
        document.getElementById('preference_title').innerHTML = title;
	var params = {};
	params['op'] = 'getModalPrefs';
	params['section'] = section;
	params['reskey'] = reskey_static;
        params['tabbed'] = tabbed;
	var handlers = {onComplete:show_modal_box};
	ajax_update(params, 'modal_box_content', handlers);

	return;
}

function firehose_get_media_popup(id) {
	if (jQuery('#preference_title')[0]) {
		jQuery('#preference_title')[0].innerHTML = "Media";
	}
	var params = {};
	params['op'] = 'firehose_get_media';
	params['id'] = id;
	show_modal_box();
	jQuery('#modal_box_content')[0].innerHTML = "<h4>Loading...</h4><img src='/images/spinner_large.gif'>";
	ajax_update(params, 'modal_box_content');
}

function saveModalPrefs() {
	var params = {};
	params['op'] = 'saveModalPrefs';
	params['data'] = jQuery("#modal_prefs").serialize();
	params['reskey'] = reskey_static;
	var handlers = {
		onComplete: function() {
			hide_modal_box();
			if (document.forms['modal_prefs'].refreshable.value)
				document.location=document.URL;
		}
	};
	ajax_update(params, '', handlers);
}

function ajaxSaveSlashboxes() {
	var wrapper = document.getElementById('slashboxes');
	var titles = YAHOO.util.Dom.getElementsByClassName('title', 'div', wrapper);
	var sep = "";
	var all = "";
	for ( i=0; i<titles.length; ++i) {
		var bid = titles[i].id.slice(0,-6);
		all += sep + bid;
		sep = ",";
	}

	var params = {};
	params['op'] = 'page_save_user_boxes';
	params['reskey'] = reskey_static;
	params['bids'] = all;
	ajax_update(params, '');
}

function ajaxRemoveSlashbox( id ) {
	var slashboxes = document.getElementById('slashboxes');
	var box = document.getElementById(id);
	if ( box.parentNode === slashboxes ) {
		slashboxes.removeChild(box);
		ajaxSaveSlashboxes();
	}
}

function displayModalPrefHelp(element) {
        var elem = document.getElementById(element);
        var vis = elem.style;
        vis.display = (!vis.display || vis.display == 'block') ? 'none' : 'block';
}

function toggle_filter_prefs() {
	var fps = jQuery('#filter_play_status')[0];
	var fp  = jQuery('#filter_prefs')[0];
	if (fps) {
		if (fps.className == "") {
			fps.className = "hide";
			if (fp) {
				fp.className = "";
				setTimeout(firehose_slider_init,500);
			} 
		} else if (fps.className == "hide") {
			fps.className = "";
			if (fp) {
				fp.className = "hide";
			}
		}
	}

}
