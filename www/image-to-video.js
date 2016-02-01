var exec = require('cordova/exec');

exports.sayHello = function(success, error, arg0) {
    exec(success, error, "ImageToVideo", "sayHello", [arg0]);
};
