/* Home controller */

Route.add(/^\/admin$/, function(R) {
    R["home/page"]();
    R.show();
});
