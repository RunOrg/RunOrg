/* Home controller */

Route.add(/^\/admin$/, function(R) {
    api.GET("/db/all",{},function(data) {
	R["home/page"](data);
	R.show();
    });
});
