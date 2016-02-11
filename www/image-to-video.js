var exec = require('cordova/exec');

exports.sayHello = function (success, error, params/*frames, width, height, fps*/) {
    /*var params = frames.slice();
    var options = {
        width: width,
        height: height,
        fps: fps
    };
    params.unshift(options);*/
    exec(success, error, "ImageToVideo", "sayHello", params);
};
