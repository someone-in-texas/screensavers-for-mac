import AppKit
import AVFoundation
import QuartzCore

// Offline, real-time motion evidence: no pre-roll, time compression or camera reframing.
let app=NSApplication.shared
app.setActivationPolicy(.prohibited)
let args=CommandLine.arguments
func option(_ key:String,_ fallback:String)->String {args.firstIndex(of:key).flatMap{$0+1<args.count ? args[$0+1]:nil} ?? fallback}
guard let duration=Double(option("--duration","180")),duration.isFinite,duration>0,duration<=3600,
      let fps=Int32(option("--fps","15")),(1...60).contains(fps) else {
    fatalError("Use --duration 1...3600 and --fps 1...60")
}
let selected=option("--saver","both")
precondition(["both","research","strawberry"].contains(selected),"Use --saver research, strawberry or both")
let folder=URL(fileURLWithPath:option("--output","build/print-motion"))
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
let size=CGSize(width:960,height:600),date=Date(timeIntervalSince1970:0)
for research in [true,false] {
    let name=research ? "research":"strawberry"
    if selected != "both" && selected != name {continue}
    let scene=FineArtScene(research:research,seed:42),root=CALayer()
    root.bounds=CGRect(origin:.zero,size:size);root.contentsScale=1
    scene.apply(SaverSettings());scene.start()
    let suffix=duration==180 ? "3-minutes":"\(Int(duration))-seconds"
    let url=folder.appendingPathComponent("\(name)-\(suffix).mp4")
    if FileManager.default.fileExists(atPath:url.path){try FileManager.default.removeItem(at:url)}
    let writer=try AVAssetWriter(outputURL:url,fileType:.mp4)
    let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:Int(size.width),AVVideoHeightKey:Int(size.height),AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:4_000_000,AVVideoExpectedSourceFrameRateKey:fps,AVVideoMaxKeyFrameIntervalKey:fps]])
    let attributes:[String:Any]=[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:Int(size.width),kCVPixelBufferHeightKey as String:Int(size.height),kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true]
    let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:attributes)
    writer.add(input);precondition(writer.startWriting());writer.startSession(atSourceTime:.zero)
    for frame in 0..<Int(duration*Double(fps)) {
        autoreleasepool {
            while !input.isReadyForMoreMediaData {RunLoop.current.run(until:Date().addingTimeInterval(0.001))}
            let time=Double(frame)/Double(fps)
            _=scene.updateLayer(root,size:size,time:time,date:date)
            var buffer:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&buffer)
            let pixels=buffer!;CVPixelBufferLockBaseAddress(pixels,[])
            let c=CGContext(data:CVPixelBufferGetBaseAddress(pixels),width:Int(size.width),height:Int(size.height),bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixels),space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
            root.render(in:c)
            if frame%Int(fps*5)==0 {
                let rep=NSBitmapImageRep(cgImage:c.makeImage()!)
                try! rep.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("\(name)-\(Int(time)).png"))
            }
            CVPixelBufferUnlockBaseAddress(pixels,[])
            precondition(adaptor.append(pixels,withPresentationTime:CMTime(value:Int64(frame),timescale:fps)))
        }
    }
    input.markAsFinished();writer.finishWriting{}
    while writer.status == .writing {RunLoop.current.run(until:Date().addingTimeInterval(0.01))}
    precondition(writer.status == .completed,String(describing:writer.error))
    print("\(name): \(duration)s, \(fps) FPS, \(scene.renewalCount) connected branch renewals")
    scene.stop()
}
