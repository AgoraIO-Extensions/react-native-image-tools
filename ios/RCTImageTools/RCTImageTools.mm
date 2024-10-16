//
//  ImageTools.mm
//
//  Created by Benjamin Lin on 2018/01/29.
//

#include "RCTImageTools.h"
#include "ImageHelpers.h"
#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTLog.h>

@implementation ImageTools {
    RCTBridge *_bridge;
}

RCT_EXPORT_MODULE();

- (instancetype)initWithBridge:(RCTBridge *)bridge {
    if (self = [super init]) {
        _bridge = bridge;
    }
    return self;
}

bool saveImage(NSString *fullPath, UIImage *image, NSString *format, float quality) {
    NSData *data = nil;
    if ([format isEqualToString:@"JPEG"]) {
        data = UIImageJPEGRepresentation(image, quality / 100.0);
    } else if ([format isEqualToString:@"PNG"]) {
        data = UIImagePNGRepresentation(image);
    }

    if (data == nil) {
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager createFileAtPath:fullPath contents:data attributes:nil];
}

NSString *generateFilePath(NSString *ext, NSString *outputPath) {
    NSString *directory;

    if ([outputPath length] == 0) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        directory = [paths firstObject];
    } else {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        directory = [documentsDirectory stringByAppendingPathComponent:outputPath];
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Error creating documents subdirectory: %@", error);
            @throw [NSException exceptionWithName:@"InvalidPathException" reason:[NSString stringWithFormat:@"Error creating documents subdirectory: %@", error] userInfo:nil];
        }
    }

    NSString *name = [[NSUUID UUID] UUIDString];
    NSString *fullName = [NSString stringWithFormat:@"%@.%@", name, ext];
    NSString *fullPath = [directory stringByAppendingPathComponent:fullName];

    return fullPath;
}

typedef unsigned char byte;

UIImage *bmp2Binary(UIImage *sourceImage, int threshold, UInt32 frontColor, UInt32 backColor) {
    CGContextRef ctx;
    CGImageRef imageRef = [sourceImage CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    byte *rawData = (byte *)malloc(height * width * 4);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);

    int byteIndex = 0;
    for (int ii = 0; ii < width * height; ++ii) {
        int grey = (rawData[byteIndex] + rawData[byteIndex + 1] + rawData[byteIndex + 2]);

        UInt32 *pixelPtr = (UInt32 *)(rawData + byteIndex);

        if (grey >= threshold * 3) {
            pixelPtr[0] = backColor;
        } else {
            pixelPtr[0] = frontColor;
        }

        byteIndex += 4;
    }

    ctx = CGBitmapContextCreate(rawData,
                                CGImageGetWidth(imageRef),
                                CGImageGetHeight(imageRef),
                                8,
                                bytesPerRow,
                                colorSpace,
                                kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);

    imageRef = CGBitmapContextCreateImage(ctx);
    UIImage *rawImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);

    CGContextRelease(ctx);
    free(rawData);

    return rawImage;
}

RCT_EXPORT_METHOD(createBinaryImage:(NSString *)path
                  type:(int)type
                  threshold:(int)threshold
                  format:(NSString *)format
                  quality:(float)quality
                  bOutputBase64:(BOOL)bOutputBase64
                  frontColorString:(NSString *)frontColorString
                  backColorString:(NSString *)backColorString
                  callback:(RCTResponseSenderBlock)callback) {

    NSString *extension = [format isEqualToString:@"PNG"] ? @"png" : @"jpg";
    NSString *fullPath;
    
    
    NSString* fullPath;

    NSString* fullPath;
    @try {
        fullPath = generateFilePath(extension, @"");
    } @catch (NSException *exception) {
        callback(@[@"Invalid output path.", @""]);
        return;
    }

    NSURL *imageUrl = [NSURL URLWithString:path];
    NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];

    if (!imageData) {
        callback(@[@"Can't retrieve the image from the path.", @""]);
        return;
    }

    UIImage *image = [UIImage imageWithData:imageData];
    if (image == nil) {
        callback(@[@"Can't create image from data.", @""]);
        return;
    }

    uint frontColor = 0;
    [[NSScanner scannerWithString:frontColorString] scanHexInt:&frontColor];
    uint backColor = 65535;
    [[NSScanner scannerWithString:backColorString] scanHexInt:&backColor];

    if (type == 1) {
        image = bmp2Binary(image, threshold, frontColor, backColor);
    }

    if (bOutputBase64) {
        NSData *dataImage = UIImagePNGRepresentation(image);
        NSString *base64 = [dataImage base64EncodedStringWithOptions:0];

            NSDictionary *response = @{@"base64": base64};
            NSDictionary *response = @{@"base64": base64};
            
        NSDictionary *response = @{@"base64": base64};
            
        callback(@[[NSNull null], response]);
    } else {
        if (!saveImage(fullPath, image, format, quality)) {
            callback(@[@"Can't save the image. Check your compression format and your output path", @""]);
            return;
        }
        NSURL *fileUrl = [[NSURL alloc] initFileURLWithPath:fullPath];
        NSString *fileName = fileUrl.lastPathComponent;
        NSError *attributesError = nil;
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:&attributesError];
        NSNumber *fileSize = fileAttributes == nil ? @(0) : [fileAttributes objectForKey:NSFileSize];
        NSDictionary *response = @{@"path": fullPath,
                                   @"uri": fileUrl.absoluteString,
                                   @"name": fileName,
                                   @"size": fileSize == nil ? @(0) : fileSize};

        callback(@[[NSNull null], response]);
    }
}

RCT_EXPORT_METHOD(GetImageRGBAs:(NSString *)path
                  callback:(RCTResponseSenderBlock)callback) {
    NSURL *imageUrl = [NSURL URLWithString:path];
    NSData *imageData = nil;

    if (imageUrl && imageUrl.scheme) {
        imageData = [NSData dataWithContentsOfURL:imageUrl];
    } else {
        imageData = [NSData dataWithContentsOfFile:path];
    }

    if (!imageData) {
        callback(@[@"Can't retrieve the image from the path.", @""]);
        return;
    }

    UIImage *image = [UIImage imageWithData:imageData];
    if (image == nil) {
        callback(@[@"Can't create image from data.", @""]);
        return;
    }

    CGImageRef cgImage = image.CGImage;
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);

    CGDataProviderRef dataProvider = CGImageGetDataProvider(cgImage);
    if (dataProvider == NULL) {
        callback(@[@"Can't get data provider from image.", @""]);
        return;
    }

    CFDataRef data = CGDataProviderCopyData(dataProvider);
    const UInt8 *rawData = CFDataGetBytePtr(data);

    NSMutableArray *rgbaArray = [NSMutableArray arrayWithCapacity:width * height * 4];

    for (NSUInteger ii = 0; ii < width * height; ++ii) {
        NSUInteger offset = ii * 4;
        uint8_t red = rawData[offset];
        uint8_t green = rawData[offset + 1];
        uint8_t blue = rawData[offset + 2];
        uint8_t alpha = rawData[offset + 3];

        [rgbaArray addObject:@(red)];
        [rgbaArray addObject:@(green)];
        [rgbaArray addObject:@(blue)];
        [rgbaArray addObject:@(alpha)];
    }

    CFRelease(data);

    NSNumber *imageWidth = @(image.size.width);
    NSNumber *imageHeight = @(image.size.height);
    NSDictionary *response = @{@"width": imageWidth,
                               @"height": imageHeight,
                               @"rgba": rgbaArray};

    callback(@[[NSNull null], response]);
}
@end
