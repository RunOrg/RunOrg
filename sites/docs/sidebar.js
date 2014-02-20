/* Extend the layout to automatically render the sidebar. */
(function() {

    function sidebar(R) {
	window.$sidebar = R.$;

	Test.tree(function(tree) {

	    // This function is only called on category nodes
	    function clean(tree) {

		var out = { sub: [], tests: [], count: 0, ok: true, ran: true, rcount: 0 };

		// If category node has an associated document
		if (tree._f) {
		    out.count += tree._f.tests || 0;
		    out.rcount += tree._f.rcount || 0;
		    out.ok = out.ok && !tree._f.failed;
		    out.file = "/docs/#/" + tree._f.file;
		    out.verb = tree._f.verb || "";
		    out.path = tree._f.path || "";
		}

		// Recurse through subnodes to populate 'out.sub' and 'out.tests'
		for (var k in tree) {
		    var node = tree[k];
		    if (k == '__' || k == '_f') continue;
		    if (node['__'] == 'cat') {
			var s = clean(node);
			s.name = k;
			out.sub.push(s);
			out.count += s.count;
			out.rcount += s.rcount;
			out.ok = out.ok && s.ok;
		    } else {                
			out.tests.push({ 
			    name: k, 
			    ok:   !node.fixture.failed,
			    ran:  node.fixture.ran,
			    verb: node.fixture.verb,
			    path: node.fixture.path,
			    file: "/docs/#/" + node.fixture.file,
			    count: node.fixture.tests,
			    failed: node.fixture.failed
			});
			out.count += node.fixture.tests || 0;
			out.rcount += node.fixture.rcount || 0;
			out.ok = out.ok && !node.fixture.failed;
			out.ran = out.ran && (!node.fixture.tests || node.fixture.ran);
		    }
		}
		out.ran = out.ran && out.count > 0;
		return out;
	    }
	    
	    var data = clean(tree);
	    data.running = Test.running;
	    data.done = (data.rcount * 100 / data.count).toFixed(2);
	    data.root = true;

	    R.sidebar(data);
	    R.show();

	    var location = document.location.pathname + document.location.hash;
	    var $a = $sidebar.find('a[href="' + location + '"]').addClass('active');

	    // When clicked on category, show sub-elements
	    $a.next().show();

	    // Open all parent categories
	    while ($a.length > 0) $a = $a.parent().closest('ul').show();	    

	    if (!Test.running) {
		var $button = $sidebar.find('button').click(function(){
		    Test.run(function(fixture,test) {
			sidebar(new Renderer($sidebar))
		    });
		});
	    }
	});
    }

    Renderer.fill('layout',{ sidebar: sidebar, body: function(R){ R.show(); }});

})();
