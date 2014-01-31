/* Simple controller. */

/* Root page */
Route.add(/^\/docs(\/(#\/?)?)?$/, function(R) {
    R.layout();
    R.show();
});

/* Individual node pages */
Route.add(/^\/docs\/#\/(.+)$/, function(R,path) {

    function body(R) {
	Test.get(path,function(contents) {
	    R.body(contents);
	    R.show();
	});
    }

    R.layout({ body: body });
    R.show();

});
