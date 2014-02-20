Route.add(/^[^#]*$/,function(R){

    R.layout({ body: page });
    R.show();

    function page(R) {
	R.page({ 
	    title: i18n.chat.title, 
	    body: body,
	    buttons: [{
		url: '#/chat/create',
		style: 'success', 
		label: i18n.chat.create.title
	    }]
	});
	R.show();
    }

    function body(R) {
	R.show();
    }
});
