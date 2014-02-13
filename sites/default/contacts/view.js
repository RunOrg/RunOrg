Route.add(/#\/contacts\/([a-zA-Z0-9]{1,11})$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	api.GET('contacts/' + id,{},function(contact){
	    R.page({ title: contact.name, body: body(contact) })
	    R.show();
	});
    }

    function body(contact) {
	return function(R) {
	    R['contacts/view'](contact);
	    R.show();
	}
    }
});