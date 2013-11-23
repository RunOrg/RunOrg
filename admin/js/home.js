// The home (/admin) route displays a list of all administrators. 

"/admin".route(function(R){
    
    $.get('/admin/all',{token:token},function(r){
	
	R.form({},function(R){
	    
	}).input().close();

	R.ul();
	for (var i = 0; i < r.admins.length; ++i) 
	    R.li().esc(r.admins[i].email).close();	
	R.show();

    });

});
