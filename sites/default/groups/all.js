Route.add(/#\/groups$/,function(R){

    R.layout({ body: page });
    R.show();

    function page(R) {
	R.page({ 
	    title: i18n.groups.title, 
	    body: body,
	    buttons: [{
		url: '#/groups/create',
		style: 'success', 
		label: i18n.groups.create.title
	    }]
	});
	R.show();
    }

    function body(R) {
	api.GET('groups/public',{},function(all){
	    R['groups/all'](all);
	    R.show();
	});
    }
});