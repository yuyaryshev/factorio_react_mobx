// Article https://pusher.com/tutorials/web-scraper-node

let fs = require('fs');
let request = require('request');
request('https://lua-api.factorio.com/latest/LuaGuiElement.html', function (error, response, body) {
	fs.writeFileSync("response.html", body, "utf-8");
	console.log('error:', error); // Print the error if one occurred
	console.log('statusCode:', response && response.statusCode); // Print the response status code if a response was received
});
