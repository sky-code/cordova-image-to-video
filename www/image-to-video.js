var exec = require('cordova/exec');

exports.sayHello = function (success, error, frames, width, height, frameRate) {
    exec(success, error, "ImageToVideo", "sayHello", [frames, width, height, frameRate]);
};
