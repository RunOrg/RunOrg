Route.add(/#\/chat\/create$/,function(R,id){

    R.layout({ body: page });
    R.show();

    function page(R) {
	R.page({ title: i18n.chat.create.title, body: body });
	R.show();	
    }

    function body(R) {
	R['chat/create']({ groups: groups });
	var sent = false, $form = R.show().find('form').submit(function(){

	    if (sent) return false;

	    var title = $form.find('input').val().trim(),
                body  = $form.find('textarea').val().trim(),
                contacts = [],
	        groups = [];

	    $form.find('.contact').children().each(function(){
		contacts.push(this.dataset.id);
	    });
	    
	    $form.find('.group:checked').children().each(function(){
		groups.push(this.dataset.id);
	    });
	   
	    if (label && (groups.length || contacts.length)) {
		sent = true;
		$form.find('button').attr('disabled',true);
		api.POST('chat/create',{contacts:contacts,groups:groups},function(result){
		    go('#/groups/'+result.id);
		});
	    }

	    return false;
	});
    }

    function groups(R) {
	api.GET('groups/public',{},function(groups) {

	    var list = [];
	    for (var i = 0; i < groups.list.length; ++i)
		if (groups.list[i].count > 0)
		    list.push(groups.list[i]);

	    R['chat/create-groups'](list);
	    R.show();

	});
    }
});