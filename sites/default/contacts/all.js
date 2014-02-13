Route.add(/#\/contacts$/,function(R){

    R.layout({ body: page });
    R.show();

    function page(R) {
	R.page({ title: i18n.contacts.title, body: body });
	R.show();
    }

    function body(R) {
	api.GET('contacts',{},function(all){
	    R['contacts/all'](all);
	    R.show();
	});
    }
});