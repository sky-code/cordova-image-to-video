import Foundation
import AVFoundation
import Photos
// swift 3

@objc(CDVMediaKit)
class CDVMediaKit: CDVPlugin {
    
    func saveVideoToPhotoLibrary(_ command: CDVInvokedUrlCommand) {
        NSLog("CDVMediaKit#saveVideoToPhotoLibrary()")
        let filePath = String(command.argument(at: 0) as! NSString)
        NSLog(filePath)
        
        if filePath.isEmpty{
            NSLog("error filePath is empty")
        }
        
        var fileURL = URL(string: filePath)!
        
        if !fileURL.isFileURL {
            fileURL = URL(fileURLWithPath: filePath)
        }
        
        var localIdentifier:String? = nil
        PHPhotoLibrary.shared().performChanges({ () -> Void in
            
            let createAssetRequest: PHAssetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)!
            let placeholder = createAssetRequest.placeholderForCreatedAsset
            localIdentifier = placeholder?.localIdentifier
        }, completionHandler: { (success, error) -> Void in
            if success {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: localIdentifier);
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
            else {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error?.localizedDescription);
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        })
        
    }
    
    func convert(_ command: CDVInvokedUrlCommand) {
        NSLog("CDVMediaKit#convert()")
        let options = command.argument(at: 0) as! NSDictionary
        let filePath = String(options["filePath"] as! NSString)
        let width = Int(options["width"] as! NSNumber)
        let height = Int(options["height"] as! NSNumber)
        let fps = Int(options["fps"] as! NSNumber)

        var frames = [String]()
        for i in 1 ... (command.arguments.count - 1) {
            let frame = command.argument(at: UInt(i)) as! String
            frames.append(frame)
        }
        

        var outputFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("instagram.mp4")
        
        if !filePath.isEmpty {
            outputFileURL = URL(string: filePath)!
            if ((outputFileURL.isFileURL) == false){
                outputFileURL = URL(fileURLWithPath: filePath)
            }
        }
        
		self.commandDelegate!.run(inBackground: {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputFileURL.path) {
            do {
                try fileManager.removeItem(atPath: outputFileURL.path)
            } catch let error as NSError {
                fatalError("Unable to delete file: \(error.localizedDescription) : \(#function).")
            }
        }

        self.startConverting(outputFileURL, frames: frames, width: width, height: height, frameRate: fps);
        NSLog("outputFileURL: \(outputFileURL)")

        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: outputFileURL.path);
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
		})
    }

    fileprivate func startConverting(_ outputFileURL: URL, frames: [String], width: Int, height: Int, frameRate: Int) {
        // prepare complete

        let videoWriter: AVAssetWriter!
        do {
            videoWriter = try AVAssetWriter(outputURL: outputFileURL, fileType: AVFileTypeMPEG4)
        } catch let error as NSError {
            NSLog("Create AVAssetWriter error: \(error.localizedDescription)");
            videoWriter = nil
        }

        let assetWriterInput = self.createAVAssetWriterInput(width, height: height);


        let adaptorAttributes: [String:AnyObject] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB) as AnyObject,
                                                     kCVPixelBufferWidthKey as String: Float(width) as AnyObject,
                                                     kCVPixelBufferHeightKey as String: Float(height) as AnyObject]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput,
                sourcePixelBufferAttributes: adaptorAttributes)

        videoWriter.add(assetWriterInput)

        videoWriter.startWriting()

        videoWriter.startSession(atSourceTime: kCMTimeZero)

        // var buffer: CVPixelBufferRef

        for (index, frame) in frames.enumerated() {
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

        videoWriter.finishWriting {
            () -> Void in

            switch videoWriter.status {

            case AVAssetWriterStatus.failed:

                NSLog("Error: \(videoWriter.error)")

            default:

                NSLog("Complete with status \(videoWriter.status)")

                    // let path = self.fileUrl(fileName).path!

                    // let content = NSFileManager.defaultManager().contentsAtPath(path)

                    // println("Video: \(path) \(content?.length)")

            }

        }
    }

    fileprivate func assetWriterInputAppendUIImage(_ pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, image: UIImage, presentationTime: CMTime) -> Bool {
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
            appendSucceeded = pixelBufferAdaptor.append(managedPixelBuffer,
                    withPresentationTime: presentationTime)
        }

        return appendSucceeded
    }

    fileprivate func waitForAVAssetWriterInput(_ assetWriterInput: AVAssetWriterInput, retryingAttempt: Int) -> Bool {
        if (assetWriterInput.isReadyForMoreMediaData) {
            return true;
        } else {
            if retryingAttempt > 30 {
                NSLog("Error: Adaptor is not ready, at 30 retrying attempts")
                return false;
            }
            NSLog("Error: Adaptor is not ready, retryingAttempt: \(retryingAttempt)")
            Thread.sleep(forTimeInterval: 0.2)
            return self.waitForAVAssetWriterInput(assetWriterInput, retryingAttempt: (retryingAttempt + 1))
        }
    }

    fileprivate func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGContext(
        data: pixelData,
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerComponent: 8,
                bytesPerRow: Int(4 * image.size.width), // or use CVPixelBufferGetBytesPerRow(pixelBuffer)
                space: rgbColorSpace,
                bitmapInfo: bitmapInfo.rawValue
        )

        context?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))

        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }

    fileprivate func createAVAssetWriterInput(_ width: Int, height: Int) -> AVAssetWriterInput {
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

                             AVVideoHeightKey: height] as [String : Any]

        let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings as? [String:AnyObject])
        assetWriterInput.expectsMediaDataInRealTime = true
        return assetWriterInput
    }

    fileprivate func UIImageFromBase64DataURL(_ DataURL: String) -> UIImage {
        // let DataURL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAQMAAAAlPW0iAAAABlBMVEUAAAD///+l2Z/dAAAAM0lEQVR4nGP4/5/h/1+G/58ZDrAz3D/McH8yw83NDDeNGe4Ug9C9zwz3gVLMDA/A6P9/AFGGFyjOXZtQAAAAAElFTkSuQmCC";
        let dataNSURL = URL(string: DataURL);
        if dataNSURL == nil {
            NSLog("unable create NSURL from DataURL");
        }
        let dataNSData = try? Data(contentsOf: dataNSURL!);
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
