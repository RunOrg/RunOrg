/* Home controller */

Route.add(/^\/$/, function(R) {
    R["home/page"]();
    R.show();
});
