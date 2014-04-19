/* Simple controller. */

function renderFixture(R,fixture) {

    var inner = fixture.children()
	.filter(function(f) { return f.verb != null; });
    
    R.body($.extend({inner:inner},contents));
    R.show();

}

/* Root page */
Route.add(/^\/docs(\/(#\/?)?)?$/, function(R) {

    function body(R) {
	Fixture.root.then(function(root) {
	    renderFixture(root);
	});
    }

    R.layout({ body: body });
    R.show();

});

/* Individual node pages */
Route.add(/^\/docs\/#\/(.+)$/, function(R,path) {

    function body(R) {
	Fixture.all.then(function(all) {
	    renderFixture(all[path]);
	});
    }

    R.layout({ body: body });
    R.show();

});
