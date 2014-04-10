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
		    var fixture = tree._f;
		    out.count += fixture.tests;
		    out.rcount += fixture.rcount;
		    out.ok = out.ok && !fixture.hasFailed();
		    out.file = "/docs/#/" + fixture.file;
		    out.verb = fixture.verb;
		    out.path = fixture.path;
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
			var fixture = node._f;
			out.tests.push({ 
			    name: k, 
			    ok:   !fixture.hasFailed(),
			    ran:  fixture.ran,
			    verb: fixture.verb,
			    path: fixture.path,
			    file: "/docs/#/" + fixture.file,
			    count: fixture.tests,
			    failed: fixture.failed
			});
			out.count += fixture.tests;
			out.rcount += fixture.rcount;
			out.ok = out.ok && !fixture.hasFailed();
			out.ran = out.ran && fixture.hasRun();
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
		$sidebar.find('button.all').click(function(){
		    Test.run(null,function(fixture,test) {
			sidebar(new Renderer($sidebar))
		    });
		});
		$sidebar.find('button.this').click(function(){
		    Test.run(document.location.hash.replace(/^#\//,''),function(fixture,test) {
			sidebar(new Renderer($sidebar))
		    });
		});
	    }
	});
    }

    Renderer.fill('layout',{ sidebar: sidebar, body: function(R){ R.show(); }});

})();
