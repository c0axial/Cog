//
//  MonkeysFile.m
//  zyVorbis
//
//  Created by Vincent Spader on 1/30/05.
//  Copyright 2005 Vincent Spader All rights reserved.
//

#import "MonkeysAudioDecoder.h"
#import "MAC/ApeInfo.h"
#import "MAC/CharacterHelper.h"

@implementation MonkeysAudioDecoder

- (BOOL)open:(NSURL *)url
{
	int n;
	str_utf16 *chars = NULL;

	chars = GetUTF16FromUTF8((const unsigned char *)[[url path] UTF8String]);
	if(chars == NULL)
		return NO;
	
	decompress = CreateIAPEDecompress(chars, &n);
	free(chars);

	if (decompress == NULL)
	{
		NSLog(@"ERROR OPENING FILE");
		return NO;
	}
	
	frequency = decompress->GetInfo(APE_INFO_SAMPLE_RATE);
	bitsPerSample = decompress->GetInfo(APE_INFO_BITS_PER_SAMPLE);
	channels = decompress->GetInfo(APE_INFO_CHANNELS);

	length = ((double)decompress->GetInfo(APE_INFO_TOTAL_BLOCKS)*1000.0)/frequency;

	return YES;
}

- (int)fillBuffer:(void *)buf ofSize:(UInt32)size
{
	int n;
	int numread;
	int blockAlign = decompress->GetInfo(APE_INFO_BLOCK_ALIGN);
	n = decompress->GetData((char *)buf, size/blockAlign, &numread);
	if (n != ERROR_SUCCESS)
	{
		NSLog(@"ERROR: %i", n);
		return 0;
	}
	numread *= blockAlign;
	
	return numread;
}

- (void)close
{
//	DBLog(@"CLOSE");
	if (decompress)
		delete decompress;
	
	decompress = NULL;
}

- (double)seekToTime:(double)milliseconds
{
	int r;
//	DBLog(@"HELLO: %i", int(frequency*((double)milliseconds/1000.0)));
	r = decompress->Seek(int(frequency*((double)milliseconds/1000.0)));
	
	return milliseconds;
}

- (NSDictionary *)properties
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:channels],@"channels",
		[NSNumber numberWithInt:bitsPerSample],@"bitsPerSample",
		[NSNumber numberWithFloat:frequency],@"sampleRate",
		[NSNumber numberWithDouble:length],@"length",
		@"little",@"endian",
		nil];
}

+ (NSArray *)fileTypes
{
	return [NSArray arrayWithObject:@"ape"];
}


@end