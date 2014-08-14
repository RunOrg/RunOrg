Route.add(/^$/,function(R){

    R.layout({ body: page });
    R.show();

    function page(R) {
	R.page({ title: i18n.people.title, body: body });
	R.show();
    }

    function body(R) {
	api.GET('people',{},function(all){
	    R['people/all'](all);
	    R.show();
	});
    }
});