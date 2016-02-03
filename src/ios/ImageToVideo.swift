import Foundation
import AVFoundation

@objc(CDVImageToVideo2) class CDVImageToVideo2 : CDVPlugin {
  func sayHello(command: CDVInvokedUrlCommand) {
	var frames:[String] = command.argumentAtIndex(0) as! [String];
	var frame:String = frames[0];
	// var data:NSData = NSData(base64EncodedString: base64String, options: NSDataBase64DecodingOptions.fromRaw(0)!)

	var data:NSData = NSData(base64EncodedString: frame)

	let message = "Hello !";
    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message);
    self.commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId);
  }

  func ConvertFramesToImages(frames: [String]) -> [UIImage] {
    print("Hello World! :-)");
	let images = [UIImage]();
	// let images = [UIImage](count: frames.count, repeatedValue: nil);

    for (index, frame) in frames.enumerate() {
      //var frame:String = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAQMAAAAlPW0iAAAABlBMVEUAAAD///+l2Z/dAAAAM0lEQVR4nGP4/5/h/1+G/58ZDrAz3D/McH8yw83NDDeNGe4Ug9C9zwz3gVLMDA/A6P9/AFGGFyjOXZtQAAAAAElFTkSuQmCC";
      var dataUrl = NSURL(string: frame);
      if dataUrl == nil {
	    NSLog("dataUrl for frame \(index) is nil");
		continue
	  }
	  var data = NSData(contentsOfURL: dataUrl!);
	  if data == nil {
	  	  NSLog("data for frame \(index) is nil");
	  }
	  let image : UIImage = UIImage(data: data);
	  images.append(image);
    }
	return images;
  }
}
