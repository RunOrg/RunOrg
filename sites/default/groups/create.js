Route.add(/#\/groups\/create$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	R.page({ title: i18n.groups.create.title, body: body });
	R.show();	
    }

    function body(R) {
	R['groups/create']();
	var sent = false, $form = R.show().find('form').submit(function(){
	    if (sent) return false;
	    var label = $form.find('input').val().trim();
	    if (label) {
		sent = true;
		$form.find('button').attr('disabled',true);
		api.POST('groups/create',{label:label},function(result){
		    go('#/groups/'+result.id);
		});
	    }
	    return false;
	});
    }
});