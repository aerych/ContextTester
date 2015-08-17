//
//  Post.h
//  ContextTester
//
//  Created by aerych on 8/13/15.
//  Copyright (c) 2015 Aerych. All rights reserved.
//

#import <CoreData/CoreData.h>
@class Topic;
@interface Post : NSManagedObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) Topic *topic;
@end
