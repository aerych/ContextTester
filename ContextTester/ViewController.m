//
//  ViewController.m
//  ContextTester
//
//  Created by aerych on 8/13/15.
//  Copyright (c) 2015 Aerych. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "Topic.h"
#import "Post.h"

@interface ViewController ()
@property (nonatomic, strong) NSManagedObjectContext *childContextOne;
@property (nonatomic, strong) NSManagedObjectContext *childContextTwo;
@property (nonatomic, strong, readonly) NSManagedObjectContext *mainContext;
@end

@implementation ViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view, typically from a nib.

    [self deleteOldData];
    [self setupStartingData];

    self.childContextOne = [self createBackgroundChildContext];
    self.childContextTwo = [self createChildContext];

    [self testChangesInChildContext];
//    [self testDeleteInChildContext];
}

- (void)testChangesInChildContext
{
    NSString *newName = @"CHANGED";
    NSArray *childOneTopics = [self topicsForContext:self.childContextOne];

    //
    //  Change tha name of a topic in one of the contexts, but do not save yet
    //

    Topic *topicOne = childOneTopics.firstObject;
    topicOne.name = newName;


    //
    //  The change should not show up in a different context
    //

    NSError *error;
    Topic *topicTwo = (Topic *)[self.childContextTwo existingObjectWithID:topicOne.objectID error:&error];

    if ([topicTwo.name isEqualToString:newName]) {
        NSLog(@"UNSAVED NAME CHANGE AFFECTED SIBLING CONTEXT");
    }


    //
    //  Save the change to the parent context, but not the persistent store.
    //

    [self.childContextOne performBlockAndWait:^{
        NSError *error;
        [self.childContextOne save:&error];
    }];


    //
    //  The chanage should STILL not show up in a different context
    //

    topicTwo = (Topic *)[self.childContextTwo existingObjectWithID:topicOne.objectID error:&error];
    if ([topicTwo.name isEqualToString:newName]) {
        NSLog(@"SAVED NAME CHANGE AFFECTED SIBLING CONTEXT");
    }


    //
    //  Save the change to the persistent store.
    //

    [self.mainContext save:&error];
    topicTwo = (Topic *)[self.childContextTwo existingObjectWithID:topicOne.objectID error:&error];
    if (![topicTwo.name isEqualToString:newName]) {
        NSLog(@"PERSISTED NAME CHANGE DID NOT UPDATE IN SIBLING CHILD CONTEXT");
    }


    [self.childContextTwo reset];

    //
    //  Fetch topics in the sibling context and fire their faults.
    //

    NSArray *results = [self topicsForContext:self.childContextTwo];
    Topic *t1 = results.firstObject;
    [t1 name];
    Topic *t2 = results.lastObject;
    [t2 name];

    NSLog(@"%@", results);
}


- (void)testDeleteInChildContext
{
    NSArray *childOneTopics = [self topicsForContext:self.childContextOne];

    //
    //  Delete a topic in one of the contexts, but do not save yet
    //

    Topic *topicOne = childOneTopics.firstObject;
    NSManagedObjectID *deletedObjectID = topicOne.objectID;
    [self.childContextOne deleteObject:topicOne];

    //
    //  The topic should show isDeleted
    //
    if (!topicOne.isDeleted) {
        NSLog(@"THE DELETED TOPIC WAS NOT MARKED FOR DELETION");
    }


    //
    //  The change should not show up in a different context
    //

    NSError *error;
    Topic *topicTwo = (Topic *)[self.childContextTwo existingObjectWithID:deletedObjectID error:&error];
    if (!topicTwo || topicTwo.isDeleted) {
        NSLog(@"UNSAVED DELETION AFFECTED SIBLING CONTEXT");
    }


    //
    //  Save the change to the parent context, but not the persistent store.
    //

    [self.childContextOne performBlockAndWait:^{
        NSError *error;
        [self.childContextOne save:&error];
    }];


    //
    //  The chanage should STILL not show up in a different context
    //

    topicTwo = (Topic *)[self.childContextTwo existingObjectWithID:deletedObjectID error:&error];
    if (!topicTwo || topicTwo.isDeleted) {
        NSLog(@"SAVED DELETION AFFECTED SIBLING CONTEXT");
    }


    //
    //  Save the change to the persistent store.
    //

    [self.mainContext save:&error];
    topicTwo = (Topic *)[self.childContextTwo existingObjectWithID:deletedObjectID error:&error];
    if ( topicTwo ) {
        NSLog(@"PERSISTED DELETION DID NOT UPDATE IN SIBLING CHILD CONTEXT");
    }


    [self.childContextTwo reset];

    //
    //  Fetch topics in the sibling context and fire their faults.
    //

    NSArray *results = [self topicsForContext:self.childContextTwo];
    
    NSLog(@"%@", results);
}


- (NSArray *)topicsForContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Topic"];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:NO]];
    NSError *error;
    NSArray *results = [context executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    return results;
}


- (NSManagedObjectContext *)createChildContext
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc]
                                       initWithConcurrencyType:NSMainQueueConcurrencyType];
    context.parentContext = self.mainContext;
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

    return context;
}

- (NSManagedObjectContext *)createBackgroundChildContext
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc]
                                       initWithConcurrencyType:NSPrivateQueueConcurrencyType];

    context.parentContext = self.mainContext;
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

    return context;
}

- (NSManagedObjectContext *)mainContext
{
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    return appDelegate.managedObjectContext;
}

- (void)setupStartingData
{
    NSArray *topicNames = @[@"topicA", @"topicB"];
    NSArray *postNames = @[@"post1", @"post2", @"post3"];

    NSManagedObjectContext *context = self.mainContext;
    for (NSString *topicName in topicNames) {
        Topic *topic = [NSEntityDescription insertNewObjectForEntityForName:@"Topic"
                                                     inManagedObjectContext:context];
        topic.name = topicName;
        for (NSString *postName in postNames) {
            Post *post = [NSEntityDescription insertNewObjectForEntityForName:@"Post"
                                                       inManagedObjectContext:context];
            post.name = postName;
            post.topic = topic;
        }
    }
    NSError *error;
    [context save:&error];
}

- (void)deleteOldData
{
    NSManagedObjectContext *context = self.mainContext;

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Topic"];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:NO]];
    NSError *error;
    NSArray *results = [context executeFetchRequest:fetchRequest error:&error];

    for (NSManagedObject *obj in results) {
        [context deleteObject:obj];
    }
    [context save:&error];
}


@end
