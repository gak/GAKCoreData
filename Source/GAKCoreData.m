#import "GAKCoreData.h"
#import <objc/runtime.h>
#include <unistd.h>

@implementation DataManager

- (id) initWithDBName:(NSString *)name
{
    self = [super init];
    dbname = name;
    coordinator = 0;
    managedObjectContext = 0;
    return self;
}

#pragma mark -
#pragma mark Database Management

- (NSString *) getWriteDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

- (NSString *) getDatabasePath
{
    NSString *dbPath = [NSString stringWithFormat:@"%@/%@.db", [self getWriteDirectory], dbname];

    NSLog(@"Database: %@", dbPath);
    return dbPath;
}

- (void) wipeDatabase
{
    unlink([[self getDatabasePath] UTF8String]);
}

#pragma mark -
#pragma mark Core Data Initilisation

- (void) initManagedObjectContext
{
    NSURL *url = [NSURL fileURLWithPath:[self getDatabasePath]];
    assert(url);

    NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
    NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:bundles];
    assert(model);

    assert(!coordinator);
    coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    assert(coordinator);

    NSError *error;
    NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&error];
    if (!store) {

        // TODO: Better handling of error (recreate db?)
        NSLog(@"%@", [error localizedDescription]);

        // Meaning the database structure has changed. Wipe the database and reinitialise.
        // TODO: Work out migrations
        if ([error code] == 134100) {

            [self wipeDatabase];
            store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&error];

            if (!store) {

                NSLog(@"%@", [error localizedDescription]);
                abort();

            }

        }

    }

    assert(store);

    assert(!managedObjectContext);
    managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator: coordinator];
    assert(managedObjectContext);
}

#pragma mark -
#pragma mark Saving

- (void) save
{
    NSError *error;
    if (![managedObjectContext save:&error]) {
        NSLog(@"Error saving data: %@", error);
        assert(0);
    }
}

#pragma mark -
#pragma mark Copying

- (NSManagedObject *) shallowClone:(NSManagedObject *)source
{
    NSString *entityName = [[source entity] name];

    //create new object in data store
    NSManagedObject *cloned = [NSEntityDescription
                               insertNewObjectForEntityForName:entityName
                               inManagedObjectContext:managedObjectContext];

    //loop through all attributes and assign then to the clone
    NSDictionary *attributes = [[NSEntityDescription
                                 entityForName:entityName
                                 inManagedObjectContext:managedObjectContext] attributesByName];

    for (NSString *attr in attributes) {
        [cloned setValue:[source valueForKey:attr] forKey:attr];
    }

    return cloned;
}

#pragma mark -
#pragma mark Retreiving

- (NSArray *) getResults:(NSFetchRequest *)request
{
    return [managedObjectContext executeFetchRequest:request error:0];
}

- (NSEntityDescription *) getNewEntity:(NSString *)type
{
    return [NSEntityDescription insertNewObjectForEntityForName:type inManagedObjectContext:managedObjectContext];
}

- (NSFetchRequest *) getFetchRequest:(NSString *)entity
{
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity:[NSEntityDescription entityForName:entity inManagedObjectContext:managedObjectContext]];
    return request;
}

#pragma mark -
#pragma mark Querying

- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort predicate:(NSString *)predStr arguments:(va_list)args
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predStr arguments:args];

    // Check if the row exists
    NSFetchRequest *request = [self getFetchRequest:entityType];
    [request setPredicate:predicate];

    if (sort)
        [request setSortDescriptors:sort];
    
    return [self getResults:request];
}

- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort predicate:(NSString *)predStr, ...
{
    va_list args;
    va_start(args, predStr);
    return [self query:entityType sort:sort predicate:predStr arguments:args];
    va_end(args);
}

- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort
{
    NSFetchRequest *request = [self getFetchRequest:entityType];
    NSArray *results = [self getResults:request];
    return results;
}

- (id) getOrCreateEntity:(NSString *)entityType predicate:(NSString *)predStr, ...
{
    va_list args;
    va_start(args, predStr);
    NSArray *results = [self query:entityType sort:0 predicate:predStr arguments:args];
    va_end(args);

    // TODO: Make this an exception
    assert([results count] <= 1);

    NSEntityDescription *entity = 0;

    // If the row doesn't exist, we'll create a new one
    if (![results count]) {

        entity = [self getNewEntity:entityType];

    } else {

        entity = [results objectAtIndex:0];

    }

    return entity;
}

#pragma mark -
#pragma mark Deleting

- (void) deleteEntity:(NSString *)entityType predicate:(NSString *)predStr, ...
{
    va_list args;
    va_start(args, predStr);
    NSArray *results = [self query:entityType sort:0 predicate:predStr arguments:args];
    va_end(args);

    for (id ent in results) {
        [managedObjectContext deleteObject:ent];
    }
}

- (void) deleteEntity:(id)ent
{
    [managedObjectContext deleteObject:ent];
}

#pragma mark -
#pragma mark Helpers

- (NSEntityDescription *) updateModelFromDict:(NSString *)model dict:(NSDictionary *)dict idField:(NSString *)idField
{
    NSNumber *objId = [dict objectForKey:idField];
    NSEntityDescription *obj = [self getOrCreateEntity:model predicate:@"id = %@", objId];
    [self copyFromDictToModel:dict model:obj];

    return obj;
}

- (void) copyFromDictToModel:(NSDictionary *)dict model:(id)model
{
    for (NSPropertyDescription *property in [model entity]) {

        NSString *propertyName = [property name];

        id value = [dict objectForKey:propertyName];
        if (!value)
            continue;

        // you can coerce a nil to a NSString but not NSNull
        if (value == [NSNull null])
            value = nil;

        [model setValue:value forKey:propertyName];

    }
}

- (NSMutableDictionary *) getDictFromModel:(id)model
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];

    for (NSPropertyDescription *property in [model entity]) {

        NSString *propertyName = [property name];
        id value = [model valueForKey:propertyName];
        [dict setValue:value forKey:propertyName];

    }

    return dict;
}

@end
