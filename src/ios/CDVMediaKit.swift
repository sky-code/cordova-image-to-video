import Foundation
import AVFoundation
import Photos

@objc(CDVMediaKit)
class CDVMediaKit: CDVPlugin {
    
    func saveVideoToPhotoLibrary(command: CDVInvokedUrlCommand) {
        NSLog("CDVMediaKit#saveVideoToPhotoLibrary()")
        let filePath = String(command.argumentAtIndex(0) as! NSString)
        NSLog(filePath)
        
        if filePath.isEmpty{
            NSLog("error filePath is empty")
        }
        
        var fileURL = NSURL(string: filePath)!
        
        if !fileURL.fileURL {
            fileURL = NSURL(fileURLWithPath: filePath)
        }
        
        var localIdentifier:String? = nil
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            
            let createAssetRequest: PHAssetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(fileURL)!
            let placeholder = createAssetRequest.placeholderForCreatedAsset
            localIdentifier = placeholder?.localIdentifier
        }, completionHandler: { (success, error) -> Void in
            if success {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: localIdentifier);
                self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId);
            }
            else {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAsString: error?.localizedDescription);
                self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId);
            }
        })
        
    }
    
    func convert(command: CDVInvokedUrlCommand) {
        NSLog("CDVMediaKit#convert()")
        let options = command.argumentAtIndex(0) as! NSDictionary
        let filePath = String(options["filePath"] as! NSString)
        let width = Int(options["width"] as! NSNumber)
        let height = Int(options["height"] as! NSNumber)
        let fps = Int(options["fps"] as! NSNumber)

        var frames = [String]()
        for i in 1 ... (command.arguments.count - 1) {
            let frame = command.argumentAtIndex(UInt(i)) as! String
            frames.append(frame)
        }
        

        var outputFileURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
            .URLByAppendingPathComponent("instagram.mp4")
        
        if !filePath.isEmpty {
            outputFileURL = NSURL(string: filePath)!
            if ((outputFileURL.fileURL) == false){
                outputFileURL = NSURL(fileURLWithPath: filePath)
            }
        }
        
		self.commandDelegate!.runInBackground({
        let fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(outputFileURL.path!) {
            do {
                try fileManager.removeItemAtPath(outputFileURL.path!)
            } catch let error as NSError {
                fatalError("Unable to delete file: \(error.localizedDescription) : \(#function).")
            }
        }

        self.startConverting(outputFileURL, frames: frames, width: width, height: height, frameRate: fps);
        NSLog("outputFileURL: \(outputFileURL)")

        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: outputFileURL.path);
        self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId);
		})
    }

    private func startConverting(outputFileURL: NSURL, frames: [String], width: Int, height: Int, frameRate: Int) {
        // prepare complete

        let videoWriter: AVAssetWriter!
        do {
            videoWriter = try AVAssetWriter(URL: outputFileURL, fileType: AVFileTypeMPEG4)
        } catch let error as NSError {
            NSLog("Create AVAssetWriter error: \(error.localizedDescription)");
            videoWriter = nil
        }

        let assetWriterInput = self.createAVAssetWriterInput(width, height: height);


        let adaptorAttributes: [String:AnyObject] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                                                     kCVPixelBufferWidthKey as String: Float(width),
                                                     kCVPixelBufferHeightKey as String: Float(height)]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput,
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

            if !self.waitForAVAssetWriterInput(adaptor.assetWriterInput, retryingAttempt: 1) {
                NSLog("assetWriterInput.readyForMoreMediaData always false")
            }

            let pixelBufferAppend = self.assetWriterInputAppendUIImage(adaptor, image: image, presentationTime: presentTime)

            if !pixelBufferAppend {
                NSLog("appendPixelBuffer \(index) error");
            }

        }
        assetWriterInput.markAsFinished()

        videoWriter.finishWritingWithCompletionHandler {
            () -> Void in

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

    private func assetWriterInputAppendUIImage(pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, image: UIImage, presentationTime: CMTime) -> Bool {
        var appendSucceeded = true
        autoreleasepool {
            // var pixelBuffer: Unmanaged<CVPixelBuffer>?
            var pixelBuffer: CVPixelBuffer?

            let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
                    pixelBufferAdaptor.pixelBufferPool!,
                    &pixelBuffer
            )

            if status != kCVReturnSuccess {
                NSLog("error: Failed to allocate pixel buffer from pool")
            }
            let managedPixelBuffer = pixelBuffer!
            self.fillPixelBufferFromImage(image, pixelBuffer: managedPixelBuffer)
            appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(managedPixelBuffer,
                    withPresentationTime: presentationTime)
        }

        return appendSucceeded
    }

    private func waitForAVAssetWriterInput(assetWriterInput: AVAssetWriterInput, retryingAttempt: Int) -> Bool {
        if (assetWriterInput.readyForMoreMediaData) {
            return true;
        } else {
            if retryingAttempt > 30 {
                NSLog("Error: Adaptor is not ready, at 30 retrying attempts")
                return false;
            }
            NSLog("Error: Adaptor is not ready, retryingAttempt: \(retryingAttempt)")
            NSThread.sleepForTimeInterval(0.2)
            return self.waitForAVAssetWriterInput(assetWriterInput, retryingAttempt: (retryingAttempt + 1))
        }
    }

    private func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBufferRef) {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0)

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGBitmapContextCreate(
        pixelData,
                Int(image.size.width),
                Int(image.size.height),
                8,
                Int(4 * image.size.width), // or use CVPixelBufferGetBytesPerRow(pixelBuffer)
                rgbColorSpace,
                bitmapInfo.rawValue
        )

        CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage)

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
    }

    private func createAVAssetWriterInput(width: Int, height: Int) -> AVAssetWriterInput {
        let videoCleanApertureSettings = [AVVideoCleanApertureWidthKey: width,

                                          AVVideoCleanApertureHeightKey: height,

                                          AVVideoCleanApertureHorizontalOffsetKey: 0,

                                          AVVideoCleanApertureVerticalOffsetKey: 0]



        let videoAspectRatioSettings = [AVVideoPixelAspectRatioHorizontalSpacingKey: 1,

                                        AVVideoPixelAspectRatioVerticalSpacingKey: 1]



        let codecSettings = [AVVideoCleanApertureKey: videoCleanApertureSettings,

                             AVVideoPixelAspectRatioKey: videoAspectRatioSettings]



        let videoSettings = [AVVideoCodecKey: AVVideoCodecH264,

                             AVVideoCompressionPropertiesKey: codecSettings,

                             AVVideoWidthKey: width,

                             AVVideoHeightKey: height]

        let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings as? [String:AnyObject])
        assetWriterInput.expectsMediaDataInRealTime = true
        return assetWriterInput
    }

    private func UIImageFromBase64DataURL(DataURL: String) -> UIImage {
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

    // lifecycle logs

    // This is just called if <param name="onload" value="true" /> in plugin.xml.
    override func pluginInitialize() {
        NSLog("CDVMediaKit#pluginInitialize()")
    }


    override func onReset() {
        NSLog("CDVMediaKit#onReset() | doing nothing")
    }


    override func onAppTerminate() {
        NSLog("CDVMediaKit#onAppTerminate() | doing nothing")
    }

}
