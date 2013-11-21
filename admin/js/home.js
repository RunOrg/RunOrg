/* The home (/admin) route displays a list of all administrators. 
 */

"/admin".route(function(R){
    
    $.get('/admin/all',{token:token},function(r){
	R.div().esc(JSON.stringify(r)).show();
    });

});
