#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface GAKCoreData: NSObject {

    NSString *dbname;
    NSPersistentStoreCoordinator *coordinator;
    NSManagedObjectContext *managedObjectContext;

}

- (id) initWithDBName:(NSString *)name;
- (NSString *) getWriteDirectory;
- (void) wipeDatabase;
- (void) save;
- (NSString *) getDatabasePath;

- (id) createEntity:(NSString *)type;

- (NSArray *) getResults:(NSFetchRequest *)request;
- (void) initManagedObjectContext;

- (NSFetchRequest *) getFetchRequest:(NSString *)entity;
- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort;
- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort predicate:(NSString *)predStr arguments:(va_list)args;
- (NSArray *) query:(NSString *)entityType sort:(NSArray *)sort predicate:(NSString *)predStr, ...;
- (id) getOrCreateEntity:(NSString *)entityType predicate:(NSString *)predStr, ...;

- (void) deleteEntity:(id)ent;
- (void) deleteEntity:(NSString *)entityType predicate:(NSString *)predStr, ...;

- (NSEntityDescription *) updateModelFromDict:(NSString *)model dict:(NSDictionary *)dict idField:(NSString *)idField;
- (NSEntityDescription *) updateModelFromDict:(NSString *)model dict:(NSDictionary *)dict;
- (void) copyFromDictToModel:(NSDictionary *)dict model:(id)model;
- (NSMutableDictionary *) getDictFromModel:(id)model;

- (NSManagedObject *) shallowClone:(NSManagedObject *)source;

@end
