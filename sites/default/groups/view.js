Route.add(/#\/groups\/([a-zA-Z0-9]{1,11})$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	api.GET('groups/'+id+'/info',{},function(info){	
	    R.page({ title: info.label || info.id, body: body });
	    R.show();
	})
    }

    function body(R) {
	api.GET('groups/'+id,{},function(all){
	    R['contacts/all'](all);
	    R.show();
	});
    }
});