Route.add(/#\/contacts$/,function(R){

    R.layout({ body: page });
    R.show();

    function page(R) {
	R.page({ title: i18n.contacts.title, body: body });
	R.show();
    }

    function body(R) {
	api.GET('contacts',{},function(all){
	    R.esc(JSON.stringify(all));
	    R.show();
	});
    }
});