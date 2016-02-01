import Foundation

@objc(CDVImageToVideo) class CDVImageToVideo : CDVPlugin {
  func sayHello(command: CDVInvokedUrlCommand) {
    let message = "Hello !";

    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsString: message);
    commandDelegate.sendPluginResult(pluginResult, callbackId:command.callbackId);
  }
}
