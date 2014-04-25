Route.add(/#\/people\/([a-zA-Z0-9]{1,11})$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	api.GET('people/' + id,{},function(person){
	    R.page({ title: person.label, body: body(person) })
	    R.show();
	});
    }

    function body(person) {
	return function(R) {
	    R['people/view'](person);
	    R.show();
	}
    }
});