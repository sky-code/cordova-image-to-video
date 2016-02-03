import Foundation
import AVFoundation

@objc(CDVImageToVideo2) class CDVImageToVideo2 : CDVPlugin {
  func sayHello(command: CDVInvokedUrlCommand) {
	let frames:[String] = command.argumentAtIndex(0) as! [String];
	let width = command.argumentAtIndex(1) as! Int
	let height = command.argumentAtIndex(2) as! Int
	let frameRate = command.argumentAtIndex(3) as! Int

	self.startConverting(frames: frames, width: width, height: height, frameRate: frameRate);

	let message = "Hello !";
    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message);
    self.commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId);
  }

  func startConverting(frames: [String], width: Int, height: Int, frameRate: Int){
    var maybeError: NSError?
    let fileManager = NSFileManager.defaultManager()
    let docDirectory = NSHomeDirectory().stringByAppendingPathComponent("Documents")
    let videoOutputPath = docDirectory.stringByAppendingPathComponent("instagram.mp4")

    if (!fileManager.removeItemAtPath(videoOutputPath, error: &maybeError)) {
        NSLog("Umable to delete file: %@", maybeError!.localizedDescription)
    }
	// prepare complete 

	let videoWriter = AVAssetWriter(
        URL: NSURL(fileURLWithPath: videoOutputPath),
        fileType: AVFileTypeMPEG4,
        error: &maybeError
    )

	var images = self.UIImageArrayFromBase64Frames(frames);
	var assetWriterInput = self.createAVAssetWriterInput(width, height);

	// var adaptorAttributes = [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32ARGB,
    //                             kCVPixelBufferWidthKey:width,
    //                             kCVPixelBufferHeightKey:height]

	var adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)

    videoWriter.addInput(assetWriterInput)
    videoWriter.startWriting()
    videoWriter.startSessionAtSourceTime(kCMTimeZero)

	var buffer: CVPixelBufferRef

	for (index, image) in images.enumerate() {
	  var img = image.CGImage;
	  let frameSize = CGSizeMake(CGFloat(CGImageGetWidth(img)), CGFloat(CGImageGetHeight(img)))
	  buffer = self.pixelBufferFromCGImage(img: img, frameSize: frameSize)
	  
	  var frameTime = CMTimeMake(1, frameRate)
	  var lastTime = CMTimeMake(index, frameRate)
	  var presentTime = CMTimeAdd(lastTime, frameTime)
	  
	  self.waitForAVAssetWriterInput(adaptor.assetWriterInput);

	  let pixelBufferAppend = adaptor.appendPixelBuffer(buffer, withPresentationTime: presentTime)
	  if(!pixelBufferAppend){
	  	  NSLog("appendPixelBuffer \(index) error");
	  }

	  if(buffer) {
	      CVBufferRelease(buffer);
	  }
	}
	assetWriterInput.markAsFinished()
	assetWriterInput.finishWritingWithCompletionHandler { () -> Void in
        switch assetWriterInput.status {
        case AVAssetWriterStatus.Failed:
            NSLog("Error: \(assetWriterInput.error)")
        default:
            NSLog("Complete with status \(assetWriterInput.status)")
            // let path = self.fileUrl(fileName).path!
            // let content = NSFileManager.defaultManager().contentsAtPath(path)
            // println("Video: \(path) \(content?.length)")
        }
    }
  
  }

  func waitForAVAssetWriterInput(assetWriterInput: AVAssetWriterInput){
  	  if(assetWriterInput.readyForMoreMediaData){
	  	  return;
	  }else{
	      NSLog("Error: Adaptor is not ready");
	      NSThread.sleepForTimeInterval(0.2);
		  self.waitForAVAssetWriterInput(assetWriterInput);
	  }
  }

  func pixelBufferFromCGImage (img: CGImageRef, frameSize: CGSize) -> CVPixelBufferRef {

    let options = [
        "kCVPixelBufferCGImageCompatibilityKey": true,
        "kCVPixelBufferCGBitmapContextCompatibilityKey": true
    ]

    var pixelBufferPointer = UnsafeMutablePointer<Unmanaged<CVPixelBuffer>?>.alloc(1)

    let buffered:CVReturn = CVPixelBufferCreate(kCFAllocatorDefault, UInt(frameSize.width), UInt(frameSize.height), OSType(kCVPixelFormatType_32ARGB), options, pixelBufferPointer)

    let lockBaseAddress = CVPixelBufferLockBaseAddress(pixelBufferPointer.memory?.takeUnretainedValue(), 0)
    var pixelData:UnsafeMutablePointer<(Void)> = CVPixelBufferGetBaseAddress(pixelBufferPointer.memory?.takeUnretainedValue())

    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)
    let space:CGColorSpace = CGColorSpaceCreateDeviceRGB()

    var context:CGContextRef = CGBitmapContextCreate(pixelData, UInt(frameSize.width), UInt(frameSize.height), 8, CVPixelBufferGetBytesPerRow(pixelBufferPointer.memory?.takeUnretainedValue()), space, bitmapInfo)

    CGContextDrawImage(context, CGRectMake(0, 0, frameSize.width, frameSize.height), img)

    CVPixelBufferUnlockBaseAddress(pixelBufferPointer.memory?.takeUnretainedValue(), 0)

    return pixelBufferPointer.memory!.takeUnretainedValue()
}

  func createAVAssetWriterInput(width: Int, height: Int){
    var videoCleanApertureSettings = [AVVideoCleanApertureWidthKey:width,
                                 AVVideoCleanApertureHeightKey:height,
                       AVVideoCleanApertureHorizontalOffsetKey:0,
                         AVVideoCleanApertureVerticalOffsetKey:0]
	
	var videoAspectRatioSettings = [AVVideoPixelAspectRatioHorizontalSpacingKey:1,
                                  AVVideoPixelAspectRatioVerticalSpacingKey:1]
	
	var codecSettings = [AVVideoCleanApertureKey:videoCleanApertureSettings,
                  AVVideoPixelAspectRatioKey:videoAspectRatioSettings]
	
	var videoSettings = [AVVideoCodecKey:AVVideoCodecH264,
     AVVideoCompressionPropertiesKey:codecSettings,
                     AVVideoWidthKey:width,
                    AVVideoHeightKey:height]
	var assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
	assetWriterInput.expectsMediaDataInRealTime = true
	return assetWriterInput
  }

  func UIImageArrayFromBase64Frames(frames: [String]) -> [UIImage] {
    NSLog("exec: UIImageArrayFromBase64Frames");
	var images = [UIImage]();
	// var images = [UIImage](count: frames.count, repeatedValue: nil);

    for (index, frame) in frames.enumerate() {
      // var frame:String = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAQMAAAAlPW0iAAAABlBMVEUAAAD///+l2Z/dAAAAM0lEQVR4nGP4/5/h/1+G/58ZDrAz3D/McH8yw83NDDeNGe4Ug9C9zwz3gVLMDA/A6P9/AFGGFyjOXZtQAAAAAElFTkSuQmCC";
      var dataUrl = NSURL(string: frame);
      if dataUrl == nil {
	    NSLog("dataUrl for frame \(index) is nil");
		continue
	  }
	  var data = NSData(contentsOfURL: dataUrl!);
	  if data == nil {
	  	  NSLog("data for frame \(index) is nil");
		  continue
	  }
	  var image : UIImage = UIImage(data: data);
	  if image == nil {
	  	  NSLog("image for frame \(index) is nil");
		  continue;
	  }
	  images.append(image!);
    }
	return images;
  }
}
