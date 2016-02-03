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

	self.startConverting(frames, width: width, height: height, frameRate: fps);

	let message = "Hello !";
    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message);
    self.commandDelegate!.sendPluginResult(pluginResult, callbackId:command.callbackId);
  }

  func startConverting(frames: [String], width: Int, height: Int, frameRate: Int){
    var maybeError: NSError?
    let fileManager = NSFileManager.defaultManager()
    let docDirectory = (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents")

    let videoOutputPath = (docDirectory as NSString).stringByAppendingPathComponent("instagram.mp4")

	// prepare complete 

  	let videoWriter: AVAssetWriter!
    do {
      videoWriter = try AVAssetWriter(

              URL: NSURL(fileURLWithPath: videoOutputPath),

              fileType: AVFileTypeMPEG4)
    } catch var error as NSError {
      maybeError = error
      videoWriter = nil
    }

	var images = self.UIImageArrayFromBase64Frames(frames);
	var assetWriterInput = self.createAVAssetWriterInput(width, height: height);


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

	  buffer = self.pixelBufferFromCGImage(img!, frameSize: frameSize)

	  

	  let fps: Int32 = Int32(frameRate)

	  var frameTime = CMTimeMake(1, fps)

	  var lastTime = CMTimeMake(Int64(index), fps)

	  var presentTime = CMTimeAdd(lastTime, frameTime)

	  

	  self.waitForAVAssetWriterInput(adaptor.assetWriterInput);



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



    var pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.alloc(1)



    let buffered:CVReturn = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), OSType(kCVPixelFormatType_32ARGB), options, pixelBufferPointer)



    let lockBaseAddress = CVPixelBufferLockBaseAddress(pixelBufferPointer.memory!, 0)

    var pixelData:UnsafeMutablePointer<(Void)> = CVPixelBufferGetBaseAddress(pixelBufferPointer.memory!)



    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.NoneSkipFirst.rawValue)

    let space:CGColorSpace = CGColorSpaceCreateDeviceRGB()!



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
