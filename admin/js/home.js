/* The home (/admin) route displays a list of all administrators. 
 */

"/admin".route(function(r){
    
    $.get('/admin/all',{token:token},function(r){
	r.esc(JSON.stringify(r)).show();
    });

});
