import Foundation
import AVFoundation

@objc(CDVImageToVideo) class CDVImageToVideo : CDVPlugin {
  func sayHello(command: CDVInvokedUrlCommand) {
	let options = command.argumentAtIndex(0) as! NSDictionary
	let width = Int(options.valueForKey("width") as! Int64)
	let height = Int(options.valueForKey("height") as! Int64)
	let fps = Int(options.valueForKey("fps") as! Int64)

	let frames = [String]()
	for i in 1...command.count{
		let frame = command.argumentAtIndex(i) as! String
		frames.append(frame)
	}

	let outputFileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("instagram.mp4")
	
	let fileManager = NSFileManager.defaultManager()
	if fileManager.fileExistsAtPath(outputFileURL.path!) {
      do {
        try fileManager.removeItemAtPath(outputFileURL.path!)
      }catch var error as NSError{
        fatalError("Unable to delete file: \(error.localizedDescription) : \(__FUNCTION__).")
      }
    }

	self.startConverting(outputFileURL, frames: frames, width: width, height: height, frameRate: fps);

	let message = "Hello !";
    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message);
    self.commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId);
  }

  func startConverting(outputFileURL: NSURL, frames: [String], width: Int, height: Int, frameRate: Int){
	// prepare complete 

  	let videoWriter: AVAssetWriter!
    do {
      videoWriter = try AVAssetWriter(URL: outputFileURL, fileType: AVFileTypeMPEG4)
    } catch var error as NSError {
      maybeError = error
	  NSLog("Create AVAssetWriter error: \(error.localizedDescription)");
      videoWriter = nil
    }

	var assetWriterInput = self.createAVAssetWriterInput(width, height: height);


	var adaptorAttributes = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,
                                 kCVPixelBufferWidthKey as String:width,
                                 kCVPixelBufferHeightKey as String:height]

	var adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput,
                                 sourcePixelBufferAttributes: adaptorAttributes)

    videoWriter.addInput(assetWriterInput)

    videoWriter.startWriting()

    videoWriter.startSessionAtSourceTime(kCMTimeZero)

	// var buffer: CVPixelBufferRef

	for (index, frame) in frames.enumerate() {
	  let fps: Int32 = Int32(frameRate)

	  let frameTime = CMTimeMake(1, fps)

	  let lastTime = CMTimeMake(Int64(index), fps)

	  let presentTime = CMTimeAdd(lastTime, frameTime)
	  
	  let image = self.UIImageFromBase64DataURL(frame)

	  if !self.waitForAVAssetWriterInput(adaptor.assetWriterInput, 0){
	  	  NSLog("assetWriterInput.readyForMoreMediaData always false")
	  }

	  let CGImg = image.CGImage
	  let frameSize = CGSizeMake(CGFloat(CGImageGetWidth(CGImg)), CGFloat(CGImageGetHeight(CGImg)))

	  let buffer : CVPixelBufferRef = self.pixelBufferFromCGImage(CGImg!, frameSize: frameSize)

	  let pixelBufferAppend = adaptor.appendPixelBuffer(buffer, withPresentationTime: presentTime)

	  if(!pixelBufferAppend){

	  	  NSLog("appendPixelBuffer \(index) error");

	  }

	}
	assetWriterInput.markAsFinished()

	videoWriter.finishWritingWithCompletionHandler { () -> Void in

        switch videoWriter.status {

        case AVAssetWriterStatus.Failed:

            NSLog("Error: \(videoWriter.error)")

        default:

            NSLog("Complete with status \(videoWriter.status)")

            // let path = self.fileUrl(fileName).path!

            // let content = NSFileManager.defaultManager().contentsAtPath(path)

            // println("Video: \(path) \(content?.length)")

        }

    }

  

  }

  func waitForAVAssetWriterInput(assetWriterInput: AVAssetWriterInput, retryingAttempt: Int) -> Bool {
  	  if(assetWriterInput.readyForMoreMediaData){
	  	  return true;
	  }else{
	      retryingAttempt = retryingAttempt + 1
		  if retryingAttempt > 30 {
		  	  NSLog("Error: Adaptor is not ready, at 30 retrying attempts")
			  return false;
		  }
	      NSLog("Error: Adaptor is not ready, retryingAttempt: \(retryingAttempt)")
	      NSThread.sleepForTimeInterval(0.2)
		  return self.waitForAVAssetWriterInput(assetWriterInput, retryingAttempt)
	  }
  }

  func pixelBufferFromCGImage (img: CGImageRef, frameSize: CGSize) -> CVPixelBufferRef {
    let options = [

        "kCVPixelBufferCGImageCompatibilityKey": true,

        "kCVPixelBufferCGBitmapContextCompatibilityKey": true

    ]

    var pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.alloc(1)

    let buffered:CVReturn = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), OSType(kCVPixelFormatType_32ARGB), options, pixelBufferPointer)

    let lockBaseAddress = CVPixelBufferLockBaseAddress(pixelBufferPointer.memory!, 0)

    var pixelData:UnsafeMutablePointer<(Void)> = CVPixelBufferGetBaseAddress(pixelBufferPointer.memory!)

    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)

    let space:CGColorSpace = CGColorSpaceCreateDeviceRGB()!

	var altCVPixelBufferGetBytesPerRow = 4*CGImageGetWidth(img);
	var recommend = CVPixelBufferGetBytesPerRow(pixelBufferPointer.memory!);
    var context:CGContextRef = CGBitmapContextCreate(pixelData, Int(frameSize.width), Int(frameSize.height), 8, CVPixelBufferGetBytesPerRow(pixelBufferPointer.memory!), space, CGImageAlphaInfo.PremultipliedFirst.rawValue)!

    CGContextDrawImage(context, CGRectMake(0, 0, frameSize.width, frameSize.height), img)

    CVPixelBufferUnlockBaseAddress(pixelBufferPointer.memory!, 0)

    return pixelBufferPointer.memory!
}

  func createAVAssetWriterInput(width: Int, height: Int) -> AVAssetWriterInput {
    let videoCleanApertureSettings = [AVVideoCleanApertureWidthKey:width,

                                 AVVideoCleanApertureHeightKey:height,

                       AVVideoCleanApertureHorizontalOffsetKey:0,

                         AVVideoCleanApertureVerticalOffsetKey:0]

	

	let videoAspectRatioSettings = [AVVideoPixelAspectRatioHorizontalSpacingKey:1,

                                  AVVideoPixelAspectRatioVerticalSpacingKey:1]

	

	let codecSettings = [AVVideoCleanApertureKey:videoCleanApertureSettings,

                  AVVideoPixelAspectRatioKey:videoAspectRatioSettings]

	

	let videoSettings = [AVVideoCodecKey:AVVideoCodecH264,

     AVVideoCompressionPropertiesKey:codecSettings,

                     AVVideoWidthKey:width,

                    AVVideoHeightKey:height]

	let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings as? [String:AnyObject])
	assetWriterInput.expectsMediaDataInRealTime = true
	return assetWriterInput
  }

  func UIImageFromBase64DataURL(DataURL: String) -> UIImage {
    NSLog("exec: UIImageFromBase64DataURL");

    // let DataURL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAQMAAAAlPW0iAAAABlBMVEUAAAD///+l2Z/dAAAAM0lEQVR4nGP4/5/h/1+G/58ZDrAz3D/McH8yw83NDDeNGe4Ug9C9zwz3gVLMDA/A6P9/AFGGFyjOXZtQAAAAAElFTkSuQmCC";
    let dataNSURL = NSURL(string: DataURL);
    if dataNSURL == nil {
	NSLog("unable create NSURL from DataURL");
	}
	let dataNSData = NSData(contentsOfURL: dataNSURL!);
	if dataNSData == nil {
	  	NSLog("unable create NSData from dataNSURL");
	}
	let image = UIImage(data: dataNSData!);
	if image == nil {
	  	NSLog("unable create UIImage from dataNSData");
	}
	return image!;
  }

  func UIImageArrayFromBase64Frames(frames: [String]) -> [UIImage] {
    NSLog("exec: UIImageArrayFromBase64Frames");
	var images = [UIImage]();
	// var images = [UIImage](count: frames.count, repeatedValue: nil);

    for (index, frame) in frames.enumerate() {
      // var frame:String = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAQMAAAAlPW0iAAAABlBMVEUAAAD///+l2Z/dAAAAM0lEQVR4nGP4/5/h/1+G/58ZDrAz3D/McH8yw83NDDeNGe4Ug9C9zwz3gVLMDA/A6P9/AFGGFyjOXZtQAAAAAElFTkSuQmCC";
      let dataUrl = NSURL(string: frame);
      if dataUrl == nil {
	    NSLog("dataUrl for frame \(index) is nil");
		continue
	  }
	  let data = NSData(contentsOfURL: dataUrl!);
	  if data == nil {
	  	  NSLog("data for frame \(index) is nil");
		  continue
	  }
	  let image = UIImage(data: data!);
	  if image == nil {
	  	  NSLog("image for frame \(index) is nil");
		  continue;
	  }
	  images.append(image!);
    }
	return images;
  }
}
