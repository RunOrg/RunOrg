Route.add(/#\/chat\/([a-zA-Z0-9]{1,11})$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	api.GET('chat/' + id,{},function(chat){
	    R.page({ title: chat.info.subject || i18n.chat.untitled, body: body(chat) })
	    R.show();
	});
    }

    function body(chat) {

	var contacts = {}, groups = {}, participants = [], i;

	for (i = 0; i < chat.contacts.length; ++i)
	    contacts[chat.contacts[i].id] = chat.contacts[i];

	for (i = 0; i < chat.groups.length; ++i) 
	    groups[chat.groups[i].id] = chat.groups[i];

	for (i = 0; i < chat.info.contacts.length; ++i) {
	    var contact = contacts[chat.info.contacts[i]];
	    participants.push({
		id: contact.id,
		pic: contact.pic,
		url: '#/contacts/' + contact.id,
		name: contact.name
	    });
	}

	for (i = 0; i < chat.info.groups.length; ++i) {
	    var group = groups[chat.info.groups[i]];
	    participants.push({
		id: group.id,
		count: group.count || 0,
		url: '#/groups/' + group.id,
		name: group.name
	    });
	}	

	return function(R) {
	    R['chat/view']({
		participants: participants,
		feed: function(R){ R.show() }
	    });
	    R.show();
	}
    }
});
