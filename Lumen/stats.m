// Copyright (c) 2015-2019 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "Constants.h"

// get serial number
NSString *get_uuid(void);

// get an anonymous identifier based on the UUID
//
// returns SHA256(UUID + salt)
// given that the UUID is pretty high entropy, this should be reasonable
// as a unique anonymous identifier
NSString *get_anonymous_identifier(void);

NSString *data_to_hex(NSData *data);

void send_stats(unsigned int retries) {
    // currently, all we send is an anonymous unique identifier
    // so it's possible to count roughly how many people use Lumen
    // and how frequently they use it

#ifdef DEBUG
    return;
#endif

    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    NSDictionary *payload = @{@"id": get_anonymous_identifier(), @"version": version};

    NSDictionary *data = @{@"identifier": TELEMETRY_IDENTIFIER, @"data": payload};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];

    NSMutableURLRequest *request = [NSMutableURLRequest new];
    [request setURL:[NSURL URLWithString:TELEMETRY_URL]];
    [request setHTTPMethod:@"POST"];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long) jsonData.length];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error && retries > 0) {
            sleep(TELEMETRY_RETRY_DELAY);
            send_stats(retries - 1);
        }
    }] resume];
}

NSString *get_anonymous_identifier() {
    NSString *uuid = get_uuid();
    NSString *input = [uuid stringByAppendingString:TELEMETRY_SALT];
    NSData *inputData = [input dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *outputData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(inputData.bytes, (CC_LONG) inputData.length, outputData.mutableBytes);
    return data_to_hex(outputData);
}

NSString *get_uuid() {
    io_service_t platform_expert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
    if (!platform_expert) {
        return nil;
    }

    CFTypeRef serial = IORegistryEntryCreateCFProperty(platform_expert, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
    IOObjectRelease(platform_expert);
    if (!serial) {
        return nil;
    }

    return (__bridge NSString *) serial;
}

NSString *data_to_hex(NSData *data) {
    NSMutableString *buf = [NSMutableString stringWithCapacity:(2 * data.length)];
    const unsigned char *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        [buf appendFormat:@"%02x", bytes[i]];
    }
    return buf;
}
