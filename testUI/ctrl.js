/* Simple controller. */

function sidebar(R) {
    Test.tree(function(tree) {
	R.sidebar(tree);
	R.show();
    });
}

Route.add(/^\/docs/, function(R) {

    R.layout({
	sidebar: sidebar
    });

    R.show();
});