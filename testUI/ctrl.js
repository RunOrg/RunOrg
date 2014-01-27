/* Simple controller. */

/* Renders the sidebar. */
function sidebar(R) {
    Test.tree(function(tree) {
	function clean(tree) {
	    var out = { sub: [], tests: [], count: 0, ok: true };
	    for (var k in tree) {
		if (k == '__') continue;
		if (tree[k]['__'] == 'cat') {
		    var s = clean(tree[k]);
		    s.name = k;
		    out.sub.push(s);
		    out.count += s.count;
		    out.ok = out.ok && s.ok;
		} else {
		    out.tests.push({ 
			name: k, 
			path: tree[k].file.path,
			file: "/docs/" + tree[k].file.file,
			count: tree[k].file.tests
		    });
		    out.count += tree[k].file.tests;
		    out.ok = out.ok && !tree[k].failed;
		}
	    }
	    return out;
	}

	R.sidebar(clean(tree));
	R.show();
    });
}

Route.add(/^\/docs/, function(R) {

    R.layout({
	sidebar: sidebar
    });

    R.show();
});