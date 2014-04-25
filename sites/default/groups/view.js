Route.add(/#\/groups\/([a-zA-Z0-9]{1,11})$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	api.GET('groups/'+id+'/info',{},function(info){	
	    R.page({ 
		title: info.label || info.id, 
		body: body, 
		buttons: [{
		    url: '#/groups/' + id + '/import',
		    style: 'success',
		    label: i18n.groups.import.title
		}]
	    });
	    R.show();
	})
    }

    function body(R) {
	api.GET('groups/'+id,{},function(all){
	    R['people/all'](all);
	    R.show();
	});
    }
});