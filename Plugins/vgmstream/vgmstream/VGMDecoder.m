//
//  VGMDecoder.m
//  vgmstream
//
//  Created by Christopher Snowhill on 02/25/14.
//  Copyright 2014 __NoWork, Inc__. All rights reserved.
//

#import "VGMDecoder.h"
#import "VGMInterface.h"

#import "PlaylistController.h"

@implementation VGMDecoder

- (BOOL)open:(id<CogSource>)s
{
    int track_num = [[[s url] fragment] intValue];
    
    NSString * path = [[s url] absoluteString];
    NSRange fragmentRange = [path rangeOfString:@"#" options:NSBackwardsSearch];
    if (fragmentRange.location != NSNotFound) {
        path = [path substringToIndex:fragmentRange.location];
    }

    stream = init_vgmstream_from_cogfile([[path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String], track_num);
    if ( !stream )
        return NO;
    
    sampleRate = stream->sample_rate;
    channels = stream->channels;
    totalFrames = get_vgmstream_play_samples( 2.0, 10.0, 10.0, stream );
    framesFade = stream->loop_flag ? sampleRate * 10 : 0;
    framesLength = totalFrames - framesFade;
    
    framesRead = 0;
    
    bitrate = get_vgmstream_average_bitrate(stream);

    [self willChangeValueForKey:@"properties"];
    [self didChangeValueForKey:@"properties"];
    
	return YES;
}

- (NSDictionary *)properties
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:bitrate / 1000], @"bitrate",
            [NSNumber numberWithInt:sampleRate], @"sampleRate",
            [NSNumber numberWithDouble:totalFrames], @"totalFrames",
            [NSNumber numberWithInt:16], @"bitsPerSample",
            [NSNumber numberWithBool:NO], @"floatingPoint",
            [NSNumber numberWithInt:channels], @"channels",
            [NSNumber numberWithBool:YES], @"seekable",
            @"host", @"endian",
            nil];
}

- (int)readAudio:(void *)buf frames:(UInt32)frames
{
    BOOL repeatone = IsRepeatOneSet();
    
    BOOL loopokay = repeatone && stream->loop_flag;
    
    if (!loopokay) {
        if (framesRead >= totalFrames) return 0;
        else if (framesRead + frames > totalFrames)
            frames = (UInt32)(totalFrames - framesRead);
    }

    sample * sbuf = (sample *) buf;
    
    render_vgmstream( sbuf, frames, stream );
    
    if ( !repeatone && framesFade && framesRead + frames > framesLength ) {
        long fadeStart = (framesLength > framesRead) ? framesLength : framesRead;
        long fadeEnd = (framesRead + frames) > totalFrames ? totalFrames : (framesRead + frames);
        long fadePos;
        long i;
        
        int64_t fadeScale = (int64_t)(totalFrames - fadeStart) * INT_MAX / framesFade;
        int64_t fadeStep = INT_MAX / framesFade;
        sbuf += (fadeStart - framesRead) * channels;
        for (fadePos = fadeStart; fadePos < fadeEnd; ++fadePos) {
            for (i = 0; i < channels; ++i) {
                sbuf[ i ] = (int16_t)((int64_t)(sbuf[ i ]) * fadeScale / INT_MAX);
            }
            sbuf += channels;
            fadeScale -= fadeStep;
            if (fadeScale <= 0) break;
        }
        frames = (UInt32)(fadePos - framesRead);
    }
    
    framesRead += frames;
    
    return frames;
}

- (long)seek:(long)frame
{
    // Constrain the seek offset to within the loop, if any
    if(stream->loop_flag && (stream->loop_end_sample - stream->loop_start_sample) && frame >= stream->loop_end_sample) {
        frame -= stream->loop_start_sample;
        frame %= (stream->loop_end_sample - stream->loop_start_sample);
        frame += stream->loop_start_sample;
    }
    
    if (frame < framesRead) {
        reset_vgmstream( stream );
        framesRead = 0;
    }
    
    while (framesRead < frame) {
        sample buffer[1024];
        long max_sample_count = 1024 / channels;
        long samples_to_skip = frame - framesRead;
        if ( samples_to_skip > max_sample_count )
            samples_to_skip = max_sample_count;
        render_vgmstream( buffer, (int)samples_to_skip, stream );
        framesRead += samples_to_skip;
    }
    
    return framesRead;
}

- (void)close
{
    close_vgmstream( stream );
    stream = NULL;
}

- (void)dealloc
{
    [self close];
}

+ (NSArray *)fileTypes 
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    size_t count;
    const char ** formats = vgmstream_get_formats(&count);
    
    for (size_t i = 0; i < count; ++i)
    {
        [array addObject:[NSString stringWithUTF8String:formats[i]]];
    }
    
    return array;
}

+ (NSArray *)mimeTypes 
{	
	return nil;
}

+ (float)priority
{
    return 0.0;
}

@end
