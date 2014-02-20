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

	    var subject  = $form.find('#subject').val().trim(),
                contacts = [],
	        groups   = [];

	    $form.find('.contacts tr').each(function(){
		contacts.push(this.dataset.id);
	    });
	    
	    $form.find('.group:checked').each(function(){
		groups.push(this.dataset.id);
	    });
	   
	    if (subject && (groups.length > 0 || contacts.length > 1)) {
		sent = true;
		$form.find('button').attr('disabled',true);
		api.POST('chat/create',{subject:subject,contacts:contacts,groups:groups},function(result){
		    if (result.id) {			
			go('#/chat/'+result.id);			
		    }
		});
	    }

	    return false;
	});

	$form.find('#contact-search').keyup(function(){

	    var $self = $(this),
	        q = $self.val().trim();
	        R = new Renderer($self.next());

	    api.GET('contacts/search',{q:q},function(result){
		R['chat/create-contacts'](result);
		R.show();
	    });

	})

        .next().on('click','a',function(){	    

	    var $contacts = $form.find('.contacts'),
                $tr = $(this).closest('tr');

	    $contacts.find('tr').each(function(){
		if (this.dataset.id == $tr[0].dataset.id) $(this).remove();
	    });

	    $tr.appendTo($contacts);
	    $('#contact-search').val('').next().html('');	    

	})

        .next().on('click','a',function() {
	    $(this).closest('tr').remove();
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