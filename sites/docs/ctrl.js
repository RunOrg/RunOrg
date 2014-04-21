/* Simple controller. */

function renderFixture(R,fixture) {

    var inner = fixture.children()
	.filter(function(f) { return f.verb != null; });
    
    var failed = fixture.failed()
	.map(function(t) { return { name: t.name, reason: t.failure() }; });

    fixture.parsed().then(function(parsed) {
	R.body($.extend({inner: inner, failed: failed},parsed));
	R.show();
    });
}

/* Root page */
Route.add(/^\/docs(\/(#\/?)?)?$/, function(R) {

    function body(R) {
	Fixture.root.then(function(root) {
	    renderFixture(R,root);
	});
    }

    R.layout({ body: body });
    R.show();

});

/* Individual node pages */
Route.add(/^\/docs\/#\/(.+)$/, function(R,path) {

    function body(R) {
	Fixture.all.then(function(all) {
	    renderFixture(R,all[path]);
	});
    }

    R.layout({ body: body });
    R.show();

});
