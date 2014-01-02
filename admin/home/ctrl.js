/* Home controller */

Route.add(/^\/admin$/, function(R) {
    API.GET("/db/all",{},function(data) {
	R["home/page"](data);
	R.show();
    });
});
