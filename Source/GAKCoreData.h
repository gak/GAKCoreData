#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface GAKCoreData: NSObject {

@private

    NSString *dbname;
    NSPersistentStoreCoordinator *coordinator;
    NSCache *queryCache;

@public

    NSManagedObjectContext *managedObjectContext;

}

- (id) initWithDBName:(NSString *)name;
- (NSString *) getWriteDirectory;
- (void) wipeDatabase;
- (void) save;
- (NSArray *) getResults:(NSFetchRequest *)request;
- (NSString *) getDatabasePath;
- (void) initManagedObjectContext;

- (NSEntityDescription *) getNewEntity:(NSString *)type;
- (NSFetchRequest *) getFetchRequest:(NSString *)entity;
- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort;
- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort predicate:(NSString *)predStr arguments:(va_list)args;
- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort predicate:(NSString *)predStr, ...;
- (id) getOrCreateEntity:(NSString *)entityType predicate:(NSString *)predStr, ...;
- (void) flushCache;

- (void) deleteEntity:(id)ent;
- (void) deleteEntity:(NSString *)entityType predicate:(NSString *)predStr, ...;

- (NSEntityDescription *) updateModelFromDict:(NSString *)model dict:(NSDictionary *)dict idField:(NSString *)idField;
- (void) copyFromDictToModel:(NSDictionary *)dict model:(id)model;
- (NSMutableDictionary *) getDictFromModel:(id)model;

- (NSManagedObject *) shallowClone:(NSManagedObject *)source;

@end
