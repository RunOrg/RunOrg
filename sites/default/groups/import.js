Route.add(/#\/groups\/([a-zA-Z0-9]{1,11})\/import$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	api.GET('groups/'+id+'/info',{},function(info){	
	    R.page({ title: info.label || info.id, body: body });
	    R.show();
	})
    }

    function body(R) {
	R["groups/import"]();
	var sent = false, $form = R.show().find('form').submit(function(){

	    if (sent) return;

	    var emails = $(this).find('textarea').val().split('\n'),
                imported = [];

	    for(var i = 0; i < emails.length; ++i) {
		var email = emails[i].trim();
		if (/@/.exec(email)) imported.push({ email: email });		
	    }	    

	    if (imported.length > 0) {
		sent = true;
		$form.find('button').attr('disabled',true);
		api.POST('people/import',imported,function(result){
		    api.POST('groups/'+id+'/add',result.created,function(){
			go('#/groups/'+id);
		    });
		});
	    }
	    
	    return false;
	});
    }
});
