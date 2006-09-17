//
//  DirectoryNode.h
//  Cog
//
//  Created by Vincent Spader on 8/20/2006.
//  Copyright 2006 Vincent Spader. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PathNode.h"

@interface DirectoryNode : PathNode
{
	NSMutableArray *subpaths;
	id controller;
}

-(id)initWithPath:(NSString *)p controller:(id) c;
- (NSArray *)subpaths;

@end
