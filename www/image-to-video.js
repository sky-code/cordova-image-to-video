var exec = require('cordova/exec');

/**
 * convert array of frames into video
 * @param {function} successCallback - success callback function
 * @param {function} errorCallback - error callback function
 * @param {object} options - set of options
 * @param {string} options.filePath - path for result video file, can be relative or full path url
 * @param {number} options.width - video width
 * @param {number} options.height - video height
 * @param {number} options.fps - video fps
 * @param {string[]} frames - array of base64 encoded images
 */
exports.convert = function (successCallback, errorCallback, options, frames) {
    var args = Array.from(frames);
    args.unshift(options);
    exec(successCallback, errorCallback, "ImageToVideo", "convert", args);
};

/**
 * save video at filePath to shared Photo Library
 * @param {function} successCallback - success callback function
 * @param {function} errorCallback - error callback function
 * @param {string} filePath - path for video file
 */
exports.saveVideoToPhotoLibrary = function(successCallback, errorCallback, filePath) {
    var args = {
        filePath: filePath
    };
    exec(successCallback, errorCallback, "ImageToVideo", "saveVideoToPhotoLibrary", args);
};
